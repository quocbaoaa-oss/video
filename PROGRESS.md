# Tiến độ dự án — Ví Đôi (iOS)

**Cập nhật:** 10/11/2026  
**Mục tiêu:** Ứng dụng quản lý chi tiêu gia đình cho hai vợ chồng (mỗi người một tài khoản, liên kết thành một gia đình chung).  
**Nền tảng đích:** iOS 17+ (SwiftUI, tiếng Việt, tiền tệ VND).  
**Trạng thái hiện tại:** Hoàn thành toàn diện giai đoạn thiết kế, nguyên mẫu tương tác và mã nguồn SwiftUI. Đã thiết lập môi trường Xcode 26 trên macOS, sửa triệt để các lỗi biên dịch, **vượt qua 100% các bài kiểm thử đơn vị**, chạy thành công trên máy ảo và **ĐÃ CÀI ĐẶT THÀNH CÔNG LÊN IPHONE THẬT CỦA BẠN (iPhone 16 Pro - "Quốc Bảo")**. Ứng dụng đã xuất hiện trên màn hình chính của iPhone!

---

## 1. Các công việc đã hoàn thành

### 1.1. Thiết kế sản phẩm & Bản mẫu tương tác (Web Prototype)
| # | Hạng mục | File | Trạng thái |
|---|---|---|---|
| 1 | Tài liệu thiết kế chức năng, luồng nghiệp vụ & UI/UX | `THIET_KE_APP.md` | Hoàn thành |
| 2 | Mockup tĩnh 5 màn hình chính | `mockup.html` | Hoàn thành |
| 3 | Mockup chi tiết 9 màn hình (Onboarding, Quyền riêng tư, Đối soát…) | `mockup_chi_tiet.html` | Hoàn thành |
| 4 | Prototype tương tác v1 | `prototype.html` | Hoàn thành |
| 5 | Prototype tương tác v2 (bản hoàn chỉnh đã kiểm thử đầy đủ luồng) | `prototype_v2.html` | Hoàn thành & đã kiểm thử |

### 1.2. Mã nguồn & Cấu hình môi trường iOS SwiftUI (`ViDoi/`)
| # | Hạng mục | File chính | Trạng thái |
|---|---|---|---|
| 6 | Cài đặt công cụ XcodeGen, sinh file dự án Xcode tự động, cấu hình `CODE_SIGN_STYLE: Automatic` để cài lên máy thật | `ViDoi/project.yml`, `ViDoi.xcodeproj` | Hoàn thành |
| 7 | Cài đặt & cấu hình Xcode 26.0.1 (tối ưu cho macOS Tahoe, đã dọn dẹp bản Xcode 16.4 để tiết kiệm dung lượng) | Hệ thống macOS | Hoàn thành |
| 8 | Mô hình dữ liệu (`Txn`, `SpendCategory`, `RecurringRule`, `Wallet`, `Budget`, `Goal`, `PendingRatioProposal`, `AppNotification`, `Snapshot`) | `ViDoi/ViDoi/Models.swift` | Hoàn thành |
| 9 | Dịch vụ đồng bộ đám mây thật qua **Firebase Auth + Cloud Firestore** kèm chế độ dự phòng `LocalOnlySync` (dùng offline hoàn toàn khi chưa gắn file cấu hình Firebase) | `ViDoi/ViDoi/FirebaseSyncService.swift` | Hoàn thành |
| 10 | Kho trạng thái trung tâm `AppStore`: lưu JSON cục bộ, gộp giao dịch chống xung đột (`mergeTransactions`), báo cáo nhiều tháng, phê duyệt tỷ lệ 2 chiều, thông báo nhắc 21:00, xuất CSV | `ViDoi/ViDoi/AppStore.swift` | Hoàn thành |
| 11 | Hệ thống giao diện SwiftUI đầy đủ (Onboarding, Khóa Face ID, Trang chủ, Sổ giao dịch, Thêm/Sửa giao dịch + máy tính + ảnh hóa đơn, Ngân sách & Báo cáo 3 tab nhiều tháng, Cân bằng 2 chiều, Gia đình & Cài đặt) | `Theme.swift`, `ViDoiApp.swift`, `OnboardingView.swift`, `HomeView.swift`, `TransactionsView.swift`, `AddTransactionView.swift`, `BudgetReportViews.swift`, `BalanceViews.swift`, `FamilyViews.swift` | Hoàn thành (Đã fix lỗi UIKit/macOS) |
| 12 | Bộ kiểm thử đơn vị (`ViDoiTests`): kiểm tra máy tính số tiền, cân bằng 60/40, chuyển ví, chống xung đột offline và phê duyệt tỷ lệ | `ViDoi/ViDoiTests/ViDoiTests.swift` | **Đạt 100% (5/5 PASS)** |
| 13 | Biên dịch (`BUILD SUCCEEDED`) và khởi chạy ứng dụng lên máy ảo iPhone 16 | `ViDoi.app` trên Simulator | Hoàn thành (Đang chạy live) |
| 14 | Ký số tự động bằng Apple ID (`baotq49.aa@gmail.com`) và cài đặt trực tiếp lên iPhone thật qua cáp | iPhone 16 Pro ("Quốc Bảo") | **Hoàn thành** |
| 15 | Khởi tạo Git repository và đẩy toàn bộ mã nguồn lên GitHub | `quocbaoaa-oss/video` | **Hoàn thành** |

