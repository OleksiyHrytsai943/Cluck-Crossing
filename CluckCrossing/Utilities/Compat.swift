import SwiftUI

// iOS 15 is the minimum, so newer SwiftUI APIs go through these helpers.

extension View {
    /// Rolling digits where available (iOS 16+).
    @ViewBuilder
    func numericTransition() -> some View {
        if #available(iOS 16.0, *) {
            contentTransition(.numericText())
        } else {
            self
        }
    }
}

extension Task where Success == Never, Failure == Never {
    /// `Task.sleep(for:)` needs iOS 16.
    static func sleep(ms: Int) async throws {
        try await Task.sleep(nanoseconds: UInt64(max(0, ms)) * 1_000_000)
    }
}
