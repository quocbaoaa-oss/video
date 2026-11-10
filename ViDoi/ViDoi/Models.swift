import Foundation

struct Person: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var initial: String { String(name.prefix(1)).uppercased() }
}

enum TxKind: String, Codable, CaseIterable {
    case expense, income, transfer
    var title: String {
        switch self {
        case .expense: return "Chi"
        case .income: return "Thu"
        case .transfer: return "Chuyển"
        }
    }
}

/// Mức hiển thị khoản chi RIÊNG của vợ/chồng đối với tôi.
enum PrivacyMode: Int, Codable, CaseIterable, Identifiable {
    case hidden, totalsOnly, full
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .hidden: return "Ẩn hẳn"
        case .totalsOnly: return "Chỉ tổng"
        case .full: return "Chi tiết"
        }
    }
    var hint: String {
        switch self {
        case .hidden: return "Không thấy gì về khoản riêng của nhau."
        case .totalsOnly: return "Hiện “Chi riêng” và số tiền, không lộ mô tả."
        case .full: return "Xem đầy đủ cả khoản riêng của nhau."
        }
    }
}

enum Scope: Int, CaseIterable, Identifiable {
    case all, me, partner
    var id: Int { rawValue }
}

struct SpendCategory: Identifiable, Codable, Hashable {
    var id: String { name }
    var name: String
    var emoji: String

    static let defaults: [SpendCategory] = [
        .init(name: "Ăn uống", emoji: "🍜"), .init(name: "Chợ", emoji: "🛒"),
        .init(name: "Nhà cửa", emoji: "🏠"), .init(name: "Hóa đơn", emoji: "💡"),
        .init(name: "Đi lại", emoji: "🚗"), .init(name: "Con cái", emoji: "👶"),
        .init(name: "Mua sắm", emoji: "🛍️"), .init(name: "Giải trí", emoji: "🎮")
    ]
    static var all: [SpendCategory] { defaults }
    static func emoji(for name: String, in list: [SpendCategory] = defaults) -> String {
        list.first { $0.name == name }?.emoji
            ?? defaults.first { $0.name == name }?.emoji
            ?? "💼"
    }
}

/// Giao dịch định kỳ hàng tháng (tiền nhà, internet, học phí, lương...).
struct RecurringRule: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: TxKind
    var title: String
    var amount: Int
    var category: String
    var dayOfMonth: Int // 1...28
    var walletID: UUID
    var userID: UUID
    var isShared: Bool
    var isActive: Bool = true
    /// Các kỳ tháng (`yyyy-MM`) đã tự động sinh giao dịch để không bị trùng.
    var generatedMonths: [String] = []
}

struct Wallet: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var balance: Int
    /// nil = ví chung; có giá trị = ví riêng của người đó.
    var ownerID: UUID?
}

struct TxComment: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var userID: UUID
    var text: String
    var createdAt: Date = Date()
}

struct Txn: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: TxKind
    var amount: Int
    var category: String
    var note: String = ""
    var date: Date
    var walletID: UUID
    /// Ví đích khi `kind == .transfer`.
    var toWalletID: UUID?
    var userID: UUID
    var isShared: Bool
    /// false = loại khỏi bảng cân đối.
    var countsInSettlement: Bool = true
    var hasReceipt: Bool = false
    /// Ảnh hóa đơn đính kèm (đã nén JPEG nhẹ).
    var receiptImageData: Data?
    var comments: [TxComment] = []
    var updatedAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id, kind, amount, category, note, date, walletID, toWalletID, userID, isShared
        case countsInSettlement, hasReceipt, receiptImageData, comments, updatedAt
    }

    init(
        id: UUID = UUID(), kind: TxKind, amount: Int, category: String, note: String = "",
        date: Date, walletID: UUID, toWalletID: UUID? = nil, userID: UUID, isShared: Bool,
        countsInSettlement: Bool = true, hasReceipt: Bool = false,
        receiptImageData: Data? = nil, comments: [TxComment] = [], updatedAt: Date = Date()
    ) {
        self.id = id; self.kind = kind; self.amount = amount; self.category = category
        self.note = note; self.date = date; self.walletID = walletID; self.toWalletID = toWalletID
        self.userID = userID; self.isShared = isShared; self.countsInSettlement = countsInSettlement
        self.hasReceipt = hasReceipt || (receiptImageData != nil)
        self.receiptImageData = receiptImageData; self.comments = comments; self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decode(TxKind.self, forKey: .kind)
        amount = try c.decode(Int.self, forKey: .amount)
        category = try c.decode(String.self, forKey: .category)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        date = try c.decode(Date.self, forKey: .date)
        walletID = try c.decode(UUID.self, forKey: .walletID)
        toWalletID = try c.decodeIfPresent(UUID.self, forKey: .toWalletID)
        userID = try c.decode(UUID.self, forKey: .userID)
        isShared = try c.decode(Bool.self, forKey: .isShared)
        countsInSettlement = try c.decodeIfPresent(Bool.self, forKey: .countsInSettlement) ?? true
        receiptImageData = try c.decodeIfPresent(Data.self, forKey: .receiptImageData)
        hasReceipt = (try c.decodeIfPresent(Bool.self, forKey: .hasReceipt) ?? false) || (receiptImageData != nil)
        comments = try c.decodeIfPresent([TxComment].self, forKey: .comments) ?? []
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? date
    }
}

struct Budget: Identifiable, Codable, Hashable {
    var id: String { "\(isShared ? "S" : "P")-\(category)" }
    var category: String
    var limit: Int
    var isShared: Bool = true

    enum CodingKeys: String, CodingKey { case category, limit, isShared }

    init(category: String, limit: Int, isShared: Bool = true) {
        self.category = category; self.limit = limit; self.isShared = isShared
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        category = try c.decode(String.self, forKey: .category)
        limit = try c.decode(Int.self, forKey: .limit)
        isShared = try c.decodeIfPresent(Bool.self, forKey: .isShared) ?? true
    }
}

struct Goal: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var emoji: String
    var name: String
    var saved: Int
    var target: Int
    var dueText: String
}

/// Đề xuất đổi tỷ lệ đóng góp chờ người kia xác nhận.
struct PendingRatioProposal: Codable, Equatable {
    var proposedRatioCreator: Int
    var requestedBy: UUID
    var createdAt: Date = Date()
}

/// Thông báo trong ứng dụng.
struct AppNotification: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var emoji: String
    var title: String
    var subtitle: String
    var createdAt: Date = Date()
    var isUnread: Bool = true
}

struct Snapshot: Codable {
    var people: [Person]
    var meID: UUID
    var creatorID: UUID?
    var transactions: [Txn]
    var deletedTxIDs: [UUID]?
    var wallets: [Wallet]
    var budgets: [Budget]
    var privateBudgets: [Budget]?
    var goals: [Goal]
    var categories: [SpendCategory]?
    var recurringRules: [RecurringRule]?
    var ratioMe: Int
    var pendingRatio: PendingRatioProposal?
    var privacy: PrivacyMode
    var onboarded: Bool
    var settledMonths: [String]
    var familyCode: String
    var monthlyBudget: Int
    var faceIDLock: Bool
    var dailyReminderEnabled: Bool?
    var largeTxAlertThreshold: Int?
    var notifications: [AppNotification]?
}
