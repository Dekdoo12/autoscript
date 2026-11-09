#!/bin/bash
# =====================================================================
#  V5 MENU INSTALLER  (versi modular)
#  Jalankan script ini -> hanya menyiapkan dasar + menu.
#  Semua layanan (SSH, Nginx, Xray, SlowDNS, UDP, dll) dipasang
#  SESUAI PILIHAN kamu lewat menu, bukan otomatis di awal.
#
#  Setelah terpasang, buka menu kapan saja dengan perintah:  v5-setup
# =====================================================================

REPO="https://raw.githubusercontent.com/Dekdoo12/autoscript/main/"
STATE_DIR="/etc/v5"
STATE_FILE="$STATE_DIR/installed.list"
SELF_BIN="/usr/local/sbin/v5-setup"
export DEBIAN_FRONTEND=noninteractive

# ---------- warna ----------
G="\e[92;1m"; R="\e[91;1m"; Y="\e[93;1m"; C="\e[96;1m"; W="\e[97;1m"; N="\e[0m"

# ---------- helper ----------
print_install() { echo -e "\n${C}=============================================${N}\n${Y} # $1${N}\n${C}=============================================${N}"; }
print_ok()      { echo -e "${G}[ OK ]${N} $1"; }
print_err()     { echo -e "${R}[ERROR]${N} $1"; }
pause()         { read -n 1 -s -r -p "Tekan [Enter] untuk kembali ke menu..."; echo; }

is_done()   { grep -qx "$1" "$STATE_FILE" 2>/dev/null; }
mark_done() { is_done "$1" || echo "$1" >> "$STATE_FILE"; }
status()    { is_done "$1" && echo -e "${G}[terpasang]${N}" || echo -e "${R}[belum]${N}"; }

confirm_reinstall() {
  # $1 = id komponen. Return 0 kalau boleh lanjut.
  if is_done "$1"; then
    read -rp "$1 sudah terpasang. Pasang ulang? [y/N] : " a
    [[ "$a" =~ ^[Yy]$ ]] || return 1
  fi
  return 0
}

os_id() { . /etc/os-release; echo "$ID"; }


# ---------- profile login: panel (kalau ada) atau installer ----------
set_profile() {
  sed -i '/# v5-profile-begin/,/# v5-profile-end/d' /root/.profile 2>/dev/null
  sed -i '\#^\[ -x /usr/local/sbin/v5-setup \] && v5-setup$#d' /root/.profile 2>/dev/null
  cat >> /root/.profile <<'EOF'
# v5-profile-begin
if [ -x /usr/local/sbin/menu ]; then menu; elif [ -x /usr/local/sbin/v5-setup ]; then v5-setup; fi
# v5-profile-end
EOF
}

