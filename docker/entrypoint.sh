#!/bin/sh
set -e

# 根据环境变量生成 config.php（仅在文件不存在或为空时）
if [ ! -f /var/www/html/config.php ] || [ ! -s /var/www/html/config.php ]; then
    cat > /var/www/html/config.php <<EOF
<?php
/*数据库配置*/
\$dbconfig=array(
    'host' => '${DB_HOST:-db}',
    'port' => ${DB_PORT:-3306},
    'user' => '${DB_USER:-epay}',
    'pwd' => '${DB_PASSWORD:-epay123}',
    'dbname' => '${DB_NAME:-epay}',
    'dbqz' => 'pay'
);
EOF
    echo "[entrypoint] 已根据环境变量生成 config.php"
fi

# 确保上传目录存在并可写
mkdir -p /var/www/html/assets/img/article
chown -R www-data:www-data /var/www/html/assets/img/article
chmod -R 777 /var/www/html/assets/img/article

# 确保目录权限
chown -R www-data:www-data /var/www/html/config.php /var/www/html/install 2>/dev/null || true

# 等待数据库就绪并初始化
echo "[entrypoint] 等待数据库就绪..."
MAX_RETRIES=30
RETRY=0
until mysqladmin ping -h "${DB_HOST:-db}" -P "${DB_PORT:-3306}" -u "${DB_USER:-epay}" -p"${DB_PASSWORD:-epay123}" --silent 2>/dev/null; do
    RETRY=$((RETRY+1))
    if [ $RETRY -ge $MAX_RETRIES ]; then
        echo "[entrypoint] 数据库连接超时，继续启动..."
        break
    fi
    echo "[entrypoint] 等待数据库启动... ($RETRY/$MAX_RETRIES)"
    sleep 2
done

# 检查数据库是否已初始化，如果没有则导入
if [ $RETRY -lt $MAX_RETRIES ]; then
    TABLE_CHECK=$(mysql -h "${DB_HOST:-db}" -P "${DB_PORT:-3306}" -u "${DB_USER:-epay}" -p"${DB_PASSWORD:-epay123}" "${DB_NAME:-epay}" -e "SELECT COUNT(*) FROM pay_config;" -s 2>/dev/null || echo "0")
    if [ "$TABLE_CHECK" = "0" ] || [ -z "$TABLE_CHECK" ]; then
        echo "[entrypoint] 数据库未初始化，开始导入..."
        if [ -f /var/www/html/install/install.sql ]; then
            sed 's/pre_/pay_/g' /var/www/html/install/install.sql | mysql -h "${DB_HOST:-db}" -P "${DB_PORT:-3306}" -u "${DB_USER:-epay}" -p"${DB_PASSWORD:-epay123}" "${DB_NAME:-epay}" 2>/dev/null
            SYSKEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
            CRONKEY=$(shuf -i 111111-999999 -n 1)
            mysql -h "${DB_HOST:-db}" -P "${DB_PORT:-3306}" -u "${DB_USER:-epay}" -p"${DB_PASSWORD:-epay123}" "${DB_NAME:-epay}" <<EOF 2>/dev/null
INSERT INTO \`pay_config\` VALUES ('syskey', '${SYSKEY}');
INSERT INTO \`pay_config\` VALUES ('build', '$(date +%Y-%m-%d)');
INSERT INTO \`pay_config\` VALUES ('cronkey', '${CRONKEY}');
EOF
            echo "[entrypoint] 数据库初始化完成"
        else
            echo "[entrypoint] 警告：install.sql 不存在"
        fi
    else
        echo "[entrypoint] 数据库已初始化 ($TABLE_CHECK 条配置)"
    fi
fi

# 确保 install.lock 存在
if [ ! -f /var/www/html/install/install.lock ]; then
    echo "docker" > /var/www/html/install/install.lock
    echo "[entrypoint] 已创建 install.lock"
fi

# 清除登录锁文件（避免之前的失败尝试导致锁定）
rm -f /var/www/html/admin/@login.lock 2>/dev/null || true

# 启动 PHP-FPM（后台运行）
echo "[entrypoint] 启动 PHP-FPM..."
php-fpm -D

# 启动 Nginx（前台运行）
echo "[entrypoint] 启动 Nginx..."
exec nginx -g 'daemon off;'
