import SwiftUI
import LocalAuthentication

@main
struct ViDoiApp: App {
    @State private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(.coral)
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @State private var showAdd = false
    @State private var locked = false

    var body: some View {
        ZStack {
            if store.onboarded {
                MainTabs(showAdd: $showAdd)
            } else {
                OnboardingView()
            }
            if locked { LockView(unlock: authenticate) }
        }
        .sheet(isPresented: $showAdd) {
            AddTransactionView().presentationDetents([.large])
        }
        .onChange(of: phase) { _, new in
            if new == .background, store.faceIDLock, store.onboarded { locked = true }
            if new == .active, locked { authenticate() }
        }
    }

    private func authenticate() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { locked = false; return }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Mở Ví Đôi") { ok, _ in
            DispatchQueue.main.async { if ok { locked = false } }
        }
    }
}

struct LockView: View {
    var unlock: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("💞").font(.system(size: 64))
            Text("Ví Đôi đã khóa").font(.title2.bold())
            Button("Mở bằng Face ID", action: unlock).buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

struct MainTabs: View {
    @Binding var showAdd: Bool
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Tổng quan", systemImage: "house.fill") }
            TransactionsView().tabItem { Label("Giao dịch", systemImage: "list.bullet.rectangle") }
            BudgetView().tabItem { Label("Ngân sách", systemImage: "chart.pie.fill") }
            FamilyView().tabItem { Label("Gia đình", systemImage: "person.2.fill") }
        }
        .overlay(alignment: .bottom) {
            Button { showAdd = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(LinearGradient(colors: [.coral, Color(hex: "FF8A6B")], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .shadow(color: .coral.opacity(0.4), radius: 10, y: 6)
            }
            .accessibilityLabel("Thêm giao dịch")
            .padding(.bottom, 18)
        }
    }
}
