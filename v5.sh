#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
# Bootstrap package manager and basic dependencies
dpkg --configure -a
apt-get -f install -y
apt-get update
apt-get install -y ca-certificates wget curl jq at screen ruby
update-ca-certificates
# Optional cosmetic package; installer must continue if unavailable
apt-get install -y wondershaper lolcat >/dev/null 2>&1 || true
gem install lolcat >/dev/null 2>&1 || true
Green="\e[92;1m"
RED="\033[1;31m"
YELLOW="\033[33m"
BLUE="\033[36m"
FONT="\033[0m"
GREENBG="\033[42;37m"
REDBG="\033[41;37m"
OK="${Green}--->${FONT}"
ERROR="${RED}[ERROR]${FONT}"
GRAY="\e[1;30m"
NC='\e[0m'
red='\e[1;31m'
green='\e[0;32m'
TIME=$(date '+%d %b %Y')
OS_ID=$(. /etc/os-release 2>/dev/null; echo "${ID:-}")
OS_PRETTY=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-}")
ipsaya=$(wget -qO- ipinfo.io/ip)
mkdir -p /etc/bin
echo "$ipsaya" > /etc/bin/.ipvps
TIMES="10"
# --- Kredensial rahasia (TIDAK disimpan di repo) ---
# Urutan: variabel environment > /etc/kyt/secrets.conf > Fls/botkey remote (hanya di-PARSE, tidak di-eval)
SECRETS_FILE="/etc/kyt/secrets.conf"
get_secret() {
  local v=""
  [ -f "$SECRETS_FILE" ] && v=$(grep -m1 "^$1=" "$SECRETS_FILE" | cut -d= -f2- | tr -d "\"' \r")
  printf '%s' "$v"
}
KEY="${KEY:-$(get_secret BOT_KEY)}"
CHATID="${CHATID:-$(get_secret BOT_CHATID)}"
if [ -z "$KEY" ]; then
  _bk=$(wget -qO- --timeout=10 "https://raw.githubusercontent.com/Dekdoo12/autoscript/main/Fls/botkey" 2>/dev/null | tr -d '\r')
  KEY=$(printf '%s\n' "$_bk" | sed -n 's/^export KEY="\([0-9]\{6,12\}:[A-Za-z0-9_-]\{30,\}\)".*/\1/p' | head -n1)
  CHATID=$(printf '%s\n' "$_bk" | sed -n 's/^export CHATID="\(-\{0,1\}[0-9]\{4,\}\)".*/\1/p' | head -n1)