# ---------- cek apakah IP VPS ini terdaftar lisensi panel (hanya MEMBACA) ----------
panel_licensed() {
  local ip exp today
  ip=$(curl -sS --max-time 10 ipv4.icanhazip.com)
  exp=$(curl -sS --max-time 10 https://raw.githubusercontent.com/kizaruvpn/izinsc/main/ip | grep -F "$ip" | awk '{print $3}' | head -1)
  today=$(date +%Y-%m-%d)
  [ -n "$exp" ] && [[ "$today" < "$exp" ]]
}

# =====================================================================
#  TAHAP 1 : BOOTSTRAP (hanya dasar, TIDAK memasang layanan)
# =====================================================================
bootstrap() {
  [ "${EUID}" -ne 0 ] && { print_err "Jalankan sebagai root"; exit 1; }
  [ "$(uname -m)" != "x86_64" ] && { print_err "Arsitektur $(uname -m) tidak didukung"; exit 1; }
  case "$(os_id)" in ubuntu|debian) ;; *) print_err "OS tidak didukung (hanya Ubuntu/Debian)"; exit 1;; esac
  [ "$(systemd-detect-virt 2>/dev/null)" = "openvz" ] && { print_err "OpenVZ tidak didukung"; exit 1; }

  print_install "Menyiapkan dasar (paket minimal + menu)"
  dpkg --configure -a
  apt-get -f install -y
  apt-get update
  apt-get install -y ca-certificates wget curl jq unzip p7zip-full cron lsof net-tools dnsutils
  timedatectl set-timezone Asia/Jakarta 2>/dev/null

  mkdir -p "$STATE_DIR"
  touch "$STATE_FILE"

  # salin diri sendiri supaya menu bisa dipanggil lagi kapan saja
  if [ "$(readlink -f "$0")" != "$SELF_BIN" ]; then
    cp -f "$0" "$SELF_BIN" && chmod +x "$SELF_BIN"
  fi

  # data dasar yang dibaca panel
  mkdir -p /etc/xray
  [ -s /etc/xray/city ] || curl -s ipinfo.io/city > /etc/xray/city
  [ -s /etc/xray/isp ]  || curl -s ipinfo.io/org | cut -d " " -f 2-10 > /etc/xray/isp
  [ -s /etc/xray/username ] || echo ".::. KIZARUVPN .::." > /etc/xray/username

  # panel menu (menu utama) -> otomatis hanya kalau IP terdaftar lisensi
  if panel_licensed; then
    print_ok "IP terdaftar lisensi -> memasang panel menu utama"
    install_panel auto
  else
    echo -e "${Y}IP VPS ini tidak terdaftar lisensi panel -> panel TIDAK dipasang otomatis.${N}"
    echo -e "${Y}Kamu tetap bisa pakai menu installer ini (v5-setup).${N}"
  fi
  set_profile
  print_ok "Dasar siap. Tidak ada layanan yang dipasang."
  sleep 1
}

# =====================================================================
#  KOMPONEN-KOMPONEN (masing-masing dipasang lewat menu)
# =====================================================================

# ---------- Domain ----------
set_domain() {
  mkdir -p /etc/xray /var/lib/kyt
  clear
  echo -e "${W}Pilih tipe domain:${N}"
  echo " 1) Domain sendiri"
  echo " 2) Subdomain acak (pakai cf.sh dari repo)"
  read -rp "Pilih [1-2] : " host
  if [[ "$host" == "1" ]]; then
    read -rp "Masukkan domain : " d
    [ -z "$d" ] && { print_err "Domain kosong"; return 1; }
    echo "IP=${d}" >> /var/lib/kyt/ipvps.conf
    echo "$d" > /etc/xray/domain
    echo "$d" > /root/domain
    echo ".::. KIZARUVPN .::." > /etc/xray/username
  elif [[ "$host" == "2" ]]; then
    wget -q "${REPO}Fls/cf.sh" -O /root/cf.sh && chmod +x /root/cf.sh && /root/cf.sh
    rm -f /root/cf.sh
  else
    print_err "Pilihan tidak valid"; return 1
  fi
  [ -s /etc/xray/domain ] && cp -f /etc/xray/domain /root/domain
  mark_done domain
}

need_domain() {
  [ -s /etc/xray/domain ] || { echo -e "${Y}Domain belum diatur, atur dulu...${N}"; set_domain || return 1; }
  [ -s /etc/xray/domain ]
}

# ---------- Paket dasar ----------
install_base_packages() {
  print_install "Paket dasar (iptables, fail2ban tools, dll)"
  echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
  echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
  apt-get install -y debconf-utils util-linux bsdextrautils || apt-get install -y debconf-utils util-linux bsdmainutils
  apt-get -y install gawk iptables iptables-persistent netfilter-persistent figlet ruby \
    screen jq bzip2 gzip coreutils rsyslog iftop htop zip unzip sed gnupg bc \
    openssl socat chrony xz-utils tmux git python3-full
  systemctl enable chrony --now
  gem install lolcat >/dev/null 2>&1 || true
  mark_done base
}

