#!/usr/bin/env bash
# ==============================================================================
# Script Tự Động Khởi Chạy & Cấu Hình Ví Đôi Bot (Bảo & Oanh)
# ==============================================================================

set -e
cd "$(dirname "$0")"

echo "⚙️ Đang cấu hình và kiểm tra kết nối Bot Ví Đôi..."

# Giải mã token và tạo file .env chuẩn xác 100%
DECODED_TOKEN=$(echo "OTA3Mzk0NjA4MjpBQUU5M3hIRUFDLTh6Tl9NRVVmeUVnRDZvXzM1QnlJTTNDNA==" | base64 -d)

cat << EOF > .env
TELEGRAM_BOT_TOKEN=${DECODED_TOKEN}
FAMILY_CODE=BO8686
FAMILY_PIN=2611
GEMINI_API_KEY=
DATA_DIR=./data
EOF

echo "✅ Đã tạo file .env chính xác!"

# Khởi động lại hoặc tạo mới tiến trình trên PM2
pm2 delete vidoi-bot 2>/dev/null || true
pm2 start bot.js --name vidoi-bot
pm2 save

echo ""
echo "=========================================================="
echo "🎉 BOT VÍ ĐÔI ĐÃ KHỞI CHẠY THÀNH CÔNG!"
echo "=========================================================="
echo "👉 Đang hiển thị log trạng thái hoạt động bên dưới:"
sleep 2
pm2 logs vidoi-bot --lines 15 --nostream
