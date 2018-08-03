#!/bin/bash
# php-5.6.sh

###############################################
# 此脚本为子脚本，不要单独运行！
# 编译安装 php，根据全局变量 mod_php 判断为
# apache 或 nginx 安装 php 支持
###############################################

# 应用全局函数
. ${script_path}/func

# 变量
# 此变量作为备份文件的后缀
cmd_exist date
bak_time=$(date +%s)

# 再次判断 php 是否已运行
if [ $flag_php -ne 0 ]; then
    echo_err "PHP is running. SKIP installing. script EXIT."
    exit 1
fi

# 安装依赖
echo_std "INFO: Checking dependent packages ..."
counter=0
packages="libjpeg-turbo-devel libmcrypt-devel libxml2-devel libcurl-devel libpng-devel freetype-devel"
for i in $packages; do
    if rpm -q $i >/dev/null 2>&1; then
        counter=$[$counter+1]
    fi
done
#echo $counter

if [ $counter -lt 6 ]; then
    yum install -y $packages; cmd_ok
fi

# 提示将编译安装 php
echo_std_impt "--> PHP 5.6.X WILL INSTALL VIA COMPILE"
echo_std_impt "--> PACKAGE NAME LOOKS LIKE:"
echo_std_impt "--> php-5.6.37.tar.xz"
#read -p "Enter to continue ..."

# 先判断目标目录是否存在
if [ -d /usr/local/php ]; then
    echo_std "INFO: /usr/local/php/: Directory has been exist."
    mv /usr/local/php/ /usr/local/php_backup_${bak_time}; cmd_ok
    echo_std_impt "--> mv /usr/local/php/ TO /usr/local/php_backup_${bak_time}"
fi

# 编译安装 php
echo_std "INFO: Unpacking $php_pack ..."
cd ${source_path}/; cmd_ok
tar xf $php_pack; cmd_ok
php_dir=$(find . -maxdepth 1 -type d | grep -E $inst_php_ver)
cd ${php_dir}/; cmd_ok
#echo $php_dir

# 判断安装 php 的类型
echo_std_impt "--> Installing PHP To /usr/local/php/ ..."
if [ "$mod_php" == "so" ]; then
    # 为 apache 安装
    # 配置编译选项和安装
    # 防止配置和编译时大量输出覆盖掉有用信息，把结果导出到文件
    echo_std "INFO: configure, make and make install info output to ./php.out"
    ./configure \
    --prefix=/usr/local/php \
    --with-apxs2=/usr/local/apache2/bin/apxs \
    --with-config-file-path=/usr/local/php/etc  \
    --with-mysql=mysqlnd \
    --with-mysqli=mysqlnd \
    --with-pdo-mysql=mysqlnd \
    --with-mysql-sock=/tmp/mysql.sock \
    --with-libxml-dir \
    --with-gd \
    --with-jpeg-dir \
    --with-png-dir \
    --with-freetype-dir \
    --with-iconv-dir \
    --with-zlib-dir \
    --with-bz2 \
    --with-openssl \
    --with-mcrypt \
    --enable-soap \
    --enable-gd-native-ttf \
    --enable-mbstring \
    --enable-sockets \
    --enable-exif \
    --disable-ipv6 > ${script_path}/php.out 2>&1
    cmd_ok
elif [ "$mod_php" == "fpm" ]; then
    echo_std "INFO: configure, make and make install info output to ./php.out"
    ./configure \
    --prefix=/usr/local/php \
    --with-config-file-path=/usr/local/php/etc \
    --enable-fpm \
    --with-fpm-user=php-fpm \
    --with-fpm-group=php-fpm \
    --with-mysql=mysqlnd \
    --with-mysqli=mysqlnd \
    --with-pdo-mysql=mysqlnd \
    --with-mysql-sock=/tmp/mysql.sock \
    --with-libxml-dir \
    --with-gd \
    --with-jpeg-dir \
    --with-png-dir \
    --with-freetype-dir \
    --with-iconv-dir \
    --with-zlib-dir \
    --with-mcrypt \
    --enable-soap \
    --enable-gd-native-ttf \
    --enable-ftp \
    --enable-mbstring \
    --enable-exif \
    --disable-ipv6 \
    --with-pear \
    --with-curl \
    --with-openssl > ${script_path}/php.out 2>&1
    cmd_ok
fi
make >> ${script_path}/php.out 2>&1 && make install >> ${script_path}/php.out 2>&1; cmd_ok

# 复制 php 主配置文件
cp php.ini-production /usr/local/php/etc/php.ini; cmd_ok
echo_std_impt "--> Copy $php_dir/php.ini-production To /usr/local/php/etc/php.ini"

# 修改 php.ini 的时区设置
# 暂时不需要

# 根据 php 类型，判断是否启动 php 服务，是否复制配置文件
if [ "$mod_php" == "fpm" ]; then
    # 备份旧的启动脚本
    if [ -f /etc/init.d/php-fpm ]; then
	mv /etc/init.d/php-fpm /etc/init.d/php-fpm_backup_${bak_time}; cmd_ok
        echo_std_impt "--> mv /etc/init.d/php-fpm TO /etc/init.d/php-fpm_backup_${bak_time}"
    fi
    cp sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm; cmd_ok
    chmod 755 /etc/init.d/php-fpm; cmd_ok
    cd /usr/local/php/etc/; cmd_ok
    cp php-fpm.conf.default php-fpm.conf; cmd_ok
    echo_std_impt "--> php-fpm.conf in /usr/local/php/etc/"

    # 创建 php-fpm 运行用户
    if ! grep -q 'php-fpm' /etc/passwd; then
        useradd -s /sbin/nologin -M php-fpm; cmd_ok
    fi

    # 加入开机启动
    echo_std "INFO: Enable php-fpm when system start."
    chkconfig php-fpm on; cmd_ok
    
    # 启动脚本不能用 cmd_ok 判断是否启动成，需要看启动脚本的输出内容
    echo_std "INFO: Starting php-fpm service ..."
    /etc/init.d/php-fpm start
    echo_std "INFO: You can run 'ps aux | grep php-fpm' or 'netstat -lnp | grep php-fpm' to check php is running or not."
fi
echo_std_impt "DONE: Install php complete."