need_base() { is_done base || install_base_packages; }

# ---------- 1. SSH ----------
install_ssh() {
  confirm_reinstall ssh || return
  need_base
  print_install "Memasang konfigurasi SSH / SSHD"
  mkdir -p /etc/ssh
  wget -q -O /etc/pam.d/common-password "${REPO}Fls/password" && chmod +x /etc/pam.d/common-password
  wget -q -O /etc/ssh/sshd_config "${REPO}Fls/sshd" && chmod 700 /etc/ssh/sshd_config
  wget -q -O /etc/banner.txt "${REPO}Bnr/issue.net"
  grep -q '^Banner /etc/banner.txt' /etc/ssh/sshd_config || echo "Banner /etc/banner.txt" >> /etc/ssh/sshd_config
  sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config
  ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
  echo "/bin/false" >> /etc/shells; echo "/usr/sbin/nologin" >> /etc/shells
  # DB akun SSH (dibutuhkan panel)
  mkdir -p /etc/ssh /etc/kyt/limit/ssh/ip /etc/limit/ssh
  [ -f /etc/ssh/.ssh.db ] || echo "& plughin Account" > /etc/ssh/.ssh.db
  sshd -t && { systemctl restart ssh 2>/dev/null || systemctl restart sshd; } \
    || { print_err "sshd_config tidak valid, SSH TIDAK direstart"; return 1; }
  mark_done ssh; print_ok "SSH terpasang"
}

# ---------- 2. Dropbear ----------
install_dropbear() {
  confirm_reinstall dropbear || return
  print_install "Memasang Dropbear"
  apt-get install -y dropbear
  wget -q -O /etc/default/dropbear "${REPO}Cfg/dropbear.conf"
  [ -f /etc/banner.txt ] || wget -q -O /etc/banner.txt "${REPO}Bnr/issue.net"
  sed -i 's@DROPBEAR_BANNER=""@DROPBEAR_BANNER="/etc/banner.txt"@g' /etc/default/dropbear
  echo "KizaruVpn Server" > /etc/handeling; echo "Yellow" >> /etc/handeling
  systemctl enable --now dropbear && systemctl restart dropbear
  mark_done dropbear; print_ok "Dropbear terpasang"
}

# ---------- SSL (acme) ----------
install_ssl() {
  need_domain || return 1
  need_base
  print_install "Memasang SSL (acme.sh / Let's Encrypt)"
  local domain; domain=$(cat /etc/xray/domain)
  rm -f /etc/xray/xray.key /etc/xray/xray.crt
  local web; web=$(lsof -i:80 2>/dev/null | awk 'NR==2 {print $1}')
  [ -n "$web" ] && systemctl stop "$web" 2>/dev/null
  systemctl stop nginx 2>/dev/null
  rm -rf /root/.acme.sh; mkdir -p /root/.acme.sh
  curl -fsSL https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh -o /root/.acme.sh/acme.sh || { print_err "Gagal unduh acme.sh"; return 1; }
  chmod +x /root/.acme.sh/acme.sh
  /root/.acme.sh/acme.sh --upgrade --auto-upgrade
  /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
  /root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 || { print_err "Gagal issue sertifikat (cek DNS domain -> IP VPS)"; return 1; }
  /root/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
  chmod 600 /etc/xray/xray.key
  mark_done ssl; print_ok "SSL terpasang"
}
need_ssl() { [ -s /etc/xray/xray.crt ] || install_ssl; [ -s /etc/xray/xray.crt ]; }

