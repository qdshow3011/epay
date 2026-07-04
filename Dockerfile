FROM php:7.4-fpm-alpine

LABEL maintainer="epay"
LABEL description="聚合支付系统 Docker 镜像"

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 安装系统依赖和 PHP 扩展
RUN apk add --no-cache \
    nginx \
    mysql-client \
    curl \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    libxml2-dev \
    oniguruma-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    mysqli \
    gd \
    zip \
    bcmath \
    opcache \
    sockets \
    && apk del --no-cache libpng-dev libjpeg-turbo-dev freetype-dev libzip-dev libxml2-dev oniguruma-dev

# 安装 Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# 设置工作目录
WORKDIR /var/www/html

# 复制项目文件
COPY . .

# 安装 Composer 依赖
RUN composer install --no-dev --optimize-autoloader --no-interaction || true

# 设置 Nginx 配置
COPY docker/nginx.conf /etc/nginx/http.d/default.conf

# 复制启动脚本
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 创建必要目录并设置权限
RUN mkdir -p /var/www/html/assets/img/article \
    && mkdir -p /var/www/html/install \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 777 /var/www/html/assets/img/article \
    && chmod -R 777 /var/www/html/install

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# 启动命令
CMD ["/usr/local/bin/entrypoint.sh"]
