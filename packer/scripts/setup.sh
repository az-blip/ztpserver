#!/bin/sh -x

# Remove unnecessary packages
yum -y remove kbd
yum -y remove plymouth
yum -y remove uboot-tools

#Grab any updates and cleanup
yum -y update yum
yum -y update
yum -y clean all

#Install ztps-related related packages
yum -y install python-devel
yum -y install gcc make gcc-c++
yum -y install tar
yum -y install wget
yum -y install libyaml
yum -y install screen
yum -y install git
yum -y install net-tools
yum -y install tcpdump
yum -y install httpd
yum -y install httpd-devel
yum -y install dhcp
yum -y install bind bind-utils
yum -y install ejabberd


#Install Python 2.7.6
#cd /tmp
#wget http://www.python.org/ftp/python/2.7.6/Python-2.7.6.tar.xz
#xz -d Python-2.7.6.tar.xz
#tar -xvf Python-2.7.6.tar
#cd Python-2.7.6
#./configure --prefix=/usr/local
#make
#make altinstall


######################################
#INSTALL PIP
######################################
cd /tmp
wget https://bootstrap.pypa.io/get-pip.py
python get-pip.py

#Install Virtualenv
pip install virtualenv

######################################
# CONFIGURE FIREWALLd
######################################
#Disable firewalld
systemctl disable firewalld.service
systemctl stop firewalld.service
firewall-cmd --state

#Put Eth0 in the internal zone. Eth1 is already in the public zone
#firewall-cmd --permanent --zone=internal --change-interface=eth0
#Open port for 8080 ZTPS
#firewall-cmd --permanent --zone=internal --add-port=8080
#Open port for XMPP
#firewall-cmd --permanent --zone=internal --add-port=5222
#Open port for DNS
#firewall-cmd --permanent --zone=internal --add-port=53

######################################
# CONFIGURE SCREEN
######################################
cp /tmp/packer/screenrc /home/ztpserveradmin/.screenrc

######################################
# CONFIGURE rsyslog
######################################
mv /etc/rsyslog.conf /etc/rsyslog.conf.bak
cp /tmp/packer/rsyslog.conf /etc/rsyslog.conf
systemctl restart rsyslog.service
netstat -tuplen | grep syslog

######################################
# CONFIGURE eJabberd
######################################
mv /etc/ejabberd/ejabberd.cfg /etc/ejabberd/ejabberd.cfg.bak
cp /tmp/packer/ejabberd.cfg /etc/ejabberd/ejabberd.cfg
#echo -e "#Generated by packer (EOS+)\nsearch localdomain ztps-test.com\nname-server 172.16.130.10" > /etc/resolv.conf
echo -e "127.0.0.1 ztps ztps.ztps-test.com" >> /etc/hosts
ejabberdctl start
sleep 5
ejabberdctl status
systemctl enable ejabberd.service
ejabberdctl register ztpsadmin im.ztps-test.com eosplus
systemctl restart ejabberd.service
ejabberdctl status

######################################
# CONFIGURE APACHE AND INSTALL MODWSGI
######################################
cd /tmp
wget https://github.com/GrahamDumpleton/mod_wsgi/archive/4.1.3.tar.gz
tar xvfz 4.1.3.tar.gz
cd mod_wsgi-4.1.3
./configure
make
make install

mv /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak
cp /tmp/packer/httpd.conf /etc/httpd/conf/httpd.conf
systemctl restart httpd.service
systemctl enable httpd.service
systemctl status httpd.service

######################################
# CONFIGURE BIND
######################################
mv /etc/named.conf /etc/named.conf.bak
cp /tmp/packer/named.conf /etc/named.conf
cp /tmp/packer/ztps-test.com.zone /var/named/
service named restart
systemctl enable named.service
systemctl status named.service

######################################
# CONFIGURE DHCP
######################################
mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak
cp /tmp/packer/dhcpd.conf /etc/dhcp/dhcpd.conf
systemctl restart dhcpd.service
systemctl enable dhcpd.service
systemctl status dhcpd.service

######################################
# INSTALL ZTPSERVER
######################################
#mkdir /etc
cd /home/ztpsadmin

#clone from GitHub
git clone https://github.com/arista-eosplus/ztpserver.git -b release-1.0
cd ztpserver

#build/install
python setup.py build
python setup.py install