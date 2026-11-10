import SwiftUI

struct FamilyView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmReset = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        HStack(spacing: -14) {
                            AvatarView(person: store.me, size: 72)
                            AvatarView(person: store.partner, size: 72)
                        }
                        Text("Gia đình \(store.me.name) & \(store.partner.name)").font(.headline)
                        Text("Mã mời: \(store.familyCode)").font(.footnote).foregroundStyle(.secondary)
                        Label(store.syncState.label, systemImage: store.sync.isCloudEnabled ? "icloud.fill" : "iphone")
                            .font(.caption).foregroundStyle(.secondary)
                        ShareLink(item: "Tham gia gia đình trên Ví Đôi với mã: \(store.familyCode)") {
                            Label("Mời vợ/chồng", systemImage: "person.badge.plus")
                        }
                    }
                    .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                }

                Section("Đóng góp tháng này") {
                    let m = store.spent(.me), p = store.spent(.partner), t = max(1, m + p)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(store.me.name) · \(Fmt.vnd(m)) (\(m * 100 / t)%)")
                        ProgressBar(value: Double(m) / Double(t), color: Color(hex: store.me.colorHex))
                        Text("\(store.partner.name) · \(Fmt.vnd(p)) (\(p * 100 / t)%)")
                        ProgressBar(value: Double(p) / Double(t), color: Color(hex: store.partner.colorHex))
                    }
                }

                Section {
                    NavigationLink("⚖️ Cân đối chi tiêu chung") { BalanceView() }
                    NavigationLink("🔔 Thông báo (\(store.unreadNotificationCount))") { NotificationsView() }
                    NavigationLink("🔁 Giao dịch định kỳ (\(store.recurringRules.count))") { RecurringRulesView() }
                    NavigationLink("🗂 Danh mục tùy chỉnh (\(store.categories.count))") { CategoriesManageView() }
                    NavigationLink("👛 Ví & tài khoản (\(store.wallets.count))") { WalletsView() }
                    NavigationLink("🎯 Mục tiêu chung (\(store.goals.count))") { GoalsView() }
                    NavigationLink("📈 Báo cáo") { ReportView() }
                }

                Section {
                    Picker("Khoản riêng của vợ/chồng", selection: $store.privacy) {
                        ForEach(PrivacyMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: store.privacy) { _, _ in store.save() }
                    Text(store.privacy.hint).font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Quyền riêng tư") } footer: { Text("Khoản chi riêng của chính bạn luôn được ẩn chi tiết với vợ/chồng theo cài đặt của họ.") }

                Section("Thông báo & nhắc nhở") {
                    Toggle("Nhắc ghi chép lúc 21:00 hàng ngày", isOn: Binding(
                        get: { store.dailyReminderEnabled },
                        set: { store.setDailyReminder($0) }
                    ))
                    Stepper("Báo chi chung lớn ≥ \(Fmt.short(store.largeTxAlertThreshold))", value: $store.largeTxAlertThreshold, in: 500_000...20_000_000, step: 500_000)
                        .onChange(of: store.largeTxAlertThreshold) { _, _ in store.save(pushToCloud: false) }
                }

                Section("Bảo mật & dữ liệu") {
                    Toggle("Khóa bằng Face ID", isOn: $store.faceIDLock).onChange(of: store.faceIDLock) { _, _ in store.save() }
                    ShareLink(item: store.exportCSV(), preview: SharePreview("ChiTieu_ViDoi.csv")) {
                        Label("⬇ Xuất dữ liệu giao dịch (CSV)", systemImage: "square.and.arrow.up")
                    }
                    Button("Nạp dữ liệu mẫu") { store.loadDemo() }
                    Button("Xóa toàn bộ dữ liệu", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Gia đình")
            .confirmationDialog("Xóa toàn bộ dữ liệu trên máy này?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Xóa và làm lại", role: .destructive) { store.resetAll() }
            }
        }
    }
}

// MARK: - Ví & tài khoản (CRUD + Chuyển tiền)
struct WalletsView: View {
    @Environment(AppStore.self) private var store
    @State private var showAdd = false
    @State private var showTransfer = false
    @State private var editing: Wallet?

