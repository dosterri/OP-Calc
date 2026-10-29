import Foundation

/// Bereiche der App, wählbar über die Modus-Taste unten links (E-006).
/// Neue Bereiche (Graph, Gleichungen, …) kommen hier als weiterer Fall hinzu.
enum AppMode: String, CaseIterable, Identifiable {
    case calculator

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calculator: return "Rechner"
        }
    }

    var systemImage: String {
        switch self {
        case .calculator: return "plus.forwardslash.minus"
        }
    }
}

/// Schlüssel für UserDefaults. `nonisolated`, damit sie als Argument von `@AppStorage` taugen (Leitfaden §6).
enum AppSettings {
    enum Key {
        nonisolated static let mode = "appMode"
    }
}
