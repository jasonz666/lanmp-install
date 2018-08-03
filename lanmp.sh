#!/bin/bash
# lanmp.sh

########################################################################
# Compile and install apache/nginx mysql and php.
# Script will exit if lanmp has been installed before.
# This script only supports CentOS 6.
# You can select following apache/nginx/mysql/php versions to install:
# Mysql 5.1.x/5.6.x
# PHP 5.4.x/5.6.x
# Nginx 1.8.x or Apache 2.2.x
# Written by Jason at 2018-07-23.
########################################################################

##################
# 全局变量
##################

# 子脚本需要用到以下变量
# 获取脚本所在的绝对路径
export script_path="$( cd "`dirname $0`"; pwd )"

# $1 必须使用绝对路径 !!!
# 否则可能因为定义 script_path 时执行 cd 造成 $1 路径混乱
export source_path="$1"
export sys_arch=
export mysql_pack=
export php_pack=
export web_pack=

# 确定需要安装版本的 grep 过滤式
# 过滤式主要用来确定源码包名 和 对应的子脚本名
export inst_mysql_ver=
export inst_php_ver=
export inst_web_ver=

# 应用全局函数
# 子脚本也需要调用这些函数
. ${script_path}/func

# 定义可能安装的版本
# 主要用于在 select 语句里选择需要安装的版本
ver_httpd="httpd-2.2.x"
ver_nginx="nginx-1.8.x"
ver_mysql1="mysql-5.1.x"
ver_mysql2="mysql-5.6.x"
ver_php1="php-5.4.x"
ver_php2="php-5.6.x"

# grep 过滤版本的表达式
grep_httpd="httpd-2.2.[a-zA-Z0-9]+"
grep_nginx="nginx-1.8.[a-zA-Z0-9]+"
grep_mysql1="mysql-5.1.[a-zA-Z0-9]+"
grep_mysql2="mysql-5.6.[a-zA-Z0-9]+"
grep_php1="php-5.4.[a-zA-Z0-9]+"
grep_php2="php-5.6.[a-zA-Z0-9]+"

# 判断 apache/nginx/mysql/php 是否存在的标记
# 存在状态包括进程正在运行，检查到可执行程序
# 存在标记用于决定是否需要安装对应的程序
export flag_httpd=0
export flag_nginx=0
export flag_mysql=0
export flag_php=0

# 编译安装 php 的哪种模式
# 值 "so" 表示支持 apache，值 "fpm" 支持 nginx
export mod_php=""

############################
# 主程序
############################

