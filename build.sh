#!/bin/bash
# Bangun ulang zip dari src/ (jalankan sebelum commit bila src/ diubah).
set -e
cd "$(dirname "$0")/src"
rm -f ../Cdy/menu.zip ../Bot/bot.zip ../Bot/kyt.zip
mkdir -p ../Cdy
zip -rqX ../Cdy/menu.zip menu
zip -rqX ../Bot/bot.zip bot
zip -rqX ../Bot/kyt.zip kyt -x '*/__pycache__/*'
echo "OK: Cdy/menu.zip Bot/bot.zip Bot/kyt.zip"
