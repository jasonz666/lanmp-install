#!/bin/bash
# nginx-1.8.sh

#################################
# 此脚本为子脚本，不要单独运行！
# 编译安装 nginx 1.8.x
#################################

# 应用全局函数
. ${script_path}/func

# 变量
# 此变量作为备份文件的后缀
cmd_exist date
bak_time=$(date +%s)

# 再次判断 nginx 是否已运行
if [ $flag_nginx -ne 0 ]; then
    echo_err "Nginx is running. SKIP installing. script EXIT."
    exit 1
fi

# 安装依赖
yum install -y pcre-devel

# 提示将用编译安装
echo_std_impt "--> NGINX 1.8.X WILL INSTALL VIA COMPILE"
echo_std_impt "--> PACKAGE NAME LOOKS LIKE:"
echo_std_impt "--> nginx-1.8.1.tar.gz"
#read -p "Enter to continue ..."

# 先判断目标目录是否存在
if [ -d /usr/local/nginx/ ]; then
    echo_std "INFO: /usr/local/nginx: Directory has been exist."
    mv /usr/local/nginx /usr/local/nginx_backup_${bak_time}; cmd_ok
    echo_std_impt "--> mv /usr/local/nginx TO /usr/local/nginx_backup_${bak_time}"
fi

# 编译安装 nginx
echo_std "INFO: Unpacking $web_pack ..."
cd ${source_path}/; cmd_ok
tar xf $web_pack; cmd_ok
web_dir=$(find . -maxdepth 1 -type d | grep -E $inst_web_ver)
cd ${web_dir}/; cmd_ok
#echo $web_dir
echo_std_impt "--> Installing nginx To /usr/local/nginx/ ..."

# 配置编译选项和安装
# 防止配置和编译时大量输出覆盖掉有用信息，把结果导出到文件
echo_std "INFO: configure, make and make install info output to ./nginx.out"
./configure \
--prefix=/usr/local/nginx \
--with-http_realip_module \
--with-http_sub_module \
--with-http_gzip_static_module \
--with-http_stub_status_module \
--with-pcre > ${script_path}/nginx.out 2>&1
cmd_ok
make >> ${script_path}/nginx.out 2>&1 && make install >> ${script_path}/nginx.out 2>&1; cmd_ok

# 复制配文件
# 暂时不需要，因为配置文件在安装目录内

# 启动 nginx
echo_std "INFO: Starting nginx ..."
/usr/local/nginx/sbin/nginx; cmd_ok
echo_std "INFO: You can run 'ps aux | grep nginx' or 'netstat -lnp | grep nginx' to check nginx is running or not."
echo_std "INFO: Input 'http://ip_addr/' in web broswer(like chrome) to access nginx."
echo_std_impt "DONE: Install nginx complete."
