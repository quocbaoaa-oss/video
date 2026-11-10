import SwiftUI

// MARK: - Cân đối chi tiêu chung
struct BalanceView: View {
    @Environment(AppStore.self) private var store
    @State private var showSettle = false

    var body: some View {
        let b = store.balance()
        let total = max(1, b.total)
        ScrollView {
            VStack(spacing: 14) {
                pendingProposalBanner

                VStack(spacing: 8) {
                    HStack(spacing: 14) {
                        AvatarView(person: store.me, size: 56)
                        Image(systemName: b.owe >= 0 ? "arrow.left" : "arrow.right").font(.title2)
                        AvatarView(person: store.partner, size: 56)
                    }
                    Text(store.isSettled ? "Hai bạn đã cân bằng 🎉"
                         : (b.owe >= 0 ? "\(store.partner.name) nên chuyển cho \(store.me.name)" : "\(store.me.name) nên chuyển cho \(store.partner.name)"))
                    Text(store.isSettled ? "0 ₫" : Fmt.vnd(abs(b.owe))).font(.system(size: 36, weight: .bold)).foregroundStyle(Color.shared)
                    Text("để cân bằng theo tỷ lệ \(store.ratioMe)/\(100 - store.ratioMe)").font(.footnote).foregroundStyle(.secondary)
                    if !store.isSettled {
                        Button("✔ Đánh dấu đã chuyển") { showSettle = true }.buttonStyle(PrimaryButton())
                    }
                }
                .frame(maxWidth: .infinity).card()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Đã chi cho khoản chung").font(.headline)
                    Text("\(store.me.name) · \(Fmt.vnd(b.paidMe)) (\(b.paidMe * 100 / total)%)")
                    ProgressBar(value: Double(b.paidMe) / Double(total), color: Color(hex: store.me.colorHex))
                    Text("\(store.partner.name) · \(Fmt.vnd(b.paidPartner)) (\(b.paidPartner * 100 / total)%)")
                    ProgressBar(value: Double(b.paidPartner) / Double(total), color: Color(hex: store.partner.colorHex))
                    Text("Phần công bằng: \(store.me.name) \(Fmt.vnd(b.total * store.ratioMe / 100)) · \(store.partner.name) \(Fmt.vnd(b.total * (100 - store.ratioMe) / 100))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .card()

                NavigationLink { RatioView() } label: {
                    HStack {
                        Text("⚙️ Tỷ lệ đóng góp").bold()
                        Spacer()
                        if let target = store.pendingRatioForMe {
                            Text("Chờ duyệt \(target)/\(100 - target)").font(.caption.bold()).foregroundStyle(Color.warn)
                        } else {
                            Text("\(store.ratioMe)/\(100 - store.ratioMe)").foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                    }
                    .card()
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading) {
                    Text("Khoản chung tháng này").font(.headline)
                    Text("Chạm để loại khỏi / đưa vào cân đối").font(.caption).foregroundStyle(.secondary)
                    ForEach(store.monthExpenses(.all).filter { $0.isShared }) { t in
                        Button {
                            var n = t; n.countsInSettlement.toggle(); store.update(n)
                        } label: {
                            TransactionRow(tx: t, showDate: true).opacity(t.countsInSettlement ? 1 : 0.4)
                                .overlay(alignment: .center) { if !t.countsInSettlement { Rectangle().frame(height: 1).foregroundStyle(.secondary) } }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .card()
            }
            .padding(.horizontal).padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Cân đối")
        .confirmationDialog("Xác nhận đã chuyển \(Fmt.vnd(abs(b.owe)))?", isPresented: $showSettle, titleVisibility: .visible) {
            Button("Xác nhận tất toán") { store.settleMonth() }
        }
    }

    @ViewBuilder
    private var pendingProposalBanner: some View {
        if let proposal = store.pendingRatio, let targetMe = store.pendingRatioForMe {
            let isRequestedByMe = (proposal.requestedBy == store.meID)
            let requesterName = store.person(proposal.requestedBy).name
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("⏳").font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isRequestedByMe
                             ? "Bạn đã đề xuất tỷ lệ \(targetMe)/\(100 - targetMe)"
                             : "\(requesterName) đề xuất đổi tỷ lệ sang \(targetMe)/\(100 - targetMe)")
                            .font(.subheadline.bold())
                        Text(isRequestedByMe
                             ? "Đang chờ \(store.partner.name) đồng ý (hoặc bạn có thể xác nhận luôn khi thử trên 1 máy)."
                             : "Tỷ lệ hiện tại: \(store.ratioMe)/\(100 - store.ratioMe). Cả hai cần đồng ý để áp dụng.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 10) {
                    Button(isRequestedByMe ? "✔ Xác nhận áp dụng" : "✔ Đồng ý") {
                        store.approvePendingRatio()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.income)

                    Button(isRequestedByMe ? "Hủy yêu cầu" : "Từ chối", role: .destructive) {
                        store.rejectPendingRatio()
                    }
                    .buttonStyle(.bordered)
                }
                .font(.footnote.bold())
            }
            .card()
        }
    }
}

struct RatioView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var ratio: Double = 50

    var body: some View {
        Form {
            Section("Chia khoản chung") {
                Picker("Cách chia", selection: Binding(get: { Int(ratio) }, set: { if $0 > 0 { ratio = Double($0) } })) {
                    Text("50/50").tag(50); Text("Theo thu nhập").tag(incomeRatio); Text("Tùy chỉnh").tag(-1)
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("\(store.me.name) \(Int(ratio))%").foregroundStyle(Color(hex: store.me.colorHex)).bold()
                    Spacer()
                    Text("\(store.partner.name) \(100 - Int(ratio))%").foregroundStyle(Color(hex: store.partner.colorHex)).bold()
                }
                Slider(value: $ratio, in: 10...90, step: 1)
            }
            Section {
                Text("Cả hai cần đồng ý khi đổi tỷ lệ. Khi bấm gửi, yêu cầu sẽ hiển thị ở màn Cân đối để vợ/chồng xác nhận trước khi áp dụng.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Button("Gửi yêu cầu thay đổi (\(Int(ratio))/\(100 - Int(ratio)))") {
                    store.requestRatioChange(newRatioMe: Int(ratio))
                    dismiss()
                }
                .disabled(Int(ratio) == store.ratioMe)
            }
        }
        .navigationTitle("Tỷ lệ đóng góp")
        .onAppear { ratio = Double(store.pendingRatioForMe ?? store.ratioMe) }
    }

    /// Tỷ lệ theo thu nhập tháng này (giới hạn 10–90).
    private var incomeRatio: Int {
        let mine = store.transactions.filter { $0.kind == .income && $0.userID == store.meID && store.inCurrentMonth($0.date) }.reduce(0) { $0 + $1.amount }
        let all = store.transactions.filter { $0.kind == .income && store.inCurrentMonth($0.date) }.reduce(0) { $0 + $1.amount }
        guard all > 0 else { return 50 }
        return min(90, max(10, mine * 100 / all))
    }
}
