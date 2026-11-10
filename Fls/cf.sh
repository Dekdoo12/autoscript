#!/bin/bash
# Buat subdomain A-record di Cloudflare milik ANDA sendiri.
# Token TIDAK disimpan di repo. Isi lewat prompt, atau siapkan file /root/.cf.env (chmod 600):
#   CF_TOKEN=xxxxx          (API Token dengan izin Zone:DNS:Edit untuk zona Anda)
#   CF_ZONE_DOMAIN=domainanda.com
apt-get install -y jq curl >/dev/null 2>&1
[ -f /root/.cf.env ] && source /root/.cf.env
clear
echo -e "\033[96;1m============================\033[0m"
echo -e "\033[95;1m      INPUT SUBDOMAIN       \033[0m"
echo -e "\033[96;1m============================\033[0m"
[ -z "${CF_ZONE_DOMAIN:-}" ] && read -rp "Domain utama di Cloudflare (mis. example.com): " CF_ZONE_DOMAIN
read -rp "Subdomain (mis. vpn)                          : " SUB
if [ -z "${CF_TOKEN:-}" ]; then read -rsp "Cloudflare API Token (tidak ditampilkan)     : " CF_TOKEN; echo; fi
IP=$(wget -qO- icanhazip.com)
SUB=$(echo "$SUB" | tr -cd 'a-zA-Z0-9-')
[ -z "$SUB" ] && { echo "Subdomain tidak valid"; exit 1; }
SUB_DOMAIN="${SUB}.${CF_ZONE_DOMAIN}"
API="https://api.cloudflare.com/client/v4"
H=(-H "Authorization: Bearer ${CF_TOKEN}" -H "Content-Type: application/json")
ZONE=$(curl -sL "${API}/zones?name=${CF_ZONE_DOMAIN}&status=active" "${H[@]}" | jq -r '.result[0].id')
[ -z "$ZONE" ] || [ "$ZONE" = "null" ] && { echo "Zona tidak ditemukan / token salah"; exit 1; }
rec_id() { curl -sL "${API}/zones/${ZONE}/dns_records?name=$1&type=A" "${H[@]}" | jq -r '.result[0].id'; }
upsert() { # nama, proxied
  local id; id=$(rec_id "$1")
  local body; body=$(jq -n --arg n "$1" --arg c "$IP" --argjson p "$2" '{type:"A",name:$n,content:$c,proxied:$p}')
  if [ -z "$id" ] || [ "$id" = "null" ]; then
    curl -sL -X POST "${API}/zones/${ZONE}/dns_records" "${H[@]}" --data "$body" >/dev/null
  else
    curl -sL -X PUT "${API}/zones/${ZONE}/dns_records/${id}" "${H[@]}" --data "$body" >/dev/null
  fi
}
echo "Pointing $SUB_DOMAIN -> $IP ..."
upsert "$SUB_DOMAIN" false
upsert "*.${SUB_DOMAIN}" true
mkdir -p /etc/xray /etc/v2ray /var/lib/kyt
for f in /root/domain /root/scdomain /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain; do echo "$SUB_DOMAIN" > "$f"; done
echo "IP=$SUB_DOMAIN" > /var/lib/kyt/ipvps.conf
unset CF_TOKEN
