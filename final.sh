#!/bin/bash
# final.sh

########################################################
# 此脚本为子脚本，不要单独运行！
# 安装好 LAMP/LNMP 后的扫尾工作
########################################################

# 应用全局函数
. ${script_path}/func

# 提示
echo_std "INFO: Doing the final work ..."

# 修改 php.ini 的时区
if ! grep -q '^[^#]*date.timezone *= *"Asia/Shanghai"' /usr/local/php/etc/php.ini; then
    sed -i '/date.timezone =/a\date.timezone = "Asia/Shanghai"' /usr/local/php/etc/php.ini; cmd_ok
    echo_std_impt "--> Change 'date.timezone' to 'Asia/Shanghai' in php/etc/php.ini"
fi

# 测试 php 解析
if [ "$mod_php" == "so" ]; then
    echo_std "INFO: Restart apache2 httpd to load php5 SO module."
    /usr/local/apache2/bin/apachectl restart
    echo_std "INFO: You can run '/usr/local/apache2/bin/apachectl -M' to check SO module load or not."

    # 在 apache2 主配置文件 httpd.conf 指定行后追加一行
    if ! grep -q '^[^#]*AddType *application/x-httpd-php *.php' /usr/local/apache2/conf/httpd.conf; then
        sed -i '/AddType application\/x-gzip .gz .tgz/a\    AddType application\/x-httpd-php .php' /usr/local/apache2/conf/httpd.conf; cmd_ok
        echo_std_impt "--> Add a line 'AddType application/x-httpd-php .php' to apache2/conf/httpd.conf"
    fi
    
    # 添加索引 index.php
    if ! grep -q '^[^#]*DirectoryIndex *index.html *index.php' /usr/local/apache2/conf/httpd.conf; then
        sed -i 's/DirectoryIndex index.html/& index.php/' /usr/local/apache2/conf/httpd.conf; cmd_ok
        echo_std_impt "--> Add 'index.php' after 'DirectoryIndex index.html' in apache2/conf/httpd.conf"
    fi

    # 重载
    /usr/local/apache2/bin/apachectl graceful
elif [ "$mod_php" == "fpm" ]; then
    echo_std "----> Open 'location ~ \.php$ { ... }' section in /usr/local/nginx/conf/nginx.conf manually to SUPPORT php-parsing."
    echo_std "----> Then run '/etc/init.d/php-fpm restart; /usr/local/nginx/sbin/nginx -s reload'"
fi

# 编写测试文件
if [ "$mod_php" == "so" ]; then
    echo -e "<?php\n\tphpinfo();\n?>" > /usr/local/apache2/htdocs/info.php; cmd_ok
    echo_std "INFO: Input 'http://ip_addr/info.php' in web broswer(like chrome) to check php-parsing OK or not."
    echo_std_impt "--> WARNING: run 'rm -f /usr/local/apache2/htdocs/info.php' after php-parsing is OK."
elif [ "$mod_php" == "fpm" ]; then
    echo -e "<?php\n\tphpinfo();\n?>" > /usr/local/nginx/html/info.php; cmd_ok
    echo_std "INFO: Input 'http://ip_addr/info.php' in web broswer(like chrome) to check php-parsing OK or not."
    echo_std_impt "--> WARNING: run 'rm -f /usr/local/nginx/html/info.php' after php-parsing is OK."
fi
