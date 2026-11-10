import Foundation
import Observation
import UserNotifications

extension String: @retroactive LocalizedError {
    public var errorDescription: String? { self }
}

/// Nguồn dữ liệu duy nhất của app. Lưu JSON cục bộ để dùng offline
/// và đồng bộ realtime giữa 2 vợ chồng qua `SyncService` (Firebase Auth + Firestore).
@Observable
final class AppStore {
    var people: [Person]
    var meID: UUID
    var creatorID: UUID
    var transactions: [Txn]
    var deletedTxIDs: [UUID]
    var wallets: [Wallet]
    var budgets: [Budget]
    var privateBudgets: [Budget]
    var goals: [Goal]
    var categories: [SpendCategory]
    var recurringRules: [RecurringRule]
    var ratioMe: Int
    var pendingRatio: PendingRatioProposal?
    var privacy: PrivacyMode
    var onboarded: Bool
    var settledMonths: [String]
    var familyCode: String
    var monthlyBudget: Int
    var faceIDLock: Bool
    var dailyReminderEnabled: Bool
    var largeTxAlertThreshold: Int
    var notifications: [AppNotification]
    var syncState: SyncState = .localOnly

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored var sync: SyncService
    @ObservationIgnored private var isApplyingRemote = false

    static let defaultPrivateBudgets: [Budget] = [
        Budget(category: "Mua sắm", limit: 1_000_000, isShared: false),
        Budget(category: "Ăn uống", limit: 1_500_000, isShared: false),
        Budget(category: "Giải trí", limit: 800_000, isShared: false)
    ]

    init(sync: SyncService? = nil) {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        let resolvedSync = sync ?? FirebaseSyncService.configureIfPossible()
        #else
        let resolvedSync = sync ?? LocalOnlySync()
        #endif
        self.sync = resolvedSync

        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("vidoi.json")
        if let data = try? Data(contentsOf: fileURL),
           let s = try? JSONDecoder().decode(Snapshot.self, from: data) {
            people = s.people
            meID = s.meID
            creatorID = s.creatorID ?? s.meID
            transactions = s.transactions
            deletedTxIDs = s.deletedTxIDs ?? []
            wallets = s.wallets
            budgets = s.budgets
            privateBudgets = s.privateBudgets ?? Self.defaultPrivateBudgets
            goals = s.goals
            categories = s.categories ?? SpendCategory.defaults
            recurringRules = s.recurringRules ?? []
            ratioMe = s.ratioMe
            pendingRatio = s.pendingRatio
            privacy = s.privacy
            onboarded = s.onboarded
            settledMonths = s.settledMonths
            familyCode = s.familyCode
            monthlyBudget = s.monthlyBudget
            faceIDLock = s.faceIDLock
            dailyReminderEnabled = s.dailyReminderEnabled ?? false
            largeTxAlertThreshold = s.largeTxAlertThreshold ?? 2_000_000
            notifications = s.notifications ?? []
        } else {
            let me = Person(name: "Tôi", colorHex: "4C8DFF")
            let partner = Person(name: "Vợ/Chồng", colorHex: "FF7EB6")
            people = [me, partner]
            meID = me.id
            creatorID = me.id
            transactions = []
            deletedTxIDs = []
            wallets = [
                Wallet(name: "Ví chung", emoji: "🏦", balance: 0, ownerID: nil),
                Wallet(name: "Tiền mặt", emoji: "💵", balance: 0, ownerID: me.id)
            ]
            budgets = [
                Budget(category: "Ăn uống", limit: 6_000_000),
                Budget(category: "Chợ", limit: 4_000_000),
                Budget(category: "Nhà cửa", limit: 2_500_000),
                Budget(category: "Hóa đơn", limit: 3_000_000),
                Budget(category: "Đi lại", limit: 1_000_000),
                Budget(category: "Con cái", limit: 2_000_000),
                Budget(category: "Mua sắm", limit: 1_200_000),
                Budget(category: "Giải trí", limit: 1_500_000)
            ]
            privateBudgets = Self.defaultPrivateBudgets
            goals = []
            categories = SpendCategory.defaults
            recurringRules = []
            ratioMe = 50
            pendingRatio = nil
            privacy = .totalsOnly
            onboarded = false
            settledMonths = []
            familyCode = AppStore.makeCode()
            monthlyBudget = 20_000_000
            faceIDLock = false
            dailyReminderEnabled = false
            largeTxAlertThreshold = 2_000_000
            notifications = []
        }

        syncState = resolvedSync.isCloudEnabled ? .connecting : .localOnly
        if onboarded {
            processDueRecurringRules()
            if resolvedSync.isCloudEnabled { startCloudSync() }
        }
    }

