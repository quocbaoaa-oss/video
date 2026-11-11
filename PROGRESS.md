# Báo cáo Tiến độ Dự án — Ví Đôi (App Chi Tiêu Gia Đình)

**Cập nhật mới nhất:** 11/11/2026  
**Mục tiêu cốt lõi:** Ứng dụng quản lý tài chính và chi tiêu thông minh cho hai vợ chồng (mỗi người một tài khoản riêng, liên kết thành bức tranh tài chính chung công bằng, minh bạch).  
**Kho mã nguồn GitHub:** [https://github.com/quocbaoaa-oss/video](https://github.com/quocbaoaa-oss/video)  
**Địa chỉ Web PWA Trực Tuyến:** [https://quocbaoaa-oss.github.io/video/](https://quocbaoaa-oss.github.io/video/)  
**Trạng thái hiện tại:** **Đã hoàn thành xuất sắc toàn bộ giai đoạn xây dựng cốt lõi và phát hành trực tuyến thành công bản Progressive Web App (PWA)!**

---

## 1. Tổng quan các nền tảng của dự án

Dự án hiện được xây dựng song song trên 2 nền tảng mạnh mẽ:

1. **Progressive Web App (PWA) — Nền tảng chính phục vụ sử dụng thực tế:**
   - Hoạt động mượt mà trên mọi thiết bị: iPhone (iOS Safari), Android (Google Chrome), iPad, macOS và Windows.
   - **Không bị giới hạn chứng chỉ 7 ngày của Apple**: Cả hai vợ chồng đều cài được trực tiếp vào Màn hình chính mà không cần máy Mac, không cần cắm cáp hay tài khoản Apple Developer.
   - Hỗ trợ **Offline First** với Service Worker: Mở app và ghi chép chi tiêu mọi lúc mọi nơi kể cả khi mất sóng, không có mạng Internet.
   - Tự động lưu trữ vĩnh viễn trên thiết bị với `localStorage`, hỗ trợ sao lưu toàn diện dạng file JSON và xuất báo cáo bảng tính CSV.

2. **Bản iOS Native (SwiftUI 5 / iOS 17+):**
   - Mã nguồn Swift thuần túy, thiết kế theo chuẩn Human Interface Guidelines của Apple.
   - Đã biên dịch thành công, đạt 100% bài kiểm thử đơn vị (`ViDoiTests`), đã đóng gói nạp trực tiếp qua cáp vào **iPhone 16 Pro ("Quốc Bảo")**.
   - Tích hợp sẵn kiến trúc đồng bộ đám mây Firebase (`FirebaseSyncService.swift`).

---

## 2. Bảng chi tiết các công việc đã hoàn thành

### 2.1. Bản Progressive Web App (PWA) Trực Tuyến
| # | Hạng mục công việc | File triển khai | Trạng thái |
|---|---|---|---|
| 1 | Xây dựng ứng dụng PWA đơn trang (SPA) đầy đủ 5 màn hình: Tổng quan (Home), Sổ giao dịch (Transactions), Thêm nhanh (Add modal), Ngân sách & Báo cáo (Budget & Reports), Cân đối & Gia đình (Balance & Family) | `index.html` | **Hoàn thành** |
| 2 | Cấu hình Web App Manifest (`standalone`, theme màu `#FF6B6B`, icon, shortcuts ghi nhanh & báo cáo) | `manifest.webmanifest`, `manifest.json` | **Hoàn thành** |
| 3 | Lập trình Service Worker quản lý bộ nhớ đệm (Caching Stale-While-Revalidate), đảm bảo app chạy mượt 100% ngoại tuyến | `sw.js` | **Hoàn thành** |
| 4 | Thiết kế và sinh bộ biểu tượng ứng dụng chuẩn đa độ phân giải (192x192, 512x512, apple-touch-icon 180x180, favicon 64x64) từ logo vector | Thư mục `icons/` | **Hoàn thành** |
| 5 | Tối ưu hóa giao diện di động: Tương thích hoàn hảo Safe Area cho Dynamic Island & Home Bar trên iPhone, hiệu ứng vuốt xóa (Swipe to delete), hoạt họa chuyển tab mượt mà | `index.html` | **Hoàn thành** |
| 6 | Bàn phím số & máy tính thông minh (`+`, `-`, `×`, `÷`, `=`), gợi ý số tiền nhanh (`50k`, `100k`, `200k`, `500k`, `1tr`) | `index.html` | **Hoàn thành** |
| 7 | Chụp và đính kèm hóa đơn trực tiếp bằng Camera điện thoại hoặc Thư viện ảnh, hỗ trợ xem phóng to toàn màn hình | `index.html` | **Hoàn thành** |
| 8 | Bộ lọc đa tháng (`‹` / `›`), xem lại lịch sử chi tiêu theo từng tháng | `index.html` | **Hoàn thành** |
| 9 | Cơ chế cân đối bù trừ 2 chiều theo tỷ lệ đóng góp (ví dụ 60/40), tự động tính số tiền ai cần chuyển cho ai | `index.html` | **Hoàn thành** |
| 10 | Tùy chỉnh tên 2 vợ chồng (Bảo & Oanh hoặc tùy biến), quản lý ví tiền, quỹ mục tiêu chung, cài đặt Dark Mode | `index.html` | **Hoàn thành** |
| 11 | Hệ thống lưu trữ an toàn `localStorage`, tính năng xuất báo cáo CSV và file sao lưu JSON | `index.html` | **Hoàn thành** |
| 12 | Thiết lập GitHub Pages, file `.nojekyll` và luồng CI/CD GitHub Actions tự động triển khai trang web | `.nojekyll`, `.github/workflows/deploy-pages.yml` | **Hoàn thành & Trực tuyến** |
| 13 | **Đồng bộ đám mây thời gian thực 2 điện thoại (Real-time Cloud Sync):** Kênh truyền tức thì Zero-config (`EventSource` SSE + JSON Relay) kết hợp tùy chọn Google Cloud Firestore riêng; tự động gộp giao dịch & bình luận không xung đột (`mergeCloudPayload`, `deletedTxIds`) | `index.html`, `sw.js` | **Hoàn thành** |
| 14 | **Ghép đôi 2 máy qua Mã QR & Magic Link (`?join=CODE&role=her`):** Phân vai thiết bị độc lập (`Tôi là Chồng` / `Tôi là Vợ`), quét QR hoặc mở link Zalo là tự động cấu hình mã gia đình và đồng bộ ngay | `index.html` | **Hoàn thành** |
| 15 | **Tất toán bằng mã VietQR chuẩn Napas247:** Tự động sinh mã QR chuyển khoản ngân hàng đúng số tiền chênh lệch và nội dung tất toán, kèm sửa giao dịch (`✏️ Sửa`), thêm Ví/Quỹ mục tiêu và khôi phục từ file JSON | `index.html` | **Hoàn thành** |

### 2.2. Bản iOS SwiftUI Native (`ViDoi/`)
| # | Hạng mục công việc | File triển khai | Trạng thái |
|---|---|---|---|
| 13 | Khởi tạo cấu hình XcodeGen và tự động ký số Apple Development | `ViDoi/project.yml`, `ViDoi.xcodeproj` | Hoàn thành |
| 14 | Định nghĩa Models dữ liệu (`Txn`, `SpendCategory`, `Wallet`, `Budget`, `Goal`, `PendingRatioProposal`) | `ViDoi/ViDoi/Models.swift` | Hoàn thành |
| 15 | Dịch vụ đồng bộ Firebase Firestore & Fallback Offline | `ViDoi/ViDoi/FirebaseSyncService.swift` | Hoàn thành |
| 16 | Bộ quản lý trạng thái `AppStore`, thuật toán gộp giao dịch chống xung đột | `ViDoi/ViDoi/AppStore.swift` | Hoàn thành |
| 17 | Toàn bộ giao diện SwiftUI 5 tab, khóa Face ID, máy tính, hóa đơn ảnh | Các Views trong `ViDoi/ViDoi/` | Hoàn thành |
| 18 | Bộ Unit Tests kiểm thử tự động thuật toán tài chính | `ViDoi/ViDoiTests/` | **Đạt 100% (5/5 PASS)** |
| 19 | Ghép đôi, bật Developer Mode và nạp cài đặt vào iPhone 16 Pro | iPhone 16 Pro ("Quốc Bảo") | **Hoàn thành** |

### 2.3. Thiết kế sản phẩm & Bản mẫu Prototype
| # | Hạng mục công việc | File triển khai | Trạng thái |
|---|---|---|---|
| 20 | Tài liệu thiết kế luồng chức năng & nghiệp vụ chi tiêu gia đình | `THIET_KE_APP.md` | Hoàn thành |
| 21 | Mockup tĩnh 5 & 9 màn hình | `mockup.html`, `mockup_chi_tiet.html` | Hoàn thành |
| 22 | Bộ bản mẫu tương tác Prototype v1 và v2 | `prototype.html`, `prototype_v2.html` | Hoàn thành |
| 23 | Bộ Logo nhận diện thương hiệu dạng vector SVG và PNG | Thư mục `Logo/` | Hoàn thành |

---

## 3. Hướng dẫn cài đặt & Trải nghiệm thực tế cho hai vợ chồng

Ứng dụng hiện đã sẵn sàng phục vụ sinh hoạt hàng ngày của hai bạn:

### Trên iPhone (Của Chồng & Vợ):
1. Dùng trình duyệt **Safari** mở: **[https://quocbaoaa-oss.github.io/video/](https://quocbaoaa-oss.github.io/video/)**
2. Bấm vào nút **Chia sẻ (Share)** ở thanh công cụ dưới đáy Safari (biểu tượng ô vuông có mũi tên hướng lên).
3. Cuộn xuống chọn **Thêm vào MH chính (Add to Home Screen)** ➔ Bấm **Thêm (Add)**.
4. Mở app **Ví Đôi** từ màn hình chính để tận hưởng trải nghiệm toàn màn hình như app gốc.

### Trên Android (Nếu có):
1. Dùng **Google Chrome** truy cập: **[https://quocbaoaa-oss.github.io/video/](https://quocbaoaa-oss.github.io/video/)**
2. Bấm vào banner **"Cài đặt Ví Đôi"** hoặc menu `⋮` chọn **Cài đặt ứng dụng**.

---

## 4. Các bước tiếp theo (Lộ trình phát triển tiếp theo)

Dưới đây là kế hoạch chi tiết cho các bước tiếp theo:

### Bước 1 — Đưa vào sử dụng thực tế hàng ngày (Thử nghiệm thực địa)
- [ ] Cài đặt ứng dụng lên màn hình chính điện thoại của cả hai vợ chồng.
- [ ] Bấm nút **"Xóa dữ liệu mẫu"** trong mục Cài đặt để bắt đầu ghi chép các khoản chi tiêu thực tế từ `0 ₫`.
- [ ] Trải nghiệm ghi chép chi tiêu ăn uống, mua sắm, xăng xe, hóa đơn sinh hoạt trong 1–2 tuần đầu.
- [ ] Kiểm tra tính tiện lợi của bàn phím máy tính nhanh và tính năng chụp ảnh đính kèm hóa đơn đi chợ/siêu thị.

### Bước 2 — Tinh chỉnh nghiệp vụ & Giao diện theo phản hồi thực tế
- [ ] Bổ sung hoặc tùy biến thêm các danh mục chi tiêu đặc thù của gia đình (nếu có).
- [ ] Điều chỉnh hạn mức ngân sách hàng tháng cho sát với thực tế chi tiêu của hai bạn.
- [ ] Tinh chỉnh cỡ chữ, khoảng cách hoặc thêm các phím tắt ghi nhanh phổ biến nhất.

### Bước 3 — Đồng bộ đám mây thời gian thực (Real-time Cloud Sync cho PWA) ✅ ĐÃ HOÀN THÀNH
- [x] Tích hợp hệ thống **Đồng bộ Đám mây Kép** (Kênh truyền tức thì Zero-config SSE + Tùy chọn Google Cloud Firestore REST API) vào bản PWA [`index.html`](file:///g:/My%20Drive/App%20chi%20tieu%20gia%20dinh/index.html).
- [x] Thiết lập **Vai trò theo từng điện thoại** (`Tôi là Chồng` / `Tôi là Vợ`) và **Ghép đôi qua Mã QR / Link mời tự động** (`?join=VD8686&role=her`).
- [x] Khi chồng ghi chép hoặc bình luận ở công ty ➔ Điện thoại của vợ ở nhà tự động nhận và gộp dữ liệu tức thì qua Internet.
- [x] Duy trì tính năng **Offline First**: Khi mất mạng vẫn ghi chép bình thường, khi có mạng lại tự động đồng bộ hóa (`online` event listener).

### Bước 4 — Tính năng thông minh & Nâng cao
- [x] **Tạo mã VietQR chuyển khoản tự động (Đã hoàn thành):** Nhấn nút `💸 Tạo mã VietQR` trong mục Gia đình tự động sinh mã VietQR chuẩn Napas247 với đúng ngân hàng, số tài khoản, số tiền cần bù trừ và nội dung chuyển khoản.
- [x] **Chỉnh sửa giao dịch & Khôi phục sao lưu JSON (Đã hoàn thành):** Cho phép sửa mọi thông tin giao dịch đã lưu (`✏️ Sửa`), thêm Ví/Quỹ mục tiêu mới và nạp lại file sao lưu `.json`.
- [ ] **Quét hóa đơn bằng AI (Gemini Vision API):** Chụp ảnh hóa đơn mua sắm, AI tự động đọc tổng tiền, ngày giờ và tự động chọn danh mục chi tiêu phù hợp.
- [ ] **Thông báo đẩy (Web Push Notifications):** Nhắc nhở hai vợ chồng ghi chép chi tiêu lúc 21:00 hàng ngày và thông báo khi có khoản chi chung lớn.

---

## 5. Cấu trúc thư mục dự án

```text
App chi tieu gia dinh/
├── .github/workflows/deploy-pages.yml# Workflow GitHub Actions tự động build & deploy PWA
├── .gitignore                       # Cấu hình loại trừ file rác / build cache
├── .nojekyll                        # Tắt Jekyll để GitHub Pages load tài nguyên tĩnh trực tiếp
├── THIET_KE_APP.md                  # Tài liệu thiết kế sản phẩm & UI/UX chi tiết
├── PROGRESS.md                      # Báo cáo tiến độ tổng thể (File này)
├── index.html                       # Ứng dụng PWA chính thức (chạy độc lập, offline, mượt mà)
├── manifest.webmanifest             # Cấu hình PWA Manifest (stand-alone, màu sắc, shortcut)
├── manifest.json                    # Cấu hình PWA Manifest phụ
├── sw.js                            # Service Worker quản lý bộ nhớ đệm Offline
├── icons/                           # Bộ icon chuẩn PWA cho iOS & Android
│   ├── icon-192.png                 # Icon 192x192
│   ├── icon-512.png                 # Icon 512x512
│   ├── apple-touch-icon.png         # Icon 180x180 cho màn hình chính iPhone
│   └── favicon.png                  # Icon 64x64 trình duyệt
├── Logo/                            # Bộ logo thiết kế đồ họa nhận diện thương hiệu
│   ├── logo_A_vi_tim.svg            # Logo vector ví trái tim
│   ├── logo_A_vi_tim.png            # Logo phân giải cao
│   └── ...
├── mockup.html, prototype_v2.html   # Các bản prototype tham khảo trước đây
└── ViDoi/                           # Bản iOS SwiftUI Native (dành cho Xcode)
    ├── project.yml                  # Cấu hình XcodeGen
    ├── ViDoi.xcodeproj              # Dự án Xcode
    └── ViDoi/                       # Mã nguồn SwiftUI native
```
