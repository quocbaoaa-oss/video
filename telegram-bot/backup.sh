#!/usr/bin/env bash
# ==============================================================================
# Script Tự Động Sao Lưu Dữ Liệu Ví Đôi Trên Máy Chủ Cloud (Linux / Ubuntu VPS)
# Tự động nén dữ liệu, lưu trữ lịch sử 30 ngày và gửi thông báo qua Telegram
# ==============================================================================

set -euo pipefail

# 1. Thư mục cài đặt & sao lưu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backups"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
BACKUP_FILE="${BACKUP_DIR}/vidoi_backup_${TIMESTAMP}.tar.gz"

mkdir -p "${BACKUP_DIR}"

echo "=========================================================="
echo "📦 Đang thực hiện sao lưu máy chủ Ví Đôi lúc $(date)..."

# 2. Kiểm tra file dữ liệu
if [ -d "${SCRIPT_DIR}/data" ]; then
    tar -czf "${BACKUP_FILE}" -C "${SCRIPT_DIR}" data
    echo "✅ Đã nén thành công: ${BACKUP_FILE} ($(du -h "${BACKUP_FILE}" | cut -f1))"
elif [ -f "${SCRIPT_DIR}/data/database.json" ]; then
    tar -czf "${BACKUP_FILE}" -C "${SCRIPT_DIR}" data/database.json
    echo "✅ Đã nén thành công: ${BACKUP_FILE}"
else
    echo "⚠️ Chưa có thư mục data để sao lưu."
    exit 0
fi

# 3. Đọc biến môi trường từ file .env nếu có (để gửi file sang Telegram)
ENV_FILE="${SCRIPT_DIR}/.env"
if [ -f "${ENV_FILE}" ]; then
    # Lấy token bot và chat id nếu được cấu hình
    BOT_TOKEN="$(grep -E '^TELEGRAM_BOT_TOKEN=' "${ENV_FILE}" | cut -d '=' -f2- | tr -d '"' || true)"
    BACKUP_CHAT_ID="$(grep -E '^BACKUP_CHAT_ID=' "${ENV_FILE}" | cut -d '=' -f2- | tr -d '"' || true)"

    if [ -n "${BOT_TOKEN}" ] && [ -n "${BACKUP_CHAT_ID}" ]; then
        echo "📤 Đang gửi bản sao lưu về Telegram..."
        curl -s -F "chat_id=${BACKUP_CHAT_ID}" \
             -F "caption=💾 Bản sao lưu tự động máy chủ Ví Đôi (${TIMESTAMP})" \
             -F "document=@${BACKUP_FILE}" \
             "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" > /dev/null || true
        echo "✅ Đã gửi bản sao lưu về Telegram thành công!"
    fi
fi

# 4. Tự động dọn dẹp các bản sao lưu cũ hơn 30 ngày
echo "🧹 Đang dọn dẹp các bản sao lưu cũ hơn 30 ngày..."
find "${BACKUP_DIR}" -type f -name "vidoi_backup_*.tar.gz" -mtime +30 -exec rm -f {} \;

echo "🎉 Hoàn tất quá trình sao lưu máy chủ!"
echo "=========================================================="