    // MARK: - Persistence & Cloud Sync
    func save(pushToCloud: Bool = true) {
        let s = Snapshot(
            people: people, meID: meID, creatorID: creatorID, transactions: transactions,
            deletedTxIDs: deletedTxIDs, wallets: wallets, budgets: budgets,
            privateBudgets: privateBudgets, goals: goals, categories: categories,
            recurringRules: recurringRules, ratioMe: ratioMe, pendingRatio: pendingRatio,
            privacy: privacy, onboarded: onboarded, settledMonths: settledMonths,
            familyCode: familyCode, monthlyBudget: monthlyBudget, faceIDLock: faceIDLock,
            dailyReminderEnabled: dailyReminderEnabled, largeTxAlertThreshold: largeTxAlertThreshold,
            notifications: notifications
        )
        if let data = try? JSONEncoder().encode(s) {
            try? data.write(to: fileURL, options: .atomic)
        }
        guard pushToCloud, !isApplyingRemote, sync.isCloudEnabled else { return }
        let payload = makeFamilyPayload()
        Task { @MainActor in
            await sync.push(payload)
            syncState = .synced(Date())
        }
    }

    func makeFamilyPayload() -> FamilyPayload {
        let ratioCreator = (meID == creatorID) ? ratioMe : (100 - ratioMe)
        return FamilyPayload(
            familyCode: familyCode,
            people: people,
            creatorID: creatorID,
            transactions: transactions,
            deletedTxIDs: deletedTxIDs,
            wallets: wallets,
            budgets: budgets,
            goals: goals,
            categories: categories,
            recurringRules: recurringRules,
            ratioCreator: ratioCreator,
            pendingRatio: pendingRatio,
            settledMonths: settledMonths,
            monthlyBudget: monthlyBudget,
            notifications: notifications,
            updatedAt: Date(),
            updatedBy: meID
        )
    }

    /// Hợp nhất hai mảng giao dịch theo `id` và `updatedAt`, loại bỏ các `id` đã nằm trong `deletedIDs`.
    static func mergeTransactions(local: [Txn], remote: [Txn], deletedIDs: Set<UUID>) -> [Txn] {
        var dict: [UUID: Txn] = [:]
        for t in local where !deletedIDs.contains(t.id) { dict[t.id] = t }
        for r in remote where !deletedIDs.contains(r.id) {
            if let existing = dict[r.id] {
                var merged = r.updatedAt >= existing.updatedAt ? r : existing
                // Hợp nhất cả bình luận theo id để không mất bình luận của hai bên
                var cmDict: [UUID: TxComment] = [:]
                for c in existing.comments { cmDict[c.id] = c }
                for c in r.comments { cmDict[c.id] = c }
                merged.comments = cmDict.values.sorted { $0.createdAt < $1.createdAt }
                dict[r.id] = merged
            } else {
                dict[r.id] = r
            }
        }
        return Array(dict.values)
    }

