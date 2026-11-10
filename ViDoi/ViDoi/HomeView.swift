import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var scope: Scope = .all
    @State private var undoTx: Txn?

    private var spent: Int { store.spent(scope) }
    private var progress: Double { Double(spent) / Double(max(1, store.monthlyBudget)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("Phạm vi", selection: $scope) {
                        Text("Chúng ta").tag(Scope.all)
                        Text(store.me.name).tag(Scope.me)
                        Text(store.partner.name).tag(Scope.partner)
                    }
                    .pickerStyle(.segmented)

                    hero
                    quickAdd
                    insights
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) { Text("Thu nhập").font(.caption).foregroundStyle(.secondary); Text("+" + Fmt.vnd(store.monthIncome)).bold().foregroundStyle(Color.income) }.card()
                        VStack(alignment: .leading) { Text("Còn lại").font(.caption).foregroundStyle(.secondary); Text(Fmt.vnd(store.monthIncome - store.spent(.all))).bold() }.card()
                    }
                    wallets
                    goals
                    recent
                }
                .padding(.horizontal)
                .padding(.bottom, 90)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(store.me.name) & \(store.partner.name)")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink { NotificationsView() } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                            if store.unreadNotificationCount > 0 {
                                Text("\(store.unreadNotificationCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Color.expense, in: Capsule())
                                    .offset(x: 8, y: -6)
                            }
                        }
                    }
                    NavigationLink { ReportView() } label: { Image(systemName: "chart.bar.xaxis") }
                }
            }
            .overlay(alignment: .bottom) { undoBar }
        }
    }

    private var hero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(.white.opacity(0.3), lineWidth: 10)
                Circle().trim(from: 0, to: min(1, progress))
                    .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: progress)
                Text("\(Int(progress * 100))%").font(.headline.bold())
            }
            .frame(width: 100, height: 100)
            VStack(alignment: .leading, spacing: 4) {
                Text("Đã chi tháng này").font(.footnote).opacity(0.9)
                Text(Fmt.vnd(spent)).font(.title2.bold()).minimumScaleFactor(0.7).lineLimit(1)
                Text(spent > store.monthlyBudget ? "Vượt \(Fmt.vnd(spent - store.monthlyBudget))" : "Còn \(Fmt.vnd(store.monthlyBudget - spent)) / \(Fmt.short(store.monthlyBudget))")
                    .font(.caption).opacity(0.9)
                Text("Dự kiến cuối tháng: \(Fmt.short(store.forecast)) \(store.forecast > store.monthlyBudget ? "⚠️" : "✅")")
                    .font(.caption).opacity(0.9)
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [.coral, Color(hex: "FF9A8B")], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private struct Quick: Identifiable { let id = UUID(); let emoji: String; let title: String; let amount: Int; let cat: String; let shared: Bool }
    private let quicks = [Quick(emoji: "☕", title: "Cà phê", amount: 45_000, cat: "Ăn uống", shared: false),
                          Quick(emoji: "🍜", title: "Ăn sáng", amount: 65_000, cat: "Ăn uống", shared: true),
                          Quick(emoji: "⛽", title: "Xăng", amount: 120_000, cat: "Đi lại", shared: true),
                          Quick(emoji: "🛒", title: "Đi chợ", amount: 300_000, cat: "Chợ", shared: true)]

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("⚡ Ghi nhanh").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(quicks) { q in
                        Button {
                            let t = Txn(kind: .expense, amount: q.amount, category: q.cat, note: q.title, date: Date(),
                                                walletID: defaultWallet, userID: store.meID, isShared: q.shared)
                            store.add(t); undoTx = t
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { if undoTx?.id == t.id { undoTx = nil } }
                        } label: {
                            Text("\(q.emoji) \(q.title) \(Fmt.short(q.amount))")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var defaultWallet: UUID {
        (store.wallets.first { $0.ownerID == store.meID } ?? store.wallets[0]).id
    }

    private var insights: some View {
        let over = store.categorySpend(.all).filter { c in
            if let b = store.budgets.first(where: { $0.category == c.name }) { return c.amount > b.limit }
            return false
        }
        let b = store.balance()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(over, id: \.name) { c in
                    InsightCard(emoji: "⚠️", text: "\(c.name) vượt ngân sách")
                }
                NavigationLink { BalanceView() } label: {
                    InsightCard(emoji: store.isSettled ? "🎉" : "⚖️",
                                text: store.isSettled ? "Đã cân bằng tháng này"
                                    : (b.owe >= 0 ? "\(store.partner.name) chuyển \(Fmt.short(abs(b.owe)))" : "Bạn chuyển \(Fmt.short(abs(b.owe)))"))
                }
                .buttonStyle(.plain)
                if let g = store.goals.first {
                    NavigationLink { GoalsView() } label: {
                        InsightCard(emoji: "🎯", text: "\(g.name) đạt \(Int(Double(g.saved) / Double(max(1, g.target)) * 100))%")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var wallets: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Ví & tài khoản").font(.headline); Spacer(); NavigationLink("Xem tất cả") { WalletsView() }.font(.footnote.bold()) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(store.wallets.filter { $0.ownerID == nil || $0.ownerID == store.meID }) { w in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(w.emoji).font(.title2)
                            Text(w.name).font(.caption)
                            Text(Fmt.vnd(w.balance)).font(.subheadline.bold())
                        }
                        .foregroundStyle(.white).padding(12).frame(width: 150, alignment: .leading)
                        .background(w.ownerID == nil ? Color.shared : Color.teal, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
        }
    }

    private var goals: some View {
        Group {
            if !store.goals.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("Mục tiêu chung").font(.headline); Spacer(); NavigationLink("Xem tất cả") { GoalsView() }.font(.footnote.bold()) }
                    ForEach(store.goals.prefix(2)) { g in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(g.emoji) \(g.name)").font(.subheadline)
                            ProgressBar(value: Double(g.saved) / Double(max(1, g.target)), color: .shared)
                        }
                    }
                }
                .card()
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Gần đây").font(.headline)
            let items = Array(store.visibleTransactions.prefix(5))
            if items.isEmpty {
                Text("Chưa có giao dịch. Bấm ＋ để ghi khoản đầu tiên.").foregroundStyle(.secondary).padding(.vertical, 12)
            }
            ForEach(items) { t in
                NavigationLink { TransactionDetailView(id: t.id) } label: { TransactionRow(tx: t) }
                    .buttonStyle(.plain)
                if t.id != items.last?.id { Divider() }
            }
        }
        .card()
    }

    @ViewBuilder private var undoBar: some View {
        if let t = undoTx {
            HStack {
                Text("Đã thêm \(t.note) \(Fmt.short(t.amount))")
                Spacer()
                Button("Hoàn tác") { store.delete(t); undoTx = nil }.bold().foregroundStyle(Color.coral)
            }
            .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal).padding(.bottom, 90)
            .transition(.move(edge: .bottom))
        }
    }
}

