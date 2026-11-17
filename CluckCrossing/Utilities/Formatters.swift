import Foundation

enum Formatters {
    private static let integer: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static func number(_ value: Int) -> String {
        integer.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "×1.4" style multiplier.
    static func multiplier(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? "×\(Int(rounded))" : String(format: "×%.1f", rounded)
    }

    static func duration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}
