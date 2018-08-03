#!/bin/bash
# httpd-2.2.sh

#####################################
# 此脚本为子脚本，不要单独运行！
# 编译安装 httpd 2.2.x
#####################################

# 应用全局函数
. ${script_path}/func

# 变量
# 此变量作为备份文件的后缀
cmd_exist date
bak_time=$(date +%s)

# 再次判断 httpd 是否已运行
if [ $flag_httpd -ne 0 ]; then
    echo_err "Httpd is running. SKIP installing. script EXIT."
    exit 1
fi

# 安装依赖
# 暂时不需要

# 提示将用编译安装
echo_std_impt "--> HTTPD 2.2.X WILL INSTALL VIA COMPILE"
echo_std_impt "--> PACKAGE NAME LOOKS LIKE:"
echo_std_impt "--> httpd-2.2.34.tar.bz2"
#read -p "Enter to continue ..."

# 先判断目标目录是否存在
if [ -d /usr/local/apache2/ ]; then
    echo_std "INFO: /usr/local/apache2: Directory has been exist."
    mv /usr/local/apache2 /usr/local/apache2_backup_${bak_time}; cmd_ok
    echo_std_impt "--> mv /usr/local/apache2 TO /usr/local/apache2_backup_${bak_time}"
fi

# 编译安装 apache2
echo_std "INFO: Unpacking $web_pack ..."
cd ${source_path}/; cmd_ok
tar xf $web_pack; cmd_ok
web_dir=$(find . -maxdepth 1 -type d | grep -E $inst_web_ver)
cd ${web_dir}/; cmd_ok
#echo $web_dir
echo_std_impt "--> Installing apache2 To /usr/local/apache2/ ..."

# 配置编译选项和安装
# 防止配置和编译时大量输出覆盖掉有用信息，把结果导出到文件
echo_std "INFO: configure, make and make install info output to ./httpd.out"
./configure \
--prefix=/usr/local/apache2 \
--with-included-apr \
--enable-so \
--enable-deflate=shared \
--enable-expires=shared \
--enable-rewrite=shared \
--with-pcre > ${script_path}/httpd.out 2>&1
cmd_ok
make >> ${script_path}/httpd.out 2>&1 && make install >> ${script_path}/httpd.out 2>&1; cmd_ok

# 复制配文件
# 暂时不需要，因为配置文件在安装目录内

# 修改配置文件，防止提示没有域名错误
cmd_exist sed
sed -i 's/^#ServerName www.example.com:80/ServerName www.example.com:80/' /usr/local/apache2/conf/httpd.conf; cmd_ok
echo_std_impt "--> Enable 'ServerName www.example.com:80' in apache2/conf/httpd.conf"

# 启动 apache
echo_std "INFO: Starting httpd ..."
/usr/local/apache2/bin/apachectl start
echo_std "INFO: You can run 'ps aux | grep httpd' or 'netstat -lnp | grep httpd' to check httpd is running or not."
echo_std "INFO: Input 'http://ip_addr/' in web broswer(like chrome). You can see 'It works' if apache2 install successfully."
echo_std_impt "DONE: Install httpd complete."
