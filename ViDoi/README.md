# Ví Đôi – SwiftUI MVP (có đồng bộ Firebase)

App iOS 17+ quản lý chi tiêu cho 2 vợ chồng (SwiftUI, `@Observable`, Swift Charts, LocalAuthentication, Firebase Auth + Cloud Firestore).

> Code được viết trên Windows nên **chưa được biên dịch**. Khi mở trong Xcode có thể cần sửa vài lỗi nhỏ.

## Chạy trong Xcode (Mac)
**Cách 1 – XcodeGen (khuyến nghị, tự cài SPM Firebase)**
1. `brew install xcodegen && cd ViDoi && xcodegen && open ViDoi.xcodeproj`
2. (Tùy chọn) Kéo `GoogleService-Info.plist` vào target `ViDoi` để bật đồng bộ đám mây thật. Nếu chưa có file này, app tự động chạy ở chế độ cục bộ (`LocalOnlySync`).

**Cách 2 – thủ công**
1. Xcode ▸ File ▸ New ▸ Project ▸ iOS App (SwiftUI, tên `ViDoi`, iOS 17).
2. Xóa `ContentView.swift` và file `@main` mặc định.
3. Kéo toàn bộ file trong thư mục `ViDoi/ViDoi/*.swift` vào project.
4. File ▸ Add Package Dependencies… ▸ nhập `https://github.com/firebase/firebase-ios-sdk` ▸ chọn `FirebaseAuth` và `FirebaseFirestore`.
5. Target ▸ Info: thêm `NSFaceIDUsageDescription` = "Mở Ví Đôi bằng Face ID".
6. Chạy trên iPhone 15/16 Simulator.

## Cấu hình Firebase để đồng bộ 2 máy thật
1. Tạo project tại [console.firebase.google.com](https://console.firebase.google.com/).
2. Thêm ứng dụng iOS với Bundle ID `vn.vidoi.app`, tải `GoogleService-Info.plist` và kéo vào Xcode target `ViDoi`.
3. Vào **Authentication ▸ Sign-in method** ▸ bật **Anonymous** (hoặc nâng cấp lên Sign in with Apple / Email sau).
4. Vào **Cloud Firestore ▸ Create database** và đặt Rules:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /families/{code} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```
5. Trên Máy 1: mở app ▸ nhập tên ▸ màn hình **Kết nối gia đình** sẽ tự đăng mã mời 6 ký tự lên `families/{CODE}` (hiệu lực 48 giờ) và lắng nghe realtime.
6. Trên Máy 2: mở app ▸ nhập tên ▸ chọn **“Tôi có mã mời từ vợ/chồng”** ▸ nhập mã 6 ký tự. Máy 2 sẽ tải toàn bộ dữ liệu gia đình về, ghi danh thành viên thứ 2 (tối đa 2 người/gia đình), tạo ví riêng mặc định và bật đồng bộ hai chiều.

## Cấu trúc
| File | Nội dung |
|---|---|
| `Models.swift` | `Person`, `Txn`, `Wallet`, `Budget`, `Goal`, `PrivacyMode`, `Snapshot` |
| `FirebaseSyncService.swift` | `SyncService`, `FamilyPayload`, `FirebaseSyncService` (Auth + Firestore realtime) & fallback `LocalOnlySync` |
| `AppStore.swift` | Trạng thái + logic (riêng tư, cân đối, ngân sách), lưu JSON offline + đồng bộ đám mây hai chiều |
| `Theme.swift` | Màu, định dạng VND, component dùng chung |
| `ViDoiApp.swift` | Entry, khóa Face ID, TabView + nút ＋ |
| `OnboardingView.swift` | Giới thiệu, hồ sơ, tạo/nhập mã gia đình có xác thực đám mây |
| `HomeView.swift` | Tổng quan, ghi nhanh, ví, mục tiêu, giao dịch gần đây |
| `TransactionsView.swift` | Danh sách (tìm, lọc, vuốt xóa + hoàn tác) và chi tiết |
| `AddTransactionView.swift` | Nhập giao dịch với bàn phím có phép tính |
| `BudgetReportViews.swift` | Ngân sách (sửa hạn mức) và Báo cáo (biểu đồ) |
| `BalanceViews.swift` | Cân đối, tỷ lệ đóng góp, tất toán |
| `FamilyViews.swift` | Gia đình, trạng thái đồng bộ, quyền riêng tư, ví, mục tiêu |

## Đã có
Onboarding · hồ sơ · **mã mời 6 ký tự xác thực trên Firestore (hết hạn 48h, giới hạn 2 thành viên) + đồng bộ realtime** · giao dịch chi/thu · Chung/Riêng · 3 mức riêng tư · ví · ngân sách · báo cáo · cân đối & tất toán · mục tiêu · Face ID · lưu offline · Hoàn tác khi xóa.

## Còn lại cho các bước tiếp theo
1. Yêu cầu đổi tỷ lệ cần người kia bấm xác nhận (hiện đồng bộ tỷ lệ mới ngay giữa 2 máy theo `ratioCreator`).
2. Báo cáo nhiều tháng + bộ chọn tháng.
3. Sửa đầy đủ các trường của giao dịch.
4. Bình luận giao dịch, giao dịch định kỳ, thông báo đẩy (FCM), widget, quét hóa đơn.