    var body: some View {
        let mine = store.wallets.filter { $0.ownerID == nil || $0.ownerID == store.meID }
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tổng tài sản (không gồm ví riêng của \(store.partner.name))").font(.footnote)
                    Text(Fmt.vnd(mine.reduce(0) { $0 + $1.balance })).font(.title.bold())
                    Button { showTransfer = true } label: {
                        Label("⇄ Chuyển tiền giữa các ví", systemImage: "arrow.left.arrow.right")
                            .font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.white.opacity(0.22), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.white).padding(.vertical, 6)
                .listRowBackground(LinearGradient(colors: [.shared, Color(hex: "A78BFA")], startPoint: .leading, endPoint: .trailing))
            }
            Section("Chạm để sửa · vuốt trái để xóa") {
                ForEach(store.wallets) { w in
                    if w.ownerID == nil || w.ownerID == store.meID {
                        Button { editing = w } label: {
                            HStack {
                                Text(w.emoji).font(.title2)
                                VStack(alignment: .leading) {
                                    Text(w.name).foregroundStyle(.primary)
                                    Text(w.ownerID == nil ? "👥 Ví chung" : "🔒 Ví riêng của \(store.me.name)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Fmt.vnd(w.balance)).bold()
                                    .foregroundStyle(w.balance < 0 ? Color.expense : Color.primary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if store.wallets.count > 1 {
                                Button(role: .destructive) { store.deleteWallet(w.id) } label: {
                                    Label("Xóa", systemImage: "trash")
                                }
                            }
                        }
                    } else {
                        HStack {
                            Text("🔒").font(.title2)
                            Text("Ví riêng của \(store.partner.name)")
                            Spacer()
                            Text("•••••").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Ví & tài khoản")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Label("Thêm ví", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            EditWalletSheet(existing: nil).presentationDetents([.medium])
        }
        .sheet(item: $editing) { w in
            EditWalletSheet(existing: w).presentationDetents([.medium])
        }
        .sheet(isPresented: $showTransfer) {
            AddTransactionView(editing: nil, initialKind: .transfer).presentationDetents([.large])
        }
    }
}

struct EditWalletSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let existing: Wallet?

    @State private var name = ""
    @State private var emoji = "🏦"
    @State private var balanceText = "0"
    @State private var isShared = true

    private let emojis = ["🏦", "💵", "💳", "📱", "🪙", "💎", "🐖", "👛"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin ví") {
                    TextField("Tên ví (vd: Techcombank, Tiền mặt…)", text: $name)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                        ForEach(emojis, id: \.self) { ic in
                            Text(ic).font(.title2)
                                .frame(width: 36, height: 36)
                                .background(emoji == ic ? Color.coral.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { emoji = ic }
                        }
                    }
                    .padding(.vertical, 4)
                    TextField("Số dư hiện tại (VND)", text: $balanceText)
                        .keyboardType(.numbersAndPunctuation)
                    Toggle("👥 Ví chung của gia đình", isOn: $isShared)
                }
            }
            .navigationTitle(existing == nil ? "Thêm ví mới" : "Sửa ví")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty else { return }
                        let bal = Int(balanceText) ?? 0
                        if var w = existing {
                            w.name = clean
                            w.emoji = emoji
                            w.balance = bal
                            w.ownerID = isShared ? nil : store.meID
                            store.updateWallet(w)
                        } else {
                            store.addWallet(name: clean, emoji: emoji, initialBalance: bal, isShared: isShared)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let w = existing {
                    name = w.name
                    emoji = w.emoji
                    balanceText = String(w.balance)
                    isShared = (w.ownerID == nil)
                }
            }
        }
    }
}

// MARK: - Mục tiêu chung (CRUD + góp tiền)
struct GoalsView: View {
    @Environment(AppStore.self) private var store
    @State private var showAdd = false
    @State private var editing: Goal?

    var body: some View {
        List {
            if store.goals.isEmpty {
                ContentUnavailableView("Chưa có mục tiêu", systemImage: "target", description: Text("Bấm ＋ ở góc trên để tạo mục tiêu tiết kiệm chung."))
            }
            ForEach(store.goals) { g in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(g.emoji).font(.title)
                        VStack(alignment: .leading) {
                            Text(g.name).bold()
                            Text("Mục tiêu \(Fmt.short(g.target)) · hạn \(g.dueText)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { editing = g } label: { Image(systemName: "pencil").font(.caption) }.buttonStyle(.plain)
                        Text("\(Int(Double(g.saved) / Double(max(1, g.target)) * 100))%").bold().foregroundStyle(Color.shared)
                    }
                    ProgressBar(value: Double(g.saved) / Double(max(1, g.target)), color: .shared)
                    HStack {
                        Text("Đã góp \(Fmt.vnd(g.saved))").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("＋ 500k") { store.contribute(g, 500_000) }.buttonStyle(.borderedProminent)
                        Button("＋ 2tr") { store.contribute(g, 2_000_000) }.buttonStyle(.bordered)
                    }
                    .font(.footnote)
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { store.deleteGoal(g.id) } label: {
                        Label("Xóa", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Mục tiêu chung")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Label("Thêm mục tiêu", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            EditGoalSheet(existing: nil).presentationDetents([.medium])
        }
        .sheet(item: $editing) { g in
            EditGoalSheet(existing: g).presentationDetents([.medium])
        }
    }
}

struct EditGoalSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let existing: Goal?

    @State private var name = ""
    @State private var emoji = "✈️"
    @State private var targetText = "20000000"
    @State private var savedText = "0"
    @State private var dueText = "Cuối năm"

    private let emojis = ["✈️", "🏠", "👶", "🚗", "💍", "🎓", "🏥", "🎯"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Mục tiêu tiết kiệm") {
                    TextField("Tên mục tiêu (vd: Du lịch Đà Nẵng, Mua nhà…)", text: $name)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                        ForEach(emojis, id: \.self) { ic in
                            Text(ic).font(.title2)
                                .frame(width: 36, height: 36)
                                .background(emoji == ic ? Color.coral.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { emoji = ic }
                        }
                    }
                    .padding(.vertical, 4)
                    TextField("Số tiền mục tiêu (VND)", text: $targetText).keyboardType(.numberPad)
                    TextField("Đã tích lũy (VND)", text: $savedText).keyboardType(.numberPad)
                    TextField("Thời hạn (vd: T12/2026, 2028…)", text: $dueText)
                }
            }
            .navigationTitle(existing == nil ? "Tạo mục tiêu" : "Sửa mục tiêu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let target = Int(targetText) ?? 0
                        let saved = Int(savedText) ?? 0
                        guard !clean.isEmpty, target > 0 else { return }
                        if var g = existing {
                            g.name = clean; g.emoji = emoji; g.target = target
                            g.saved = max(0, min(saved, target)); g.dueText = dueText
                            store.updateGoal(g)
                        } else {
                            store.addGoal(name: clean, emoji: emoji, target: target, saved: saved, dueText: dueText)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (Int(targetText) ?? 0) <= 0)
                }
            }
            .onAppear {
                if let g = existing {
                    name = g.name; emoji = g.emoji
                    targetText = String(g.target); savedText = String(g.saved); dueText = g.dueText
                }
            }
        }
    }
}

// MARK: - Trung tâm thông báo trong app
struct NotificationsView: View {
    @Environment(AppStore.self) private var store
    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.dateFormat = "HH:mm d/M"; return f
    }()

