import SwiftUI
import Charts

// MARK: - Ngân sách (Chung & Riêng + sửa ngân sách tổng tháng)
struct BudgetView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: Budget?
    @State private var showEditMonthly = false
    @State private var isPrivateTab = false
    @State private var selectedMonth: Date = Date()

    private var activeBudgets: [Budget] {
        isPrivateTab ? store.privateBudgets : store.budgets
    }

    private var spendByCat: [String: Int] {
        let list = isPrivateTab
            ? store.categorySpend(.me, privateOnly: true, in: selectedMonth)
            : store.categorySpend(.all, sharedOnly: true, in: selectedMonth)
        return Dictionary(uniqueKeysWithValues: list.map { ($0.name, $0.amount) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    MonthSwitcher(month: $selectedMonth)

                    Picker("Loại ngân sách", selection: $isPrivateTab) {
                        Text("👥 Chung").tag(false)
                        Text("🔒 Riêng của tôi").tag(true)
                    }
                    .pickerStyle(.segmented)

                    let totalLimit = activeBudgets.reduce(0) { $0 + $1.limit }
                    let totalSpent = activeBudgets.reduce(0) { $0 + (spendByCat[$1.category] ?? 0) }
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(isPrivateTab ? "Ngân sách riêng" : "Ngân sách chung") \(Fmt.monthTitle(selectedMonth).lowercased())")
                                .font(.footnote).foregroundStyle(.secondary)
                            Spacer()
                            Button("Hạn mức tổng: \(Fmt.short(store.monthlyBudget)) ✎") { showEditMonthly = true }
                                .font(.caption.bold()).foregroundStyle(Color.coral)
                        }
                        Text("\(Fmt.num(totalSpent)) / \(Fmt.vnd(totalLimit))").font(.title3.bold()).minimumScaleFactor(0.7)
                        ProgressBar(value: Double(totalSpent) / Double(max(1, totalLimit)), color: totalSpent > totalLimit ? .expense : .coral)
                    }
                    .card()

                    VStack(spacing: 14) {
                        ForEach(activeBudgets) { b in
                            let spent = spendByCat[b.category] ?? 0
                            let p = Double(spent) / Double(max(1, b.limit))
                            Button { editing = b } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("\(store.emoji(for: b.category)) \(b.category)")
                                        Spacer()
                                        Text("\(Fmt.short(spent)) / \(Fmt.short(b.limit))").font(.caption).foregroundStyle(.secondary)
                                        if p > 1 { Text("Vượt \(Int((p - 1) * 100))%").font(.caption.bold()).foregroundStyle(Color.expense) }
                                        else if p >= 0.8 { Text("Sắp hết").font(.caption.bold()).foregroundStyle(Color.warn) }
                                    }
                                    ProgressBar(value: p, color: budgetColor(p))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .card()

                    NavigationLink { ReportView(initialMonth: selectedMonth) } label: {
                        HStack { Text("📊 Báo cáo nhiều tháng & xu hướng").bold(); Spacer(); Image(systemName: "chevron.right") }.card()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal).padding(.bottom, 90)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ngân sách")
            .sheet(item: $editing) { EditBudgetSheet(budget: $0) }
            .sheet(isPresented: $showEditMonthly) { EditMonthlyBudgetSheet() }
        }
    }
}

struct EditBudgetSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let budget: Budget
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Hạn mức tháng cho \(budget.category) (\(budget.isShared ? "Chung" : "Riêng"))") {
                    TextField("Số tiền", text: $text).keyboardType(.numberPad)
                    Stepper("Tăng/giảm 500.000 ₫") {
                        text = String((Int(text) ?? budget.limit) + 500_000)
                    } onDecrement: {
                        text = String(max(0, (Int(text) ?? budget.limit) - 500_000))
                    }
                }
            }
            .navigationTitle("Sửa ngân sách")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        store.setLimit(budget.category, Int(text) ?? budget.limit, isShared: budget.isShared)
                        dismiss()
                    }
                }
            }
            .onAppear { text = String(budget.limit) }
        }
        .presentationDetents([.medium])
    }
}

struct EditMonthlyBudgetSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Ngân sách tổng tháng của gia đình (hiển thị trên Tổng quan)") {
                    TextField("Số tiền (VND)", text: $text).keyboardType(.numberPad)
                    Stepper("Tăng/giảm 1.000.000 ₫") {
                        text = String((Int(text) ?? store.monthlyBudget) + 1_000_000)
                    } onDecrement: {
                        text = String(max(1_000_000, (Int(text) ?? store.monthlyBudget) - 1_000_000))
                    }
                }
            }
            .navigationTitle("Ngân sách tổng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        store.setMonthlyBudget(Int(text) ?? store.monthlyBudget)
                        dismiss()
                    }
                }
            }
            .onAppear { text = String(store.monthlyBudget) }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Bộ chọn tháng dùng chung
