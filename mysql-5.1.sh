#!/bin/bash
# mysql-5.1.sh

########################################################
# 此脚本为子脚本，不要单独运行！
# Install mysql 5.1.x
# 此脚本包含 mysql 依赖包的安装，mysql 用二进制包安装
########################################################

# 应用全局函数
. ${script_path}/func

# 变量
# 此变量作为备份文件的后缀
cmd_exist date
bak_time=$(date +%s)

# 再次判断 mysql 是否已运行
if [ $flag_mysql -ne 0 ]; then
    echo_err "Mysql is running. SKIP installing. script EXIT."
    exit 1
fi

# 提示将用二进制安装
echo_std_impt "--> MYSQL 5.1.X USE BINARY PACKAGE(NON-COMPILE) TO INSTALL"
echo_std_impt "--> PACKAGE NAME LOOKS LIKE:"
echo_std_impt "--> mysql-5.1.72-linux-x86_64-glibc23.tar.gz"
#read -p "Enter to continue ..."

# 判断安装包是否对应系统位数
cmd_exist grep
if ! echo $mysql_pack | grep -q "$sys_arch"; then
    echo_err "You need download mysql $sys_arch package to install."
    exit 1
fi

# 先判断目标目录是否存在
if [ -d /usr/local/mysql/ ]; then
    #echo_err "/usr/local/mysql/: Directory has been exist. install FAILED."
    echo_std "INFO: /usr/local/mysql/: Directory has been exist."
    mv /usr/local/mysql/ /usr/local/mysql_backup_${bak_time}; cmd_ok
    echo_std_impt "--> mv /usr/local/mysql/ TO /usr/local/mysql_backup_${bak_time}"
fi

# 如果数据库目录不为空，初始化可能会失败，为了安装也不能覆盖原有数据
if [ -d /data/mysql/ ]; then
    #echo_err "/data/mysql/: Database directory NOT empty. STOP init mysql."
    echo_std "INFO: /data/mysql/: Directory has been exist."
    mv /data/mysql/ /data/mysql_backup_${bak_time}; cmd_ok
    echo_std_impt "--> mv /data/mysql/ TO /data/mysql_backup_${bak_time}"
fi

# 安装 mysql
echo_std "INFO: Unpacking $mysql_pack ..."
cd ${source_path}/; cmd_ok
tar xf $mysql_pack; cmd_ok
mysql_dir=$(find . -maxdepth 1 -type d | grep -E $inst_mysql_ver)
#echo $mysql_dir

# 检查 mysql 用户是否存在
if ! grep -q 'mysql' /etc/passwd; then
    useradd -s /sbin/nologin -M mysql; cmd_ok
fi
echo_std_impt "--> Installing $mysql_dir To /usr/local/mysql/ ..."
mv $mysql_dir /usr/local/mysql; cmd_ok

# 先复制配置文件，初始化时会加载配置文件
# 如果有旧的配置文件存在，可能初始化失败
cd /usr/local/mysql/support-files/; cmd_ok
if [ -f /etc/my.cnf ]; then
    mv /etc/my.cnf /etc/my.cnf_backup_${bak_time}; cmd_ok
    echo_std_impt "--> Old conf /etc/my.cnf move to /etc/my.cnf_backup_${bak_time}"
fi
cp my-large.cnf /etc/my.cnf; cmd_ok

# 初始化 mysql
cd /usr/local/mysql; cmd_ok
echo_std_impt "--> Database directory is /data/mysql/"
mkdir -p /data/mysql; cmd_ok
chown -R mysql:mysql /data/mysql; cmd_ok
echo_std "INFO: Starting init mysql ..."

# 初始化语句不能用 cmd_ok 判断是否成功，只能看是否返回两个 OK
./scripts/mysql_install_db --user=mysql --datadir=/data/mysql
echo_std "INFO: If you can see 'Installing MySQL system tables... OK' and 'Filling help tables... OK' mean mysql init SUCCESSFULLY."

# 复制配置文件
echo_std "INFO: Copying conf and service files ..."
cd support-files/; cmd_ok

# 脚本里的 cp 命令不会继承终端中设置的 alias，所以不带 -i 选项
# 如果配置文件存在，先备份
if [ -f /etc/init.d/mysqld ]; then
    mv /etc/init.d/mysqld /etc/init.d/mysqld_backup_${bak_time}; cmd_ok
    echo_std_impt "--> Old service script /etc/init.d/mysqld move to /etc/init.d/mysqld_backup_${bak_time}"
fi
cp mysql.server /etc/init.d/mysqld; cmd_ok
echo_std "INFO: Setting basedir and datadir in /etc/init.d/mysqld ..."
sed -i 's#^basedir=#basedir=/usr/local/mysql#' /etc/init.d/mysqld; cmd_ok
sed -i 's#^datadir=#datadir=/data/mysql#' /etc/init.d/mysqld; cmd_ok

# 加入开机启动
echo_std "INFO: Enable mysql when system start."
chkconfig mysqld on; cmd_ok

# 启动脚本不能用 cmd_ok 判断是否启动成，需要看启动脚本的输出内容
/etc/init.d/mysqld start
echo_std "INFO: You can run 'ps aux | grep mysql' or 'netstat -lnp | grep mysql' to check mysql is running or not."
echo_std_impt "DONE: Install mysql complete."
