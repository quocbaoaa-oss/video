# Tiến độ dự án — Ví Đôi

**Cập nhật:** 11/11/2026  
**Mục tiêu:** Ứng dụng quản lý chi tiêu gia đình cho hai vợ chồng (mỗi người một tài khoản, liên kết thành một gia đình chung).  
**Nền tảng:** 
- **iOS Native:** iOS 17+ (SwiftUI, tiếng Việt, tiền tệ VND, Apple Developer).
- **Progressive Web App (PWA):** Đa nền tảng (iOS Safari, Android Chrome, macOS, Windows), chạy Offline độc lập, cài trực tiếp lên Màn hình chính không lo hết hạn chứng chỉ 7 ngày!
**Kho mã nguồn GitHub:** [https://github.com/quocbaoaa-oss/video](https://github.com/quocbaoaa-oss/video)  
**Địa chỉ Web PWA Trực Tuyến:** [https://quocbaoaa-oss.github.io/video/](https://quocbaoaa-oss.github.io/video/)  
**Trạng thái hiện tại:** **Hoàn thành xuất sắc cả bản iOS Native và bản Progressive Web App (PWA)! Đã chạy trực tiếp trên GitHub Pages!**

---

## 1. Bảng tổng hợp các công việc đã hoàn thành

### 1.1. Bản Progressive Web App (PWA) — Mới hoàn thành
| # | Hạng mục | File chính | Trạng thái |
|---|---|---|---|
| 1 | Ứng dụng PWA hoàn chỉnh (Single Page Application, giao diện iOS SF Pro mượt mà, Dark Mode, hỗ trợ Safe Area Dynamic Island & Home Bar) | `index.html` | **Hoàn thành** |
| 2 | Cấu hình Web App Manifest (`standalone`, theme `#FF6B6B`, shortcuts ghi nhanh/báo cáo) | `manifest.webmanifest`, `manifest.json` | **Hoàn thành** |
| 3 | Service Worker (`sw.js`): Chiến lược Stale-While-Revalidate, lưu trữ cache ngoại tuyến chạy 100% không cần mạng | `sw.js` | **Hoàn thành** |
| 4 | Bộ biểu tượng ứng dụng đầy đủ độ phân giải (192x192, 512x512, apple-touch-icon, favicon) sinh từ logo gốc | `icons/icon-192.png`, `icons/icon-512.png`, `icons/apple-touch-icon.png`, `icons/favicon.png` | **Hoàn thành** |
| 5 | Hệ thống lưu trữ dữ liệu tự động `localStorage` (giao dịch, ví, ngân sách, mục tiêu, tên vợ chồng, cài đặt tỷ lệ), sao lưu JSON & xuất CSV | `index.html` | **Hoàn thành** |
| 6 | Chụp & đính kèm ảnh hóa đơn trực tiếp từ Camera điện thoại / Thư viện ảnh, xem phóng to toàn màn hình | `index.html` | **Hoàn thành** |
| 7 | Bàn phím máy tính thông minh (`+`, `-`, `×`, `÷`, `=`), gợi ý số tiền nhanh (`50k`, `100k`, `200k`, `500k`, `1tr`) | `index.html` | **Hoàn thành** |
| 8 | Banner hướng dẫn cài đặt thông minh cho iOS ("Chia sẻ ➔ Thêm vào MH chính") và nút 1-chạm cho Android | `index.html` | **Hoàn thành** |

### 1.2. Bản iOS SwiftUI Native (`ViDoi/`)
| # | Hạng mục | File chính | Trạng thái |
|---|---|---|---|
| 9 | Cài đặt công cụ XcodeGen, cấu hình ký số Apple Development (`DEVELOPMENT_TEAM: 7SWD44767U`) | `ViDoi/project.yml`, `ViDoi.xcodeproj` | Hoàn thành |
| 10 | Mô hình dữ liệu (`Txn`, `SpendCategory`, `RecurringRule`, `Wallet`, `Budget`, `Goal`, `PendingRatioProposal`, `Snapshot`) | `ViDoi/ViDoi/Models.swift` | Hoàn thành |
| 11 | Dịch vụ đồng bộ đám mây **Firebase Auth + Cloud Firestore** kèm chế độ dự phòng `LocalOnlySync` | `ViDoi/ViDoi/FirebaseSyncService.swift` | Hoàn thành |
| 12 | Kho trạng thái trung tâm `AppStore`: gộp giao dịch chống xung đột, báo cáo đa tháng, duyệt tỷ lệ, xuất CSV | `ViDoi/ViDoi/AppStore.swift` | Hoàn thành |
| 13 | Hệ thống giao diện SwiftUI đầy đủ (Onboarding, Face ID, Trang chủ, Sổ giao dịch, Thêm/Sửa + máy tính + camera hóa đơn, Ngân sách & Báo cáo, Cân bằng 60/40, Gia đình) | Các file Views trong `ViDoi/ViDoi/` | Hoàn thành |
| 14 | Bộ kiểm thử đơn vị (`ViDoiTests`): kiểm tra máy tính số tiền, cân bằng 60/40, chuyển ví, chống xung đột | `ViDoi/ViDoiTests/` | **Đạt 100% (5/5 PASS)** |
| 15 | Cài đặt thành công trực tiếp lên **iPhone thật (iPhone 16 Pro - "Quốc Bảo")** | `ViDoi.app` trên iPhone | **Hoàn thành** |

### 1.3. Thiết kế sản phẩm & Bản mẫu ban đầu
| # | Hạng mục | File | Trạng thái |
|---|---|---|---|
| 16 | Tài liệu thiết kế chức năng, luồng nghiệp vụ & UI/UX | `THIET_KE_APP.md` | Hoàn thành |
| 17 | Mockup tĩnh & Prototype tương tác v1, v2 | `mockup.html`, `prototype_v2.html` | Hoàn thành |
| 18 | Bộ tài nguyên Logo thiết kế dạng vector & PNG | `Logo/` | Hoàn thành |

---

## 2. Hướng dẫn sử dụng & Cài đặt bản PWA

### Trên iPhone (iOS Safari)
1. Mở trình duyệt **Safari** và truy cập vào đường dẫn trang web Ví Đôi (hoặc link deploy GitHub Pages / Vercel / Netlify / máy chủ nội bộ).
2. Chạm vào biểu tượng **Chia sẻ (Share)** hình ô vuông có mũi tên hướng lên ở thanh dưới cùng Safari.
3. Cuộn xuống và chọn **Thêm vào MH chính (Add to Home Screen)**.
4. Bấm **Thêm (Add)** ở góc trên bên phải.
5. Biểu tượng **Ví Đôi** sẽ xuất hiện trên màn hình chính như một ứng dụng iOS thực thụ: mở toàn màn hình, không có thanh địa chỉ Safari, lưu dữ liệu offline và chạy mượt mà ngay cả khi không có mạng!

### Trên Android (Google Chrome)
1. Mở **Chrome** và truy cập trang web.
2. Bấm vào banner **"Cài đặt Ví Đôi"** hiển thị trên đầu màn hình (hoặc bấm menu 3 chấm ➔ chọn **Cài đặt ứng dụng / Thêm vào màn hình chính**).
3. Ứng dụng được cài đặt vào khay ứng dụng và màn hình chính.

### Trên Máy tính (Mac / Windows)
- Mở trên Chrome / Edge / Safari: Có thể bấm vào biểu tượng "Cài đặt" trên thanh địa chỉ để cài đặt thành ứng dụng desktop riêng biệt.

---

## 3. Cấu trúc thư mục dự án

```text
App chi tieu gia dinh/
├── .gitignore                       # Cấu hình loại trừ file rác / build cache
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
├── Logo/                            # Bộ logo thiết kế đồ họa
│   ├── logo_A_vi_tim.svg            # Logo vector ví trái tim
│   ├── logo_A_vi_tim.png            # Logo phân giải cao
│   └── ...
├── mockup.html, prototype_v2.html   # Các bản prototype tham khảo trước đây
└── ViDoi/                           # Bản iOS SwiftUI Native (dành cho Xcode)
    ├── project.yml                  # Cấu hình XcodeGen
    ├── ViDoi.xcodeproj              # Dự án Xcode
    └── ViDoi/                       # Mã nguồn SwiftUI native
```