struct MonthSwitcher: View {
    @Binding var month: Date
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        HStack {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left.circle.fill").font(.title3).foregroundStyle(Color.coral)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(Fmt.monthTitle(month)).font(.headline)
                if !isCurrentMonth {
                    Button("Về tháng này") { withAnimation { month = Date() } }
                        .font(.caption2).foregroundStyle(Color.coral)
                }
            }
            Spacer()
            Button { shift(1) } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isCurrentMonth ? Color.secondary.opacity(0.35) : Color.coral)
            }
            .disabled(isCurrentMonth)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func shift(_ delta: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: delta, to: month) {
            withAnimation { month = min(next, Date()) }
        }
    }
}

// MARK: - Báo cáo nhiều tháng (Danh mục · Xu hướng 6 tháng · So sánh)
struct ReportView: View {
    @Environment(AppStore.self) private var store
    enum Tab: String, CaseIterable, Identifiable {
        case categories = "Danh mục"
        case trend = "Xu hướng"
        case compare = "So sánh"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .categories
    @State private var scope: Scope = .all
    @State private var selectedMonth: Date

    init(initialMonth: Date = Date()) {
        _selectedMonth = State(initialValue: initialMonth)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                MonthSwitcher(month: $selectedMonth)

                Picker("Chế độ báo cáo", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .categories:
                    categoriesTab
                case .trend:
                    trendTab
                case .compare:
                    compareTab
                }
            }
            .padding(.horizontal).padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Báo cáo")
    }

