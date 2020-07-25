#! /bin/bash
brew tap cloudflare/cloudflare
brew install cloudflared
mkdir -p /usr/local/etc/cloudflared
cat << EOF > /usr/local/etc/cloudflared/config.yml
proxy-dns: true
proxy-dns-upstream:
 - https://1.1.1.1/dns-query
 - https://1.0.0.1/dns-query
EOF
sudo cloudflared service install
sudo launchctl start com.cloudflare.cloudflared
