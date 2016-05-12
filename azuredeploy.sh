#!/bin/bash

set -x
#set -xeuo pipefail

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

if [ $# != 6 ]; then
    echo "Usage: $0 <MasterHostname> <TemplateBaseUrl> <mountFolder> <numDataDisks> <dockerVer> <dockerComposeVer>"
    exit 1
fi

# Set user args
MASTER_HOSTNAME=$1
TEMPLATE_BASE_URL="$2"

# Shares
MNT_POINT="$3"
SHARE_HOME=$MNT_POINT/home
SHARE_DATA=$MNT_POINT/data
SHARE_BACKUP=$MNT_POINT/backup

numberofDisks="$4"
dockerVer="$5"
dockerComposeVer="$6"


# Installs all required packages.
#
install_pkgs()
{
    rpm --rebuilddb
    updatedb
    yum clean all
    yum -y install epel-release
    #yum  -y update --exclude=WALinuxAgent
    yum  -y update
    yum -y install zlib zlib-devel bzip2 bzip2-devel bzip2-libs openssl openssl-devel openssl-libs gcc gcc-c++ nfs-utils rpcbind git libicu libicu-devel make wget zip unzip mdadm wget
    wget -qO- "https://pgp.mit.edu/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e" 
    rpm --import "https://pgp.mit.edu/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e"
    yum install -y yum-utils
    yum-config-manager --add-repo https://packages.docker.com/$dockerVer/yum/repo/main/centos/7
    yum install -y docker-engine 
    systemctl stop firewalld
    systemctl disable firewalld
    service docker start
    wget https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.6.2.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    yum install -y binutils.x86_64 compat-libcap1.x86_64 gcc.x86_64 gcc-c++.x86_64 glibc.i686 glibc.x86_64 \
    glibc-devel.i686 glibc-devel.x86_64 ksh compat-libstdc++-33 libaio.i686 libaio.x86_64 libaio-devel.i686 libaio-devel.x86_64 \
    libgcc.i686 libgcc.x86_64 libstdc++.i686 libstdc++.x86_64 libstdc++-devel.i686 libstdc++-devel.x86_64 libXi.i686 libXi.x86_64 \
    libXtst.i686 libXtst.x86_64 make.x86_64 sysstat.x86_64
    curl -L https://github.com/docker/compose/releases/download/$dockerComposeVer/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
    curl -L https://github.com/docker/machine/releases/download/v0.7.0-rc1/docker-machine-`uname -s`-`uname -m` >/usr/local/bin/docker-machine && \
    chmod +x /usr/local/bin/docker-machine
    chmod +x /usr/local/bin/docker-compose
    export PATH=$PATH:/usr/local/bin/
    mv /etc/localtime /etc/localtime.bak
    ln -s /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
    #yum -y install icu patch ruby ruby-devel rubygems python-pip
    #yum install -y nodejs
    #yum install -y npm
    #npm install -g azure-cli
    # Setting tomcat
    #docker run -it -dp 80:8080 -p 8009:8009  rossbachp/apache-tomcat8
    docker run -dti --restart=always --name=azure-cli microsoft/azure-cli 
    docker run -it -d --restart=always -p 8080:8080 rancher/server
    systemctl enable docker
    #yum groupinstall -y "Infiniband Support"
    #yum install -y infiniband-diags perftest qperf opensm
    #chkconfig opensm on
    #chkconfig rdma on
    #reboot
}


setup_dynamicdata_disks()
{
    mountPoint="$1"
    createdPartitions=""

    # Loop through and partition disks until not found

if [ "$numberofDisks" == "1" ]
then
   disking=( sdc )
elif [ "$numberofDisks" == "2" ]; then
   disking=( sdc sdd )
elif [ "$numberofDisks" == "3" ]; then
   disking=( sdc sdd sde )
elif [ "$numberofDisks" == "4" ]; then
   disking=( sdc sdd sde sdf )
elif [ "$numberofDisks" == "5" ]; then
   disking=( sdc sdd sde sdf sdg )
elif [ "$numberofDisks" == "6" ]; then
   disking=( sdc sdd sde sdf sdg sdh )
elif [ "$numberofDisks" == "7" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi )
elif [ "$numberofDisks" == "8" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj )
elif [ "$numberofDisks" == "9" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk )
elif [ "$numberofDisks" == "10" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl )
elif [ "$numberofDisks" == "11" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm )
elif [ "$numberofDisks" == "12" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn )
elif [ "$numberofDisks" == "13" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo )
elif [ "$numberofDisks" == "14" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp )
elif [ "$numberofDisks" == "15" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq )
elif [ "$numberofDisks" == "16" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr )
fi

printf "%s\n" "${disking[@]}"

for disk in "${disking[@]}"
do
        fdisk -l /dev/$disk || break
        fdisk /dev/$disk << EOF
n
p
1


t
fd
w
EOF
        createdPartitions="$createdPartitions /dev/${disk}1"
done

    # Create RAID-0 volume
    if [ -n "$createdPartitions" ]; then
        devices=`echo $createdPartitions | wc -w`
        mdadm --create /dev/md10 --level 0 --raid-devices $devices $createdPartitions
        mkfs -t ext4 /dev/md10
        echo "/dev/md10 $mountPoint ext4 defaults,nofail 0 2" >> /etc/fstab
        mount /dev/md10
    fi
}
# Creates and exports two shares on the master nodes:
#
# /share/home (for HPC user)
# /share/data
#
# These shares are mounted on all worker nodes.
#
setup_shares()
{
    mkdir -p $SHARE_HOME
    mkdir -p $SHARE_DATA
    mkdir -p $SHARE_BACKUP

   # if is_master; then
        #setup_data_disks $SHARE_DATA
	setup_dynamicdata_disks $SHARE_DATA
        echo "$SHARE_HOME    *(rw,async)" >> /etc/exports
        echo "$SHARE_DATA    *(rw,async)" >> /etc/exports

        systemctl enable rpcbind || echo "Already enabled"
        systemctl enable nfs-server || echo "Already enabled"
        systemctl start rpcbind || echo "Already enabled"
        systemctl start nfs-server || echo "Already enabled"
    #else
    #    echo "master:$SHARE_HOME $SHARE_HOME    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
    #    echo "master:$SHARE_DATA $SHARE_DATA    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
    #    mount -a
    #    mount | grep "^master:$SHARE_HOME"
    #    mount | grep "^master:$SHARE_DATA"
    #fi
}

install_gallera()
{
#!/bin/bash
SERVERIP=`ifconfig eth0 | awk '/inet /{print substr($2,0)}'`

# Disabling SELinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Adding hosts configuration
cat >>/etc/hosts <<EOL
# West Europe

#East US

EOL

# Add MariaDB repo
cat >/etc/yum.repos.d/MariaDB.repo <<EOL
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=0
EOL

# Setting up the crontab
cat >/root/crontab.txt <<EOL
0       23      *       *       *       /usr/sbin/ntpdate pool.ntp.org > /dev/null
0       9       5       *       *       /usr/local/bin/archive_logfiles.sh
0       3       *       *       *       /usr/local/bin/backup-databases.sh
EOL
crontab /root/crontab.txt

# Setting up welcome message
cat >/etc/motd <<EOL
####################################################################
#  Server      : $HOSTNAME                                 #
#  IP          : $SERVERIP                                      #
#  OS          : Linux CentOS 7.2 x64                              #
#  Role        : MySQL Database East US #1                         #
#  Environment : Production                                        #
####################################################################
#  MySQL conf           : /etc/my.cnf                              #
#  MySQL Data dir       : /var/lib/mysql                           #
#  MySQL Backup dir     : /data/backup                             #
#  Daily Backup (cron)  : /usr/local/bin/backup-databases.sh       #
####################################################################
EOL



# Install MariaDB Cluster
yum -y install MariaDB-server MariaDB-client galera
systemctl enable mariadb
systemctl start mariadb

# Setting up MySQL
mysql -e "UPDATE mysql.user SET Password = PASSWORD('strong_pwd') WHERE User = 'root';"
mysql -e "CREATE USER 'ingenico-prod'@'%' IDENTIFIED BY 'strong_pwd';"
mysql -e "CREATE DATABASE ingenico_10_2_prod;"
mysql -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, TRIGGER ON ingenico_10_2_prod.* TO 'ingenico-prod'@'%';"
mysql -e "CREATE USER 'backupuser'@'localhost' IDENTIFIED BY 'strong_pwd';"
mysql -e "GRANT EVENT, LOCK TABLES, SELECT, SHOW DATABASES ON *.* TO 'backupuser'@'localhost';"
mysql -e "DROP USER ''@'localhost';"
mysql -e "DROP USER ''@'$(hostname)';"
mysql -e "DROP DATABASE test;"
mysql -e "FLUSH PRIVILEGES;"

# Setting up passwordless login
cat >>/etc/my.cnf.d/client.cnf <<EOL
user='root'
password=strong_pwd
EOL

# Adding to MySQL cluster
cat >/etc/my.cnf.d/server.cnf <<EOL
#
# These groups are read by MariaDB server.
# Use it for options that only the server (but not clients) should see
#
# See the examples of server my.cnf files in /usr/share/mysql/
#

# this is read by the standalone daemon and embedded servers
[server]

# this is only for the mysqld standalone daemon
[mysqld]
max_allowed_packet = 1073741824
innodb_buffer_pool_size = 2816M
innodb-flush-method = O_DIRECT
innodb_flush_log_at_trx_commit = 2
innodb_log_file_size=1000M
lower_case_table_names = 1
max_allowed_packet=100M
log-error=/var/log/mysqld.log

#
# * Galera-related settings
#
[galera]
# Mandatory settings
wsrep_on=ON
wsrep_provider=/usr/lib64/galera/libgalera_smm.so
wsrep_cluster_address='gcomm://'
wsrep_cluster_name='ingenico'
wsrep_node_address='$SERVERIP'
wsrep_node_name='$HOSTNAME'
wsrep_sst_method=rsync
binlog_format=row
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2

#
# Allow server to accept connections on all interfaces.
#
bind-address=0.0.0.0


# this is only for embedded server
[embedded]

# This group is only read by MariaDB servers, not by MySQL.
# If you use the same .cnf file for MySQL and MariaDB,
# you can put MariaDB-only options here
[mariadb]

# This group is only read by MariaDB-10.1 servers.
# If you use the same .cnf file for MariaDB of different versions,
# use this group for options that older servers don't understand
[mariadb-10.1]
EOL

galera_new_cluster

# Creating MySQL backup script
cat >/usr/local/bin/backup-databases.sh <<EOL
#!/bin/bash

DATE=`date +%d%m%Y_%H%M`
BACKUP_DIR="/data/backup"
echo "Backing up databases..."

# This section can be copied and repeated to backup multiple databases
DATABASE="ingenico_10_2_prod"
echo "Dumping ${DATABASE}..."
mysqldump \-u backupuser \--password=strong_pwd --max_allowed_packet=100M ${DATABASE} | gzip > ${BACKUP_DIR}/backup_${DATABASE}_${DATE}.sql.gz
echo "Done."

echo "Cleaning dumps older than 7 days..."
find ${BACKUP_DIR}/* -mtime +7 -delete
echo "Done."
EOL
chmod +x /usr/local/bin/backup-databases.sh
}

setup_shares
install_pkgs
install_gallera

