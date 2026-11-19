# 🤖 Ví Đôi — Telegram Bot Ghi Chép Nhanh & Tự Động Quét Hóa Đơn

Bot Telegram thông minh hỗ trợ hai vợ chồng **Bảo & Oanh** ghi chép thu chi siêu tốc bằng tin nhắn, **tự động bóc tách hóa đơn bằng AI (Gemini Vision)**, **tự động sao lưu dữ liệu máy chủ** và **đồng bộ thời gian thực 2 chiều sang ứng dụng Ví Đôi PWA**.

---

## 🌟 Tính Năng Nổi Bật

- 🧾 **Tự động đọc & điền hóa đơn bằng AI (Gemini Vision):**
  - Chụp hoặc gửi ảnh hóa đơn/bill mua sắm vào chat.
  - AI tự động trích xuất: **Tên cửa hàng, ngày, tổng tiền thanh toán và danh sách các món hàng**.
  - Hiển thị bảng duyệt thông minh kèm nút: **[✅ Xác nhận lưu]**, **[📁 Đổi danh mục]**, **[💳 Đổi tài khoản]**, **[🗑 Hủy]**.
- ⚡ **Ghi chép 1 chạm qua tin nhắn:** Nhắn `cf 45k`, `ăn sáng 65k tiền mặt`, `đi chợ 250k vcb`, `lương 30tr vcb`...
- 🧠 **Tự động nhận diện thông minh (NLP Tiếng Việt):**
  - Nhận diện số tiền đa dạng: `45k`, `1tr5`, `1.5tr`, `2tr`, `250000`, `50.000`...
  - Tự động gán Danh mục: Ăn uống, Chợ & Siêu thị, Đi lại, Nhà cửa, Hóa đơn, Con cái, Mua sắm, Sức khỏe...
  - Tự động gán Tài khoản / Ví: `vcb` (Ví chung VCB), `tiền mặt` (Tiền mặt Bảo), `momo` (Ví riêng Oanh), `tín dụng` (Thẻ tín dụng TCB)...
- 🔄 **Đồng bộ thời gian thực với Ví Đôi PWA:** Ngay khi xác nhận, app trên điện thoại của cả 2 vợ chồng tự động cập nhật số dư và thêm giao dịch vào sổ.
- 💾 **Sao lưu máy chủ an toàn & Tự động (Disaster Recovery):**
  - Gõ lệnh `/backup` bất kỳ lúc nào để bot gửi ngay file sao lưu JSON về chat.
  - Tự động sao lưu và gửi báo cáo về Telegram mỗi đêm lúc **02:00 AM**.
  - Kèm script bash `backup.sh` dọn dẹp và nén dữ liệu 30 ngày trên Linux VPS.

---

## 🚀 Hướng Dẫn Cài Đặt Trên Máy Chủ Cloud (VPS)

### Bước 1: Tạo Bot trên Telegram (Mất 1 phút)
1. Mở Telegram, tìm kiếm **`@BotFather`** (có tích xanh).
2. Gõ lệnh: `/newbot`
3. Đặt tên hiển thị cho bot: ví dụ `Ví Đôi — Trợ Lý Tài Chính`.
4. Đặt username cho bot (kết thúc bằng chữ `bot`): ví dụ `vidoi_baooanh_bot`.
5. `@BotFather` sẽ gửi chuỗi **HTTP API Token** (dạng `123456789:ABCdefGhIJKlmNoPQRstuVWXyz`). Hãy sao chép chuỗi này.
6. *(Tùy chọn nếu dùng trong nhóm chat 2 vợ chồng):* Gõ `/setprivacy` ➔ Chọn bot của bạn ➔ Chọn **`Disable`** (để bot đọc được tin nhắn trong nhóm).

---

### Bước 2: Tải mã nguồn lên Máy chủ Cloud & Cấu hình
Mở terminal trên máy chủ cloud:

```bash
cd "App chi tieu gia dinh/telegram-bot"
cp .env.example .env
nano .env
```

Điền các thông số vào file `.env`:
```env
TELEGRAM_BOT_TOKEN="123456789:ABCdefGhIJKlmNoPQRstuVWXyz"
FAMILY_CODE="BO8686"
FAMILY_PIN="2611"
GEMINI_API_KEY="AIzaSy..."    # Lấy miễn phí tại aistudio.google.com
DATA_DIR="./data"
```
*(Bấm `Ctrl + O` rồi `Enter` để lưu, `Ctrl + X` để thoát).*

