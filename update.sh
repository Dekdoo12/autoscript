#!/bin/bash
dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
biji=`date +"%Y-%m-%d" -d "$dateFromServer"`
red() { echo -e "\\033[32;1m${*}\\033[0m"; }
mkdir -p /usr/local/sbin
clear
fun_bar() {
    CMD[0]="$1"
    CMD[1]="$2"
    (
        [[ -e $HOME/fim ]] && rm $HOME/fim
        ${CMD[0]} -y >/dev/null 2>&1
        ${CMD[1]} -y >/dev/null 2>&1
        touch $HOME/fim
    ) >/dev/null 2>&1 &
    tput civis
    echo -ne "  \033[0;33mPlease Wait Loading \033[1;37m- \033[0;33m["
    while true; do
        for ((i = 0; i < 18; i++)); do
            echo -ne "\033[0;32m#"
            sleep 0.1s
        done
        [[ -e $HOME/fim ]] && rm $HOME/fim && break
        echo -e "\033[0;33m]"
        sleep 1s
        tput cuu1
        tput dl1
        echo -ne "  \033[0;33mPlease Wait Loading \033[1;37m- \033[0;33m["
    done
    echo -e "\033[0;33m]\033[1;37m -\033[1;32m OK !\033[1;37m"
    tput cnorm
}
res1() {
tmpd=$(mktemp -d) && cd "$tmpd" || return 1
wget -q https://raw.githubusercontent.com/Dekdoo12/autoscript/main/Cdy/menu.zip && unzip -o -q menu.zip && chmod +x menu/*
rm -f menu/*~ menu/*.bak menu/m-noobz
cp -f menu/* /usr/local/sbin/
wget -q -O /usr/local/sbin/m-noobz https://raw.githubusercontent.com/Dekdoo12/autoscript/main/Cfg/m-noobz && chmod +x /usr/local/sbin/m-noobz
cd / && rm -rf "$tmpd"
if [ -f "/etc/slowdns/install.sh" ] && [ -f "/etc/slowdns/slowdns.env" ]; then
    echo "Slowdns Sudah Terinstall"
else
    echo "Slowdns Belum Terpasang"
    wget -q -O /tmp/slowdns-setup "https://raw.githubusercontent.com/Dekdoo12/autoscript/main/Cfg/slowdns.sh" && bash /tmp/slowdns-setup
fi
}
netfilter-persistent
clear
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e " \e[1;97;101m          UPDATE SCRIPT        \e[0m"
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
echo -e "  \033[1;91m update script service\033[1;37m"
fun_bar 'res1'
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
read -n 1 -s -r -p "Press [ Enter ] to back on menu"
rm -f "$0"
menu

###########- COLOR CODE -##############
