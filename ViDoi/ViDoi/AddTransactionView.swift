import SwiftUI
import PhotosUI
import UIKit

struct AddTransactionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Nếu khác nil thì đang ở chế độ sửa giao dịch đã có.
    let editingTx: Txn?

    @State private var kind: TxKind = .expense
    @State private var expr = ""
    @State private var category = SpendCategory.all[0].name
    @State private var note = ""
    @State private var date = Date()
    @State private var walletID: UUID?
    @State private var toWalletID: UUID?
    @State private var paidByMe = true
    @State private var isShared = true
    @State private var hasReceipt = false
    @State private var receiptData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var countsInSettlement = true
    @State private var makeRecurring = false
    @State private var shake = 0

    init(editing: Txn? = nil, initialKind: TxKind = .expense) {
        self.editingTx = editing
        _kind = State(initialValue: editing?.kind ?? initialKind)
    }

    private var value: Int { Self.evaluate(expr) }
    private var hasOperator: Bool { expr.dropFirst().contains { $0 == "+" || $0 == "-" } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Hủy") { dismiss() }
                Spacer()
                Text(editingTx == nil ? "Thêm giao dịch" : "Sửa giao dịch").bold()
                Spacer()
                Color.clear.frame(width: 30)
            }
            .padding()

            ScrollView {
                VStack(spacing: 12) {
                    Picker("Loại", selection: $kind) {
                        ForEach(TxKind.allCases, id: \.self) { k in
                            Text(k.title).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(Self.pretty(expr) + " ₫")
                        .font(.system(size: 42, weight: .bold)).monospacedDigit()
                        .foregroundStyle(kind == .income ? Color.income : (kind == .transfer ? Color.shared : Color.primary))
                        .minimumScaleFactor(0.5).lineLimit(1)
                        .modifier(Shake(animatableData: CGFloat(shake)))
                    Text(hasOperator ? "= \(Fmt.vnd(value))" : " ").font(.footnote).foregroundStyle(.secondary)

                    if kind == .expense {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                            ForEach(store.categories) { c in
                                Button { category = c.name } label: {
                                    VStack(spacing: 2) { Text(c.emoji).font(.title2); Text(c.name).font(.caption2).lineLimit(1) }
                                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.coral, lineWidth: category == c.name ? 2 : 0))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    TextField("📝 Ghi chú (không bắt buộc)", text: $note)
                        .padding().background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                    VStack(spacing: 0) {
                        if kind == .transfer {
                            Picker("Từ ví", selection: Binding(get: { walletID ?? defaultWallet }, set: { walletID = $0 })) {
                                ForEach(store.wallets) { Text("\($0.emoji) \($0.name)").tag($0.id) }
                            }
                            Divider()
                            Picker("Sang ví", selection: Binding(get: { toWalletID ?? defaultTargetWallet }, set: { toWalletID = $0 })) {
                                ForEach(targetWallets) { Text("\($0.emoji) \($0.name)").tag($0.id) }
                            }
                            Divider()
                            DatePicker("Ngày", selection: $date, in: ...Date(), displayedComponents: .date)
                        } else {
                            Picker("Ví", selection: Binding(get: { walletID ?? defaultWallet }, set: { walletID = $0 })) {
                                ForEach(availableWallets) { Text("\($0.emoji) \($0.name)").tag($0.id) }
                            }
                            Divider()
                            DatePicker("Ngày", selection: $date, in: ...Date(), displayedComponents: .date)
                            Divider()
                            Picker("Người ghi", selection: $paidByMe) {
                                Text(store.me.name).tag(true); Text(store.partner.name).tag(false)
                            }
                            Divider()
                            Toggle(isOn: $isShared) {
                                VStack(alignment: .leading) {
                                    Text("👥 Khoản chung")
                                    Text(isShared ? "Cả hai cùng thấy" : "🔒 Chỉ người ghi thấy").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if isShared && kind == .expense {
                                Divider()
                                Toggle("⚖️ Tính vào cân đối tháng", isOn: $countsInSettlement)
                            }
                            Divider()
                            HStack {
                                Text("📎 Hóa đơn")
                                Spacer()
                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    Label(receiptData != nil ? "Đổi ảnh" : "Chọn ảnh", systemImage: "photo")
                                        .font(.footnote.bold())
                                }
                                if receiptData != nil || hasReceipt {
                                    Button("Gỡ", role: .destructive) {
                                        receiptData = nil; hasReceipt = false; photoItem = nil
                                    }
                                    .font(.footnote)
                                }
                            }
                            .padding(.vertical, 8)
                            if let data = receiptData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable().scaledToFill()
                                    .frame(height: 90).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .padding(.bottom, 6)
                            }
                            if editingTx == nil {
                                Divider()
                                Toggle("🔁 Lặp lại hàng tháng (ngày \(min(Calendar.current.component(.day, from: date), 28)))", isOn: $makeRecurring)
                            }
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 4)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
            }

            keypad
        }
        .background(Color(.systemGroupedBackground))
        .onAppear(perform: loadExistingIfNeeded)
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let raw = try? await newItem.loadTransferable(type: Data.self),
                   let img = UIImage(data: raw),
                   let jpeg = img.jpegData(compressionQuality: 0.45) {
                    await MainActor.run {
                        receiptData = jpeg
                        hasReceipt = true
                    }
                }
            }
        }
    }

    private func loadExistingIfNeeded() {
        guard let t = editingTx, expr.isEmpty else { return }
        kind = t.kind
        expr = String(t.amount)
        if t.kind == .expense { category = t.category }
        note = t.note
        date = t.date
        walletID = t.walletID
        toWalletID = t.toWalletID
        paidByMe = (t.userID == store.meID)
        isShared = t.isShared
        hasReceipt = t.hasReceipt
        receiptData = t.receiptImageData
        countsInSettlement = t.countsInSettlement
    }

    private var availableWallets: [Wallet] {
        store.wallets.filter { $0.ownerID == nil || $0.ownerID == (paidByMe ? store.meID : store.partner.id) }
    }
    private var defaultWallet: UUID { (availableWallets.first ?? store.wallets[0]).id }
    private var targetWallets: [Wallet] {
        let src = walletID ?? defaultWallet
        let others = store.wallets.filter { $0.id != src }
        return others.isEmpty ? store.wallets : others
    }
    private var defaultTargetWallet: UUID { targetWallets[0].id }

    private var keypad: some View {
        let keys = ["7", "8", "9", "⌫", "4", "5", "6", "+", "1", "2", "3", "−", "000", "0", "C", "="]
        return VStack(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(keys, id: \.self) { k in
                    Button { press(k) } label: {
                        Text(k).font(.title2.weight("+−=".contains(k) ? .bold : .regular))
                            .foregroundStyle("+−=".contains(k) ? Color.coral : Color.primary)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            Button(editingTx == nil ? "Lưu giao dịch" : "Cập nhật giao dịch") { save() }
                .buttonStyle(PrimaryButton())
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
    }

    private func press(_ k: String) {
        switch k {
        case "⌫": if !expr.isEmpty { expr.removeLast() }
        case "C": expr = ""
        case "=": expr = value > 0 ? String(value) : ""
        case "+", "−":
            guard !expr.isEmpty else { return }
            let op: Character = k == "+" ? "+" : "-"
            if let last = expr.last, last == "+" || last == "-" { expr.removeLast() }
            expr.append(op)
        default:
            if expr.count < 24 { expr += k }
            while expr.count > 1, expr.first == "0", expr.dropFirst().first?.isNumber == true { expr.removeFirst() }
        }
    }

    private func save() {
        let v = value
        guard v > 0 else { withAnimation(.linear(duration: 0.4)) { shake += 1 }; return }
        let uid = paidByMe ? store.meID : store.partner.id
        let srcID = walletID ?? defaultWallet
        let dstID: UUID? = (kind == .transfer) ? (toWalletID ?? defaultTargetWallet) : nil
        let catName: String = {
            switch kind {
            case .expense: return category
            case .income: return "Thu"
            case .transfer: return "Chuyển khoản"
            }
        }()
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)

        if var existing = editingTx {
            existing.kind = kind
            existing.amount = v
            existing.category = catName
            existing.note = trimmedNote
            existing.date = date
            existing.walletID = srcID
            existing.toWalletID = dstID
            existing.userID = uid
            existing.isShared = kind == .transfer ? true : isShared
            existing.countsInSettlement = (kind == .expense && isShared) ? countsInSettlement : false
            existing.hasReceipt = hasReceipt || (receiptData != nil)
            existing.receiptImageData = receiptData
            store.update(existing)
        } else {
            let t = Txn(
                kind: kind, amount: v, category: catName,
                note: trimmedNote, date: date,
                walletID: srcID, toWalletID: dstID, userID: uid,
                isShared: kind == .transfer ? true : isShared,
                countsInSettlement: (kind == .expense && isShared) ? countsInSettlement : false,
                hasReceipt: hasReceipt || (receiptData != nil),
                receiptImageData: receiptData
            )
            store.add(t)
            if makeRecurring && kind != .transfer {
                let day = min(max(1, Calendar.current.component(.day, from: date)), 28)
                let rule = RecurringRule(
                    kind: kind,
                    title: trimmedNote.isEmpty ? catName : trimmedNote,
                    amount: v,
                    category: catName,
                    dayOfMonth: day,
                    walletID: srcID,
                    userID: uid,
                    isShared: isShared,
                    isActive: true,
                    generatedMonths: [store.monthKey(for: date)]
                )
                store.addRecurring(rule)
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    // MARK: helpers
    static func evaluate(_ e: String) -> Int {
        var total = 0, sign = 1
        var cur = ""
        for ch in e {
            if ch == "+" || ch == "-" {
                total += sign * (Int(cur) ?? 0); cur = ""; sign = ch == "+" ? 1 : -1
            } else { cur.append(ch) }
        }
        return total + sign * (Int(cur) ?? 0)
    }
    static func pretty(_ e: String) -> String {
        if e.isEmpty { return "0" }
        var out = "", num = ""
        for ch in e {
            if ch.isNumber { num.append(ch) } else {
                out += Fmt.num(Int(num) ?? 0) + (ch == "-" ? " − " : " + "); num = ""
            }
        }
        if !num.isEmpty { out += Fmt.num(Int(num) ?? 0) }
        return out
    }
}

struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}
