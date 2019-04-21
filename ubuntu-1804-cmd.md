# 常用Ubuntu操作(18.04)

## ssh免密碼登入控制

```shell-script
ssh-keygen -t ed25519
ssh-keyscan <host> >> .ssh/known_hosts
ssh-copy-id <user>@<host>
```

```shell-script
ssh-keygen -t ed25519
ssh <user>@<host> "mkdir ~/.ssh/"
cat ~/.ssh/id_ed25519.pub | ssh <user>@<host> "cat >> ~/.ssh/authorized_keys"
```

## 更改apt-mirror

```shell-script
# for ubuntu 18.04
sudo mv /etc/apt/sources.list /etc/apt/sources.list.old
sudo nano /etc/apt/sources.list
###############################
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
###############################
```

## 設定系統時間自動對時

```shell-script
sudo apt install -y ntp
sudo timedatectl set-timezone Asia/Taipei
sudo timedatectl set-ntp true
sudo timedatectl set-local-rtc false
sudo ntpq -p
timedatectl status
```

## 配置防火牆

```shell-script
sudo ufw allow <process or port>
sudo ufw allow from <ip>
sudo ufw allow from <ip> to any port <port>
sudo ufw enable
sudo ufw disable
sudo ufw status numbered
```

## 新增刪除使用者

```shell-script
sudo adduser <user>
sudo deluser <user>
```

## 開機port號自動轉傳

```shell-script
sudo nano /etc/rc.local
#######################
iptables -t nat -A PREROUTING -i <interface> -p tcp --dport <from port> -j REDIRECT --to-port <to port>
#######################
```

```shell-script
sudo apt install -y iptables-persistent
# 安裝時都選No
iptables -t nat -A PREROUTING -i <interface> -p tcp --dport <from port> -j REDIRECT --to-port <to port>
sudo netfilter-persistent save
```

## Certbot憑證

-   首先，先確認放在網站資源根目錄`<webroot>`裡的檔案可以被外部http請求拿到

```shell-script
sudo add-apt-repository ppa:certbot/certbot
sudo apt update
sudo apt install -y software-properties-common certbot
sudo certbot certonly --webroot -w <path_to_webroot> -d <domain_name>
sudo cp /etc/letsencrypt/live/<domain_name>/fullchain.pem <cert_dir>/fullchain.pem
sudo cp /etc/letsencrypt/live/<domain_name>/privkey.pem <cert_dir>/privkey.pem
```

## acme.sh憑證

-   首先，先確認放在網站資源根目錄`<webroot>`裡的檔案可以被外部http請求拿到

```shell-script
curl https://get.acme.sh | sh
acme.sh --issue -d <domain_name> -w <webroot>
acme.sh --install-cert -d <domain_name> --key-file <cert_dir>/privkey.pem --fullchain-file <cert_dir>/fullchain.pem
```

## pm2開機自動重啟

-   確定node進程正常啟動後

```shell-script
# enable
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u <user> --hp /home/<user>
# disable
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 unstartup systemd -u <user> --hp /home/<user>
```

## 開機自動掛載外接裝置

-   假設外接磁區已是ext4檔案系統

```shell-script
sudo blkid
# 找到欲掛載磁區的UUID
sudo nano /etc/fstab
####################
UUID=<UUID> <dir_to_be_mounted> ext4 defaults 0
####################
sudo mount <dir_to_be_mounted>
```

## mongodb備份與還原

```shell-script
mongodump --db <db_name> --out <backup_dir>
mongorestore <backup_dir>
```
