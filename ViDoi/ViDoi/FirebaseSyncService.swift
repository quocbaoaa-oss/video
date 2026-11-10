import Foundation

/// Gói dữ liệu gia đình được lưu trên Firestore tại `families/{familyCode}`.
/// Mỗi thành viên tự giữ cài đặt riêng (`privacy`, `faceIDLock`, `meID`) trên máy;
/// dữ liệu chung (thành viên, giao dịch, ví, ngân sách, mục tiêu, tỷ lệ, tất toán) được đồng bộ realtime.
struct FamilyPayload: Codable, Equatable {
    var familyCode: String
    var people: [Person]
    var creatorID: UUID
    var transactions: [Txn]
    var deletedTxIDs: [UUID]?
    var wallets: [Wallet]
    var budgets: [Budget]
    var goals: [Goal]
    var categories: [SpendCategory]?
    var recurringRules: [RecurringRule]?
    /// Tỷ lệ đóng góp của người tạo gia đình (`creatorID`), từ 10 đến 90.
    var ratioCreator: Int
    /// Đề xuất đổi tỷ lệ đang chờ thành viên kia đồng ý.
    var pendingRatio: PendingRatioProposal?
    var settledMonths: [String]
    var monthlyBudget: Int
    var notifications: [AppNotification]?
    var updatedAt: Date
    var updatedBy: UUID
}

enum SyncState: Equatable {
    case localOnly
    case connecting
    case synced(Date)
    case error(String)

    var label: String {
        switch self {
        case .localOnly: return "Chế độ cục bộ (chưa gắn Firebase)"
        case .connecting: return "Đang kết nối đám mây…"
        case .synced(let d):
            let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
            return "Đã đồng bộ lúc \(f.string(from: d))"
        case .error(let msg): return "Lỗi đồng bộ: \(msg)"
        }
    }
}

enum JoinResult {
    case joined(FamilyPayload)
    case notFound
    case full
    case failed(String)
}

protocol SyncService: AnyObject {
    var isCloudEnabled: Bool { get }
    /// Đăng nhập ẩn danh (hoặc khôi phục phiên) và trả về UID trên đám mây.
    func ensureSignedIn() async throws -> String
    /// Tạo hồ sơ gia đình mới trên đám mây với mã mời 6 ký tự.
    func createFamily(_ payload: FamilyPayload) async throws
    /// Xác thực mã mời 6 ký tự, thêm thành viên thứ 2 vào gia đình và trả về dữ liệu gia đình hiện có.
    func join(code: String, member: Person) async -> JoinResult
    /// Đẩy bản cập nhật mới nhất lên đám mây.
    func push(_ payload: FamilyPayload) async
    /// Lắng nghe thay đổi realtime của `families/{code}`.
    func listen(code: String, onChange: @escaping @Sendable (FamilyPayload) -> Void)
    func stopListening()
}

// MARK: - Fallback cục bộ khi chưa cài Firebase SDK hoặc chưa có GoogleService-Info.plist
final class LocalOnlySync: SyncService {
    var isCloudEnabled: Bool { false }
    func ensureSignedIn() async throws -> String { "local-user" }
    func createFamily(_ payload: FamilyPayload) async throws {}
    func join(code: String, member: Person) async -> JoinResult {
        code.count == 6 ? .notFound : .failed("Mã phải gồm 6 ký tự")
    }
    func push(_ payload: FamilyPayload) async {}
    func listen(code: String, onChange: @escaping @Sendable (FamilyPayload) -> Void) {}
    func stopListening() {}
}

#if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

/// Đồng bộ thật qua Firebase Auth + Cloud Firestore.
/// Cấu trúc Firestore:
/// - `families/{CODE}`: chứa `FamilyPayload` (JSON mã hóa trong trường `payload`, kèm `memberCount`, `expiresAt`, `updatedAt`).
final class FirebaseSyncService: SyncService {
    var isCloudEnabled: Bool { FirebaseApp.app() != nil }
    private var listener: ListenerRegistration?
    private let collection = "families"

    static func configureIfPossible() -> SyncService {
        if FirebaseApp.app() == nil,
           Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        return FirebaseApp.app() != nil ? FirebaseSyncService() : LocalOnlySync()
    }