### 1.3. Chi tiết các tính năng nghiệp vụ đã chạy thực tế
- **Góc nhìn linh hoạt:** Chuyển đổi tức thì giữa tài khoản **Hùng** và **Lan** ngay trên thanh đầu trang để kiểm thử phân quyền.
- **Quyền riêng tư 3 mức cho khoản Riêng:** `Ẩn hẳn` (chỉ chủ khoản thấy), `Chỉ tổng` (người kia thấy tổng tiền nhưng ẩn chi tiết), `Chi tiết` (hiển thị đầy đủ kèm nhãn *Riêng*).
- **Ghi chép & chỉnh sửa giao dịch đầy đủ:**
  - Hỗ trợ 3 loại: **Chi tiêu**, **Thu nhập**, **Chuyển khoản nội bộ** giữa các ví.
  - Bàn phím máy tính (`+`, `-`, `×`, `÷`), nút gợi ý số tiền nhanh (`50k`, `500k`…), đính kèm ảnh hóa đơn (`PhotosPicker`).
  - Sửa toàn bộ thông tin giao dịch, xóa có thanh **Hoàn tác (Undo)**, và trao đổi **bình luận** trực tiếp trên từng giao dịch.
- **Ngân sách & Báo cáo đa tháng:**
  - Chuyển đổi tháng (`‹` / `›`) xuyên suốt Trang chủ, Sổ giao dịch, Ngân sách, Báo cáo và Cân bằng.
  - Ngân sách tách riêng hạn mức **Chung** và **Riêng**, cảnh báo khi chi tiêu đạt 80% & 100%.
  - Báo cáo 3 tab (**Danh mục**, **Tháng** 6 tháng gần nhất, **So sánh** tỷ lệ thực đóng vs. thỏa thuận).
- **Cân bằng & Đối soát công bằng (2 chiều):**
  - Tự động tính số tiền cần chuyển bù theo tỷ lệ đóng góp (ví dụ 60% / 40%).
  - Đổi tỷ lệ yêu cầu **người kia xác nhận** (`PendingRatioProposal`) trước khi áp dụng.
  - Ghi nhận thanh toán bù trừ chỉ với 1 chạm.
- **Tự động hóa & Tiện ích:**
  - Quản lý danh mục tùy chỉnh, giao dịch định kỳ hàng tháng (`RecurringRule`).
  - Quản lý ví/tài khoản và quỹ mục tiêu chung.
  - Nhắc nhở ghi chép lúc 21:00 hàng ngày, khóa Face ID/Mật mã máy, xuất file CSV.

---

## 2. Hạn chế hiện tại & Hạng mục chờ tích hợp

1. **Chưa gắn file cấu hình Firebase thật (`GoogleService-Info.plist`):** Ứng dụng hiện đang chạy ở chế độ `LocalOnlySync` (lưu trữ cục bộ an toàn trên từng máy). Khi cần đồng bộ dữ liệu thời gian thực giữa 2 điện thoại, chỉ cần tải file cấu hình từ Firebase Console và gắn vào dự án.
2. **Ký chứng chỉ cá nhân miễn phí (Personal Team):** Do cài đặt trực tiếp qua cáp không qua App Store, chứng chỉ cá nhân miễn phí của Apple có thời hạn 7 ngày (sau 7 ngày cắm cáp vào Mac bấm Cmd + R để làm mới) hoặc 1 năm nếu dùng tài khoản Apple Developer trả phí.
3. **Lộ trình tính năng nâng cao Giai đoạn 2:**
   - Quét hóa đơn tự động bằng AI / VisionKit.
   - Tiện ích màn hình chính & màn hình khóa (`WidgetKit`).
   - Phím tắt Siri / App Intents ("Ghi nhanh 50k tiền cà phê").
   - Ứng dụng Apple Watch.

---

## 3. Các bước tiếp theo (Checklist triển khai)