## 用法提示
if [ $# -ne 1 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Usage: ./lanmp.sh SOURCE_DIR" 1>&2
    echo 1>&2
    echo "SOURCE_DIR: The directory includes httpd/nginx/mysql/php source code packages. Such as /usr/local/src/" 1>&2
    echo 1>&2
    echo "ATTENTION: SOURCE_DIR must be an ABSOLUTE PATH." 1>&2
    exit 1
fi

# 检查源码存放目录可用性
cmd_exist grep
if [ ! -d ${source_path} ]; then
    echo_err "SOURCE_DIR '$1' not exist."
    echo_err "RUN: './lanmp.sh -h' for help."
    exit 1
elif ! echo ${source_path} | grep -q '^/'; then
    echo_err "SOURCE_DIR must be an ABSOLUTE PATH."
    echo_err "RUN: './lanmp.sh -h' for help."
    exit 1
fi

## 提示信息
echo_std "INFO: It will install LAMP or LNMP."
echo_std "INFO: Install order is mysql --> apache/nginx --> php"

## 检查系统版本
echo_std "INFO: Checking operationg system version ..."
if [ -f /etc/centos-release ] && grep -qi 'centos release 6' /etc/centos-release
then
    :;
else
    # 输出错误信息到 stderr
    # 错误信息带脚本名称以便排除
    echo_err "This system is not CentOS 6. install FAILED."
    # 关键错误立即退出脚本，返回码1
    # 如果调用子脚本执行失败，判断子脚本返回非0时，主脚本退出，返回码2
    exit 1
fi

## 获取系统架构
cmd_exist arch
sys_arch=`arch`
if [ "$sys_arch" != "" ]; then
    echo_std "INFO: Your system architecture is ${sys_arch}."
else
    echo_err "Get system architecture FAILED. Binary install mysql can not be continued."
    exit 1
fi

## 检查 selinux 和防火墙
echo_std "INFO: Checking selinux and iptables status ..."
if [ `getenforce` != "Disabled" ]; then
    echo_err "You need DISABLE selinux."
    exit 1
else
    echo_std "--> selinux disabled"
fi
echo_std_impt "--> RUN: iptables -F"
iptables -F

## 检测 apache, nginx, mysql, php 是否运行
# 如果全部 anmp 都在运行就可以退出脚本
echo_std "INFO: Checking apache/nginx/mysql/php running or not ..."
n_httpd=`ps aux | grep 'bin/httpd' | wc -l`
if [ $n_httpd -gt 1 ]; then
    echo_std_impt "--> Httpd is running."
    flag_httpd=1
fi
n_nginx=`ps aux | grep 'bin/nginx' | wc -l`
if [ $n_nginx -gt 1 ]; then
    echo_std_impt "--> Nginx is running."
    flag_nginx=1
fi
n_php=`ps aux | grep 'php-fpm' | wc -l`
if [ $n_php -gt 1 ]; then
    echo_std_impt "--> PHP is running."
    flag_php=1
fi
n_mysql=`ps aux | grep 'bin/mysql' | wc -l`
if [ $n_mysql -gt 1 ]; then
    echo_std_impt "--> Mysql is running."
    flag_mysql=1
fi
tmp_flag=$((flag_httpd + flag_nginx + flag_php + flag_mysql))
#echo $flag_httpd $flag_nginx $flag_php $flag_mysql $tmp_flag
if [ $tmp_flag -eq 3 ]; then
    echo_err "Apache/mysql/php or Nginx/mysql/php is running. script EXIT."
    exit 1
fi

## 检查是否安装过 apache, nginx, mysql, php
echo_std "INFO: Checking installed apache/nginx/mysql/php ..." 
cmd_exist find
#find / -type f > ${script_path}/find.tmp
find / ! -path "/sys*" ! -path "/boot*" ! -path "/dev*" ! -path "/proc*" ! -path "/tmp*" -type f > ${script_path}/find.tmp
is_httpd=$(grep 'bin/apachectl$' ${script_path}/find.tmp)
is_nginx=$(grep 'bin/nginx$' ${script_path}/find.tmp)
is_mysql=$(grep 'bin/mysql$' ${script_path}/find.tmp)
is_php=$(grep 'bin/php$' ${script_path}/find.tmp)
cmd_exist rm
rm -f ${script_path}/find.tmp

# 如果已发现有安装存在询问是否继续
if [ "$is_httpd" != "" ] || [ "$is_nginx" != "" ] || [ "$is_mysql" != "" ] || [ "$is_php" != "" ]; then
    echo_std "[ $is_httpd, $is_nginx, $is_mysql, $is_php ]"
    echo_std "INFO: You have installed apache/nginx/mysql/php before."
    read -p "Do you want to continue? (yes/no) " ret_str
    if [ "$ret_str" != "yes" ]; then
        exit 1
    fi
fi

## 安装 epel 扩展源
echo_std "INFO: Checking EPEL installed or not ..."
if ! yum repolist 2>/dev/null | grep -q epel; then
    yum install -y epel-release; cmd_ok
else
    echo_std "INFO: EPEL has been installed."
fi

##############################
# 安装 LANMP
##############################

#### 选择需要安装的 mysql 版本
# 如果 mysql 正在运行，跳过安装
if [ $flag_mysql -eq 0 ]; then
    echo_std "INFO: Which mysql do you want to install?"
    select mysql_ver in $ver_mysql1 $ver_mysql2; do
        case $mysql_ver in
            $ver_mysql1)
                echo_std "You choose $ver_mysql1 to install."
                inst_mysql_ver=$grep_mysql1
                break
                ;;
            $ver_mysql2)
                echo_std "You choose $ver_mysql2 to install."
                inst_mysql_ver=$grep_mysql2
                break
                ;;
            *)
                ;;
        esac
    done
    #echo $inst_mysql_ver

    echo_std "INFO: Checking mysql source code packages ..."
    cd ${source_path}/; cmd_ok
    mysql_pack=$(find . -maxdepth 1 -type f | grep -E "$inst_mysql_ver" | grep -iE "(gz|bz2|xz|zip)$")
    if [ "$mysql_pack" == "" ]; then
        echo_err "Mysql source code package not found in $source_path"
        exit 1
    fi
    #echo $mysql_pack

    # 调用安装 mysql 脚本
    cd ${script_path}/; cmd_ok
    mysql_sh=$(find . -maxdepth 1 -type f | grep -E "$inst_mysql_ver" | grep -i "sh$")
    if [ "$mysql_sh" != "" ]; then
        /bin/bash ${script_path}/${mysql_sh}
        if [ $? -ne 0 ]; then
            echo_err "${mysql_sh}: Sub-script run FAILED."
            exit 2
        fi
    fi
