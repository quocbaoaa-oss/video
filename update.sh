#!/usr/bin/env bash
# ==============================================================================
# Script Cập Nhật 1 Chạm Bot Ví Đôi (Bảo & Oanh)
# ==============================================================================

set -e
TARGET_DIR="${HOME}/video"

echo "🔄 Đang cập nhật mã nguồn Ví Đôi Bot từ GitHub..."
cd "$TARGET_DIR"
git pull origin main

echo "🚀 Đang khởi động lại Bot với cấu hình AI mới nhất..."
cd "$TARGET_DIR/telegram-bot"
bash run.sh