    func ensureSignedIn() async throws -> String {
        if let user = Auth.auth().currentUser { return user.uid }
        let res = try await Auth.auth().signInAnonymously()
        return res.user.uid
    }

    func createFamily(_ payload: FamilyPayload) async throws {
        _ = try await ensureSignedIn()
        let ref = Firestore.firestore().collection(collection).document(payload.familyCode)
        let data = try encode(payload, inviteValidHours: 48)
        try await ref.setData(data)
    }

    func join(code: String, member: Person) async -> JoinResult {
        let clean = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count == 6 else { return .failed("Mã mời phải gồm 6 ký tự.") }
        do {
            _ = try await ensureSignedIn()
            let db = Firestore.firestore()
            let ref = db.collection(collection).document(clean)
            let snap = try await ref.getDocument()
            guard snap.exists, let raw = snap.data(),
                  let json = raw["payload"] as? String,
                  let data = json.data(using: .utf8) else {
                return .notFound
            }
            if let exp = (raw["expiresAt"] as? Timestamp)?.dateValue(), exp < Date(),
               (raw["memberCount"] as? Int ?? 1) < 2 {
                return .failed("Mã mời đã hết hạn (quá 48 giờ).")
            }
            var family = try Self.decoder.decode(FamilyPayload.self, from: data)
            if !family.people.contains(where: { $0.id == member.id }) {
                if family.people.count >= 2 {
                    // Thay thế slot "Vợ/Chồng" giữ chỗ nếu người tạo chưa có thành viên thứ 2 thật
                    let placeholderIdx = family.people.firstIndex { $0.id != family.creatorID }
                    if let idx = placeholderIdx, (raw["memberCount"] as? Int ?? 1) < 2 {
                        let oldID = family.people[idx].id
                        family.people[idx] = member
                        family.transactions = family.transactions.map { t in
                            var copy = t
                            if copy.userID == oldID { copy.userID = member.id }
                            return copy
                        }
                        family.wallets = family.wallets.map { w in
                            var copy = w
                            if copy.ownerID == oldID { copy.ownerID = member.id }
                            return copy
                        }
                    } else {
                        return .full
                    }
                } else {
                    family.people.append(member)
                }
            }
            // Đảm bảo người mới có ít nhất 1 ví riêng
            if !family.wallets.contains(where: { $0.ownerID == member.id }) {
                family.wallets.append(Wallet(name: "Tiền mặt (\(member.name))", emoji: "💵", balance: 0, ownerID: member.id))
            }
            family.updatedAt = Date()
            family.updatedBy = member.id
            let encoded = try encode(family, inviteValidHours: nil, memberCount: 2)
            try await ref.setData(encoded, merge: true)
            return .joined(family)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func push(_ payload: FamilyPayload) async {
        guard isCloudEnabled else { return }
        do {
            _ = try await ensureSignedIn()
            let ref = Firestore.firestore().collection(collection).document(payload.familyCode)
            let data = try encode(payload, inviteValidHours: nil, memberCount: payload.people.count)
            try await ref.setData(data, merge: true)
        } catch {
            // Giữ im lặng khi offline; Firestore sẽ tự đồng bộ lại hoặc lần save kế tiếp sẽ đẩy lên.
        }
    }

    func listen(code: String, onChange: @escaping @Sendable (FamilyPayload) -> Void) {
        guard isCloudEnabled, !code.isEmpty else { return }
        stopListening()
        let ref = Firestore.firestore().collection(collection).document(code)
        listener = ref.addSnapshotListener { snap, _ in
            guard let raw = snap?.data(),
                  let json = raw["payload"] as? String,
                  let data = json.data(using: .utf8),
                  let family = try? Self.decoder.decode(FamilyPayload.self, from: data) else { return }
            onChange(family)
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Helpers
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    private func encode(_ payload: FamilyPayload, inviteValidHours: Int?, memberCount: Int = 1) throws -> [String: Any] {
        let json = String(data: try Self.encoder.encode(payload), encoding: .utf8) ?? "{}"
        var out: [String: Any] = [
            "familyCode": payload.familyCode,
            "payload": json,
            "memberCount": memberCount,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let h = inviteValidHours {
            out["expiresAt"] = Timestamp(date: Date().addingTimeInterval(TimeInterval(h * 3600)))
        }
        return out
    }
}
#endif