else
    echo_std "INFO: Mysql is running. SKIP installing."
fi

#### 选择需要安装 apache 或 nginx
# 只有 apache/nginx 都没有运行，选择才有意义
if [ $flag_httpd -eq 0 -a $flag_nginx -eq 0 ]; then
    echo_std "INFO: Which web app do you want to install?"
    select web_ver in $ver_httpd $ver_nginx; do
        case $web_ver in
            $ver_httpd)
                echo_std "You choose $ver_httpd to install."
                inst_web_ver=$grep_httpd
                break
                ;;
            $ver_nginx)
                echo_std "You choose $ver_nginx to install."
                inst_web_ver=$grep_nginx
                break
                ;;
            *)
                ;;
        esac
    done
    #echo inst_web_ver

    echo_std "INFO: Checking source code package ..."
    cd ${source_path}/; cmd_ok
    web_pack=$(find . -maxdepth 1 -type f | grep -E "$inst_web_ver" | grep -iE "(gz|bz2|xz|zip)$")
    if [ "$web_pack" == "" ]; then
        echo_err "Web app source code package not found in $source_path"
        exit 1
    fi
    #echo $web_pack

    # 调用安装 apache/nginx 脚本
    cd ${script_path}/; cmd_ok
    web_sh=$(find . -maxdepth 1 -type f | grep -E "$inst_web_ver" | grep -i "sh$")
    if [ "$web_sh" != "" ]; then
        /bin/bash ${script_path}/${web_sh}
        if [ $? -ne 0 ]; then
            echo_err "${web_sh}: Sub-script run FAILED."
            exit 2
        fi
    fi
else
    # 只要 apache/nginx 之一在运行，就可以跳过安装
    echo_std "INFO: Httpd or Nginx is running. SKIP installing."
fi
#echo $inst_web_ver

#### 选择需要安装的 php 版本
# 编译安装 php 5.4, php 5.6 大同小异，这里选 php 5.6.x
if [ $flag_php -eq 0 ]; then
    # Don't select php if apache or nginx is running
    if [ $flag_httpd -eq 1 ]; then
        echo_std_impt "INFO: Httpd is running. It will install php so(shared object)."
        mod_php="so"
    elif [ $flag_nginx -eq 1 ]; then
        echo_std_impt "INFO: Nginx is running. It will install php-fpm"
        mod_php="fpm"
    else
        echo_std "INFO: Which php do you want to install?"
        # 选择安装 apache/php 还是 nginx/php-fpm
        select pick_mod in "php-so for apache2" "php-fpm for nginx"; do
            case $pick_mod in
                "php-so for apache2")
                    echo_std "You choose to compile php shared object(so) file for apache2"
                    mod_php="so"
                    break
                    ;;
                "php-fpm for nginx")
                    echo_std "You choose to compile php-fpm for nginx"
                    mod_php="fpm"
                    break
                    ;;
                *)
                    ;;
            esac
        done
        #echo $mod_php
    fi

    # 选取源码包名
    echo_std "INFO: Checking php source code package ..."
    inst_php_ver=$grep_php2
    cd ${source_path}/; cmd_ok
    php_pack=$(find . -maxdepth 1 -type f | grep -E "$inst_php_ver" | grep -iE "(gz|bz2|xz|zip)$")
    if [ "$php_pack" == "" ]; then
        echo_err "PHP source code package not found in $source_path"
        exit 1
    fi

    # 安装 php
    cd ${script_path}/; cmd_ok
    php_sh=$(find . -maxdepth 1 -type f | grep -E "$inst_php_ver" | grep -i "sh$")
    if [ "$php_sh" != "" ]; then
        /bin/bash ${script_path}/${php_sh}
        if [ $? -ne 0 ]; then
            echo_err "${php_sh}: Sub-script run FAILED."
            exit 2
        fi
    fi
else
    echo_std "INFO: PHP is running. SKIP installing."
fi

## 扫尾工作
/bin/bash ${script_path}/final.sh
if [ $? -ne 0 ]; then
    echo_err "${php_sh}: Sub-script run FAILED."
    exit 2
fi

#### 完成
echo_std "DONE: LAMP/LNMP install complete. Byebye."