    var body: some View {
        List {
            if store.notifications.isEmpty {
                ContentUnavailableView("Chưa có thông báo", systemImage: "bell.slash", description: Text("Cảnh báo vượt ngân sách, khoản chi lớn và bình luận mới sẽ hiện tại đây."))
            }
            ForEach(store.notifications) { n in
                Button { store.markNotificationRead(n.id) } label: {
                    HStack(spacing: 12) {
                        Text(n.emoji).font(.title2).frame(width: 40, height: 40)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n.title).fontWeight(n.isUnread ? .bold : .regular).foregroundStyle(.primary)
                            Text("\(n.subtitle) · \(Self.fmt.string(from: n.createdAt))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if n.isUnread {
                            Circle().fill(Color.coral).frame(width: 9, height: 9)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Thông báo")
        .toolbar {
            if store.unreadNotificationCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đọc hết") { store.markAllNotificationsRead() }
                }
            }
        }
    }
}

// MARK: - Giao dịch định kỳ hàng tháng
struct RecurringRulesView: View {
    @Environment(AppStore.self) private var store
    @State private var showAdd = false
    @State private var toastMsg: String?

    var body: some View {
        List {
            if store.recurringRules.isEmpty {
                ContentUnavailableView(
                    "Chưa có giao dịch định kỳ",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text("Thêm các khoản lặp hàng tháng như tiền nhà, internet, học phí, lương…")
                )
            }
            ForEach(store.recurringRules) { r in
                let isDoneThisMonth = r.generatedMonths.contains(store.monthKey)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Text(r.kind == .income ? "💼" : store.emoji(for: r.category))
                            .font(.title2).frame(width: 40, height: 40)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.title).fontWeight(.semibold)
                            Text("Ngày \(r.dayOfMonth) hàng tháng · \(store.person(r.userID).name) · \(r.isShared ? "Chung" : "Riêng 🔒")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text((r.kind == .income ? "+" : "-") + Fmt.vnd(r.amount))
                            .fontWeight(.semibold).monospacedDigit()
                            .foregroundStyle(r.kind == .income ? Color.income : Color.expense)
                    }
                    HStack {
                        Label(
                            isDoneThisMonth ? "Đã ghi tháng này" : "Chưa ghi tháng này",
                            systemImage: isDoneThisMonth ? "checkmark.circle.fill" : "clock"
                        )
                        .font(.caption)
                        .foregroundStyle(isDoneThisMonth ? Color.income : Color.secondary)
                        Spacer()
                        Button("Ghi ngay") {
                            store.triggerRecurringNow(r)
                            toastMsg = "Đã ghi “\(r.title)” vào giao dịch tháng này"
                        }
                        .font(.caption.bold())
                        .buttonStyle(.bordered)
                        Toggle("", isOn: Binding(
                            get: { r.isActive },
                            set: { v in var copy = r; copy.isActive = v; store.updateRecurring(copy) }
                        ))
                        .labelsHidden()
                    }
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { store.deleteRecurring(r.id) } label: {
                        Label("Xóa", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Giao dịch định kỳ")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Label("Thêm", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddRecurringSheet().presentationDetents([.medium, .large])
        }
        .safeAreaInset(edge: .bottom) {
            if let m = toastMsg {
                HStack {
                    Text(m).font(.footnote)
                    Spacer()
                    Button("Đóng") { toastMsg = nil }.font(.footnote.bold())
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding()
            }
        }
        .onAppear { store.processDueRecurringRules() }
    }
}

struct AddRecurringSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var kind: TxKind = .expense
    @State private var title = ""
    @State private var amountText = ""
    @State private var category = SpendCategory.defaults[0].name
    @State private var dayOfMonth = 1
    @State private var paidByMe = true
    @State private var isShared = true
    @State private var walletID: UUID?

    private var availableWallets: [Wallet] {
        store.wallets.filter { $0.ownerID == nil || $0.ownerID == (paidByMe ? store.meID : store.partner.id) }
    }
    private var defaultWallet: UUID { (availableWallets.first ?? store.wallets[0]).id }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Loại", selection: $kind) {
                        Text("Khoản chi").tag(TxKind.expense)
                        Text("Khoản thu").tag(TxKind.income)
                    }
                    .pickerStyle(.segmented)
                    TextField("Tên khoản định kỳ (vd: Tiền nhà, Internet…)", text: $title)
                    TextField("Số tiền (VND)", text: $amountText).keyboardType(.numberPad)
                }
                if kind == .expense {
                    Section("Danh mục") {
                        Picker("Danh mục", selection: $category) {
                            ForEach(store.categories) { c in
                                Text("\(c.emoji) \(c.name)").tag(c.name)
                            }
                        }
                    }
                }
                Section("Lịch & ví") {
                    Stepper("Ngày \(dayOfMonth) hàng tháng", value: $dayOfMonth, in: 1...28)
                    Picker("Người ghi", selection: $paidByMe) {
                        Text(store.me.name).tag(true)
                        Text(store.partner.name).tag(false)
                    }
                    Picker("Ví", selection: Binding(get: { walletID ?? defaultWallet }, set: { walletID = $0 })) {
                        ForEach(availableWallets) { Text("\($0.emoji) \($0.name)").tag($0.id) }
                    }
                    Toggle("👥 Khoản chung của gia đình", isOn: $isShared)
                }
            }
            .navigationTitle("Thêm định kỳ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        guard let amt = Int(amountText), amt > 0 else { return }
                        let catName = kind == .income ? "Thu" : category
                        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let r = RecurringRule(
                            kind: kind,
                            title: cleanTitle.isEmpty ? catName : cleanTitle,
                            amount: amt,
                            category: catName,
                            dayOfMonth: dayOfMonth,
                            walletID: walletID ?? defaultWallet,
                            userID: paidByMe ? store.meID : store.partner.id,
                            isShared: isShared
                        )
                        store.addRecurring(r)
                        dismiss()
                    }
                    .disabled((Int(amountText) ?? 0) <= 0)
                }
            }
            .onAppear {
                if let first = store.categories.first { category = first.name }
            }
        }
    }
}

