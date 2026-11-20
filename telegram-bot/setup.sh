#!/usr/bin/env bash
# ==============================================================================
# Script Cài Đặt Tự Động 1 Chạm Cho Máy Chủ Ví Đôi (Bảo & Oanh)
# ==============================================================================

set -e

echo "=========================================================="
echo "🚀 ĐANG TỰ ĐỘNG CÀI ĐẶT MÔI TRƯỜNG MÁY CHỦ VÍ ĐÔI..."
echo "=========================================================="

# 1. Cập nhật hệ thống và cài đặt công cụ cần thiết
export DEBIAN_FRONTEND=noninteractive
apt update -y
apt install -y git curl nano ca-certificates gnupg

# 2. Cài đặt Node.js 20 LTS (nếu chưa có)
if ! command -v node >/dev/null 2>&1 || [ "$(node -v | cut -d'.' -f1 | tr -d 'v')" -lt 18 ]; then
    echo "📦 Đang cài đặt Node.js 20 LTS..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg --yes
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
    apt update -y
    apt install -y nodejs
fi

echo "✅ Node.js: $(node -v) | NPM: $(npm -v)"

# 3. Cài đặt PM2
if ! command -v pm2 >/dev/null 2>&1; then
    echo "📦 Đang cài đặt PM2..."
    npm install -g pm2
fi

# 4. Tải hoặc cập nhật mã nguồn Ví Đôi Bot
TARGET_DIR="$HOME/video"
if [ -d "$TARGET_DIR" ]; then
    echo "🔄 Đang cập nhật mã nguồn mới nhất từ GitHub..."
    cd "$TARGET_DIR"
    git pull origin main || true
else
    echo "📥 Đang tải mã nguồn từ GitHub..."
    git clone https://github.com/quocbaoaa-oss/video.git "$TARGET_DIR"
    cd "$TARGET_DIR"
fi

cd "$TARGET_DIR/telegram-bot"
chmod +x backup.sh run.sh

# 5. Khởi chạy bot tự động 1 chạm với AI
bash run.sh

echo ""
echo "=========================================================="
echo "🎉 CÀI ĐẶT MÔI TRƯỜNG & KHỞI CHẠY BOT THÀNH CÔNG 100%!"
echo "=========================================================="
echo "👉 Bot đã sẵn sàng nhận diện chi tiêu & hóa đơn bằng AI!"
echo "=========================================================="
