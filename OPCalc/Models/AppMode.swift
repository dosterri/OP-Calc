import Foundation

/// Bereiche der App, wählbar über die Modus-Taste unten links (E-006).
/// Neue Bereiche (Graph, Gleichungen, …) kommen hier als weiterer Fall hinzu.
enum AppMode: String, CaseIterable, Identifiable {
    case calculator
    case graph
    case graph3D
    case equations
    case differential
    case stochastics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calculator: return "Rechner"
        case .graph: return "Graph"
        case .graph3D: return "Graph 3D"
        case .equations: return "Gleichungen"
        case .differential: return "Differentialgleichung"
        case .stochastics: return "Stochastik"
        }
    }

    var systemImage: String {
        switch self {
        case .calculator: return "plus.forwardslash.minus"
        case .graph: return "chart.xyaxis.line"
        case .graph3D: return "cube"
        case .equations: return "equal.square"
        case .differential: return "point.topleft.down.to.point.bottomright.curvepath"
        case .stochastics: return "chart.bar"
        }
    }
}

/// Schlüssel für UserDefaults. `nonisolated`, damit sie als Argument von `@AppStorage` taugen (Leitfaden §6).
enum AppSettings {
    enum Key {
        nonisolated static let mode = "appMode"
    }
}