// MARK: - Quản lý danh mục tùy chỉnh
struct CategoriesManageView: View {
    @Environment(AppStore.self) private var store
    @State private var showAdd = false
    @State private var editing: SpendCategory?

    var body: some View {
        List {
            Section {
                ForEach(store.categories) { c in
                    let limit = store.budgets.first(where: { $0.category == c.name })?.limit ?? 0
                    Button { editing = c } label: {
                        HStack(spacing: 12) {
                            Text(c.emoji).font(.title2).frame(width: 38, height: 38)
                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).fontWeight(.medium).foregroundStyle(.primary)
                                Text(limit > 0 ? "Ngân sách: \(Fmt.vnd(limit))/tháng" : "Chưa đặt ngân sách")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "pencil").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if store.categories.count > 1 {
                            Button(role: .destructive) {
                                store.deleteCategory(name: c.name)
                            } label: { Label("Xóa", systemImage: "trash") }
                        }
                    }
                }
            } header: {
                Text("Chạm để đổi tên/biểu tượng · vuốt trái để xóa")
            }
        }
        .navigationTitle("Danh mục tùy chỉnh")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Label("Thêm", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            EditCategorySheet(existing: nil).presentationDetents([.medium])
        }
        .sheet(item: $editing) { cat in
            EditCategorySheet(existing: cat).presentationDetents([.medium])
        }
    }
}

