# Ubuntu Note(for 18.04)

## SSH remote by key

```bash
ssh-keygen -t ed25519
ssh-keyscan <host> >> .ssh/known_hosts
ssh-copy-id <user>@<host>
```

```bash
ssh-keygen -t ed25519
ssh <user>@<host> "mkdir ~/.ssh/"
cat ~/.ssh/id_ed25519.pub | ssh <user>@<host> "cat >> ~/.ssh/authorized_keys"
```

## Change APT Server

```bash
# for ubuntu 18.04
sudo mv /etc/apt/sources.list /etc/apt/sources.list.old
sudo nano /etc/apt/sources.list
########################################################
deb http://free.nchc.org.tw/ubuntu bionic main restricted
deb-src http://free.nchc.org.tw/ubuntu bionic main restricted
deb http://free.nchc.org.tw/ubuntu bionic-updates main restricted
deb-src http://free.nchc.org.tw/ubuntu bionic-updates main restricted
deb http://free.nchc.org.tw/ubuntu bionic universe
deb-src http://free.nchc.org.tw/ubuntu bionic universe
deb http://free.nchc.org.tw/ubuntu bionic-updates universe
deb-src http://free.nchc.org.tw/ubuntu bionic-updates universe
deb http://free.nchc.org.tw/ubuntu bionic multiverse
deb-src http://free.nchc.org.tw/ubuntu bionic multiverse
deb http://free.nchc.org.tw/ubuntu bionic-updates multiverse
deb-src http://free.nchc.org.tw/ubuntu bionic-updates multiverse
deb http://free.nchc.org.tw/ubuntu bionic-backports main restricted universe multiverse
deb-src http://free.nchc.org.tw/ubuntu bionic-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu bionic-security main restricted
deb-src http://security.ubuntu.com/ubuntu bionic-security main restricted
deb http://security.ubuntu.com/ubuntu bionic-security universe
deb-src http://security.ubuntu.com/ubuntu bionic-security universe
deb http://security.ubuntu.com/ubuntu bionic-security multiverse
deb-src http://security.ubuntu.com/ubuntu bionic-security multiverse
########################################################
```

## Setup ntp

```bash
sudo apt install -y ntp
sudo timedatectl set-timezone Asia/Taipei
sudo timedatectl set-ntp true
sudo timedatectl set-local-rtc false
sudo ntpq -p
timedatectl status
```

## Setup ufw

```bash
sudo ufw allow <process or port>
sudo ufw allow from <ip>
sudo ufw allow from <ip> to any port <port>
sudo ufw enable
sudo ufw disable
sudo ufw status numbered
```

## Add/delete user

```bash
sudo adduser <user>
sudo deluser <user>
```

## Forward routing on system boot

```bash
sudo nano /etc/rc.local
#######################
iptables -t nat -A PREROUTING -i <interface> -p tcp --dport <from port> -j REDIRECT --to-port <to port>
#######################
```

```bash
sudo apt install -y iptables-persistent
# 'No' in installation
iptables -t nat -A PREROUTING -i <interface> -p tcp --dport <from port> -j REDIRECT --to-port <to port>
sudo netfilter-persistent save
```

## HTTPS certification using Certbot

- First, check files in `<webroot>` directory could be access by http GET.

```bash
sudo add-apt-repository ppa:certbot/certbot
sudo apt update
sudo apt install -y software-properties-common certbot
sudo certbot certonly --webroot -w <path_to_webroot> -d <domain_name>
sudo cp /etc/letsencrypt/live/<domain_name>/fullchain.pem <cert_dir>/fullchain.pem
sudo cp /etc/letsencrypt/live/<domain_name>/privkey.pem <cert_dir>/privkey.pem
```

## HTTPS certification using acme.sh

- First, check files in `<webroot>` directory could be access by http GET.

```bash
curl https://get.acme.sh | sh
acme.sh --issue -d <domain_name> -w <webroot>
acme.sh --install-cert -d <domain_name> --key-file <cert_dir>/privkey.pem --fullchain-file <cert_dir>/fullchain.pem
```

## pm2 auto startup when reboot

- Check if `node` process is running.

```bash
# enable
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u <user> --hp /home/<user>
# disable
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 unstartup systemd -u <user> --hp /home/<user>
```

## Mount external volumes on system boot

- External volume is formatted to `ext4`

```bash
sudo blkid
# find UUID to mount
sudo nano /etc/fstab
####################
UUID=<UUID> <dir_to_be_mounted> ext4 defaults 0
####################
sudo mount <dir_to_be_mounted>
```

## MongoDB backup and restore

```bash
mongodump --db <db_name> --out <backup_dir>
mongorestore <backup_dir>
```