---

### Bước 3: Khởi chạy Bot

#### Cách 1: Chạy bằng Docker (Khuyên dùng — Ổn định nhất)
```bash
docker compose up -d --build
```
Bot sẽ chạy ngầm vĩnh viễn trong container, tự động bật lại khi máy chủ khởi động lại.

*Xem log:*
```bash
docker compose logs -f
```

#### Cách 2: Chạy trực tiếp bằng Node.js (Yêu cầu Node 18+)
```bash
npm install -g pm2
pm2 start bot.js --name "vidoi-bot"
pm2 save
pm2 startup
```

---

## 💾 Hướng Dẫn Thiết Lập Tự Động Sao Lưu Máy Chủ

### Cách 1: Sao lưu nhanh qua Telegram
- Bất cứ khi nào muốn sao lưu, bạn chỉ cần gửi lệnh **`/backup`** vào chat bot.
- Bot sẽ lập tức đóng gói toàn bộ cơ sở dữ liệu thành file `vidoi_backup_YYYYMMDD_HHmmss.json` và gửi trực tiếp về máy bạn.
- Bạn có thể nạp file này vào ứng dụng **Ví Đôi PWA** (mục *Cài đặt ➔ Khôi phục từ file JSON*) để phục hồi số liệu bất kỳ lúc nào.
- Ngoài ra, bot đã tích hợp sẵn **tiến trình tự động gửi file sao lưu mỗi đêm lúc 02:00 AM** vào Telegram của hai bạn.

### Cách 2: Thiết lập Cronjob tự động trên Linux VPS (Nén lịch sử 30 ngày)
1. Cấp quyền thực thi cho script sao lưu:
   ```bash
   chmod +x backup.sh
   ```
2. Thêm vào bảng lập lịch hệ thống Linux (`crontab`):
   ```bash
   crontab -e
   ```
3. Dán dòng sau vào cuối file (chạy tự động lúc 02:00 sáng hàng ngày):
   ```cron
   0 2 * * * /path/to/telegram-bot/backup.sh >> /var/log/vidoi_backup.log 2>&1
   ```
   *(Thay `/path/to/` bằng đường dẫn thực tế trên máy chủ của bạn).*

---

## 💡 Cú Pháp Mẫu Ghi Chép & Quét Hóa Đơn

1. **Quét hóa đơn AI tự động điền:**
   - Chụp hoặc gửi ảnh hóa đơn trực tiếp vào chat.
   - Bot lập tức bóc tách số tiền, tên nơi bán và các món hàng.
   - Bấm **`[✅ Xác nhận lưu vào Ví Đôi]`** để ghi vào sổ, hoặc đổi danh mục/tài khoản chỉ với 1 chạm.

2. **Ghi chép chi tiêu bằng tin nhắn:**
   - `cf 45k` ➔ Ăn uống (45.000 ₫)
   - `ăn sáng 65k tiền mặt` ➔ Ăn uống, trừ ví Tiền mặt (65.000 ₫)
   - `đi chợ 250k vcb` ➔ Chợ & Siêu thị, trừ ví VCB (250.000 ₫)
   - `xăng xe 120k` ➔ Đi lại (120.000 ₫)
   - `tiền điện 1tr2 vcb` ➔ Hóa đơn (1.200.000 ₫)

3. **Ghi nhận thu nhập (tiền về):**
   - `lương 30tr vcb` ➔ Lương & Thưởng, cộng ví VCB (+30.000.000 ₫)
   - `thu 5tr bán đồ cũ` ➔ Kinh doanh (+5.000.000 ₫)

4. **Chuyển tiền giữa các ví / Tiết kiệm:**
   - `chuyển 5tr vcb sang tiết kiệm` ➔ Chuyển ví (Trừ VCB, cộng Tiết kiệm)
   - `chuyển 2tr vcb qua tiền mặt` ➔ Rút tiền mặt (Trừ VCB, cộng Tiền mặt)

5. **Các lệnh tiện ích:**
   - `/backup` hoặc `/saoluu`: Tải ngay file sao lưu database về máy.
   - `/vi` hoặc `/sodu`: Xem số dư tất cả các ví và tổng tài sản hiện có.
   - `/baocao` hoặc `/thongke`: Xem tổng thu, tổng chi và số dư tháng này.
   - `/role him` (đổi sang Chồng) hoặc `/role her` (đổi sang Vợ).
   - `/help`: Xem hướng dẫn chi tiết.