struct EditCategorySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let existing: SpendCategory?

    @State private var name = ""
    @State private var emoji = "🏷️"
    @State private var limitText = "1000000"

    private let suggestedEmojis = ["🍜", "🛒", "🏠", "💡", "🚗", "👶", "🛍️", "🎮", "💊", "📚", "🎁", "✈️", "🐾", "💄", "🏋️", "🏷️"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Tên & biểu tượng") {
                    TextField("Tên danh mục (vd: Thú cưng, Hiếu hỷ…)", text: $name)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                        ForEach(suggestedEmojis, id: \.self) { ic in
                            Text(ic).font(.title2)
                                .frame(width: 36, height: 36)
                                .background(emoji == ic ? Color.coral.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { emoji = ic }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Ngân sách tháng (VND)") {
                    TextField("Hạn mức tháng", text: $limitText).keyboardType(.numberPad)
                }
            }
            .navigationTitle(existing == nil ? "Thêm danh mục" : "Sửa danh mục")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty else { return }
                        let lim = Int(limitText) ?? 0
                        if let old = existing {
                            store.updateCategory(oldName: old.name, newName: clean, emoji: emoji)
                            if lim > 0 { store.setLimit(clean, lim) }
                        } else {
                            store.addCategory(name: clean, emoji: emoji, budgetLimit: lim)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let c = existing {
                    name = c.name
                    emoji = c.emoji
                    let lim = store.budgets.first(where: { $0.category == c.name })?.limit ?? 0
                    limitText = String(lim)
                }
            }
        }
    }
}