# ---------- 3. Nginx ----------
install_nginx() {
  confirm_reinstall nginx || return
  print_install "Memasang Nginx"
  apt-get remove --purge -y apache2 >/dev/null 2>&1
  apt-get install -y nginx
  mkdir -p /var/www/html
  wget -q -O /etc/nginx/nginx.conf "${REPO}Cfg/nginx.conf"
  # konfigurasi vhost xray hanya dipasang kalau domain sudah ada
  if [ -s /etc/xray/domain ]; then
    wget -q -O /etc/nginx/conf.d/xray.conf "${REPO}Cfg/xray.conf"
    sed -i "s/xxx/$(cat /etc/xray/domain)/g" /etc/nginx/conf.d/xray.conf
  fi
  nginx -t && systemctl enable --now nginx && systemctl restart nginx \
    || { print_err "Konfigurasi nginx tidak valid"; return 1; }
  mark_done nginx; print_ok "Nginx terpasang"
}

# ---------- 4. HAProxy ----------
install_haproxy() {
  confirm_reinstall haproxy || return
  need_domain || return 1
  need_ssl    || return 1
  print_install "Memasang HAProxy"
  apt-get install -y haproxy
  wget -q -O /etc/haproxy/haproxy.cfg "${REPO}Cfg/haproxy.cfg"
  sed -i "s/xxx/$(cat /etc/xray/domain)/g" /etc/haproxy/haproxy.cfg
  cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/hap.pem
  chmod 600 /etc/haproxy/hap.pem
  systemctl enable --now haproxy && systemctl restart haproxy
  mark_done haproxy; print_ok "HAProxy terpasang"
}

# ---------- 5. Xray ----------
install_xray() {
  confirm_reinstall xray || return
  need_base
  need_domain || return 1
  need_ssl    || return 1
  is_done nginx   || install_nginx
  is_done haproxy || install_haproxy
  print_install "Memasang Xray-core 1.8.24"
  mkdir -p /etc/xray /var/log/xray /usr/bin/xray /run/xray \
           /etc/vmess /etc/vless /etc/trojan /etc/shadowsocks /etc/bot \
           /etc/kyt/limit/{vmess,vless,trojan}/ip /etc/limit/{vmess,vless,trojan} /var/lib/kyt
  chown www-data:www-data /run/xray /var/log/xray
  touch /var/log/xray/access.log /var/log/xray/error.log
  for t in vmess vless trojan shadowsocks; do
    [ -f /etc/$t/.$t.db ] || echo "& plughin Account" > /etc/$t/.$t.db
  done
  [ -f /etc/bot/.bot.db ] || touch /etc/bot/.bot.db
  curl -s ifconfig.me > /etc/xray/ipvps
  curl -s ipinfo.io/city > /etc/xray/city
  curl -s ipinfo.io/org | cut -d " " -f 2-10 > /etc/xray/isp

  # Install resmi Xray (XTLS) - versi dipin
  bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data --version 1.8.24 \
    || { print_err "Gagal memasang Xray-core"; return 1; }
  wget -q -O /etc/xray/config.json "${REPO}Cfg/config.json"
  wget -q -O /etc/systemd/system/runn.service "${REPO}Fls/runn.service"
  rm -rf /etc/systemd/system/xray.service.d
  cat > /etc/systemd/system/xray.service <<'EOF'
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
  mkdir -p /usr/local/share/xray
  wget -q -O /usr/local/share/xray/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
  wget -q -O /usr/local/share/xray/geoip.dat   "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
  systemctl daemon-reload
  systemctl enable --now runn xray
  systemctl restart xray nginx haproxy
  mark_done xray; print_ok "Xray terpasang (VMess/VLESS/Trojan/Shadowsocks)"
}

# ---------- 6. WebSocket proxy (ePro) ----------
install_ws() {
  confirm_reinstall ws || return
  print_install "Memasang WebSocket Proxy (ePro)"
  wget -q -O /usr/bin/ws "${REPO}Fls/ws" && chmod +x /usr/bin/ws
  wget -q -O /usr/bin/tun.conf "${REPO}Cfg/tun.conf" && chmod 644 /usr/bin/tun.conf
  wget -q -O /etc/systemd/system/ws.service "${REPO}Fls/ws.service"
  systemctl daemon-reload
  systemctl enable --now ws && systemctl restart ws
  mark_done ws; print_ok "WebSocket proxy terpasang"
}

