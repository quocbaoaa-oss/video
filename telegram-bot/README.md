# 🤖 Ví Đôi — Telegram Bot Ghi Chép Nhanh

Bot Telegram thông minh hỗ trợ hai vợ chồng **Bảo & Oanh** ghi chép thu chi siêu tốc bằng tin nhắn, tự động phân tích ngôn ngữ tự nhiên Tiếng Việt và **đồng bộ tức thì 2 chiều sang ứng dụng Ví Đôi PWA**.

---

## 🌟 Tính Năng Nổi Bật

- ⚡ **Ghi chép 1 chạm qua tin nhắn:** Chỉ cần nhắn `cf 45k`, `ăn sáng 65k tiền mặt`, `đi chợ 250k vcb`, `lương 30tr vcb`...
- 🧠 **Tự động nhận diện thông minh (NLP Tiếng Việt):**
  - Nhận diện số tiền đa dạng: `45k`, `1tr5`, `1.5tr`, `2tr`, `250000`, `50.000`...
  - Tự động gán Danh mục: Ăn uống, Chợ & Siêu thị, Đi lại, Nhà cửa, Hóa đơn, Con cái, Mua sắm, Sức khỏe...
  - Tự động gán Tài khoản / Ví: `vcb` (Ví chung VCB), `tiền mặt` (Tiền mặt Bảo), `momo` (Ví riêng Oanh), `tín dụng` (Thẻ tín dụng TCB)...
- 🔄 **Đồng bộ thời gian thực với Ví Đôi PWA:** Ngay khi bot phản hồi, app trên điện thoại của cả 2 vợ chồng tự động cập nhật số dư và thêm giao dịch vào sổ.
- 👥 **Phân vai linh hoạt:** Hỗ trợ dùng trong chat riêng 1-1 hoặc thêm bot vào **Nhóm chat 2 vợ chồng**, tự động nhận diện ai là người chi/thu.
- 📱 **Nút bấm tương tác tiện lợi:**
  - Nút **[🗑 Hủy / Xóa]** để hoàn tác giao dịch nếu gõ nhầm.
  - Nút **[👥 Chung / 🔒 Riêng]** để đổi tính chất bảo mật.
  - Nút **[📊 Xem số dư ví]** xem nhanh số dư tất cả tài khoản.

---

## 🚀 Hướng Dẫn Cài Đặt Trên Máy Chủ Cloud (VPS)

### Bước 1: Tạo Bot trên Telegram (Mất 1 phút)
1. Mở Telegram, tìm kiếm **`@BotFather`** (có tích xanh).
2. Gõ lệnh `/newbot`.
3. Đặt tên hiển thị cho bot: ví dụ `Ví Đôi — Trợ Lý Tài Chính`.
4. Đặt username cho bot (phải kết thúc bằng chữ `bot`): ví dụ `ViDoiBaoOanh_bot`.
5. `@BotFather` sẽ gửi cho bạn một chuỗi **HTTP API Token** (dạng `123456789:ABCdefGhIJKlmNoPQRstuVWXyz`). **Hãy sao chép token này.**
6. *(Tùy chọn nếu dùng trong nhóm):* Gõ `/setprivacy` ➔ Chọn bot của bạn ➔ Chọn **`Disable`** để bot có thể đọc được tin nhắn ghi chép trong nhóm 2 vợ chồng.

---

### Bước 2: Tải mã nguồn lên Máy chủ Cloud
Trên máy chủ Cloud (VPS), mở terminal và di chuyển vào thư mục:

```bash
cd "App chi tieu gia dinh/telegram-bot"
```

Tạo file cấu hình `.env` từ file mẫu:
```bash
cp .env.example .env
nano .env
```

Điền token bot vừa lấy vào:
```env
TELEGRAM_BOT_TOKEN="123456789:ABCdefGhIJKlmNoPQRstuVWXyz"
FAMILY_CODE="BO8686"
FAMILY_PIN="2611"
DATA_DIR="./data"
```
*(Bấm `Ctrl + O` rồi `Enter` để lưu, `Ctrl + X` để thoát).*

---

### Bước 3: Khởi chạy Bot

#### Cách 1: Chạy bằng Docker (Khuyên dùng — Ổn định nhất)
Nếu server đã có Docker & Docker Compose:
```bash
docker compose up -d --build
```
Bot sẽ chạy ngầm vĩnh viễn trong container, tự động bật lại khi server khởi động lại.

*Xem log hoạt động:*
```bash
docker compose logs -f
```

#### Cách 2: Chạy trực tiếp bằng Node.js (Yêu cầu Node 18 trở lên)
Không cần cài thêm thư viện (Zero dependency):
```bash
# Cài pm2 để chạy ngầm (nếu chưa có: npm install -g pm2)
pm2 start bot.js --name "vidoi-bot"
pm2 save
pm2 startup
```

---

## 💡 Hướng Dẫn Sử Dụng & Cú Pháp Mẫu

Sau khi bật bot, bạn hãy mở Telegram tìm bot của bạn (hoặc thêm bot vào nhóm chat của 2 vợ chồng):

1. **Khởi động:** Gõ `/start` ➔ Bấm chọn vai trò **`👨 Tôi là Bảo`** hoặc **`👩 Tôi là Oanh`**.
2. **Ghi chép chi tiêu:**
   - `cf 45k` ➔ Ăn uống (45.000 ₫)
   - `ăn sáng 65k tiền mặt` ➔ Ăn uống, trừ ví Tiền mặt (65.000 ₫)
   - `đi chợ 250k vcb` ➔ Chợ & Siêu thị, trừ ví VCB (250.000 ₫)
   - `xăng xe 120k` ➔ Đi lại (120.000 ₫)
   - `mua bỉm cho con 350k vcb` ➔ Con cái (350.000 ₫)
   - `tiền điện 1tr2 vcb` ➔ Hóa đơn (1.200.000 ₫)
3. **Ghi nhận thu nhập (tiền về):**
   - `lương 30tr vcb` ➔ Lương & Thưởng, cộng ví VCB (+30.000.000 ₫)
   - `thu 5tr bán đồ cũ` ➔ Kinh doanh (+5.000.000 ₫)
4. **Chuyển tiền giữa các ví / Tiết kiệm:**
   - `chuyển 5tr vcb sang tiết kiệm` ➔ Chuyển ví (Trừ VCB, cộng Tiết kiệm)
   - `chuyển 2tr vcb qua tiền mặt` ➔ Rút tiền mặt (Trừ VCB, cộng Tiền mặt)
5. **Các lệnh tiện ích:**
   - `/vi` hoặc `/sodu`: Xem số dư tất cả các ví và tổng tài sản hiện có.
   - `/baocao` hoặc `/thongke`: Xem tổng thu, tổng chi và số dư tháng này.
   - `/role him` (đổi sang Chồng) hoặc `/role her` (đổi sang Vợ).
   - `/help`: Xem trợ giúp.