    // MARK: 1. Tab Danh mục (theo tháng đang chọn)
    private var categoriesTab: some View {
        let cats = store.categorySpend(scope, in: selectedMonth)
        let total = cats.reduce(0) { $0 + $1.amount }
        return VStack(spacing: 14) {
            Picker("Phạm vi", selection: $scope) {
                Text("Chúng ta").tag(Scope.all)
                Text(store.me.name).tag(Scope.me)
                Text(store.partner.name).tag(Scope.partner)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 10) {
                Text("Chi theo danh mục · \(Fmt.monthTitle(selectedMonth))").font(.headline)
                if cats.isEmpty {
                    Text("Chưa có giao dịch chi trong tháng này.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    Chart(cats, id: \.name) { c in
                        SectorMark(angle: .value("Số tiền", c.amount), innerRadius: .ratio(0.62), angularInset: 2)
                            .foregroundStyle(by: .value("Danh mục", c.name))
                    }
                    .frame(height: 200)
                    .chartBackground { _ in
                        VStack {
                            Text(Fmt.short(total)).font(.title2.bold())
                            Text("đã chi").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(cats, id: \.name) { c in
                        HStack {
                            Text("\(store.emoji(for: c.name)) \(c.name)")
                            Spacer()
                            Text(Fmt.vnd(c.amount)).font(.subheadline.bold())
                            Text("\(Int(Double(c.amount) / Double(max(1, total)) * 100))%")
                                .font(.caption).foregroundStyle(.secondary)
                                .frame(width: 38, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .card()
        }
    }

    // MARK: 2. Tab Xu hướng 6 tháng
    private struct PersonBar: Identifiable {
        var id: String { "\(monthLabel)-\(person)" }
        let month: Date
        let monthLabel: String
        let person: String
        let amount: Int
        let colorHex: String
    }

    private var trendTab: some View {
        let points = store.monthlyTrend(months: 6, endingAt: selectedMonth)
        let bars: [PersonBar] = points.flatMap { p in
            [
                PersonBar(month: p.month, monthLabel: p.label, person: store.me.name, amount: p.spentMe, colorHex: store.me.colorHex),
                PersonBar(month: p.month, monthLabel: p.label, person: store.partner.name, amount: p.spentPartner, colorHex: store.partner.colorHex)
            ]
        }
        let current = points.last
        let previous = points.dropLast().last

        return VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Chi tiêu 6 tháng gần nhất").font(.headline)
                Chart(bars) { b in
                    BarMark(
                        x: .value("Tháng", b.monthLabel),
                        y: .value("Số tiền", b.amount)
                    )
                    .foregroundStyle(by: .value("Thành viên", b.person))
                    .position(by: .value("Thành viên", b.person))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale([
                    store.me.name: Color(hex: store.me.colorHex),
                    store.partner.name: Color(hex: store.partner.colorHex)
                ])
                .frame(height: 210)
                Text("Chạm vào từng tháng bên dưới để chuyển nhanh báo cáo sang tháng đó.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .card()

            // Nhận xét tự động so với tháng liền trước
            if let cur = current {
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 Nhận xét \(Fmt.monthTitle(cur.month).lowercased())").font(.headline)
                    if let prev = previous, prev.totalSpent > 0 {
                        let diffPct = Int(round(Double(cur.totalSpent - prev.totalSpent) / Double(prev.totalSpent) * 100))
                        HStack(spacing: 8) {
                            Text(diffPct > 0 ? "📈" : "📉")
                            Text(diffPct == 0
                                 ? "Chi tiêu ngang bằng với \(Fmt.monthTitle(prev.month).lowercased())."
                                 : "Tổng chi \(diffPct > 0 ? "tăng" : "giảm") \(abs(diffPct))% so với \(Fmt.monthTitle(prev.month).lowercased()) (\(Fmt.short(prev.totalSpent)) → \(Fmt.short(cur.totalSpent))).")
                                .font(.footnote)
                        }
                    }
                    if cur.income > 0 {
                        let rate = max(0, Int(round(Double(cur.netSaved) / Double(cur.income) * 100)))
                        HStack(spacing: 8) {
                            Text(cur.netSaved >= 0 ? "🌱" : "⚠️")
                            Text(cur.netSaved >= 0
                                 ? "Tiết kiệm được \(Fmt.vnd(cur.netSaved)) (\(rate)% thu nhập)."
                                 : "Chi vượt thu \(Fmt.vnd(abs(cur.netSaved))) trong tháng này.")
                                .font(.footnote)
                        }
                    }
                }
                .card()
            }

            // Bảng Thu – Chi – Tiết kiệm 6 tháng
            VStack(alignment: .leading, spacing: 8) {
                Text("Thu – Chi – Tiết kiệm theo tháng").font(.headline)
                ForEach(points.reversed()) { p in
                    let isSel = store.inMonth(p.month, of: selectedMonth)
                    Button {
                        withAnimation { selectedMonth = p.month }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Fmt.monthTitle(p.month))
                                    .fontWeight(isSel ? .bold : .medium)
                                    .foregroundStyle(isSel ? Color.coral : Color.primary)
                                Text("Thu +\(Fmt.short(p.income)) · Chi -\(Fmt.short(p.totalSpent))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text((p.netSaved >= 0 ? "+" : "") + Fmt.short(p.netSaved))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(p.netSaved >= 0 ? Color.income : Color.expense)
                                Text("còn lại").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    if p.id != points.first?.id { Divider() }
                }
            }
            .card()
        }
    }

    // MARK: 3. Tab So sánh hai người & giao dịch lớn nhất
    private var compareTab: some View {
        let m = store.spent(.me, in: selectedMonth)
        let p = store.spent(.partner, in: selectedMonth)
        let exps = store.monthExpenses(.all, in: selectedMonth)
        let shared = exps.filter { $0.isShared }.reduce(0) { $0 + $1.amount }
        let all = max(1, m + p)
        let top = Array(exps.sorted { $0.amount > $1.amount }.prefix(4))

        return VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ai chi bao nhiêu · \(Fmt.monthTitle(selectedMonth))").font(.headline)
                Chart {
                    BarMark(x: .value("Số tiền", m), y: .value("Người", store.me.name))
                        .foregroundStyle(Color(hex: store.me.colorHex))
                    BarMark(x: .value("Số tiền", p), y: .value("Người", store.partner.name))
                        .foregroundStyle(Color(hex: store.partner.colorHex))
                }
                .frame(height: 110)
                HStack {
                    Text("\(store.me.name): \(Fmt.vnd(m)) (\(m * 100 / all)%)")
                    Spacer()
                    Text("\(store.partner.name): \(Fmt.vnd(p)) (\(p * 100 / all)%)")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .card()

            VStack(alignment: .leading, spacing: 8) {
                Text("Tỷ trọng Chung / Riêng").font(.headline)
                ProgressBar(value: Double(shared) / Double(all), color: .shared)
                Text("👥 Chung \(Fmt.vnd(shared)) (\(shared * 100 / all)%) · 🔒 Riêng \(Fmt.vnd(m + p - shared))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .card()

            VStack(alignment: .leading, spacing: 6) {
                Text("Giao dịch lớn nhất trong tháng").font(.headline)
                if top.isEmpty {
                    Text("Chưa có giao dịch.").foregroundStyle(.secondary).padding(.vertical, 8)
                } else {
                    ForEach(top) { t in
                        NavigationLink { TransactionDetailView(id: t.id) } label: {
                            TransactionRow(tx: t, showDate: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .card()
        }
    }
}