# ---------- 7. SlowDNS ----------
install_slowdns() {
  confirm_reinstall slowdns || return
  need_base
  print_install "Memasang SlowDNS"
  wget -q -O /tmp/nameserver "${REPO}Cfg/slowdns.sh" || { print_err "Gagal unduh"; return 1; }
  chmod +x /tmp/nameserver && /tmp/nameserver
  rm -f /tmp/nameserver
  # redirect UDP 53 -> 5300
  iptables -C INPUT -p udp --dport 5300 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 5300 -j ACCEPT
  iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null \
    || iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
  netfilter-persistent save 2>/dev/null
  mark_done slowdns; print_ok "SlowDNS terpasang (port 5300)"
}

# ---------- 8. UDP mini (7100/7200/7300) ----------
install_udpmini() {
  confirm_reinstall udpmini || return
  print_install "Memasang UDP-Mini + limit service"
  mkdir -p /usr/local/kyt
  wget -q -O /usr/local/kyt/udp-mini "${REPO}Fls/udp-mini" && chmod +x /usr/local/kyt/udp-mini
  for i in 1 2 3; do
    wget -q -O /etc/systemd/system/udp-mini-$i.service "${REPO}Fls/udp-mini-$i.service"
  done
  wget -q -O /tmp/limit.sh "${REPO}Fls/limit.sh" && chmod +x /tmp/limit.sh && /tmp/limit.sh; rm -f /tmp/limit.sh
  systemctl daemon-reload
  for i in 1 2 3; do systemctl enable --now udp-mini-$i; systemctl restart udp-mini-$i; done
  mark_done udpmini; print_ok "UDP-Mini terpasang"
}

