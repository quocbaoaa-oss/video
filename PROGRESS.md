# Tiến độ dự án — Ví Đôi (iOS)

**Cập nhật:** 10/11/2026  
**Mục tiêu:** Ứng dụng quản lý chi tiêu gia đình cho hai vợ chồng (mỗi người một tài khoản, liên kết thành một gia đình chung).  
**Nền tảng đích:** iOS 17+ (SwiftUI, tiếng Việt, tiền tệ VND).  
**Kho mã nguồn GitHub:** [https://github.com/quocbaoaa-oss/video](https://github.com/quocbaoaa-oss/video)  
**Trạng thái hiện tại:** **Hoàn thành xuất sắc toàn bộ mục tiêu giai đoạn cốt lõi!** 
- Mã nguồn SwiftUI đã biên dịch hoàn chỉnh, vượt qua 100% bài kiểm thử đơn vị.
- Đã cài đặt thành công trực tiếp lên **iPhone thật (iPhone 16 Pro - "Quốc Bảo")** qua chứng chỉ Apple Development.
- Đã đồng bộ và đẩy toàn bộ mã nguồn lên **GitHub** với xác thực SSH tự động.

---

## 1. Bảng tổng hợp các công việc đã hoàn thành

### 1.1. Thiết kế sản phẩm & Bản mẫu tương tác (Web Prototype)
| # | Hạng mục | File | Trạng thái |
|---|---|---|---|
| 1 | Tài liệu thiết kế chức năng, luồng nghiệp vụ & UI/UX | `THIET_KE_APP.md` | Hoàn thành |
| 2 | Mockup tĩnh 5 màn hình chính | `mockup.html` | Hoàn thành |
| 3 | Mockup chi tiết 9 màn hình (Onboarding, Quyền riêng tư, Đối soát…) | `mockup_chi_tiet.html` | Hoàn thành |
| 4 | Prototype tương tác v1 | `prototype.html` | Hoàn thành |
| 5 | Prototype tương tác v2 (bản hoàn chỉnh đã kiểm thử đầy đủ luồng) | `prototype_v2.html` | Hoàn thành & đã kiểm thử |

### 1.2. Mã nguồn iOS SwiftUI (`ViDoi/`)
| # | Hạng mục | File chính | Trạng thái |
|---|---|---|---|
| 6 | Cài đặt công cụ XcodeGen, cấu hình ký số Apple Development (`DEVELOPMENT_TEAM: 7SWD44767U`) | `ViDoi/project.yml`, `ViDoi.xcodeproj` | Hoàn thành |
| 7 | Cài đặt & cấu hình môi trường Xcode 26.0.1 (tối ưu hóa cho macOS Tahoe, dọn dẹp Xcode 16.4) | Hệ thống macOS | Hoàn thành |
| 8 | Mô hình dữ liệu (`Txn`, `SpendCategory`, `RecurringRule`, `Wallet`, `Budget`, `Goal`, `PendingRatioProposal`, `AppNotification`, `Snapshot`) | `ViDoi/ViDoi/Models.swift` | Hoàn thành |
| 9 | Dịch vụ đồng bộ đám mây **Firebase Auth + Cloud Firestore** kèm chế độ dự phòng `LocalOnlySync` (chạy mượt mà offline không phụ thuộc mạng) | `ViDoi/ViDoi/FirebaseSyncService.swift` | Hoàn thành |
| 10 | Kho trạng thái trung tâm `AppStore`: lưu JSON cục bộ, gộp giao dịch chống xung đột (`mergeTransactions`), báo cáo nhiều tháng, phê duyệt tỷ lệ 2 chiều, thông báo nhắc 21:00, xuất CSV | `ViDoi/ViDoi/AppStore.swift` | Hoàn thành |
| 11 | Hệ thống giao diện SwiftUI đầy đủ (Onboarding, Khóa Face ID, Trang chủ, Sổ giao dịch, Thêm/Sửa giao dịch + máy tính + ảnh hóa đơn, Ngân sách & Báo cáo 3 tab nhiều tháng, Cân bằng 2 chiều, Gia đình & Cài đặt) | `Theme.swift`, `ViDoiApp.swift`, `OnboardingView.swift`, `HomeView.swift`, `TransactionsView.swift`, `AddTransactionView.swift`, `BudgetReportViews.swift`, `BalanceViews.swift`, `FamilyViews.swift` | Hoàn thành |
| 12 | Bộ kiểm thử đơn vị (`ViDoiTests`): kiểm tra máy tính số tiền, cân bằng 60/40, chuyển ví, chống xung đột offline và phê duyệt tỷ lệ | `ViDoi/ViDoiTests/ViDoiTests.swift` | **Đạt 100% (5/5 PASS)** |
| 13 | Biên dịch (`BUILD SUCCEEDED`) và chạy thử nghiệm trên máy ảo iPhone 16 Simulator | `ViDoi.app` trên Simulator | Hoàn thành |

### 1.3. Cài đặt trực tiếp lên iPhone thật & Quản lý mã nguồn
| # | Hạng mục | Đối tượng | Trạng thái |
|---|---|---|---|
| 14 | Ghép đôi thiết bị (Pairing) & Kích hoạt Developer Mode cho máy thật | iPhone 16 Pro ("Quốc Bảo") | Hoàn thành |
| 15 | Ký số Personal Team (`baotq49.aa@gmail.com`) & Sinh cấu hình Provisioning Profile | `vn.vidoi.app.quocbao` | Hoàn thành |
| 16 | Nạp và cài đặt ứng dụng thành công lên iPhone thật qua cáp | `ViDoi.app` trên iPhone | **Hoàn thành** |
| 17 | Tạo file `.gitignore` chuẩn, cấu hình khóa SSH ed25519 cho GitHub | macOS / `~/.ssh` | Hoàn thành |
| 18 | Đẩy toàn bộ mã nguồn lên GitHub repository | `quocbaoaa-oss/video` | **Hoàn thành** |

---

## 2. Chi tiết các tính năng nghiệp vụ đã hoạt động thực tế

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

## 3. Các bước tiếp theo

### Bước 1 — Mở và trải nghiệm ứng dụng trên iPhone của bạn
- [x] Đã cài ứng dụng vào màn hình chính iPhone.
- [ ] **Mở khóa Tin cậy chứng chỉ (Làm 1 lần duy nhất trên iPhone):**
  1. Vào **Cài đặt (Settings)** ➔ **Cài đặt chung (General)**.
  2. Chọn **Quản lý VPN & Thiết bị (VPN & Device Management)**.
  3. Bấm vào tài khoản `baotq49.aa@gmail.com` trong mục *Developer App*.
  4. Bấm **Tin cậy "baotq49.aa@gmail.com"** (Trust).
  5. Ra màn hình chính chạm vào icon **Ví Đôi** để mở app.

### Bước 2 — Sử dụng thử nghiệm & Tinh chỉnh thực tế
- [ ] Trải nghiệm ghi chép các khoản chi tiêu thực tế hàng ngày, thử tính năng máy tính, gắn ảnh hóa đơn.
- [ ] Thử nghiệm đổi tháng, kiểm tra báo cáo chi tiêu và đối soát cân bằng.
- [ ] Ghi nhận phản hồi về trải nghiệm giao diện (UX) để điều chỉnh giao diện hoặc font chữ nếu cần.

### Bước 3 — Kích hoạt đồng bộ đám mây Firebase (Khi cần liên kết 2 điện thoại riêng biệt)
- [ ] Tạo project miễn phí trên [Firebase Console](https://console.firebase.google.com/).
- [ ] Bật dịch vụ **Authentication (Anonymous)** và **Cloud Firestore**.
- [ ] Tải file `GoogleService-Info.plist` gắn vào Xcode.
- [ ] Máy người chồng tạo mã gia đình (6 ký tự); máy người vợ nhập mã để đồng bộ tự động dữ liệu 2 chiều qua Internet.

### Bước 4 — Lộ trình Giai đoạn 2 (Tính năng cao cấp)
- [ ] **Tiện ích màn hình (WidgetKit):** Xem nhanh hạn mức ngân sách còn lại và số dư ngay trên màn hình khóa / màn hình chính.
- [ ] **Quét hóa đơn AI (VisionKit / Gemini):** Chụp ảnh hóa đơn tự động bóc tách số tiền và danh mục chi tiêu.
- [ ] **Siri Shortcuts & App Intents:** Hỗ trợ ra lệnh bằng giọng nói: *"Siri, ghi 50 nghìn tiền cà phê vào Ví Đôi"*.

---

## 4. Cấu trúc thư mục dự án

```text
App chi tieu gia dinh/
├── .gitignore                       # Cấu hình loại trừ file rác / build cache
├── THIET_KE_APP.md                  # Tài liệu thiết kế sản phẩm & UI/UX chi tiết
├── PROGRESS.md                      # Báo cáo tiến độ tổng thể (File này)
├── mockup.html                      # Mockup tĩnh 5 màn hình chính
├── mockup_chi_tiet.html             # Mockup chi tiết 9 màn hình
├── prototype.html                   # Prototype tương tác v1
├── prototype_v2.html                # Prototype tương tác v2 (bản web hoàn chỉnh)
└── ViDoi/                           # Toàn bộ mã nguồn ứng dụng iOS SwiftUI
    ├── project.yml                  # Cấu hình XcodeGen & Apple Code Signing
    ├── ViDoi.xcodeproj              # File dự án Xcode
    ├── README.md                    # Hướng dẫn mở dự án & cấu hình Firebase
    ├── ViDoi/
    │   ├── ViDoiApp.swift           # Entry point, TabView 5 tab, khóa Face ID
    │   ├── Models.swift             # Data models, danh mục, định kỳ, đề xuất tỷ lệ
    │   ├── FirebaseSyncService.swift# Đồng bộ Firebase + LocalOnlySync fallback
    │   ├── AppStore.swift           # Quản lý trạng thái, gộp dữ liệu chống xung đột, CSV
    │   ├── Theme.swift              # Bảng màu, format tiền tệ VND, UI components
    │   ├── OnboardingView.swift     # Màn hình mở đầu & liên kết gia đình
    │   ├── HomeView.swift           # Trang chủ & thông báo
    │   ├── TransactionsView.swift   # Sổ giao dịch, bộ lọc, hoàn tác, sửa & bình luận
    │   ├── AddTransactionView.swift # Thêm giao dịch, bàn phím máy tính, hóa đơn
    │   ├── BudgetReportViews.swift  # Ngân sách Chung/Riêng & Báo cáo 3 tab đa tháng
    │   ├── BalanceViews.swift       # Cân bằng chi tiêu, chuyển tiền bù, duyệt tỷ lệ
    │   └── FamilyViews.swift        # Quản lý ví, quỹ mục tiêu, định kỳ, quyền riêng tư
    └── ViDoiTests/
        └── ViDoiTests.swift         # Bộ 5 bài unit test tài chính (100% PASS)
```
