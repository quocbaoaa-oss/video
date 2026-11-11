import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    enum Step { case welcome, profile, link }
    @State private var step: Step = .welcome
    @State private var page = 0
    @State private var name = ""
    @State private var colorHex = "4C8DFF"
    @State private var joining = false
    @State private var code = ""
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var partnerName = ""

    private let slides: [(String, String, String)] = [
        ("👫", "Hai người, một gia đình", "Mỗi người một tài khoản riêng, liên kết để cùng nhìn một bức tranh tài chính."),
        ("🔐", "Chung & Riêng rõ ràng", "Khoản chung cả hai cùng thấy. Khoản riêng chỉ mình bạn – bạn quyết định mức chia sẻ."),
        ("⚖️", "Cân đối công bằng", "App tự tính ai cần chuyển cho ai theo tỷ lệ đóng góp.")
    ]
    private let colors = ["4C8DFF", "FF7EB6", "2EC4B6", "F59E0B", "7C5CFF"]

    var body: some View {
        VStack {
            switch step {
            case .welcome: welcome
            case .profile: profile
            case .link: link
            }
        }
        .padding()
        .animation(.easeInOut, value: step)
        .background(LinearGradient(colors: [Color.coral.opacity(0.12), Color.shared.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.coral.opacity(0.35), radius: 10, y: 6)
                Text("Ví Đôi").font(.title2.bold())
            }
            .padding(.top, 8)
            TabView(selection: $page) {
                ForEach(slides.indices, id: \.self) { i in
                    VStack(spacing: 16) {
                        Text(slides[i].0).font(.system(size: 96))
                        Text(slides[i].1).font(.title.bold()).multilineTextAlignment(.center)
                        Text(slides[i].2).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(.horizontal).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            Button(page == slides.count - 1 ? "Bắt đầu" : "Tiếp tục") {
                if page == slides.count - 1 { step = .profile } else { withAnimation { page += 1 } }
            }
            .buttonStyle(PrimaryButton())
            Button("Bỏ qua") { step = .profile }.foregroundStyle(.secondary)
        }
    }

    private var profile: some View {
        VStack(spacing: 18) {
            Text("Hồ sơ của bạn").font(.largeTitle.bold()).frame(maxWidth: .infinity, alignment: .leading)
            Text("Để vợ/chồng nhận ra bạn trong app").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            AvatarView(person: Person(name: name.isEmpty ? "?" : name, colorHex: colorHex), size: 90)
            TextField("Tên của bạn", text: $name)
                .padding().background(.background, in: RoundedRectangle(cornerRadius: 14))
            HStack(spacing: 14) {
                ForEach(colors, id: \.self) { c in
                    Circle().fill(Color(hex: c)).frame(width: 36, height: 36)
                        .overlay(Circle().stroke(Color.primary, lineWidth: colorHex == c ? 3 : 0).padding(-4))
                        .onTapGesture { colorHex = c }
                }
            }
            Spacer()
            Button("Tiếp tục") {
                store.updateMe(name: name.trimmingCharacters(in: .whitespaces), colorHex: colorHex)
                step = .link
                Task { await store.publishFamilyInvite() }
            }
            .buttonStyle(PrimaryButton())
        }
    }

    private var link: some View {
        VStack(spacing: 16) {
            Text("Kết nối gia đình").font(.largeTitle.bold()).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                Image(systemName: store.sync.isCloudEnabled ? "icloud.fill" : "iphone")
                Text(store.syncState.label)
            }
            .font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            if !joining {
                VStack(spacing: 8) {
                    Text("Mã mời của bạn").foregroundStyle(.secondary)
                    Text(store.familyCode).font(.system(size: 40, weight: .bold, design: .monospaced)).tracking(6)
                    ShareLink(item: "Tham gia gia đình của mình trên Ví Đôi với mã: \(store.familyCode)") {
                        Label("Chia sẻ mã mời", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButton())
                    Text("Gửi mã này cho vợ/chồng. Hiệu lực 48 giờ.").font(.footnote).foregroundStyle(.secondary)
                }
                .card()
                Button("Tôi có mã mời từ vợ/chồng") { errorMessage = nil; joining = true }.buttonStyle(SecondaryButton())
            } else {
                VStack(spacing: 10) {
                    TextField("Nhập mã 6 ký tự", text: $code)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .font(.system(size: 28, weight: .bold, design: .monospaced)).multilineTextAlignment(.center)
                        .padding().background(.background, in: RoundedRectangle(cornerRadius: 14))
                        .onChange(of: code) { _, v in code = String(v.uppercased().prefix(6)); errorMessage = nil }
                    TextField("Tên vợ/chồng (nếu chạy offline)", text: $partnerName)
                        .padding().background(.background, in: RoundedRectangle(cornerRadius: 14))
                    if let err = errorMessage {
                        Text(err).foregroundStyle(.red).font(.footnote).multilineTextAlignment(.center)
                    }
                    Button(isBusy ? "Đang xác thực…" : "Tham gia") {
                        Task {
                            isBusy = true
                            let res = await store.joinFamily(code: code, partnerFallbackName: partnerName)
                            isBusy = false
                            if case .failure(let msg) = res { errorMessage = msg }
                        }
                    }
                    .buttonStyle(PrimaryButton()).disabled(code.count < 6 || isBusy)
                    Button("Quay lại") { joining = false; errorMessage = nil }.foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Dùng dữ liệu mẫu để khám phá") { finish(demo: true) }.buttonStyle(SecondaryButton())
            Button("Để sau, vào app ngay") { finish(demo: false) }.foregroundStyle(.secondary)
        }
    }

    private func finish(demo: Bool) {
        if demo {
            store.loadDemo()
        } else {
            store.onboarded = true
            store.save()
            store.startCloudSync()
        }
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(Color.coral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).foregroundStyle(Color.coral)
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.coral, lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
