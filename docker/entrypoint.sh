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

# 确保 install.lock 存在（数据库已在 db-init.sh 中初始化）
if [ ! -f /var/www/html/install/install.lock ]; then
    echo "docker" > /var/www/html/install/install.lock
    echo "[entrypoint] 已创建 install.lock"
fi

# 确保 config.php 可写
chown www-data:www-data /var/www/html/config.php 2>/dev/null || true

# 启动 PHP-FPM（后台运行）
echo "[entrypoint] 启动 PHP-FPM..."
php-fpm -D

# 启动 Nginx（前台运行）
echo "[entrypoint] 启动 Nginx..."
exec nginx -g 'daemon off;'
