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
    @State private var showCamera = false
    @State private var showReceiptPreview = false
    @State private var countsInSettlement = true
    @State private var makeRecurring = false
    @State private var shake = 0
    @FocusState private var noteFocused: Bool

    init(editing: Txn? = nil, initialKind: TxKind = .expense) {
        self.editingTx = editing
        _kind = State(initialValue: editing?.kind ?? initialKind)
    }

    private var value: Int { Self.evaluate(expr) }
    private var hasOperator: Bool {
        expr.dropFirst().contains { $0 == "+" || $0 == "-" || $0 == "*" || $0 == "/" }
    }

    /// Gợi ý số tiền thông minh theo con số đang gõ (vd gõ 45 -> 45k, 450k, 4,5tr).
    private var smartSuggestions: [Int] {
        if expr.isEmpty {
            return [35_000, 50_000, 100_000, 200_000, 500_000, 1_000_000]
        }
        guard !hasOperator, let base = Int(expr), base > 0, base < 100_000 else { return [] }
        let candidates = [base * 1_000, base * 10_000, base * 100_000, base * 1_000_000]
        return candidates.filter { $0 >= 1_000 && $0 <= 500_000_000 }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        Picker("Loại", selection: $kind) {
                            ForEach(TxKind.allCases, id: \.self) { k in
                                Text(k.title).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(spacing: 2) {
                            Text(Self.pretty(expr) + " ₫")
                                .font(.system(size: 40, weight: .bold)).monospacedDigit()
                                .foregroundStyle(kind == .income ? Color.income : (kind == .transfer ? Color.shared : Color.primary))
                                .minimumScaleFactor(0.5).lineLimit(1)
                                .modifier(Shake(animatableData: CGFloat(shake)))
                            if hasOperator {
                                Text("= \(Fmt.vnd(value))")
                                    .font(.footnote.bold())
                                    .foregroundStyle(Color.coral)
                            } else if noteFocused {
                                Text("Chạm vào số tiền để mở lại bàn phím tính")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture { noteFocused = false }

                        if kind == .expense {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                                ForEach(store.categories) { c in
                                    Button {
                                        noteFocused = false
                                        category = c.name
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text(c.emoji).font(.title3)
                                            Text(c.name).font(.caption2).lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.coral, lineWidth: category == c.name ? 2 : 0))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("📝 Ghi chú (vd: Phở sáng, Tiền điện…)", text: $note)
                                .focused($noteFocused)
                                .submitLabel(.done)
                                .onSubmit { noteFocused = false }
                            if !note.isEmpty {
                                Button {
                                    note = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            if noteFocused {
                                Button("Xong") { noteFocused = false }
                                    .font(.footnote.bold())
                                    .foregroundStyle(Color.coral)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

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
                                HStack(spacing: 12) {
                                    Text("📎 Hóa đơn")
                                    Spacer()
                                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                        Button {
                                            noteFocused = false
                                            showCamera = true
                                        } label: {
                                            Label("Chụp", systemImage: "camera.fill")
                                                .font(.footnote.bold())
                                        }
                                    }
                                    PhotosPicker(selection: $photoItem, matching: .images) {
                                        Label(receiptData != nil ? "Đổi ảnh" : "Thư viện", systemImage: "photo")
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
                                    Button { showReceiptPreview = true } label: {
                                        Image(uiImage: ui)
                                            .resizable().scaledToFill()
                                            .frame(height: 90).clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(alignment: .bottomTrailing) {
                                                Label("Xem rõ", systemImage: "magnifyingglass")
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                                    .background(.ultraThinMaterial, in: Capsule())
                                                    .padding(6)
                                            }
                                            .padding(.bottom, 6)
                                    }
                                    .buttonStyle(.plain)
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
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)

                if !noteFocused {
                    keypad
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button(editingTx == nil ? "Lưu giao dịch" : "Cập nhật giao dịch") {
                        noteFocused = false
                        save()
                    }
                    .buttonStyle(PrimaryButton())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: noteFocused)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(editingTx == nil ? "Thêm giao dịch" : "Sửa giao dịch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        noteFocused = false
                        save()
                    }
                    .bold()
                }
            }
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
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    if let jpeg = image.jpegData(compressionQuality: 0.45) {
                        receiptData = jpeg
                        hasReceipt = true
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showReceiptPreview) {
                if let data = receiptData, let ui = UIImage(data: data) {
                    ReceiptPreviewSheet(image: ui)
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
            // Dải gợi ý số tiền thông minh + phép nhân/chia
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(smartSuggestions, id: \.self) { amt in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                expr = String(amt)
                            } label: {
                                Text(Fmt.short(amt))
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.coral)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.coral.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                HStack(spacing: 4) {
                    ForEach(["×", "÷"], id: \.self) { op in
                        Button { press(op) } label: {
                            Text(op)
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.coral)
                                .frame(width: 34, height: 30)
                                .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(keys, id: \.self) { k in
                    Button { press(k) } label: {
                        Text(k).font(.title3.weight("+−=".contains(k) ? .bold : .medium))
                            .foregroundStyle("+−=".contains(k) ? Color.coral : Color.primary)
                            .frame(maxWidth: .infinity).frame(height: 43)
                            .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            Button(editingTx == nil ? "Lưu giao dịch" : "Cập nhật giao dịch") { save() }
                .buttonStyle(PrimaryButton())
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color(.secondarySystemGroupedBackground), in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
    }

    private static func isOp(_ c: Character) -> Bool {
        c == "+" || c == "-" || c == "*" || c == "/"
    }

    private func press(_ k: String) {
        switch k {
        case "⌫": if !expr.isEmpty { expr.removeLast() }
        case "C": expr = ""
        case "=": expr = value > 0 ? String(value) : ""
        case "+", "−", "×", "÷":
            guard !expr.isEmpty else { return }
            let op: Character = {
                switch k {
                case "+": return "+"
                case "−": return "-"
                case "×": return "*"
                default: return "/"
                }
            }()
            if let last = expr.last, Self.isOp(last) { expr.removeLast() }
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

    // MARK: - Máy tính (+, -, *, / theo thứ tự ưu tiên nhân/chia trước)
    static func evaluate(_ e: String) -> Int {
        guard !e.isEmpty else { return 0 }
        var numbers: [Int] = []
        var ops: [Character] = []
        var cur = ""
        for ch in e {
            if isOp(ch) {
                numbers.append(Int(cur) ?? 0)
                cur = ""
                ops.append(ch)
            } else if ch.isNumber {
                cur.append(ch)
            }
        }
        if !cur.isEmpty {
            numbers.append(Int(cur) ?? 0)
        } else if !ops.isEmpty {
            ops.removeLast()
        }
        guard !numbers.isEmpty else { return 0 }

        // Bước 1: tính * và /
        var addNums: [Int] = [numbers[0]]
        var addOps: [Character] = []
        for i in 0..<ops.count where (i + 1) < numbers.count {
            let op = ops[i]
            let next = numbers[i + 1]
            if op == "*" {
                addNums[addNums.count - 1] *= next
            } else if op == "/" {
                addNums[addNums.count - 1] = next == 0 ? 0 : (addNums[addNums.count - 1] / next)
            } else {
                addOps.append(op)
                addNums.append(next)
            }
        }

        // Bước 2: tính + và -
        var total = addNums[0]
        for i in 0..<addOps.count where (i + 1) < addNums.count {
            if addOps[i] == "+" {
                total += addNums[i + 1]
            } else {
                total -= addNums[i + 1]
            }
        }
        return max(0, total)
    }

    static func pretty(_ e: String) -> String {
        if e.isEmpty { return "0" }
        var out = "", num = ""
        for ch in e {
            if ch.isNumber {
                num.append(ch)
            } else {
                out += Fmt.num(Int(num) ?? 0)
                num = ""
                switch ch {
                case "-": out += " − "
                case "*": out += " × "
                case "/": out += " ÷ "
                default: out += " + "
                }
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

// MARK: - Camera & Xem ảnh hóa đơn phóng to
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onCapture(img)
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ReceiptPreviewSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width * scale, height: geo.size.height * scale)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Ảnh hóa đơn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(scale > 1 ? "Thu nhỏ" : "Phóng to 2×") {
                        withAnimation { scale = scale > 1 ? 1.0 : 2.0 }
                    }
                    .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                        .bold()
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