### Bước 1 — Cài đặt trực tiếp lên iPhone thật (Đang thực hiện)
- [x] Đã cấu hình `CODE_SIGN_STYLE: Automatic` trong `ViDoi/project.yml` và tái tạo dự án `ViDoi.xcodeproj`.
- [ ] **Bật Developer Mode trên iPhone:** Vào *Cài đặt ▸ Quyền riêng tư & Bảo mật ▸ Chế độ nhà phát triển* ▸ Bật và khởi động lại iPhone.
- [ ] **Kết nối cáp:** Cắm iPhone vào máy Mac, chọn *Tin cậy máy tính này* và nhập mật mã iPhone.
- [ ] **Đăng nhập Apple ID vào Xcode:** Mở Xcode ▸ *Settings (Cmd + ,) ▸ Accounts* ▸ Bấm `+` thêm Apple ID cá nhân (miễn phí).
- [ ] **Chọn Team & Thiết bị:** Trong Xcode target `ViDoi`, chọn *Team* là Personal Team của bạn; trên thanh toolbar chọn thiết bị đích là chiếc iPhone của bạn.
- [ ] **Đẩy app:** Bấm `Cmd + R` để cài đặt trực tiếp lên iPhone.
- [ ] **Tin cậy chứng chỉ trên iPhone:** Vào *Cài đặt ▸ Cài đặt chung ▸ Quản lý VPN & Thiết bị* ▸ Bấm Tin cậy chứng chỉ Apple ID để mở app.

### Bước 2 — Kích hoạt đồng bộ Firebase giữa 2 điện thoại vợ & chồng
- [ ] Tạo project trên [Firebase Console](https://console.firebase.google.com/), bật **Authentication (Anonymous)** và **Cloud Firestore**.
- [ ] Tải `GoogleService-Info.plist` cho Bundle ID `vn.vidoi.app` (hoặc bundle ID cá nhân đã chọn) và kéo vào Xcode.
- [ ] Máy 1 tạo mã mời gia đình 6 ký tự; Máy 2 nhập mã mời để bắt đầu đồng bộ hai chiều thời gian thực.

### Bước 3 — Trải nghiệm thực tế & Lộ trình Giai đoạn 2
- [ ] Hai vợ chồng dùng thử thực tế trong 1–2 tuần ghi chép hàng ngày để thu thập phản hồi UX.
- [ ] Triển khai tiếp **WidgetKit** (xem nhanh số dư & ngân sách còn lại) và **OCR hóa đơn**.

---

## 4. Cấu trúc thư mục hiện tại

```text
App chi tieu gia dinh/
├── THIET_KE_APP.md                  # Tài liệu thiết kế sản phẩm & UI/UX
├── PROGRESS.md                      # File theo dõi tiến độ tổng thể
├── mockup.html                      # Mockup tĩnh 5 màn hình chính
├── mockup_chi_tiet.html             # Mockup chi tiết 9 màn hình
├── prototype.html                   # Prototype tương tác v1
├── prototype_v2.html                # Prototype tương tác v2 (bản hoàn chỉnh)
└── ViDoi/                           # Dự án iOS SwiftUI
    ├── project.yml                  # Cấu hình XcodeGen (Automatic Signing + ViDoiTests)
    ├── ViDoi.xcodeproj              # Dự án Xcode hoàn chỉnh (đang mở trên macOS)
    ├── README.md                    # Hướng dẫn mở project & cấu hình Firebase
    ├── ViDoi/
    │   ├── ViDoiApp.swift           # Entry point, TabView, nút +, khóa Face ID
    │   ├── Models.swift             # Models, danh mục, định kỳ, đề xuất tỷ lệ
    │   ├── FirebaseSyncService.swift# Đồng bộ Firebase + Fallback LocalOnlySync
    │   ├── AppStore.swift           # Kho trạng thái, gộp xung đột, báo cáo, CSV
    │   ├── Theme.swift              # Bảng màu, định dạng VND, card, avatar, progress bar
    │   ├── OnboardingView.swift     # Màn hình giới thiệu & kết nối gia đình
    │   ├── HomeView.swift           # Trang chủ + Trung tâm thông báo
    │   ├── TransactionsView.swift   # Sổ giao dịch, bộ lọc, hoàn tác, sửa & bình luận
    │   ├── AddTransactionView.swift # Sheet thêm giao dịch, máy tính, chuyển khoản, ảnh
    │   ├── BudgetReportViews.swift  # Ngân sách Chung/Riêng & Báo cáo đa tháng
    │   ├── BalanceViews.swift       # Cân bằng chi tiêu, phê duyệt tỷ lệ 2 chiều
    │   └── FamilyViews.swift        # Quản lý gia đình, ví, quỹ, định kỳ, quyền riêng tư
    └── ViDoiTests/
        └── ViDoiTests.swift         # Bộ 5 bài unit test tài chính (Đạt 100% PASS)
```
