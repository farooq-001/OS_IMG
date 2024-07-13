#!/bin/bash
APP_PATH=/opt/SNB-TECH
LOG_PATH=/var/log
LOG_FILE=snb-tech-sysprep.log

SE_CONFIG=/etc/selinux/config
SUDOERS=/etc/sudoers

SNB_USER=babafarooq
SNB_PASSWD='babafarooq001@'

exec > >(tee -i $LOG_PATH/$LOG_FILE)
exec 2>&1

prompt_confirm() {
  while true; do
    read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
    case $REPLY in
      [yY]) echo ; return 0 ;;
      [nN]) echo ; return 1 ;;
      *) printf " \033[31m %s \n\033[0m" "Invalid input"
    esac 
  done  
}

if [ "$USER" != "root" ]; then
    echo ""
    echo 'Invalid User!!! Please login as root and rerun the script.'
    echo ""
    exit 0
fi

echo -n "Checking for Internet access..."
IP=$(curl -s ipinfo.io/ip 2> /dev/null)
if [[ $? -eq 0 ]]; then
    echo " Online."
    echo ""
else
    echo " Offline."
    echo ""
    echo "Check internet access and rerun script. Terminating Script!"
    exit 1
fi

if [ -f "$SE_CONFIG" ] && grep -q SELINUX=enforcing "$SE_CONFIG"; then
    sed -i "s/^SELINUX=enforcing.*$/SELINUX=permissive/g" $SE_CONFIG
    echo ""
    echo "SELinux in enforcing mode, changed to permissive."
    echo ""
fi

sed -i 's/#PermitRootLogin/PermitRootLogin/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart ssh

if ! id -u $SNB_USER &>/dev/null; then
    echo ""
    echo "Adding user $SNB_USER."
    adduser --disabled-password --gecos "" $SNB_USER
    echo "$SNB_USER:$SNB_PASSWD" | chpasswd
    usermod -aG sudo $SNB_USER
    echo ""
fi

if ! grep -q $SNB_USER "$SUDOERS"; then
    echo ""
    echo "Adding $SNB_USER user to $SUDOERS"
    echo "$SNB_USER     ALL=(ALL)       NOPASSWD: ALL" >> $SUDOERS
    echo ""
fi

echo "Changing timezone to UTC.."
timedatectl set-timezone UTC
localectl set-locale LANG=en_US.UTF-8

apt update
apt -y install software-properties-common
add-apt-repository universe
apt update

apt -y install htop vim nano net-tools wget firewalld tar tcpdump netcat bind9-utils language-pack-en

echo 'export HISTTIMEFORMAT="%y/%m/%d %T "' >> /etc/profile.d/snb-profile.sh
echo 'export HISTSIZE=100000' >> /etc/profile.d/snb-profile.sh
echo 'export HISTFILESIZE=100000' >> /etc/profile.d/snb-profile.sh
chmod +x /etc/profile.d/SNBprofile.sh

systemctl enable firewalld
systemctl start firewalld

mkdir -p /opt/SNB-TECH
touch /opt/SNB-TECH/.sysprep
echo "Sysprep completed."
echo ""