struct InsightCard: View {
    let emoji: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Text(emoji).font(.title2)
            Text(text).font(.footnote).multilineTextAlignment(.leading)
        }
        .padding(12).frame(width: 240, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct TransactionRow: View {
    @Environment(AppStore.self) private var store
    let tx: Txn
    var showDate = false

    var body: some View {
        let masked = store.isMasked(tx)
        let isTransfer = (tx.kind == .transfer)
        let fromW = store.wallets.first { $0.id == tx.walletID }?.name ?? "Ví"
        let toW = store.wallets.first { $0.id == tx.toWalletID }?.name ?? "Ví"
        let titleText: String = {
            if masked { return "Chi riêng" }
            if isTransfer { return tx.note.isEmpty ? "\(fromW) → \(toW)" : tx.note }
            return tx.note.isEmpty ? tx.category : tx.note
        }()
        let iconText: String = {
            if masked { return "🔒" }
            switch tx.kind {
            case .income: return "💼"
            case .transfer: return "⇄"
            case .expense: return store.emoji(for: tx.category)
            }
        }()
        let amountPrefix: String = {
            switch tx.kind {
            case .income: return "+"
            case .expense: return "-"
            case .transfer: return "⇄ "
            }
        }()
        let amountColor: Color = {
            switch tx.kind {
            case .income: return .income
            case .expense: return .expense
            case .transfer: return .shared
            }
        }()

        HStack(spacing: 12) {
            Text(iconText)
                .font(.title3).frame(width: 42, height: 42)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 2) {
                Text(titleText).fontWeight(.medium)
                HStack(spacing: 4) {
                    AvatarView(person: store.person(tx.userID), size: 16)
                    Text(
                        "\(store.person(tx.userID).name) · \(isTransfer ? "Chuyển ví" : (tx.isShared ? "Chung" : "Riêng 🔒"))"
                        + (showDate ? " · \(Fmt.day(tx.date))" : "")
                        + (!masked && tx.hasReceipt ? " · 📎" : "")
                        + (!masked && !tx.comments.isEmpty ? " · 💬\(tx.comments.count)" : "")
                    )
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(amountPrefix + Fmt.num(tx.amount))
                .fontWeight(.semibold).monospacedDigit()
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