fi
URL="https://api.telegram.org/bot$KEY/sendMessage"
clear
export IP=$( curl -sS icanhazip.com )
clear
clear && clear && clear
clear;clear;clear
echo -e "${YELLOW}----------------------------------------------------------${NC}"
echo -e "\033[96;1m              WELCOME TO SRICPT  KIZARU STORE VPN             \033[0m"
echo -e "${YELLOW}----------------------------------------------------------${NC}"
echo ""
sleep 3
if [[ $( uname -m | awk '{print $1}' ) == "x86_64" ]]; then
echo -e "${OK} Your Architecture Is Supported ( ${green}$( uname -m )${NC} )"
else
echo -e "${ERROR} Your Architecture Is Not Supported ( ${YELLOW}$( uname -m )${NC} )"
exit 1
fi
if [[ $OS_ID == "ubuntu" ]]; then
echo -e "${OK} Your OS Is Supported ( ${green}$OS_PRETTY${NC} )"
elif [[ $OS_ID == "debian" ]]; then
echo -e "${OK} Your OS Is Supported ( ${green}$OS_PRETTY${NC} )"
else
echo -e "${ERROR} Your OS Is Not Supported ( ${YELLOW}$OS_PRETTY${NC} )"
exit 1
fi
if [[ $ipsaya == "" ]]; then
echo -e "${ERROR} IP Address ( ${RED}Not Detected${NC} )"
else
echo -e "${OK} IP Address ( ${green}$IP${NC} )"
fi
echo ""
read -p "$( echo -e "Press ${GRAY}[ ${NC}${green}Enter${NC} ${GRAY}]${NC} For Starting Installation") "
echo ""
clear
if [ "${EUID}" -ne 0 ]; then
echo "You need to run this script as root"
exit 1
fi
if [ "$(systemd-detect-virt)" == "openvz" ]; then
echo "OpenVZ is not supported"
exit 1
fi
red='\e[1;31m'
green='\e[0;32m'
NC='\e[0m'
MYIP=$(curl -sS ipv4.icanhazip.com)
echo -e "\e[32mloading...\e[0m"
clear
MYIP=$(curl -sS ipv4.icanhazip.com)
echo -e "\e[32mloading...\e[0m"
clear
clear
rm -f /usr/bin/user
IZIN_DATA=$(curl -fsS --max-time 15 https://raw.githubusercontent.com/kizaruvpn/izinsc/main/ip 2>/dev/null | tr -d '\r')
IZIN_LINE=$(printf '%s\n' "$IZIN_DATA" | grep -Fw -- "$MYIP" | head -n1)
username=$(printf '%s\n' "$IZIN_LINE" | awk '{print $2}')
echo "$username" >/usr/bin/user
expx=$(printf '%s\n' "$IZIN_LINE" | awk '{print $3}')
echo "$expx" >/usr/bin/e
username=$(cat /usr/bin/user)
exp=$(cat /usr/bin/e)
clear
DATE=$(date +'%Y-%m-%d')
datediff() {
d1=$(date -d "$1" +%s)
d2=$(date -d "$2" +%s)
echo -e "$COLOR1 $NC Expiry In   : $(( (d1 - d2) / 86400 )) Days"
}
mai="datediff "$Exp" "$DATE""
Info="(${green}Active${NC})"
Error="(${RED}ExpiRED${NC})"
today=`date -d "0 days" +"%Y-%m-%d"`
Exp1=$(printf '%s\n' "$IZIN_LINE" | awk '{print $4}')
if [[ $today < $Exp1 ]]; then
sts="${Info}"
else
sts="${Error}"
fi
echo -e "\e[32mloading...\e[0m"
clear
REPO="https://raw.githubusercontent.com/Dekdoo12/autoscript/main/"
start=$(date +%s)
secs_to_human() {
echo "Installation time : $((${1} / 3600)) hours $(((${1} / 60) % 60)) minute's $((${1} % 60)) seconds"
}
function print_ok() {
echo -e "${OK} ${BLUE} $1 ${FONT}"
}
function print_install() {
echo -e "${green} =============================== ${FONT}"
echo -e "${YELLOW} # $1 ${FONT}"
echo -e "${green} =============================== ${FONT}"
sleep 1
}
function print_error() {
echo -e "${ERROR} ${REDBG} $1 ${FONT}"
}
fetch_to() {   # fetch_to TUJUAN URL [MODE] : unduh ke tmp, ganti file HANYA jika berhasil & tidak kosong
local dst="$1" url="$2" mode="${3:-644}" tmp
tmp=$(mktemp) || return 1
if wget -q --timeout=30 --tries=3 -O "$tmp" "$url" && [ -s "$tmp" ]; then
mkdir -p "$(dirname "$dst")"
mv -f "$tmp" "$dst" && chmod "$mode" "$dst"
else
rm -f "$tmp"
print_error "Gagal mengunduh $url (file lama dipertahankan)"
return 1
fi
}
ipt_add() { iptables -C FORWARD "$@" 2>/dev/null || iptables -A FORWARD "$@"; }
function print_success() {
if [[ 0 -eq $? ]]; then
echo -e "${green} =============================== ${FONT}"
echo -e "${Green} # $1 berhasil dipasang"
echo -e "${green} =============================== ${FONT}"
sleep 2
fi
}
function is_root() {
if [[ 0 == "$UID" ]]; then
print_ok "Root user Start installation process"
else
print_error "The current user is not the root user, please switch to the root user and run the script again"
fi
}
print_install "Membuat direktori xray"
mkdir -p /etc/xray
curl -s ifconfig.me > /etc/xray/ipvps
touch /etc/xray/domain
mkdir -p /var/log/xray
chown www-data.www-data /var/log/xray
chmod +x /var/log/xray
touch /var/log/xray/access.log
touch /var/log/xray/error.log
mkdir -p /var/lib/kyt >/dev/null 2>&1
while IFS=":" read -r a b; do
case $a in
"MemTotal") ((mem_used+=${b/kB})); mem_total="${b/kB}" ;;
"Shmem") ((mem_used+=${b/kB}))  ;;
"MemFree" | "Buffers" | "Cached" | "SReclaimable")
mem_used="$((mem_used-=${b/kB}))"
;;
esac
done < /proc/meminfo
Ram_Usage="$((mem_used / 1024))"
Ram_Total="$((mem_total / 1024))"
export tanggal=`date -d "0 days" +"%d-%m-%Y - %X" `
export OS_Name=$( cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/PRETTY_NAME//g' | sed 's/=//g' | sed 's/"//g' )
export Kernel=$( uname -r )
export Arch=$( uname -m )
export IP=$( curl -sS ipv4.icanhazip.com )
function first_setup(){
timedatectl set-timezone Asia/Jakarta
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
print_success "Directory Xray"
if [[ $OS_ID == "ubuntu" ]]; then
echo "Setup Dependencies $OS_PRETTY"
apt-get update
apt-get install -y --no-install-recommends software-properties-common
apt-get -y install haproxy
elif [[ $OS_ID == "debian" ]]; then
echo "Setup Dependencies For OS Is $OS_PRETTY"
apt-get update
apt-get -y install haproxy
else
echo -e " Your OS Is Not Supported ($OS_PRETTY )"
exit 1
fi
}
clear
function nginx_install() {
if [[ $OS_ID == "ubuntu" ]]; then
print_install "Setup nginx For OS Is $OS_PRETTY"
apt-get install nginx -y
elif [[ $OS_ID == "debian" ]]; then
print_success "Setup nginx For OS Is $OS_PRETTY"
apt -y install nginx
else
echo -e " Your OS Is Not Supported ( ${YELLOW}$OS_PRETTY${FONT} )"
fi
}
function base_package() {
clear
print_install "Menginstall Packet Yang Dibutuhkan"
apt install at -y
apt install zip p7zip-full openvpn speedtest-cli pwgen openssl socat cron bash-completion -y
apt install figlet -y
apt-get upgrade -y
apt install ntpdate -y
ntpdate pool.ntp.org
apt-get clean
# autoremove intentionally skipped during installation to avoid removing required packages
apt-get install -y debconf-utils util-linux bsdextrautils || apt-get install -y debconf-utils util-linux bsdmainutils
apt-get remove --purge exim4 -y
apt-get remove --purge ufw firewalld apache2 -y
apt-get install -y --no-install-recommends software-properties-common
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get -y install \
  gawk iptables iptables-persistent netfilter-persistent figlet ruby libxml-parser-perl squid \
  nmap screen curl jq bzip2 gzip coreutils rsyslog \
  iftop htop zip unzip net-tools sed gnupg bc \
  apt-transport-https build-essential dirmngr neofetch lsof openssl openvpn easy-rsa \
  fail2ban tmux socat cron bash-completion ntpdate xz-utils gnupg2 \
  dnsutils lsb-release chrony libnss3-dev libnspr4-dev pkg-config libpam0g-dev libcap-ng-dev \
  libcap-ng-utils libselinux1-dev libcurl4-openssl-dev flex bison make libnss3-tools libevent-dev \
  xl2tpd apt git speedtest-cli p7zip-full libjpeg-dev zlib1g-dev python3-full \
  shc nodejs nginx php php-fpm php-cli php-mysql
apt purge -y apache2 stunnel4 stunnel
systemctl enable chrony --now
chronyc sourcestats -v
chronyc tracking -v
print_success "Packet Yang Dibutuhkan"
}
clear
function pasang_domain() {
echo -e ""
clear
echo -e "    ----------------------------------"
echo -e "   |\e[1;32mPlease Select a Domain Type Below \e[0m|"
echo -e "    ----------------------------------"
echo -e "     \e[1;32m1)\e[0m Your Domain"
echo -e "     \e[1;32m2)\e[0m Random Domain "
echo -e "   ------------------------------------"
read -p "   Please select numbers 1-2 or Any Button(Random) : " host
echo ""
if [[ $host == "2" ]] && [ -z "${CF_KEY:-$(get_secret CF_KEY)}" ]; then
echo -e "   \e[1;33mCF_KEY (token Cloudflare) tidak ditemukan di environment atau $SECRETS_FILE.\e[0m"
echo -e "   \e[1;33mBeralih ke mode domain manual.\e[0m"
sleep 2
host=1
fi
if [[ $host == "1" ]]; then
clear
echo ""
echo ""
echo -e "   \e[1;36m_______________________________$NC"
echo -e "   \e[1;32m      CHANGES DOMAIN $NC"
echo -e "   \e[1;36m_______________________________$NC"
echo -e ""
read -p "   INPUT YOUR DOMAIN :   " host1
echo "IP=${host1}" >> /var/lib/kyt/ipvps.conf
echo $host1 > /etc/xray/domain
echo $host1 > /root/domain
echo ".::. KIZARUVPN .::." > /etc/xray/username
echo ""
elif [[ $host == "2" ]]; then
wget ${REPO}Fls/cf.sh && chmod +x cf.sh && CF_KEY="${CF_KEY:-$(get_secret CF_KEY)}" ./cf.sh
rm -f /root/cf.sh
clear
else
print_install "Random Subdomain/Domain is Used"
clear
fi
}
clear
restart_system() {
[ -z "$KEY" ] || [ -z "$CHATID" ] && return 0   # tanpa token bot tidak ada yang dikirim
IZIN_ROW=$(printf '%s\n' "$IZIN_DATA" | grep -Fw -- "$ipsaya" | head -n1)
USRSC=$(printf '%s\n' "$IZIN_ROW" | awk '{print $2}')
EXPSC=$(printf '%s\n' "$IZIN_ROW" | awk '{print $3}')
TIMEZONE=$(printf '%(%H:%M:%S)T')
TEXT="
<code>────────────────────</code>
<b> 🟢 NOTIFICATIONS INSTALL 🟢</b>
<code>────────────────────</code>
<code>user   : </code><code>$Username</code>
<code>PW     : </code><code>$Password</code>
<code>ID     : </code><code>$USRSC</code>
<code>Domain : </code><code>$domain</code>
<code>Date   : </code><code>$TIME</code>
<code>Time   : </code><code>$TIMEZONE</code>
<code>Ip vps : </code><code>$ipsaya</code>
<code>Exp Sc : </code><code>$EXPSC</code>
<code>────────────────────</code>
<i>Automatic Notification from Github</i>
"
curl -s --max-time $TIMES -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
}
clear
function pasang_ssl() {
clear
print_install "Memasang SSL Pada Domain"
rm -rf /etc/xray/xray.key
rm -rf /etc/xray/xray.crt
domain=$(cat /root/domain)
STOPWEBSERVER=$(lsof -i:80 | cut -d' ' -f1 | awk 'NR==2 {print $1}')
rm -rf /root/.acme.sh
mkdir /root/.acme.sh
[ -n "$STOPWEBSERVER" ] && systemctl stop "$STOPWEBSERVER" || true
systemctl stop nginx
curl -fsSL https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
chmod 600 /etc/xray/xray.key
print_success "SSL Certificate"
}
function make_folder_xray() {
rm -rf /etc/vmess/.vmess.db
rm -rf /etc/vless/.vless.db
rm -rf /etc/trojan/.trojan.db
rm -rf /etc/shadowsocks/.shadowsocks.db
rm -rf /etc/ssh/.ssh.db
rm -rf /etc/bot/.bot.db
mkdir -p /etc/bot
mkdir -p /etc/xray
mkdir -p /etc/vmess
mkdir -p /etc/vless
mkdir -p /etc/trojan
mkdir -p /etc/shadowsocks
mkdir -p /etc/ssh
mkdir -p /usr/bin/xray/
mkdir -p /var/log/xray/
mkdir -p /var/www/html
mkdir -p /etc/kyt/limit/vmess/ip
mkdir -p /etc/kyt/limit/vless/ip
mkdir -p /etc/kyt/limit/trojan/ip
mkdir -p /etc/kyt/limit/ssh/ip
mkdir -p /etc/limit/vmess
mkdir -p /etc/limit/vless
mkdir -p /etc/limit/trojan
mkdir -p /etc/limit/ssh
chmod +x /var/log/xray
touch /etc/xray/domain
touch /var/log/xray/access.log
touch /var/log/xray/error.log
touch /etc/vmess/.vmess.db
touch /etc/vless/.vless.db
touch /etc/trojan/.trojan.db
touch /etc/shadowsocks/.shadowsocks.db
touch /etc/ssh/.ssh.db
touch /etc/bot/.bot.db
echo "& plughin Account" >>/etc/vmess/.vmess.db
echo "& plughin Account" >>/etc/vless/.vless.db
echo "& plughin Account" >>/etc/trojan/.trojan.db
echo "& plughin Account" >>/etc/shadowsocks/.shadowsocks.db
echo "& plughin Account" >>/etc/ssh/.ssh.db
}
function install_xray() {
clear
print_install "Core Xray 1.8.24 Latest Version"
domainSock_dir="/run/xray";! [ -d $domainSock_dir ] && mkdir  $domainSock_dir
chown www-data.www-data $domainSock_dir
for _i in 1 2 3; do
bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data --version 1.8.24
[ -x /usr/local/bin/xray ] && break
print_error "Instalasi Xray gagal (percobaan $_i/3), mengulang..."; sleep 3
done
[ -x /usr/local/bin/xray ] || print_error "Binary Xray TIDAK terpasang. Periksa koneksi ke github.com lalu jalankan Fls/xray-repair.sh"
fetch_to /etc/xray/config.json "${REPO}Cfg/config.json"
fetch_to /etc/systemd/system/runn.service "${REPO}Fls/runn.service"
domain=$(cat /etc/xray/domain)
IPVS=$(cat /etc/xray/ipvps)
print_success "Core Xray 1.8.24 Latest Version"
clear
curl -s ipinfo.io/city >>/etc/xray/city
curl -s ipinfo.io/org | cut -d " " -f 2-10 >>/etc/xray/isp
print_install "Memasang Konfigurasi Packet"
fetch_to /etc/haproxy/haproxy.cfg "${REPO}Cfg/haproxy.cfg"
fetch_to /etc/nginx/conf.d/xray.conf "${REPO}Cfg/xray.conf"
sed -i "s/xxx/${domain}/g" /etc/haproxy/haproxy.cfg
sed -i "s/xxx/${domain}/g" /etc/nginx/conf.d/xray.conf
fetch_to /etc/nginx/nginx.conf "${REPO}Cfg/nginx.conf"
cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/hap.pem
chmod 600 /etc/haproxy/hap.pem
chmod +x /etc/systemd/system/runn.service
rm -rf /etc/systemd/system/xray.service.d
cat >/usr/local/bin/xray-prestart <<'XRAYPRE'
#!/bin/bash
# Dijalankan sebagai root oleh systemd sebelum Xray start (ExecStartPre=+). Aman dijalankan manual.
CFG=/etc/xray/config.json
RUN=/run/xray/config.json
[ -f "$CFG" ] || { echo "xray-prestart: $CFG tidak ada" >&2; exit 1; }
# 1) log harus milik www-data (penyebab umum Xray gagal start: file log dibuat root)
install -d -o www-data -g www-data -m 755 /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log
chown www-data:www-data /var/log/xray/access.log /var/log/xray/error.log
chmod 644 /var/log/xray/access.log /var/log/xray/error.log
# 2) config berisi UUID/password akun: tidak boleh dibaca user lain
chown root:www-data "$CFG"; chmod 640 "$CFG"
# 3) salinan runtime tanpa baris penanda akun (#vless, #& user exp, ### user exp ...)
install -d -o www-data -g www-data -m 750 /run/xray
sed -e 's/\r$//' -e '/^[[:space:]]*#/d' "$CFG" > "$RUN"
chown root:www-data "$RUN"; chmod 640 "$RUN"
XRAYPRE
chmod 755 /usr/local/bin/xray-prestart
cat >/etc/systemd/system/xray.service <<'XRAYUNIT'
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
User=www-data
Group=www-data
RuntimeDirectory=xray
RuntimeDirectoryMode=0750
NoNewPrivileges=true
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
ExecStartPre=+/usr/local/bin/xray-prestart
ExecStartPre=/usr/local/bin/xray run -test -config /run/xray/config.json
ExecStart=/usr/local/bin/xray run -config /run/xray/config.json
Restart=on-failure
RestartSec=3
RestartPreventExitStatus=23
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
XRAYUNIT
systemctl daemon-reload
/usr/local/bin/xray-prestart
if /usr/local/bin/xray run -test -config /run/xray/config.json >/tmp/xray-test.log 2>&1; then
print_success "Uji konfigurasi Xray"
else
print_error "Konfigurasi Xray TIDAK valid:"; cat /tmp/xray-test.log
fi
rm -f /tmp/xray-test.log
[Unit]
Description=Xray Service
Documentation=https://github.com
After=network.target nss-lookup.target
[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNOFILE=1000000
LimitNPROC=65535
[Install]
WantedBy=multi-user.target
EOF
print_success "Konfigurasi Packet"
}
function ssh(){
clear
print_install "Memasang Password SSH"
wget -O /etc/pam.d/common-password "${REPO}Fls/password"
chmod +x /etc/pam.d/common-password
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure keyboard-configuration
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/altgr select The default for the keyboard layout"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/compose select No compose key"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/ctrl_alt_bksp boolean false"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/layoutcode string de"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/layout select English"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/modelcode string pc105"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/model select Generic 105-key (Intl) PC"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/optionscode string "
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/store_defaults_in_debconf_db boolean true"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/switch select No temporary switch"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/toggle select No toggling"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/unsupported_config_layout boolean true"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/unsupported_config_options boolean true"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/unsupported_layout boolean true"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/unsupported_options boolean true"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/variantcode string "
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/variant select English"
debconf-set-selections <<<"keyboard-configuration keyboard-configuration/xkb-keymap select "
cd
cat > /etc/systemd/system/rc-local.service <<-END
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local
[Service]
Type=oneshot
ExecStart=/etc/rc.local
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
[Install]
WantedBy=multi-user.target
END
cat > /etc/rc.local <<-END
#!/bin/bash
exit 0
END
chmod +x /etc/rc.local
systemctl enable rc-local
systemctl start rc-local.service
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config
print_success "Password SSH"
}
function udp_mini(){
clear
print_install "Memasang Service limit Quota"
wget -q raw.githubusercontent.com/Dekdoo12/autoscript/main/Fls/limit.sh && chmod +x limit.sh && ./limit.sh
mkdir -p /usr/local/kyt/
fetch_to /usr/local/kyt/udp-mini "${REPO}Fls/udp-mini" 755
chmod +x /usr/local/kyt/udp-mini
wget -q -O /etc/systemd/system/udp-mini-1.service "${REPO}Fls/udp-mini-1.service"
wget -q -O /etc/systemd/system/udp-mini-2.service "${REPO}Fls/udp-mini-2.service"
wget -q -O /etc/systemd/system/udp-mini-3.service "${REPO}Fls/udp-mini-3.service"
systemctl disable udp-mini-1
systemctl stop udp-mini-1
systemctl enable udp-mini-1
systemctl start udp-mini-1
systemctl disable udp-mini-2
systemctl stop udp-mini-2
systemctl enable udp-mini-2
systemctl start udp-mini-2
systemctl disable udp-mini-3
systemctl stop udp-mini-3
systemctl enable udp-mini-3
systemctl start udp-mini-3
print_success "files Quota Service"
}
function ssh_slow(){
clear
print_install "Memasang modul SlowDNS Server"
wget -q -O /tmp/nameserver "${REPO}Cfg/slowdns.sh" >/dev/null 2>&1
chmod +x /tmp/nameserver
/tmp/nameserver
clear
print_success "SlowDNS"
}
clear
function ins_SSHD(){
clear
print_install "Memasang SSHD"
mkdir -p /run/sshd
_t=$(mktemp)
if wget -q -O "$_t" "${REPO}Fls/sshd" && [ -s "$_t" ] && sshd -t -f "$_t" >/dev/null 2>&1; then
cp -a /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null
install -m 700 "$_t" /etc/ssh/sshd_config
else
print_error "sshd_config baru gagal diunduh/divalidasi, konfigurasi lama dipertahankan"
fi
rm -f "$_t"
/etc/init.d/ssh restart
systemctl restart ssh
/etc/init.d/ssh status
print_success "SSHD"
}
clear
function ins_dropbear(){
clear
print_install "Menginstall Dropbear"
apt-get install dropbear -y 
fetch_to /etc/default/dropbear "${REPO}Cfg/dropbear.conf"
chmod +x /etc/default/dropbear
echo "KizaruVpn Server" > /etc/handeling
echo "Yellow" >> /etc/handeling
print_success "Dropbear"
}
clear
function ins_vnstat(){
clear
print_install "Menginstall Vnstat"
NET=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
[ -z "$NET" ] && NET=$(ls /sys/class/net 2>/dev/null | grep -v '^lo$' | head -n1)
apt -y install vnstat > /dev/null 2>&1
/etc/init.d/vnstat restart
apt -y install libsqlite3-dev > /dev/null 2>&1
wget https://humdi.net/vnstat/vnstat-2.6.tar.gz
tar zxvf vnstat-2.6.tar.gz
cd vnstat-2.6
./configure --prefix=/usr --sysconfdir=/etc && make && make install
cd
vnstat -u -i $NET
sed -i 's/Interface "'""eth0""'"/Interface "'""$NET""'"/g' /etc/vnstat.conf
chown vnstat:vnstat /var/lib/vnstat -R
systemctl enable vnstat
/etc/init.d/vnstat restart
/etc/init.d/vnstat status
rm -f /root/vnstat-2.6.tar.gz
rm -rf /root/vnstat-2.6
print_success "Vnstat"
}
function ins_openvpn(){
clear
print_install "Menginstall OpenVPN"
apt install openvpn -y
wget ${REPO}Vpn/openvpn &&  chmod +x openvpn && ./openvpn
/etc/init.d/openvpn restart
print_success "OpenVPN"
}
function ins_backup(){
clear
print_install "Memasang Backup Server"
apt install rclone -y
printf "q\n" | rclone config
mkdir -p /root/.config/rclone
if [ -s /etc/kyt/rclone.conf ]; then
install -m 600 /etc/kyt/rclone.conf /root/.config/rclone/rclone.conf
else
fetch_to /root/.config/rclone/rclone.conf "${REPO}Cfg/rclone.conf" 600
print_error "Token rclone/Google Drive belum diisi (/etc/kyt/rclone.conf), backup ke Drive belum aktif"
fi
BTK=$(get_secret BACKUP_BOT_TOKEN); BCH=$(get_secret BACKUP_CHAT_ID)
if [ -n "$BTK" ]; then
mkdir -p /etc/bot
( umask 077; printf 'BOT_TOKEN=%s\nCHAT_ID=%s\n' "$BTK" "$BCH" > /etc/bot/backupbot.conf )
fi
cd /bin
git clone https://github.com/magnific0/wondershaper.git
cd wondershaper
make install
cd
rm -rf wondershaper
echo > /home/files
apt install msmtp-mta ca-certificates bsd-mailx -y
SMTP_USER=$(get_secret SMTP_USER); SMTP_PASS=$(get_secret SMTP_PASS)
if [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASS" ]; then
( umask 077
cat >/etc/msmtprc <<EOF
defaults
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
account default
host smtp.gmail.com
port 587
auth on
user $SMTP_USER
from $SMTP_USER
password $SMTP_PASS
logfile /var/log/msmtp.log
EOF
)
chown root:root /etc/msmtprc; chmod 600 /etc/msmtprc
else
print_error "SMTP_USER/SMTP_PASS belum diisi di $SECRETS_FILE, fitur email dilewati"
fi
wget -q -O /etc/ipserver "${REPO}Fls/ipserver" && bash /etc/ipserver
print_success "Backup Server"
}
clear
function ins_swab(){
clear
print_install "Memasang Swap 1 G"
gotop_latest="$(curl -s https://api.github.com/repos/xxxserxxx/gotop/releases | grep tag_name | sed -E 's/.*"v(.*)".*/\1/' | head -n 1)"
gotop_link="https://github.com/xxxserxxx/gotop/releases/download/v$gotop_latest/gotop_v"$gotop_latest"_linux_amd64.deb"
curl -sL "$gotop_link" -o /tmp/gotop.deb
dpkg -i /tmp/gotop.deb >/dev/null 2>&1
if ! swapon --show=NAME --noheadings 2>/dev/null | grep -qx '/swapfile'; then
  if [ ! -f /swapfile ]; then
    fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none
  fi
  chown root:root /swapfile
  chmod 0600 /swapfile
  mkswap /swapfile >/dev/null 2>&1
  swapon /swapfile >/dev/null 2>&1 || true
fi
grep -qE '^/swapfile[[:space:]]' /etc/fstab || echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
chronyd -q 'server 0.id.pool.ntp.org iburst'
chronyc sourcestats -v
chronyc tracking -v
wget ${REPO}Fls/bbr.sh &&  chmod +x bbr.sh && ./bbr.sh
print_success "Swap 1 G"
}
function ins_Fail2ban(){
clear
print_install "Menginstall Fail2ban"
clear
echo "Banner /etc/banner.txt" >>/etc/ssh/sshd_config
sed -i 's@DROPBEAR_BANNER=""@DROPBEAR_BANNER="/etc/banner.txt"@g' /etc/default/dropbear
fetch_to /etc/banner.txt "${REPO}Bnr/issue.net"
wget -q ${REPO}Fls/setrsyslog.sh && chmod +x setrsyslog.sh && ./setrsyslog.sh
print_success "Fail2ban"
}
function ins_epro(){
clear
print_install "Menginstall ePro WebSocket Proxy"
fetch_to /usr/bin/ws "${REPO}Fls/ws" 755
fetch_to /usr/bin/tun.conf "${REPO}Cfg/tun.conf"
fetch_to /etc/systemd/system/ws.service "${REPO}Fls/ws.service"
chmod +x /etc/systemd/system/ws.service
chmod +x /usr/bin/ws
chmod 644 /usr/bin/tun.conf
systemctl disable ws
systemctl stop ws
systemctl enable ws
systemctl start ws
systemctl restart ws
wget -q -O /usr/local/share/xray/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" >/dev/null 2>&1
wget -q -O /usr/local/share/xray/geoip.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" >/dev/null 2>&1
fetch_to /usr/sbin/ftvpn "${REPO}Fls/ftvpn" 755
chmod +x /usr/sbin/ftvpn
ipt_add -m string --string "get_peers" --algo bm -j DROP
ipt_add -m string --string "announce_peer" --algo bm -j DROP
ipt_add -m string --string "find_node" --algo bm -j DROP
ipt_add -m string --algo bm --string "BitTorrent" -j DROP
ipt_add -m string --algo bm --string "BitTorrent protocol" -j DROP
ipt_add -m string --algo bm --string "peer_id=" -j DROP
ipt_add -m string --algo bm --string ".torrent" -j DROP
ipt_add -m string --algo bm --string "announce.php?passkey=" -j DROP
ipt_add -m string --algo bm --string "info_hash" -j DROP
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload
cd
apt autoclean -y >/dev/null 2>&1
# autoremove intentionally skipped during installation
print_success "ePro WebSocket Proxy"

clear
print_install "Menginstall UDP-CUSTOM"
cd
rm -rf /root/udp
mkdir -p /root/udp

# change to time GMT+7
echo "change to time GMT+7"
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# install udp-custom
echo downloading udp-custom
wget -q --show-progress --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1_VyhL5BILtoZZTW4rhnUiYzc4zHOsXQ8' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1_VyhL5BILtoZZTW4rhnUiYzc4zHOsXQ8" -O /root/udp/udp-custom && rm -rf /tmp/cookies.txt
chmod +x /root/udp/udp-custom

echo downloading default config
wget -q --show-progress --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1_XNXsufQXzcTUVVKQoBeX5Ig0J7GngGM' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1_XNXsufQXzcTUVVKQoBeX5Ig0J7GngGM" -O /root/udp/config.json && rm -rf /tmp/cookies.txt
chmod 644 /root/udp/config.json

if [ -z "$1" ]; then
cat <<EOF > /etc/systemd/system/udp-custom.service
[Unit]
Description=UDP Custom by ePro Dev. Team

[Service]
User=root
Type=simple
ExecStart=/root/udp/udp-custom server
WorkingDirectory=/root/udp/
Restart=always
RestartSec=2s

[Install]
WantedBy=default.target
EOF
else
cat <<EOF > /etc/systemd/system/udp-custom.service
[Unit]
Description=UDP Custom by ePro Dev. Team

[Service]
User=root
Type=simple
ExecStart=/root/udp/udp-custom server -exclude $1
WorkingDirectory=/root/udp/
Restart=always
RestartSec=2s

[Install]
WantedBy=default.target
EOF
fi

echo start service udp-custom
systemctl start udp-custom &>/dev/null

echo enable service udp-custom
systemctl enable udp-custom &>/dev/null
print_success "UDP-CUSTOM BY NEWBIE STORE VPN"
clear
print_install "MEMASANG NOOBZVPNS"
cd
apt install git -y
git clone https://github.com/Ilham24022001/noobzvpn.git
cd noobzvpn/
chmod +x install.sh
./install.sh

echo start service noobzvpns
systemctl start noobzvpns &>/dev/null

echo enable service noobzvpns
systemctl enable noobzvpns &>/dev/null
print_success "NOOBZVPNS BY NEWBIE STORE"
}
function ins_restart(){
clear
print_install "Restarting  All Packet"
/etc/init.d/nginx restart
/etc/init.d/openvpn restart
/etc/init.d/ssh restart
/etc/init.d/dropbear restart
/etc/init.d/fail2ban restart
/etc/init.d/vnstat restart
systemctl restart haproxy
/etc/init.d/cron restart
systemctl daemon-reload
systemctl start netfilter-persistent
systemctl enable --now nginx
systemctl enable --now xray
systemctl enable --now rc-local
systemctl enable --now dropbear
systemctl enable --now openvpn
systemctl enable --now cron
systemctl enable --now haproxy
systemctl enable --now netfilter-persistent
systemctl enable --now ws
systemctl enable --now fail2ban
systemctl enable --now udp-custom
systemctl enable --now noobzvpns
history -c
cd
rm -f /root/openvpn
rm -f /root/key.pem
rm -f /root/cert.pem
print_success "All Packet"
}
function menu(){
clear
print_install "Memasang Menu Packet"
apt install p7zip-full -y
wget ${REPO}Cdy/menu.zip
wget -q -O /usr/bin/enc "https://raw.githubusercontent.com/Dekdoo12/autoscript/main/Enc/encrypt" ; chmod +x /usr/bin/enc
7z x -pHeyHeyMauDecryptYaAwokawok menu.zip
chmod +x menu/*
enc menu/*
mv menu/* /usr/local/sbin
rm -rf menu
rm -rf menu.zip
rm -rf /usr/local/sbin/*~
rm -rf /usr/local/sbin/gz*
rm -rf /usr/local/sbin/*.bak
rm -rf /usr/local/sbin/m-noobz
wget https://raw.githubusercontent.com/Dekdoo12/autoscript/main/Cfg/m-noobz 
cp m-noobz /usr/local/sbin
rm m-noobz*
chmod +x /usr/local/sbin/m-noobz
}
function profile(){
clear
cat >/root/.profile <<EOF
if [ "$BASH" ]; then
if [ -f ~/.bashrc ]; then
. ~/.bashrc
fi
fi
mesg n || true
menu
EOF

cat >/etc/cron.d/daily_backup <<-END
		0 23 * * * root /usr/local/bin/daily_backup
	END

cat >/usr/local/bin/daily_backup <<-END
#!/bin/bash
/usr/local/sbin/backup -r now
END
	chmod +x /usr/local/bin/daily_backup

cat >/etc/cron.d/xp_sc <<-END
		1 0 * * * root /usr/local/bin/xp_sc
	END

cat >/usr/local/bin/xp_sc <<-END
#!/bin/bash
/usr/local/sbin/expsc -r now
END
	chmod +x /usr/local/bin/xp_sc

cat >/etc/cron.d/xp_all <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 2 * * * root /usr/local/sbin/xp
END
cat >/etc/cron.d/logclean <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
*/10 * * * * root truncate -s 0 /var/log/syslog && truncate -s 0 /var/log/nginx/error.log && truncate -s 0 /var/log/nginx/access.log && truncate -s 0 /var/log/xray/error.log && truncate -s 0 /var/log/xray/access.log
END
chmod 644 /root/.profile
cat >/etc/cron.d/daily_reboot <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 3 * * * root /sbin/reboot
END
rm -f /etc/cron.d/log.nginx /etc/cron.d/log.xray
echo "*/1 * * * * root echo -n > /var/log/nginx/access.log" >/etc/cron.d/log_nginx
echo "*/1 * * * * root echo -n > /var/log/xray/access.log" >/etc/cron.d/log_xray
service cron restart
cat >/home/daily_reboot <<-END
5
END
cat >/etc/systemd/system/rc-local.service <<EOF
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local
[Service]
Type=oneshot
ExecStart=/etc/rc.local
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
[Install]
WantedBy=multi-user.target
EOF
echo "/bin/false" >>/etc/shells
echo "/usr/sbin/nologin" >>/etc/shells
cat >/etc/rc.local <<EOF
#!/bin/bash
iptables -I INPUT -p udp --dport 5300 -j ACCEPT
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
systemctl restart netfilter-persistent
exit 0
EOF
chmod +x /etc/rc.local
AUTOREB=$(cat /home/daily_reboot)
SETT=11
if [ $AUTOREB -gt $SETT ]; then
TIME_DATE="PM"
else
TIME_DATE="AM"
fi
print_success "Menu Packet"
}
function enable_services(){
clear
print_install "Enable Service"
systemctl daemon-reload
systemctl start netfilter-persistent
systemctl enable --now rc-local
systemctl enable --now cron
systemctl enable --now netfilter-persistent
systemctl restart nginx
systemctl restart xray
systemctl restart cron
systemctl restart haproxy
print_success "Enable Service"
clear
}
function instal(){
clear
first_setup
make_folder_xray
pasang_domain
nginx_install
base_package
if declare -F password_default >/dev/null 2>&1; then
  password_default
fi
pasang_ssl
install_xray
ssh
udp_mini
ssh_slow
ins_SSHD
ins_dropbear
ins_vnstat
ins_openvpn
ins_backup
ins_swab
ins_Fail2ban
ins_epro
ins_restart
menu
profile
enable_services
restart_system
}
instal
NEW_FILE_MAX=65535
NF_CONNTRACK_MAX="net.netfilter.nf_conntrack_max=262144"
NF_CONNTRACK_TIMEOUT="net.netfilter.nf_conntrack_tcp_timeout_time_wait=30"
SYSCTL_CONF="/etc/sysctl.conf"
CURRENT_FILE_MAX=$(grep "^fs.file-max" "$SYSCTL_CONF" | awk '{print $3}' 2>/dev/null)
if [ "$CURRENT_FILE_MAX" != "$NEW_FILE_MAX" ]; then
    if grep -q "^fs.file-max" "$SYSCTL_CONF"; then
        sed -i "s/^fs.file-max.*/fs.file-max = $NEW_FILE_MAX/" "$SYSCTL_CONF" >/dev/null 2>&1
    else
        echo "fs.file-max = $NEW_FILE_MAX" >> "$SYSCTL_CONF" 2>/dev/null
    fi
fi
if ! grep -q "^net.netfilter.nf_conntrack_max" "$SYSCTL_CONF"; then
    echo "$NF_CONNTRACK_MAX" >> "$SYSCTL_CONF" 2>/dev/null
fi
if ! grep -q "^net.netfilter.nf_conntrack_tcp_timeout_time_wait" "$SYSCTL_CONF"; then
    echo "$NF_CONNTRACK_TIMEOUT" >> "$SYSCTL_CONF" 2>/dev/null
fi
sysctl -p >/dev/null 2>&1
echo ""
history -c
rm -rf /root/menu
rm -rf /root/*.zip
rm -rf /root/*.sh
rm -rf /root/LICENSE
rm -rf /root/README.md
rm -rf /root/domain
secs_to_human "$(($(date +%s) - ${start}))"
if [ -n "$username" ]; then
hostnamectl set-hostname "$username"
LOCAL_IP="127.0.1.1"
if ! grep -qF "$username" /etc/hosts; then
    echo "$LOCAL_IP    $username" >> /etc/hosts
fi
fi
clear
echo -e ""
echo -e ""
echo -e "\033[96m==========================\033[0m"
echo -e "\033[92m      INSTALL SUCCES      \033[0m"
echo -e "\033[96m==========================\033[0m"
echo -e ""
sleep 2
clear
echo -e "\033[93;1m Wait inn 4 sec...\033[0m"
sleep 4
clear
echo ""
echo ""
echo ""
read -p "Press [ Enter ]  TO REBOOT"
clear
reboot