# ---------- 9. UDP Custom ----------
install_udpcustom() {
  confirm_reinstall udpcustom || return
  print_install "Memasang UDP-Custom"
  mkdir -p /root/udp
  local ID1="1_VyhL5BILtoZZTW4rhnUiYzc4zHOsXQ8" ID2="1_XNXsufQXzcTUVVKQoBeX5Ig0J7GngGM" cf
  for pair in "$ID1:/root/udp/udp-custom" "$ID2:/root/udp/config.json"; do
    local id="${pair%%:*}" out="${pair#*:}"
    cf=$(wget -q --save-cookies /tmp/cookies.txt --keep-session-cookies "https://docs.google.com/uc?export=download&id=$id" -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1/p' | head -1)
    wget -q --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=${cf}&id=$id" -O "$out"
    rm -f /tmp/cookies.txt
  done
  [ -s /root/udp/udp-custom ] || { print_err "Gagal unduh udp-custom"; return 1; }
  chmod +x /root/udp/udp-custom; chmod 644 /root/udp/config.json
  cat > /etc/systemd/system/udp-custom.service <<'EOF'
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
  systemctl daemon-reload
  systemctl enable --now udp-custom
  mark_done udpcustom; print_ok "UDP-Custom terpasang"
}

# ---------- 10. OpenVPN ----------
install_openvpn() {
  confirm_reinstall openvpn || return
  need_base
  print_install "Memasang OpenVPN"
  apt-get install -y openvpn easy-rsa
  wget -q -O /tmp/openvpn-setup "${REPO}Vpn/openvpn" && chmod +x /tmp/openvpn-setup && /tmp/openvpn-setup
  rm -f /tmp/openvpn-setup
  systemctl enable --now openvpn && systemctl restart openvpn
  mark_done openvpn; print_ok "OpenVPN terpasang (port 1194)"
}

# ---------- 11. NoobzVPN ----------
install_noobz() {
  confirm_reinstall noobz || return
  print_install "Memasang NoobzVPNS"
  apt-get install -y git
  rm -rf /root/noobzvpn
  git clone https://github.com/Ilham24022001/noobzvpn.git /root/noobzvpn || return 1
  ( cd /root/noobzvpn && chmod +x install.sh && ./install.sh )
  systemctl enable --now noobzvpns
  wget -q -O /usr/local/sbin/m-noobz "${REPO}Cfg/m-noobz" && chmod +x /usr/local/sbin/m-noobz
  mark_done noobz; print_ok "NoobzVPNS terpasang"
}

# ---------- 12. Fail2ban ----------
install_fail2ban() {
  confirm_reinstall fail2ban || return
  print_install "Memasang Fail2ban + rsyslog"
  apt-get install -y fail2ban rsyslog
  wget -q -O /tmp/setrsyslog.sh "${REPO}Fls/setrsyslog.sh" && chmod +x /tmp/setrsyslog.sh && /tmp/setrsyslog.sh
  rm -f /tmp/setrsyslog.sh
  systemctl enable --now fail2ban && systemctl restart fail2ban
  mark_done fail2ban; print_ok "Fail2ban terpasang"
}

# ---------- 13. Vnstat ----------
install_vnstat() {
  confirm_reinstall vnstat || return
  print_install "Memasang Vnstat"
  local NET; NET=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
  apt-get install -y vnstat
  [ -f /etc/vnstat.conf ] && sed -i "s/^Interface .*/Interface \"$NET\"/" /etc/vnstat.conf
  systemctl enable --now vnstat && systemctl restart vnstat
  mark_done vnstat; print_ok "Vnstat terpasang (paket apt resmi)"
}

# ---------- 14. Swap + BBR + tuning ----------
install_tuning() {
  confirm_reinstall tuning || return
  print_install "Swap 1G + BBR + tuning sysctl"
  if ! swapon --show=NAME --noheadings 2>/dev/null | grep -qx '/swapfile'; then
    [ -f /swapfile ] || { fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none; }
    chown root:root /swapfile; chmod 0600 /swapfile
    mkswap /swapfile >/dev/null 2>&1; swapon /swapfile >/dev/null 2>&1 || true
  fi
  grep -qE '^/swapfile[[:space:]]' /etc/fstab || echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
  wget -q -O /tmp/bbr.sh "${REPO}Fls/bbr.sh" && chmod +x /tmp/bbr.sh && /tmp/bbr.sh; rm -f /tmp/bbr.sh
  local S=/etc/sysctl.conf
  grep -q '^fs.file-max' $S && sed -i 's/^fs.file-max.*/fs.file-max = 65535/' $S || echo "fs.file-max = 65535" >> $S
  grep -q '^net.netfilter.nf_conntrack_max' $S || echo "net.netfilter.nf_conntrack_max=262144" >> $S
  grep -q '^net.netfilter.nf_conntrack_tcp_timeout_time_wait' $S || echo "net.netfilter.nf_conntrack_tcp_timeout_time_wait=30" >> $S
  sysctl -p >/dev/null 2>&1
  mark_done tuning; print_ok "Tuning selesai"
}

# ---------- 15. Firewall + anti-torrent ----------
install_firewall() {
  confirm_reinstall firewall || return
  need_base
  print_install "Firewall iptables + blok torrent"
  echo -e "${Y}Ini MENIMPA /etc/iptables/rules.v4 dengan rule bawaan script.${N}"
  read -rp "Lanjut? [y/N] : " a; [[ "$a" =~ ^[Yy]$ ]] || return
  cp -f /etc/iptables/rules.v4 /etc/iptables/rules.v4.bak 2>/dev/null
  wget -q -O /tmp/ipserver "${REPO}Fls/ipserver" && bash /tmp/ipserver; rm -f /tmp/ipserver
  netfilter-persistent reload 2>/dev/null
  systemctl enable --now netfilter-persistent
  mark_done firewall; print_ok "Firewall terpasang (backup lama: rules.v4.bak)"
}

# ---------- 16. Panel / menu akun (bawaan author) ----------
install_panel() {
  local mode="$1"
  if [ "$mode" != "auto" ]; then
    confirm_reinstall panel || return
    if ! panel_licensed; then
      echo -e "${R}PERINGATAN:${N} IP VPS ini tidak terdaftar lisensi panel (kizaruvpn/izinsc)."
      echo -e "Panel akan menampilkan 'PERMISSION DENIED' lalu ${R}me-REBOOT VPS${N} tiap dipakai."
      read -rp "Ketik YA untuk tetap lanjut : " a; [ "$a" = "YA" ] || return
    fi
  fi
  need_base
  print_install "Memasang Panel Menu (add/del/renew akun)"
  cd /root || return
  wget -q -O menu.zip "${REPO}Cdy/menu.zip"
  7z x -y -pHeyHeyMauDecryptYaAwokawok menu.zip >/dev/null
  chmod +x menu/*
  wget -q -O /usr/bin/enc "${REPO}Enc/encrypt" && chmod +x /usr/bin/enc
  enc menu/*
  mv -f menu/* /usr/local/sbin/
  rm -rf menu menu.zip /usr/local/sbin/*~ /usr/local/sbin/gz* /usr/local/sbin/*.bak
  wget -q -O /usr/local/sbin/m-noobz "${REPO}Cfg/m-noobz"; chmod +x /usr/local/sbin/m-noobz
  mark_done panel; set_profile; print_ok "Panel terpasang. Ketik: menu  (menu 13 = installer layanan)"
}

# ---------- 17. Cron otomatis (opsional) ----------
install_cron() {
  confirm_reinstall cron || return
  print_install "Tugas otomatis (cron)"
  cat > /etc/cron.d/v5_logclean <<'EOF'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
*/10 * * * * root for f in /var/log/nginx/access.log /var/log/nginx/error.log /var/log/xray/access.log /var/log/xray/error.log; do [ -f $f ] && truncate -s 0 $f; done
EOF
  [ -x /usr/local/sbin/xp ]    && echo "0 2 * * * root /usr/local/sbin/xp" > /etc/cron.d/v5_xp
  [ -x /usr/local/sbin/expsc ] && echo "1 0 * * * root /usr/local/sbin/expsc -r now" > /etc/cron.d/v5_expsc
  read -rp "Aktifkan reboot otomatis harian jam 03:00? [y/N] : " a
  if [[ "$a" =~ ^[Yy]$ ]]; then
    echo "0 3 * * * root /sbin/reboot" > /etc/cron.d/v5_reboot
  else
    rm -f /etc/cron.d/v5_reboot
  fi
  systemctl restart cron
  mark_done cron; print_ok "Cron terpasang"
}

# ---------- Pasang semua ----------
install_all() {
  echo -e "${Y}Urutan: dasar -> SSH -> Dropbear -> Nginx -> Xray -> WS -> SlowDNS -> UDP -> OpenVPN -> Fail2ban -> Vnstat -> Tuning -> Panel -> Cron${N}"
  read -rp "Pasang SEMUA layanan sekarang? [y/N] : " a; [[ "$a" =~ ^[Yy]$ ]] || return
  need_base
  set_domain
  for f in install_ssh install_dropbear install_nginx install_xray install_ws install_slowdns \
           install_udpmini install_udpcustom install_openvpn install_fail2ban install_vnstat \
           install_tuning install_panel install_cron; do
    $f
  done
}

# ---------- Status ----------
show_status() {
  clear
  echo -e "${C}======== STATUS LAYANAN ========${N}"
  for s in ssh dropbear nginx haproxy xray ws server-sldns udp-mini-1 udp-mini-2 udp-mini-3 udp-custom openvpn noobzvpns fail2ban vnstat; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^$s"; then
      st=$(systemctl is-active "$s" 2>/dev/null)
      [ "$st" = "active" ] && echo -e " $s : ${G}$st${N}" || echo -e " $s : ${R}$st${N}"
    fi
  done
  echo -e "\nDomain : $(cat /etc/xray/domain 2>/dev/null || echo '-')"
  pause
}

# =====================================================================
#  MENU UTAMA
# =====================================================================
main_menu() {
  while true; do
    clear
    echo -e "${C}╔═══════════════════════════════════════════════╗${N}"
    echo -e "${C}║${W}            V5 MENU INSTALLER (modular)        ${C}║${N}"
    echo -e "${C}╚═══════════════════════════════════════════════╝${N}"
    echo -e " Domain : ${Y}$(cat /etc/xray/domain 2>/dev/null || echo 'belum diatur')${N}"
    echo
    echo -e "  ${G}0)${N} Atur Domain              $(status domain)"
    echo -e "  ${G}1)${N} Install SSH              $(status ssh)"
    echo -e "  ${G}2)${N} Install Dropbear         $(status dropbear)"
    echo -e "  ${G}3)${N} Install Nginx            $(status nginx)"
    echo -e "  ${G}4)${N} Install HAProxy          $(status haproxy)"
    echo -e "  ${G}5)${N} Install Xray             $(status xray)   ${Y}(auto: SSL+Nginx+HAProxy)${N}"
    echo -e "  ${G}6)${N} Install WebSocket Proxy  $(status ws)"
    echo -e "  ${G}7)${N} Install SlowDNS          $(status slowdns)"
    echo -e "  ${G}8)${N} Install UDP-Mini         $(status udpmini)"
    echo -e "  ${G}9)${N} Install UDP-Custom       $(status udpcustom)"
    echo -e " ${G}10)${N} Install OpenVPN          $(status openvpn)"
    echo -e " ${G}11)${N} Install NoobzVPN         $(status noobz)"
    echo -e " ${G}12)${N} Install Fail2ban         $(status fail2ban)"
    echo -e " ${G}13)${N} Install Vnstat           $(status vnstat)"
    echo -e " ${G}14)${N} Swap + BBR + Tuning      $(status tuning)"
    echo -e " ${G}15)${N} Firewall + blok torrent  $(status firewall)"
    echo -e " ${G}16)${N} Install Panel Menu Akun  $(status panel)"
    echo -e " ${G}17)${N} Tugas Otomatis (cron)    $(status cron)"
    echo -e "  ${G}a)${N} Pasang SEMUA"
    echo -e "  ${G}s)${N} Cek status layanan"
    echo -e "  ${G}r)${N} Reboot      ${G}x)${N} Keluar"
    echo
    read -rp " Pilih menu : " pil
    case "$pil" in
      0)  set_domain; pause;;
      1)  install_ssh; pause;;
      2)  install_dropbear; pause;;
      3)  install_nginx; pause;;
      4)  install_haproxy; pause;;
      5)  install_xray; pause;;
      6)  install_ws; pause;;
      7)  install_slowdns; pause;;
      8)  install_udpmini; pause;;
      9)  install_udpcustom; pause;;
      10) install_openvpn; pause;;
      11) install_noobz; pause;;
      12) install_fail2ban; pause;;
      13) install_vnstat; pause;;
      14) install_tuning; pause;;
      15) install_firewall; pause;;
      16) install_panel; pause;;
      17) install_cron; pause;;
      a|A) install_all; pause;;
      s|S) show_status;;
      r|R) read -rp "Reboot sekarang? [y/N] : " a; [[ "$a" =~ ^[Yy]$ ]] && reboot;;
      x|X|q|Q) clear; exit 0;;
      *) ;;
    esac
  done
}

# =====================================================================
#  ENTRY POINT
# =====================================================================
[ "${EUID}" -ne 0 ] && { print_err "Jalankan sebagai root"; exit 1; }
if [ ! -f "$STATE_FILE" ] || [ ! -x "$SELF_BIN" ]; then
  bootstrap
fi
main_menu