    @MainActor
    func applyRemote(_ payload: FamilyPayload) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        familyCode = payload.familyCode
        creatorID = payload.creatorID
        people = payload.people
        if !people.contains(where: { $0.id == meID }), let first = people.first {
            meID = first.id
        }
        let delSet = Set(deletedTxIDs).union(payload.deletedTxIDs ?? [])
        deletedTxIDs = Array(delSet)
        transactions = Self.mergeTransactions(local: transactions, remote: payload.transactions, deletedIDs: delSet)
        wallets = payload.wallets
        budgets = payload.budgets
        goals = payload.goals
        if let cats = payload.categories, !cats.isEmpty { categories = cats }
        if let rules = payload.recurringRules { recurringRules = rules }
        ratioMe = (meID == payload.creatorID) ? payload.ratioCreator : (100 - payload.ratioCreator)
        pendingRatio = payload.pendingRatio
        settledMonths = payload.settledMonths
        monthlyBudget = payload.monthlyBudget
        if let remoteNotifs = payload.notifications {
            var nDict: [UUID: AppNotification] = [:]
            for n in remoteNotifs { nDict[n.id] = n }
            for n in notifications {
                if var r = nDict[n.id] { r.isUnread = r.isUnread && n.isUnread; nDict[n.id] = r }
                else { nDict[n.id] = n }
            }
            notifications = nDict.values.sorted { $0.createdAt > $1.createdAt }
        }
        syncState = .synced(payload.updatedAt)
        save(pushToCloud: false)
    }

    func startCloudSync() {
        guard sync.isCloudEnabled else {
            syncState = .localOnly
            return
        }
        syncState = .connecting
        let code = familyCode
        sync.listen(code: code) { [weak self] payload in
            Task { @MainActor in
                self?.applyRemote(payload)
            }
        }
    }

    /// Người thứ nhất tạo gia đình mới trên đám mây (khi bắt đầu mở mã mời).
    @MainActor
    func publishFamilyInvite() async {
        creatorID = meID
        let payload = makeFamilyPayload()
        guard sync.isCloudEnabled else {
            syncState = .localOnly
            return
        }
        do {
            syncState = .connecting
            try await sync.createFamily(payload)
            syncState = .synced(Date())
            startCloudSync()
        } catch {
            syncState = .error(error.localizedDescription)
        }
    }

    /// Người thứ hai nhập mã mời 6 ký tự để tham gia gia đình của vợ/chồng.
    @MainActor
    func joinFamily(code: String, partnerFallbackName: String) async -> Result<Void, String> {
        let clean = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count == 6 else { return .failure("Mã mời phải gồm 6 ký tự.") }

        if !sync.isCloudEnabled {
            if clean == familyCode || clean == "XK7P2A" {
                familyCode = clean
                if !partnerFallbackName.isEmpty { setPartnerName(partnerFallbackName) }
                onboarded = true
                save(pushToCloud: false)
                return .success(())
            }
            return .failure("Chưa cấu hình Firebase. Để thử offline, hãy nhập mã XK7P2A.")
        }

        let res = await sync.join(code: clean, member: me)
        switch res {
        case .joined(let payload):
            applyRemote(payload)
            onboarded = true
            save(pushToCloud: false)
            startCloudSync()
            return .success(())
        case .notFound:
            return .failure("Không tìm thấy gia đình với mã \(clean).")
        case .full:
            return .failure("Gia đình này đã đủ 2 thành viên.")
        case .failed(let message):
            return .failure(message)
        }
    }

    static func makeCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    // MARK: - People
    var me: Person { people.first { $0.id == meID } ?? people[0] }
    var partner: Person { people.first { $0.id != meID } ?? people[0] }
    func person(_ id: UUID) -> Person { people.first { $0.id == id } ?? me }
    func updateMe(name: String, colorHex: String) {
        if let i = people.firstIndex(where: { $0.id == meID }) {
            people[i].name = name.isEmpty ? "Tôi" : name
            people[i].colorHex = colorHex
        }
        save()
    }
    func setPartnerName(_ name: String) {
        if let i = people.firstIndex(where: { $0.id != meID }) { people[i].name = name }
        save()
    }

    // MARK: - Privacy
    private func isPartnerPrivate(_ t: Txn) -> Bool { !t.isShared && t.userID != meID }
    func isVisible(_ t: Txn) -> Bool { !(isPartnerPrivate(t) && privacy == .hidden) }
    func isMasked(_ t: Txn) -> Bool { isPartnerPrivate(t) && privacy == .totalsOnly }
    func canEdit(_ t: Txn) -> Bool { t.userID == meID }

    // MARK: - Queries
    var visibleTransactions: [Txn] {
        transactions.filter(isVisible).sorted { $0.date > $1.date }
    }
    func inMonth(_ d: Date, of ref: Date) -> Bool {
        Calendar.current.isDate(d, equalTo: ref, toGranularity: .month)
    }
    func inCurrentMonth(_ d: Date) -> Bool {
        inMonth(d, of: Date())
    }
    func monthKey(for d: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: d)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }
    var monthKey: String { monthKey(for: Date()) }

    func monthExpenses(_ scope: Scope = .all, in month: Date = Date()) -> [Txn] {
        visibleTransactions.filter { t in
            guard t.kind == .expense, inMonth(t.date, of: month) else { return false }
            switch scope {
            case .all: return true
            case .me: return t.userID == meID
            case .partner: return t.userID != meID
            }
        }
    }
    func spent(_ scope: Scope = .all, in month: Date = Date()) -> Int {
        monthExpenses(scope, in: month).reduce(0) { $0 + $1.amount }
    }
    func income(in month: Date = Date()) -> Int {
        transactions.filter { $0.kind == .income && inMonth($0.date, of: month) }.reduce(0) { $0 + $1.amount }
    }
    var monthIncome: Int { income(in: Date()) }

    func categorySpend(_ scope: Scope = .all, sharedOnly: Bool = false, privateOnly: Bool = false, in month: Date = Date()) -> [(name: String, amount: Int)] {
        var dict: [String: Int] = [:]
        for t in monthExpenses(scope, in: month) {
            if sharedOnly && !t.isShared { continue }
            if privateOnly && t.isShared { continue }
            dict[t.category, default: 0] += t.amount
        }
        return dict.map { (name: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
    }

    struct MonthlyPoint: Identifiable {
        var id: String { Fmt.monthTitle(month) }
        let month: Date
        let label: String
        let spentMe: Int
        let spentPartner: Int
        let income: Int
        var totalSpent: Int { spentMe + spentPartner }
        var netSaved: Int { income - totalSpent }
    }
    func monthlyTrend(months count: Int = 6, endingAt endMonth: Date = Date()) -> [MonthlyPoint] {
        let cal = Calendar.current
        let anchor = cal.date(from: cal.dateComponents([.year, .month], from: endMonth)) ?? endMonth
        return (0..<count).reversed().compactMap { offset -> MonthlyPoint? in
            guard let m = cal.date(byAdding: .month, value: -offset, to: anchor) else { return nil }
            return MonthlyPoint(
                month: m,
                label: Fmt.monthShort(m),
                spentMe: spent(.me, in: m),
                spentPartner: spent(.partner, in: m),
                income: income(in: m)
            )
        }
    }
    var forecast: Int {
        let day = max(1, Calendar.current.component(.day, from: Date()))
        let days = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
        return spent(.all) / day * days
    }

    // MARK: - Settlement & Ratio Proposal (Xác nhận 2 chiều)
    struct Balance { var paidMe: Int; var paidPartner: Int; var total: Int; var owe: Int }
    /// `owe` > 0: vợ/chồng cần chuyển cho tôi; < 0: tôi cần chuyển cho vợ/chồng.
    func balance(in month: Date = Date()) -> Balance {
        let shared = monthExpenses(.all, in: month).filter { $0.isShared && $0.countsInSettlement }
        let pm = shared.filter { $0.userID == meID }.reduce(0) { $0 + $1.amount }
        let pp = shared.filter { $0.userID != meID }.reduce(0) { $0 + $1.amount }
        let total = pm + pp
        let fairMe = total * ratioMe / 100
        return Balance(paidMe: pm, paidPartner: pp, total: total, owe: pm - fairMe)
    }
    var isSettled: Bool { settledMonths.contains(monthKey) }
    func settleMonth() {
        if !isSettled {
            settledMonths.append(monthKey)
            pushNotification(emoji: "✅", title: "\(me.name) đã xác nhận tất toán \(Fmt.monthTitle(Date()).lowercased())", subtitle: "Cân đối chi tiêu chung")
            save()
        }
    }

    /// Tỷ lệ đề xuất của tôi từ `pendingRatio` (nếu có).
    var pendingRatioForMe: Int? {
        guard let p = pendingRatio else { return nil }
        return (meID == creatorID) ? p.proposedRatioCreator : (100 - p.proposedRatioCreator)
    }
    /// Đề xuất đổi tỷ lệ đóng góp. Khi bật đám mây sẽ chờ người kia bấm Đồng ý; khi thử trên 1 máy vẫn tạo thẻ xác nhận để kiểm thử.
    func requestRatioChange(newRatioMe: Int) {
        let clamped = min(90, max(10, newRatioMe))
        guard clamped != ratioMe else { return }
        let creatorRatio = (meID == creatorID) ? clamped : (100 - clamped)
        pendingRatio = PendingRatioProposal(proposedRatioCreator: creatorRatio, requestedBy: meID)
        pushNotification(
            emoji: "⚖️",
            title: "\(me.name) đề xuất đổi tỷ lệ đóng góp thành \(clamped)/\(100 - clamped)",
            subtitle: "Chờ \(partner.name) xác nhận"
        )
        save()
    }
    func approvePendingRatio() {
        guard let target = pendingRatioForMe else { return }
        ratioMe = target
        pendingRatio = nil
        settledMonths.removeAll { $0 == monthKey }
        pushNotification(emoji: "🤝", title: "Đã áp dụng tỷ lệ đóng góp mới \(ratioMe)/\(100 - ratioMe)", subtitle: "Cả hai đã đồng ý")
        save()
    }
    func rejectPendingRatio() {
        pendingRatio = nil
        save()
    }

    // MARK: - Effects on Wallets
    private func applyWalletEffect(_ t: Txn, reverse: Bool) {
        let sign = reverse ? -1 : 1
        switch t.kind {
        case .expense:
            if let i = wallets.firstIndex(where: { $0.id == t.walletID }) {
                wallets[i].balance -= sign * t.amount
            }
        case .income:
            if let i = wallets.firstIndex(where: { $0.id == t.walletID }) {
                wallets[i].balance += sign * t.amount
            }
        case .transfer:
            if let from = wallets.firstIndex(where: { $0.id == t.walletID }) {
                wallets[from].balance -= sign * t.amount
            }
            if let toID = t.toWalletID, let to = wallets.firstIndex(where: { $0.id == toID }) {
                wallets[to].balance += sign * t.amount
            }
        }
    }

    // MARK: - Mutations (Transactions)
    func add(_ t: Txn) {
        var item = t
        item.updatedAt = Date()
        deletedTxIDs.removeAll { $0 == item.id }
        transactions.append(item)
        applyWalletEffect(item, reverse: false)
        if item.kind == .expense && item.isShared {
            settledMonths.removeAll { $0 == monthKey(for: item.date) }
        }
        checkAlertsAfterAdding(item)
        save()
    }
    func delete(_ t: Txn) {
        guard let idx = transactions.firstIndex(where: { $0.id == t.id }) else { return }
        let removed = transactions.remove(at: idx)
        if !deletedTxIDs.contains(removed.id) { deletedTxIDs.append(removed.id) }
        applyWalletEffect(removed, reverse: true)
        save()
    }
    func restore(_ t: Txn) { add(t) }
    func update(_ t: Txn) {
        guard let i = transactions.firstIndex(where: { $0.id == t.id }) else { return }
        let old = transactions[i]
        applyWalletEffect(old, reverse: true)
        var updated = t
        updated.updatedAt = Date()
        applyWalletEffect(updated, reverse: false)
        transactions[i] = updated
        if old.amount != updated.amount || old.isShared != updated.isShared || old.userID != updated.userID || old.kind != updated.kind {
            settledMonths.removeAll { $0 == monthKey(for: updated.date) }
        }
        save()
    }
    func addComment(txID: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = transactions.firstIndex(where: { $0.id == txID }) else { return }
        transactions[i].comments.append(TxComment(userID: meID, text: trimmed))
        transactions[i].updatedAt = Date()
        pushNotification(emoji: "💬", title: "\(me.name) bình luận: “\(trimmed)”", subtitle: transactions[i].note.isEmpty ? transactions[i].category : transactions[i].note)
        save()
    }
    func deleteComment(txID: UUID, commentID: UUID) {
        guard let i = transactions.firstIndex(where: { $0.id == txID }) else { return }
        transactions[i].comments.removeAll { $0.id == commentID }
        transactions[i].updatedAt = Date()
        save()
    }

    // MARK: - Wallets CRUD & Transfer
    func addWallet(name: String, emoji: String, initialBalance: Int, isShared: Bool) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let ic = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let w = Wallet(name: clean, emoji: ic.isEmpty ? "👛" : String(ic.prefix(2)), balance: initialBalance, ownerID: isShared ? nil : meID)
        wallets.append(w)
        save()
    }
    func updateWallet(_ wallet: Wallet) {
        if let i = wallets.firstIndex(where: { $0.id == wallet.id }) {
            wallets[i] = wallet
            save()
        }
    }
    func deleteWallet(_ id: UUID) {
        guard wallets.count > 1 else { return }
        wallets.removeAll { $0.id == id }
        save()
    }

    // MARK: - Goals CRUD
    func addGoal(name: String, emoji: String, target: Int, saved: Int, dueText: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, target > 0 else { return }
        let ic = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        goals.append(Goal(emoji: ic.isEmpty ? "🎯" : String(ic.prefix(2)), name: clean, saved: max(0, min(saved, target)), target: target, dueText: dueText.isEmpty ? "Không thời hạn" : dueText))
        save()
    }
    func updateGoal(_ g: Goal) {
        if let i = goals.firstIndex(where: { $0.id == g.id }) { goals[i] = g; save() }
    }
    func deleteGoal(_ id: UUID) {
        goals.removeAll { $0.id == id }
        save()
    }
    func contribute(_ goal: Goal, _ amount: Int) {
        if let i = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[i].saved = min(goals[i].target, goals[i].saved + amount)
            save()
        }
    }

    // MARK: - Budgets (Chung & Riêng + Tổng tháng)
    func setLimit(_ category: String, _ limit: Int, isShared: Bool = true) {
        if isShared {
            if let i = budgets.firstIndex(where: { $0.category == category }) { budgets[i].limit = limit }
            else { budgets.append(Budget(category: category, limit: limit, isShared: true)) }
        } else {
            if let i = privateBudgets.firstIndex(where: { $0.category == category }) { privateBudgets[i].limit = limit }
            else { privateBudgets.append(Budget(category: category, limit: limit, isShared: false)) }
        }
        save()
    }
    func setMonthlyBudget(_ total: Int) {
        guard total > 0 else { return }
        monthlyBudget = total
        save()
    }

    // MARK: - Danh mục tùy chỉnh
    func emoji(for category: String) -> String {
        if category == "Chuyển khoản" { return "⇄" }
        return SpendCategory.emoji(for: category, in: categories)
    }
    func addCategory(name: String, emoji: String, budgetLimit: Int) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !categories.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        let ic = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        categories.append(SpendCategory(name: trimmed, emoji: ic.isEmpty ? "🏷️" : String(ic.prefix(2))))
        if budgetLimit > 0 {
            budgets.append(Budget(category: trimmed, limit: budgetLimit))
        }
        save()
    }
    func updateCategory(oldName: String, newName: String, emoji: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = categories.firstIndex(where: { $0.name == oldName }) else { return }
        let ic = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        categories[i] = SpendCategory(name: trimmed, emoji: ic.isEmpty ? categories[i].emoji : String(ic.prefix(2)))
        if oldName != trimmed {
            for idx in transactions.indices where transactions[idx].category == oldName { transactions[idx].category = trimmed }
            for idx in budgets.indices where budgets[idx].category == oldName { budgets[idx].category = trimmed }
            for idx in privateBudgets.indices where privateBudgets[idx].category == oldName { privateBudgets[idx].category = trimmed }
            for idx in recurringRules.indices where recurringRules[idx].category == oldName { recurringRules[idx].category = trimmed }
        }
        save()
    }
    func deleteCategory(name: String) {
        guard categories.count > 1 else { return }
        categories.removeAll { $0.name == name }
        budgets.removeAll { $0.category == name }
        privateBudgets.removeAll { $0.category == name }
        save()
    }

    // MARK: - Giao dịch định kỳ hàng tháng
    func addRecurring(_ rule: RecurringRule) {
        recurringRules.append(rule)
        processDueRecurringRules()
        save()
    }
    func updateRecurring(_ rule: RecurringRule) {
        if let i = recurringRules.firstIndex(where: { $0.id == rule.id }) {
            recurringRules[i] = rule
            save()
        }
    }
    func deleteRecurring(_ id: UUID) {
        recurringRules.removeAll { $0.id == id }
        save()
    }
    func triggerRecurringNow(_ rule: RecurringRule) {
        let mk = monthKey
        let t = Txn(
            kind: rule.kind, amount: rule.amount,
            category: rule.kind == .income ? "Thu" : rule.category,
            note: rule.title + " (định kỳ)",
            date: Date(), walletID: rule.walletID, userID: rule.userID, isShared: rule.isShared
        )
        if let idx = recurringRules.firstIndex(where: { $0.id == rule.id }),
           !recurringRules[idx].generatedMonths.contains(mk) {
            recurringRules[idx].generatedMonths.append(mk)
        }
        add(t)
    }
    @discardableResult
    func processDueRecurringRules(now: Date = Date()) -> Int {
        let cal = Calendar.current
        let today = cal.component(.day, from: now)
        let mk = monthKey(for: now)
        var created = 0
        for i in recurringRules.indices {
            let r = recurringRules[i]
            guard r.isActive, !r.generatedMonths.contains(mk), today >= r.dayOfMonth else { continue }
            guard !sync.isCloudEnabled || r.userID == meID else { continue }
            var comp = cal.dateComponents([.year, .month], from: now)
            comp.day = min(r.dayOfMonth, 28)
            let txDate = cal.date(from: comp) ?? now
            let t = Txn(
                kind: r.kind, amount: r.amount,
                category: r.kind == .income ? "Thu" : r.category,
                note: r.title + " (định kỳ)",
                date: txDate, walletID: r.walletID, userID: r.userID, isShared: r.isShared
            )
            recurringRules[i].generatedMonths.append(mk)
            transactions.append(t)
            applyWalletEffect(t, reverse: false)
            created += 1
        }
        if created > 0 { save() }
        return created
    }

    // MARK: - Notifications & Local Reminder
    var unreadNotificationCount: Int { notifications.filter(\.isUnread).count }
    func markAllNotificationsRead() {
        for i in notifications.indices { notifications[i].isUnread = false }
        save(pushToCloud: false)
    }
    func markNotificationRead(_ id: UUID) {
        if let i = notifications.firstIndex(where: { $0.id == id }) {
            notifications[i].isUnread = false
            save(pushToCloud: false)
        }
    }
    func pushNotification(emoji: String, title: String, subtitle: String) {
        notifications.insert(AppNotification(emoji: emoji, title: title, subtitle: subtitle), at: 0)
        if notifications.count > 40 { notifications = Array(notifications.prefix(40)) }
    }
    private func checkAlertsAfterAdding(_ t: Txn) {
        guard t.kind == .expense else { return }
        if t.isShared && t.amount >= largeTxAlertThreshold {
            pushNotification(
                emoji: "💸",
                title: "\(person(t.userID).name) vừa chi chung \(Fmt.vnd(t.amount))",
                subtitle: "\(t.note.isEmpty ? t.category : t.note) · vượt ngưỡng \(Fmt.short(largeTxAlertThreshold))"
            )
        }
        if let b = budgets.first(where: { $0.category == t.category }), b.limit > 0 {
            let catTotal = categorySpend(.all).first(where: { $0.name == t.category })?.amount ?? 0
            let pct = Int(Double(catTotal) / Double(b.limit) * 100)
            if pct >= 100 {
                pushNotification(emoji: "⚠️", title: "\(t.category) đã vượt ngân sách (\(pct)%)", subtitle: "\(Fmt.vnd(catTotal)) / \(Fmt.vnd(b.limit))")
            } else if pct >= 80 {
                pushNotification(emoji: "🔔", title: "\(t.category) đã dùng \(pct)% ngân sách tháng", subtitle: "Còn \(Fmt.vnd(max(0, b.limit - catTotal)))")
            }
        }
    }
    func setDailyReminder(_ enabled: Bool) {
        dailyReminderEnabled = enabled
        save(pushToCloud: false)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["vidoi.daily.21"])
        guard enabled else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Ví Đôi 💞"
            content.body = "Dành 5 giây ghi lại chi tiêu hôm nay cùng vợ/chồng nhé!"
            content.sound = .default
            var comp = DateComponents(); comp.hour = 21; comp.minute = 0
            let trig = UNCalendarNotificationTrigger(dateMatching: comp, repeats: true)
            center.add(UNNotificationRequest(identifier: "vidoi.daily.21", content: content, trigger: trig))
        }
    }

    // MARK: - Xuất CSV
    func exportCSV(in month: Date? = nil) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
        var lines = ["Ngay,Loai,SoTienVND,DanhMuc,GhiChu,NguoiGhi,Vi,PhamVi"]
        let list = visibleTransactions.filter { t in
            guard let m = month else { return true }
            return inMonth(t.date, of: m)
        }
        for t in list {
            let masked = isMasked(t)
            let wName = wallets.first(where: { $0.id == t.walletID })?.name ?? ""
            let noteClean = (masked ? "Chi rieng" : t.note).replacingOccurrences(of: ",", with: " ")
            let catClean = (masked ? "Chi rieng" : t.category).replacingOccurrences(of: ",", with: " ")
            lines.append("\(df.string(from: t.date)),\(t.kind.title),\(t.amount),\(catClean),\(noteClean),\(person(t.userID).name),\(masked ? "An" : wName),\(t.isShared ? "Chung" : "Rieng")")
        }
        return lines.joined(separator: "\n")
    }

    func resetAll() {
        sync.stopListening()
        try? FileManager.default.removeItem(at: fileURL)
        let fresh = AppStore(sync: sync)
        people = fresh.people; meID = fresh.meID; creatorID = fresh.creatorID
        transactions = []; deletedTxIDs = []; wallets = fresh.wallets
        budgets = fresh.budgets; privateBudgets = Self.defaultPrivateBudgets; goals = []
        categories = SpendCategory.defaults; recurringRules = []
        ratioMe = 50; pendingRatio = nil; privacy = .totalsOnly
        onboarded = false; settledMonths = []; familyCode = fresh.familyCode
        notifications = []
    }

    // MARK: - Demo data
    func loadDemo() {
        let cal = Calendar.current
        func ago(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: Date()) ?? Date() }
        let p = partner.id
        wallets = [
            Wallet(name: "Ví chung VCB", emoji: "🏦", balance: 18_700_000, ownerID: nil),
            Wallet(name: "Tiền mặt", emoji: "💵", balance: 2_340_000, ownerID: meID),
            Wallet(name: "Thẻ tín dụng TCB", emoji: "💳", balance: -3_200_000, ownerID: meID),
            Wallet(name: "Momo", emoji: "📱", balance: 1_250_000, ownerID: p)
        ]
        let v = wallets[0].id, c = wallets[1].id, m = wallets[3].id
        func tx(_ d: Int, _ cat: String, _ note: String, _ a: Int, _ u: UUID, _ shared: Bool, _ w: UUID, _ k: TxKind = .expense) -> Txn {
            Txn(kind: k, amount: a, category: cat, note: note, date: ago(d), walletID: w, userID: u, isShared: shared)
        }
        func mTx(_ mOffset: Int, _ day: Int, _ cat: String, _ note: String, _ a: Int, _ u: UUID, _ shared: Bool, _ w: UUID, _ k: TxKind = .expense) -> Txn {
            let base = cal.date(byAdding: .month, value: -mOffset, to: Date()) ?? Date()
            var comp = cal.dateComponents([.year, .month], from: base)
            comp.day = day
            let d = cal.date(from: comp) ?? base
            return Txn(kind: k, amount: a, category: cat, note: note, date: d, walletID: w, userID: u, isShared: shared)
        }
        var sample: [Txn] = [
            tx(4, "Thu", "Lương", 20_000_000, meID, true, v, .income), tx(4, "Thu", "Lương", 12_000_000, p, true, v, .income),
            tx(8, "Nhà cửa", "Tiền nhà", 2_100_000, meID, true, v), tx(8, "Hóa đơn", "Internet", 250_000, p, true, v),
            tx(7, "Chợ", "Co.opmart", 1_150_000, p, true, v), tx(7, "Ăn uống", "Ăn trưa", 85_000, meID, true, c),
            tx(6, "Con cái", "Học phí", 1_500_000, meID, true, v), tx(6, "Ăn uống", "Cà phê", 45_000, p, false, m),
            tx(5, "Mua sắm", "Quần áo", 780_000, p, false, m), tx(3, "Chợ", "Winmart", 840_000, p, true, v),
            tx(3, "Hóa đơn", "Tiền điện", 1_250_000, meID, true, v),
            Txn(
                kind: .expense, amount: 1_800_000, category: "Ăn uống", note: "Ăn tối gia đình",
                date: ago(2), walletID: v, userID: p, isShared: true, hasReceipt: true,
                comments: [
                    TxComment(userID: meID, text: "Em ơi khoản này là sinh nhật mẹ phải không?"),
                    TxComment(userID: p, text: "Dạ đúng rồi anh 🎂")
                ]
            ),
            tx(2, "Mua sắm", "Shopee", 650_000, meID, false, c), tx(1, "Đi lại", "Grab", 95_000, p, true, m),
            tx(1, "Ăn uống", "Ăn trưa", 70_000, meID, true, c), tx(0, "Ăn uống", "Phở sáng", 65_000, meID, true, c),
            tx(0, "Ăn uống", "Cà phê", 45_000, p, false, m)
        ]
        let history: [(Int, Int, Int, Int, Int, Int)] = [
            (1, 3_600_000, 2_400_000, 2_100_000, 1_450_000, 950_000),
            (2, 4_100_000, 2_700_000, 2_100_000, 1_600_000, 1_300_000),
            (3, 3_200_000, 2_200_000, 2_100_000, 1_350_000, 800_000),
            (4, 3_900_000, 2_500_000, 2_100_000, 1_500_000, 1_100_000),
            (5, 3_400_000, 2_100_000, 2_100_000, 1_300_000, 750_000)
        ]
        for (mOff, food, market, home, bill, fun) in history {
            sample.append(contentsOf: [
                mTx(mOff, 5, "Thu", "Lương", 20_000_000, meID, true, v, .income),
                mTx(mOff, 5, "Thu", "Lương", 12_000_000, p, true, v, .income),
                mTx(mOff, 3, "Nhà cửa", "Tiền nhà", home, meID, true, v),
                mTx(mOff, 8, "Hóa đơn", "Điện & Internet", bill, meID, true, v),
                mTx(mOff, 12, "Ăn uống", "Ăn uống trong tháng", food / 2, meID, true, c),
                mTx(mOff, 18, "Ăn uống", "Nhà hàng cuối tuần", food / 2, p, true, v),
                mTx(mOff, 20, "Chợ", "Siêu thị & chợ", market, p, true, v),
                mTx(mOff, 24, "Giải trí", "Xem phim & dã ngoại", fun, p, false, m)
            ])
        }
        transactions = sample
        deletedTxIDs = []
        goals = [Goal(emoji: "✈️", name: "Du lịch Đà Nẵng", saved: 8_000_000, target: 15_000_000, dueText: "T1/2027"),
                 Goal(emoji: "🏠", name: "Quỹ mua nhà", saved: 120_000_000, target: 800_000_000, dueText: "2029")]
        let mk = monthKey
        recurringRules = [
            RecurringRule(kind: .expense, title: "Tiền nhà", amount: 2_100_000, category: "Nhà cửa", dayOfMonth: 1, walletID: v, userID: meID, isShared: true, generatedMonths: [mk]),
            RecurringRule(kind: .expense, title: "Internet FPT", amount: 250_000, category: "Hóa đơn", dayOfMonth: 15, walletID: v, userID: p, isShared: true, generatedMonths: [mk]),
            RecurringRule(kind: .expense, title: "Học phí con", amount: 1_500_000, category: "Con cái", dayOfMonth: 5, walletID: v, userID: meID, isShared: true, generatedMonths: [mk]),
            RecurringRule(kind: .income, title: "Lương cố định", amount: 20_000_000, category: "Thu", dayOfMonth: 5, walletID: v, userID: meID, isShared: true, generatedMonths: [mk])
        ]
        notifications = [
            AppNotification(emoji: "⚠️", title: "Mua sắm đã vượt ngân sách 19%", subtitle: "Chung · hôm nay"),
            AppNotification(emoji: "💬", title: "Lan đã bình luận “Dạ đúng rồi anh 🎂”", subtitle: "Ăn tối gia đình"),
            AppNotification(emoji: "💸", title: "Lan chi chung 1.800.000 ₫", subtitle: "Ăn tối gia đình", isUnread: false)
        ]
        ratioMe = 62; onboarded = true
        setPartnerName("Lan")
        save()
        if sync.isCloudEnabled { startCloudSync() }
    }
}
