# Báo cáo Tiến độ Dự án — Ví Đôi (App Chi Tiêu Gia Đình)

**Cập nhật mới nhất:** 11/11/2026 (Phiên bản PWA v11)  
**Mục tiêu cốt lõi:** Ứng dụng quản lý tài chính và chi tiêu thông minh cho hai vợ chồng **Bảo & Oanh** (mỗi người một tài khoản riêng, liên kết thành bức tranh tài chính chung công bằng, minh bạch).  
**Kho mã nguồn GitHub:** [https://github.com/quocbaoaa-oss/video](https://github.com/quocbaoaa-oss/video)  
**Địa chỉ Web PWA Trực Tuyến:** [https://quocbaoaa-oss.github.io/video/](https://quocbaoaa-oss.github.io/video/)  
**Trạng thái hiện tại:** **Đã hoàn thành toàn diện các nâng cấp kiến trúc nghiệp vụ tài chính, thiết kế UI/UX di động on-demand, hệ thống sự kiện gia đình và đồng bộ mã hóa E2EE!**

---

## 1. Tổng quan các nền tảng của dự án

Dự án hiện được xây dựng song song trên 2 nền tảng mạnh mẽ:

1. **Progressive Web App (PWA) — Nền tảng chính phục vụ sử dụng thực tế hàng ngày:**
   - Hoạt động mượt mà trên mọi thiết bị: iPhone (iOS Safari), Android (Google Chrome), iPad, macOS và Windows.
   - **Không bị giới hạn chứng chỉ 7 ngày của Apple**: Cả hai vợ chồng đều cài được trực tiếp vào Màn hình chính (Add to Home Screen) mà không cần máy Mac, không cần cắm cáp hay tài khoản Apple Developer.
   - Hỗ trợ **Offline First** với Service Worker (`vidoi-pwa-v11-transfers-haptics-calendar-love`): Mở app và ghi chép chi tiêu mọi lúc mọi nơi kể cả khi mất sóng, không có mạng Internet.
   - **Bảo mật đa lớp**: Khóa PIN Gia Đình 4 số, mã hóa đầu cuối E2EE cho kênh truyền realtime đám mây, tự động lưu trữ vĩnh viễn trên thiết bị với `localStorage`/IndexedDB.

2. **Bản iOS Native (SwiftUI 5 / iOS 17+):**
   - Mã nguồn Swift thuần túy, thiết kế theo chuẩn Human Interface Guidelines của Apple.
   - Đạt 100% bài kiểm thử đơn vị (`ViDoiTests`), đã nạp trực tiếp qua cáp vào **iPhone 16 Pro ("Quốc Bảo")**.
   - Tích hợp sẵn kiến trúc đồng bộ đám mây Firebase (`FirebaseSyncService.swift`).

---

## 2. Bảng chi tiết các công việc đã hoàn thành

### 2.1. Nâng cấp UI/UX & Nghiệp vụ Mới Nhất (Phiên bản v11)
| # | Hạng mục công việc | Mô tả chi tiết kỹ thuật | Trạng thái |
|---|---|---|---|
| 1 | **Bàn phím On-demand & Tối ưu Form nhập** | Bàn phím số tùy biến chỉ mở lên khi người dùng chạm vào ô số tiền; tự động ẩn khi chạm ngoài; ô nhập ghi chú/tên chỉ kích hoạt bàn phím hệ điều hành khi người dùng chủ động focus, không tự động bung che khuất màn hình. | **Đã hoàn thành** |
| 2 | **Làm nổi bật trực quan Danh mục** | Hiệu ứng Active nổi bật với viền sáng neon, màu nền nổi và animation mượt mà khi chạm chọn các mục chi tiêu/thu nhập. | **Đã hoàn thành** |
| 3 | **Trình quản lý Danh mục (Category Manager)** | Cho phép thêm mới, sửa tên và thay đổi biểu tượng Emoji tùy ý cho cả 2 nhóm Chi tiêu và Thu nhập; bổ sung sẵn các danh mục tài chính: *Cho vay, Gửi tiết kiệm, Đầu tư...* | **Đã hoàn thành** |
| 4 | **Tái thiết kế màn hình Tổng quan (Dashboard)** | Thẻ tài chính tháng hiển thị rõ: Tổng thu nhập (xanh), Tổng chi (đỏ cam), Số dư ròng tích lũy. Thống kê cơ cấu chi tiêu/thu nhập trực quan; bảng theo dõi chi tiết số dư từng Tài khoản / Ví (Tiền mặt, Ngân hàng, Tiết kiệm, Đầu tư, Cho vay...). | **Đã hoàn thành** |
| 5 | **Theo dõi Sự kiện & Công việc Gia đình** | Module quản lý sự kiện/công việc: sinh nhật, ngày kỷ niệm, hạn đóng tiền, trả nợ/thu nợ... **Tự động quét và hiển thị lên màn hình Tổng quan trước 1 ngày diễn ra** kèm huy hiệu đếm ngược (`Hôm nay`, `Ngày mai`, `Sắp diễn ra`). | **Đã hoàn thành** |
| 6 | **Nghiệp vụ Chuyển ví (`kind: 't'`)** | Phân loại giao dịch thứ 3: **🔄 Chuyển ví** (luân chuyển giữa Ví nguồn và Ví đích kèm nút đảo chiều `⇄`). **Tự động cân đối số dư các tài khoản mà không làm sai lệch dòng tiền sinh hoạt** (không tính vào Tổng chi hay Tổng thu). | **Đã hoàn thành** |
| 7 | **Trải nghiệm iOS & Haptic Feedback** | Tích hợp phản hồi rung xúc giác `navigator.vibrate` chân thật khi gõ bàn phím số, chuyển tab, chọn chip tiền, mở khóa PIN; bổ sung CSS `overscroll-behavior-y: contain` chống giật nảy màn hình trên Safari iOS. | **Đã hoàn thành** |
| 8 | **Xuất lịch Apple / Google Calendar (`.ics`)** | Nút `📲` bên cạnh mỗi sự kiện gia đình tạo và tải file `.ics` tiêu chuẩn iCalendar, tích hợp chuông nhắc nhở trước 1 ngày (`TRIGGER:-P1D`), đồng bộ 1 chạm vào Apple Calendar hoặc Google Calendar. | **Đã hoàn thành** |
| 9 | **Hộp lời nhắn yêu thương (Love Note)** | Thẻ lời nhắn ngọt ngào của Bảo & Oanh hiển thị trang trọng trên trang Tổng quan; hỗ trợ chạm để gửi lời nhắn mới và **tự động mã hóa E2EE đồng bộ tức thì sang máy đối phương**. | **Đã hoàn thành** |
| 10 | **Chọn Tài khoản Thu / Chi khi ghi nhận** | Bổ sung khung chọn chuyên biệt **Tài khoản Chi tiền** (trừ tiền) khi Chi tiêu và **Tài khoản Nhận tiền** (cộng tiền) khi Thu nhập; danh sách tài khoản ngân hàng / tiền mặt hiển thị dạng thẻ ngang vuốt chạm mượt mà + dropdown chọn nhanh + nút thêm tài khoản trực tiếp; tự động trừ/cộng số dư chuẩn xác 100%; hiển thị nhãn tài khoản rõ nét trên từng dòng giao dịch và chi tiết. | **Đã hoàn thành (v12)** |
| 11 | **Trợ lý Telegram Bot Ghi Chép Siêu Tốc** | Xây dựng Bot Telegram độc lập (`telegram-bot/`) chạy trên máy chủ Cloud (VPS); tự động nhận diện ngôn ngữ tự nhiên Tiếng Việt (số tiền, danh mục, ví nguồn/đích, phân vai Chồng/Vợ); tích hợp nút bấm tương tác (xóa, đổi chung/riêng, xem số dư); **đồng bộ thời gian thực tức thì sang ứng dụng Ví Đôi PWA**; đóng gói sẵn Docker & Docker Compose chạy 1 lệnh. | **Đã hoàn thành** |

### 2.2. Các tính năng cốt lõi trước đó của bản PWA
| # | Hạng mục công việc | File triển khai | Trạng thái |
|---|---|---|---|
| 10 | Giao diện SPA 5 màn hình chuẩn di động Safe Area iPhone | `index.html` | Hoàn thành |
| 11 | Cấu hình PWA Manifest standalone, icon đa phân giải | `manifest.webmanifest`, `icons/` | Hoàn thành |
| 12 | Service Worker quản lý bộ nhớ đệm Offline First | `sw.js` | Hoàn thành |
| 13 | Bàn phím số & máy tính thông minh (`+`, `-`, `×`, `÷`, `=`) kèm chip gợi ý | `index.html` | Hoàn thành |
| 14 | Chụp & đính kèm ảnh hóa đơn trực tiếp, xem phóng to toàn màn hình | `index.html` | Hoàn thành |
| 15 | Bộ lọc đa tháng (`‹` / `›`), xem lại lịch sử giao dịch từng tháng | `index.html` | Hoàn thành |
| 16 | Cơ chế cân đối bù trừ 2 chiều theo tỷ lệ đóng góp (ví dụ 60/40 hoặc 50/50) | `index.html` | Hoàn thành |
| 17 | Tùy chỉnh tên 2 vợ chồng (Bảo & Oanh), quản lý ví tiền, quỹ mục tiêu chung | `index.html` | Hoàn thành |
| 18 | Đồng bộ đám mây thời gian thực 2 điện thoại (Real-time Cloud Sync + SSE Relay + Firestore) | `index.html` | Hoàn thành |
| 19 | Ghép đôi 2 máy qua Mã QR & Magic Link (`?join=CODE&role=her`) | `index.html` | Hoàn thành |
| 20 | Tất toán bằng mã VietQR chuẩn Napas247 tự điền số tiền và nội dung | `index.html` | Hoàn thành |
| 21 | Khóa Bảo Mật Nội Bộ (Private Couple Lock Gate) bằng Mã PIN Gia Đình | `index.html` | Hoàn thành |
| 22 | Giao diện Titanium chuyên biệt: **Sapphire Titanium** cho Bảo & **Rose Titanium** cho Oanh | `index.html` | Hoàn thành |
| 23 | Triển khai tự động CI/CD GitHub Pages trên 2 nhánh `main` và `gh-pages` | GitHub Actions | Hoàn thành |

### 2.3. Bản iOS SwiftUI Native (`ViDoi/`)
| # | Hạng mục công việc | File triển khai | Trạng thái |
|---|---|---|---|
| 24 | Khởi tạo cấu hình XcodeGen và tự động ký số Apple Development | `ViDoi/project.yml`, `ViDoi.xcodeproj` | Hoàn thành |
| 25 | Định nghĩa Models dữ liệu (`Txn`, `SpendCategory`, `Wallet`, `Budget`, `Goal`) | `ViDoi/ViDoi/Models.swift` | Hoàn thành |
| 26 | Dịch vụ đồng bộ Firebase Firestore & Fallback Offline | `ViDoi/ViDoi/FirebaseSyncService.swift` | Hoàn thành |
| 27 | Bộ quản lý trạng thái `AppStore`, thuật toán gộp giao dịch chống xung đột | `ViDoi/ViDoi/AppStore.swift` | Hoàn thành |
| 28 | Toàn bộ giao diện SwiftUI 5 tab, khóa Face ID, máy tính, hóa đơn ảnh | Các Views trong `ViDoi/ViDoi/` | Hoàn thành |
| 29 | Bộ Unit Tests kiểm thử tự động thuật toán tài chính (5/5 PASS) | `ViDoi/ViDoiTests/` | **Đạt 100%** |
| 30 | Ghép đôi, bật Developer Mode và nạp cài đặt vào iPhone 16 Pro | iPhone 16 Pro ("Quốc Bảo") | Hoàn thành |

---

## 3. Hướng dẫn sử dụng & Trải nghiệm thực tế cho hai vợ chồng

Ứng dụng trực tuyến tại: **[https://quocbaoaa-oss.github.io/video/](https://quocbaoaa-oss.github.io/video/)**

### Trên iPhone (Của Chồng Bảo & Vợ Oanh):
1. Mở link trên bằng trình duyệt **Safari**.
2. Nhấn nút **Chia sẻ (Share)** ở thanh dưới cùng (biểu tượng ô vuông có mũi tên chỉ lên).
3. Chọn **Thêm vào MH chính (Add to Home Screen)** ➔ Nhấn **Thêm (Add)**.
4. Mở app **Ví Đôi** từ màn hình chính:
   - Nhập mã PIN gia đình: `2611` (hoặc mã riêng của hai bạn).
   - Chọn vai trò: `Tôi là Chồng` (trên máy Bảo) hoặc `Tôi là Vợ` (trên máy Oanh).
   - App sẽ tự động áp dụng giao diện màu Titanium tương ứng và kết nối kênh đồng bộ riêng tư.

---

## 4. Các bước tiếp theo (Lộ trình phát triển đề xuất)

Dưới đây là các hạng mục đề xuất để tiếp tục hoàn thiện ứng dụng trong giai đoạn tới:

### Bước 1 — Kiểm thử thực địa trong đời sống hàng ngày (Ưu tiên cao)
- [ ] Hai vợ chồng sử dụng ứng dụng để ghi nhận các khoản chi tiêu thực tế hàng ngày (chợ búa, ăn uống, xăng xe, hóa đơn điện nước).
- [ ] Thử nghiệm tính năng **Chuyển ví** khi rút tiền từ Ngân hàng vào Tiền mặt, hoặc chuyển tiền vào Sổ tiết kiệm/Đầu tư.
- [ ] Thử nghiệm tính năng **Sự kiện gia đình**: thêm ngày giỗ, ngày sinh nhật, ngày đóng tiền nhà/học phí và kiểm tra hiển thị nhắc nhở trước 1 ngày trên Tổng quan.
- [ ] Trải nghiệm tính năng **Hộp lời nhắn yêu thương**: gửi lời nhắn động viên cho nhau mỗi ngày.

### Bước 2 — Tích hợp Trí tuệ Nhân tạo (AI Vision OCR)
- [ ] **Quét hóa đơn thông minh bằng AI (Gemini Vision API)**:
  - Chụp ảnh hóa đơn siêu thị, nhà hàng, cây xăng.
  - AI tự động trích xuất: Tổng số tiền thanh toán, Tên cửa hàng, Ngày giờ giao dịch.
  - Tự động gợi ý danh mục chi tiêu chính xác (ví dụ: hóa đơn WinMart ➔ `Ăn uống` / `Nhu yếu phẩm`).

### Bước 3 — Báo cáo phân tích chuyên sâu & Dự báo tài chính
- [ ] **Biểu đồ xu hướng chi tiêu 6 tháng / 1 năm**:
  - Trực quan hóa đường cong chi tiêu của gia đình theo thời gian.
  - Cảnh báo các tuần/tháng có xu hướng chi vượt ngân sách dự kiến.
- [ ] **Dự báo dòng tiền & Đích đến Tự do Tài chính**:
  - Tính toán tốc độ tích lũy dựa trên số dư các quỹ tiết kiệm & đầu tư.
  - Dự báo thời điểm hoàn thành các mục tiêu lớn (mua xe, mua nhà, quỹ học tập cho con).

### Bước 4 — Thông báo Đẩy Web (Web Push Notifications)
- [ ] Cấu hình Web Push thông qua Service Worker:
  - Nhắc nhở 2 vợ chồng ghi chép vào khung giờ cố định buổi tối (ví dụ 21:00).
  - Báo chuông khi đối phương vừa ghi một khoản chi chung lớn hoặc gửi lời nhắn yêu thương mới.

---

## 5. Cấu trúc thư mục dự án

```text
App chi tieu gia dinh/
├── .github/workflows/deploy-pages.yml# Workflow GitHub Actions tự động build & deploy PWA
├── .gitignore                       # Cấu hình loại trừ file rác / build cache
├── .nojekyll                        # Tắt Jekyll để GitHub Pages load tài nguyên tĩnh trực tiếp
├── THIET_KE_APP.md                  # Tài liệu thiết kế sản phẩm & UI/UX chi tiết
├── PROGRESS.md                      # Báo cáo tiến độ tổng thể (File này)
├── index.html                       # Ứng dụng PWA chính thức (v11: Chuyển ví, Haptic, Lịch, Lời nhắn)
├── manifest.webmanifest             # Cấu hình PWA Manifest (stand-alone, màu sắc, shortcut)
├── manifest.json                    # Cấu hình PWA Manifest phụ
├── sw.js                            # Service Worker quản lý bộ nhớ đệm Offline (v11)
├── icons/                           # Bộ icon chuẩn PWA cho iOS & Android (192, 512, apple-touch, favicon)
├── telegram-bot/                    # Trợ lý Bot Telegram ghi chép siêu tốc trên Cloud Server
│   ├── bot.js                       # Xử lý NLP tiếng Việt, đồng bộ PWA, giao tiếp Bot API
│   ├── Dockerfile                   # Đóng gói container Node 18
│   ├── docker-compose.yml           # Triển khai 1 lệnh trên Cloud VPS
│   ├── .env.example                 # File mẫu cấu hình Token, mã gia đình, PIN
│   └── README.md                    # Hướng dẫn chi tiết từ tạo bot đến vận hành
├── Logo/                            # Bộ logo thiết kế đồ họa nhận diện thương hiệu
├── mockup.html, prototype_v2.html   # Các bản prototype tham khảo trước đây
└── ViDoi/                           # Bản iOS SwiftUI Native (dành cho Xcode)
    ├── project.yml                  # Cấu hình XcodeGen
    ├── ViDoi.xcodeproj              # Dự án Xcode
    └── ViDoi/                       # Mã nguồn SwiftUI native (Models, Views, AppStore, Tests)
```
