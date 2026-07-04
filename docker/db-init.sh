#!/bin/bash
# Docker MySQL 初始化脚本
# 将 install.sql 中的 pre_ 前缀替换为 pay_ 并导入数据库

set -e

echo "[init] 开始初始化 epay 数据库..."

# 等待 MySQL 就绪
until mysqladmin ping -h localhost --silent; do
    echo "[init] 等待 MySQL 启动..."
    sleep 2
done

# 检查是否已初始化
if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" -e "SELECT 1 FROM pay_config LIMIT 1;" 2>/dev/null; then
    echo "[init] 数据库已存在数据，跳过初始化"
    exit 0
fi

# 读取 install.sql 并替换前缀
SQL_FILE="/epay-install.sql"
if [ -f "$SQL_FILE" ]; then
    echo "[init] 正在导入数据库结构..."
    
    # 替换 pre_ 为 pay_ 并执行
    sed 's/pre_/pay_/g' "$SQL_FILE" | mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}"
    
    # 生成随机 syskey 和 cronkey 并插入
    SYSKEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
    CRONKEY=$(shuf -i 111111-999999 -n 1)
    
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" <<EOF
INSERT INTO \`pay_config\` VALUES ('syskey', '${SYSKEY}');
INSERT INTO \`pay_config\` VALUES ('build', '$(date +%Y-%m-%d)');
INSERT INTO \`pay_config\` VALUES ('cronkey', '${CRONKEY}');
EOF
    
    echo "[init] 数据库初始化完成！"
else
    echo "[init] 错误：未找到 install.sql 文件"
    exit 1
fi
