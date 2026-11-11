import SwiftUI
import PhotosUI
import UIKit

struct TransactionsView: View {
    @Environment(AppStore.self) private var store
    enum Filter: String, CaseIterable, Identifiable {
        case all = "Tất cả", shared = "Chung", priv = "Riêng", me = "Của tôi", partner = "Vợ/chồng"
        var id: String { rawValue }
    }
    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var category: String?
    @State private var selectedMonth: Date = Date()
    @State private var filterByMonth = true
    @State private var deleted: Txn?
    @State private var editingTx: Txn?

    private var filtered: [Txn] {
        store.visibleTransactions.filter { t in
            if filterByMonth, !store.inMonth(t.date, of: selectedMonth) { return false }
            switch filter {
            case .all: break
            case .shared: if !t.isShared { return false }
            case .priv: if t.isShared { return false }
            case .me: if t.userID != store.meID { return false }
            case .partner: if t.userID == store.meID { return false }
            }
            if let c = category, t.category != c { return false }
            if !query.isEmpty {
                if store.isMasked(t) { return false }
                let commentText = t.comments.map(\.text).joined(separator: " ")
                let hay = (t.note + t.category + store.person(t.userID).name + commentText).lowercased()
                if !hay.contains(query.lowercased()) { return false }
            }
            return true
        }
    }

