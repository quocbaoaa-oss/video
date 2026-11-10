import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
    static let coral = Color(hex: "FF6B6B")
    static let teal = Color(hex: "2EC4B6")
    static let shared = Color(hex: "7C5CFF")
    static let income = Color(hex: "22C55E")
    static let expense = Color(hex: "EF4444")
    static let warn = Color(hex: "F59E0B")
}

enum Fmt {
    private static let nf: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()
    /// 1250000 -> "1.250.000"
    static func num(_ v: Int) -> String { nf.string(from: NSNumber(value: v)) ?? "\(v)" }
    /// 1250000 -> "1.250.000 ₫"
    static func vnd(_ v: Int) -> String { num(v) + " ₫" }
    /// 1500000 -> "1,5tr", 45000 -> "45k"
    static func short(_ v: Int) -> String {
        let a = abs(v)
        if a >= 1_000_000 {
            let s = String(format: "%.1f", Double(v) / 1_000_000).replacingOccurrences(of: ".0", with: "")
            return s.replacingOccurrences(of: ".", with: ",") + "tr"
        }
        if a >= 1_000 { return "\(v / 1_000)k" }
        return "\(v)"
    }
    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.dateFormat = "EEE, d/M"; return f
    }()
    static func day(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Hôm nay" }
        if cal.isDateInYesterday(d) { return "Hôm qua" }
        return dayFmt.string(from: d)
    }
    private static let monthTitleFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.dateFormat = "MM/yyyy"; return f
    }()
    static func monthTitle(_ d: Date) -> String { "Tháng " + monthTitleFmt.string(from: d) }
    static func monthShort(_ d: Date) -> String { "T\(Calendar.current.component(.month, from: d))" }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
#if canImport(UIKit)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
#else
            .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
#endif
    }
}
extension View { func card() -> some View { modifier(CardStyle()) } }

struct AvatarView: View {
    let person: Person
    var size: CGFloat = 36
    var body: some View {
        Text(person.initial)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hex: person.colorHex), in: Circle())
    }
}

struct ProgressBar: View {
    var value: Double
    var color: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
#if canImport(UIKit)
                Capsule().fill(Color(.systemFill))
#else
                Capsule().fill(Color.gray.opacity(0.2))
#endif
                Capsule().fill(color).frame(width: g.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: 8)
    }
}

func budgetColor(_ p: Double) -> Color { p > 1 ? .expense : p >= 0.8 ? .warn : .income }