    private var groups: [(day: Date, items: [Txn])] {
        let dict = Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }
        return dict.keys.sorted(by: >).map { (day: $0, items: dict[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        if filterByMonth {
                            MonthSwitcher(month: $selectedMonth)
                        }
                        HStack {
                            Button {
                                withAnimation { filterByMonth.toggle() }
                            } label: {
                                Label(
                                    filterByMonth ? "Theo tháng (\(Fmt.monthTitle(selectedMonth)))" : "Đang xem: Tất cả các tháng",
                                    systemImage: "calendar"
                                )
                                .font(.caption.bold())
                                .foregroundStyle(Color.coral)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            if let c = category {
                                Button("Danh mục: \(store.emoji(for: c)) \(c) ✕") { category = nil }
                                    .font(.caption.bold())
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
                }
                ForEach(groups, id: \.day) { g in
                    Section {
                        ForEach(g.items) { t in
                            NavigationLink { TransactionDetailView(id: t.id) } label: { TransactionRow(tx: t) }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    if store.canEdit(t) {
                                        Button { editingTx = t } label: { Label("Sửa", systemImage: "pencil") }
                                            .tint(.shared)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if store.canEdit(t) {
                                        Button(role: .destructive) { store.delete(t); deleted = t } label: { Label("Xóa", systemImage: "trash") }
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text(Fmt.day(g.day)).bold()
                            Spacer()
                            let total = g.items.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
                            if total > 0 { Text("-" + Fmt.vnd(total)) }
                        }
                    }
                }
            }
            .contentMargins(.bottom, 40, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .overlay {
                if groups.isEmpty {
                    ContentUnavailableView("Chưa có giao dịch", systemImage: "magnifyingglass",
                                           description: Text("Thử đổi tháng, đổi bộ lọc hoặc bấm ＋ để thêm giao dịch."))
                }
            }
            .searchable(text: $query, prompt: "Tìm giao dịch, danh mục, ghi chú, bình luận")
            .navigationTitle("Giao dịch")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Lọc", selection: $filter) { ForEach(Filter.allCases) { Text($0.rawValue).tag($0) } }
                        Menu("Danh mục") {
                            Button("Tất cả") { category = nil }
                            ForEach(store.categories) { c in Button("\(c.emoji) \(c.name)") { category = c.name } }
                        }
                    } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                }
            }
            .sheet(item: $editingTx) { tx in
                AddTransactionView(editing: tx).presentationDetents([.large])
            }
            .safeAreaInset(edge: .bottom) {
                if let t = deleted {
                    HStack {
                        Text("Đã xóa “\(t.note.isEmpty ? t.category : t.note)”")
                        Spacer()
                        Button("Hoàn tác") { store.restore(t); deleted = nil }.bold().foregroundStyle(Color.coral)
                    }
                    .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal).padding(.bottom, 80)
                }
            }
        }
    }
}

struct TransactionDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var confirmDelete = false
    @State private var showEdit = false
    @State private var showCamera = false
    @State private var showReceiptPreview = false
    @State private var commentDraft = ""
    @State private var photoItem: PhotosPickerItem?
    @FocusState private var commentFocused: Bool

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.dateFormat = "HH:mm d/M"; return f
    }()

    var body: some View {
        if let t = store.transactions.first(where: { $0.id == id }), store.isVisible(t) {
            let masked = store.isMasked(t)
            let wallet = store.wallets.first { $0.id == t.walletID }
            let toWallet = store.wallets.first { $0.id == t.toWalletID }
            List {
                Section {
                    VStack(spacing: 8) {
                        Text(masked ? "🔒" : (t.kind == .income ? "💼" : (t.kind == .transfer ? "⇄" : store.emoji(for: t.category)))).font(.system(size: 44))
                        Text((t.kind == .income ? "+" : (t.kind == .transfer ? "⇄ " : "-")) + Fmt.vnd(t.amount))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(t.kind == .income ? Color.income : (t.kind == .transfer ? Color.shared : Color.primary))
                        Text(masked ? "Chi riêng" : (t.note.isEmpty ? t.category : t.note)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                }
                Section {
                    LabeledContent("Loại", value: t.kind.title)
                    if t.kind != .transfer {
                        LabeledContent("Danh mục", value: masked ? "🔒 Ẩn" : t.category)
                    }
                    LabeledContent("Người ghi") { HStack { AvatarView(person: store.person(t.userID), size: 20); Text(store.person(t.userID).name) } }
                    LabeledContent("Ngày", value: Fmt.day(t.date))
                    if t.kind == .transfer {
                        LabeledContent("Từ ví", value: wallet.map { "\($0.emoji) \($0.name)" } ?? "—")
                        LabeledContent("Sang ví", value: toWallet.map { "\($0.emoji) \($0.name)" } ?? "—")
                    } else {
                        LabeledContent("Ví", value: masked ? "🔒 Ẩn" : (wallet.map { "\($0.emoji) \($0.name)" } ?? "—"))
                        LabeledContent("Hiển thị", value: t.isShared ? "👥 Chung" : "🔒 Riêng")
                    }
                    if t.isShared && t.kind == .expense {
                        LabeledContent("Cân đối tháng", value: t.countsInSettlement ? "Có tính" : "Đã loại khỏi cân đối")
                    }
                    if !masked && !t.note.isEmpty {
                        LabeledContent("Ghi chú", value: t.note)
                    }
                }

                if masked {
                    Section { Text("Đây là khoản chi riêng. Chi tiết được ẩn theo cài đặt quyền riêng tư.").font(.footnote).foregroundStyle(.secondary) }
                } else {
                    // Hóa đơn đính kèm
                    Section("📎 Hóa đơn") {
                        if let data = t.receiptImageData, let ui = UIImage(data: data) {
                            Button { showReceiptPreview = true } label: {
                                Image(uiImage: ui)
                                    .resizable().scaledToFill()
                                    .frame(maxHeight: 200).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(alignment: .bottomTrailing) {
                                        Label("Xem rõ", systemImage: "magnifyingglass")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 8).padding(.vertical, 4)
                                            .background(.ultraThinMaterial, in: Capsule())
                                            .padding(6)
                                    }
                            }
                            .buttonStyle(.plain)
                        } else if t.hasReceipt {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 110)
                                .overlay {
                                    VStack(spacing: 4) {
                                        Image(systemName: "doc.text.image").font(.title)
                                        Text("Ảnh hóa đơn đính kèm").font(.caption)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                        }
                        HStack(spacing: 14) {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button { showCamera = true } label: {
                                    Label("Chụp ảnh", systemImage: "camera.fill")
                                }
                            }
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label(t.hasReceipt ? "Đổi ảnh" : "＋ Chọn ảnh", systemImage: "photo")
                            }
                            Spacer()
                            if t.hasReceipt && store.canEdit(t) {
                                Button("Gỡ ảnh", role: .destructive) {
                                    var copy = t; copy.hasReceipt = false; copy.receiptImageData = nil; store.update(copy)
                                }
                                .font(.footnote)
                            }
                        }
                    }

                    // Bình luận trao đổi giữa hai vợ chồng
                    Section("💬 Bình luận (\(t.comments.count))") {
                        if t.comments.isEmpty {
                            Text("Chưa có bình luận. Hỏi nhẹ nhàng nhé 😊")
                                .font(.footnote).foregroundStyle(.secondary)
                        } else {
                            ForEach(t.comments) { c in
                                let author = store.person(c.userID)
                                let isMine = (c.userID == store.meID)
                                HStack(alignment: .top, spacing: 10) {
                                    if !isMine { AvatarView(person: author, size: 28) }
                                    VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(author.name).font(.caption.bold())
                                            Text(Self.timeFmt.string(from: c.createdAt))
                                                .font(.caption2).foregroundStyle(.secondary)
                                        }
                                        Text(c.text)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(
                                                isMine ? Color.coral.opacity(0.16) : Color(.tertiarySystemFill),
                                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            )
                                    }
                                    .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
                                    if isMine { AvatarView(person: author, size: 28) }
                                }
                                .padding(.vertical, 2)
                                .swipeActions(edge: .trailing) {
                                    if isMine {
                                        Button(role: .destructive) {
                                            store.deleteComment(txID: t.id, commentID: c.id)
                                        } label: { Label("Xóa", systemImage: "trash") }
                                    }
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("Viết bình luận…", text: $commentDraft)
                                .focused($commentFocused)
                                .textFieldStyle(.roundedBorder)
                                .submitLabel(.send)
                                .onSubmit { submitComment(for: t.id) }
                            Button("Gửi") { submitComment(for: t.id) }
                                .buttonStyle(.borderedProminent)
                                .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    if store.canEdit(t) {
                        Section {
                            Button("✏️ Sửa toàn bộ giao dịch") { showEdit = true }
                            Button(t.isShared ? "🔒 Chuyển sang Riêng" : "👥 Chuyển sang Chung") {
                                var n = t; n.isShared.toggle(); store.update(n)
                            }
                            Button("🗑 Xóa giao dịch", role: .destructive) { confirmDelete = true }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Chi tiết")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !masked && store.canEdit(t) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sửa") { showEdit = true }
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                AddTransactionView(editing: t).presentationDetents([.large])
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    if let jpeg = image.jpegData(compressionQuality: 0.45) {
                        var copy = t
                        copy.receiptImageData = jpeg
                        copy.hasReceipt = true
                        store.update(copy)
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showReceiptPreview) {
                if let data = t.receiptImageData, let ui = UIImage(data: data) {
                    ReceiptPreviewSheet(image: ui)
                }
            }
            .confirmationDialog("Xóa giao dịch này?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Xóa", role: .destructive) { store.delete(t); dismiss() }
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let raw = try? await newItem.loadTransferable(type: Data.self),
                       let img = UIImage(data: raw),
                       let jpeg = img.jpegData(compressionQuality: 0.45) {
                        await MainActor.run {
                            var copy = t
                            copy.receiptImageData = jpeg
                            copy.hasReceipt = true
                            store.update(copy)
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView("Giao dịch không còn tồn tại", systemImage: "questionmark.folder")
        }
    }

    private func submitComment(for txID: UUID) {
        let text = commentDraft
        commentDraft = ""
        commentFocused = false
        store.addComment(txID: txID, text: text)
    }
}
