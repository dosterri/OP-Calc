import SwiftUI

/// Einstiegspunkt der Oberfläche: zeigt den Bereich, der über die Modus-Taste gewählt ist (E-006).
struct RootView: View {
    @AppStorage(AppSettings.Key.mode) private var storedMode = "calculator"
    @State private var workspace = WorkspaceState()

    /// Unbekannte gespeicherte Werte (z. B. nach einem Update) fallen auf den Rechner zurück.
    private var mode: Binding<AppMode> {
        Binding(
            get: { AppMode(rawValue: storedMode) ?? .calculator },
            set: { storedMode = $0.rawValue }
        )
    }

    var body: some View {
        content
            .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch AppMode(rawValue: storedMode) ?? .calculator {
        case .calculator:
            CalculatorView(mode: mode)
        case .graph:
            GraphView(mode: mode)
        case .graph3D:
            Graph3DView(mode: mode)
        case .equations:
            EquationsView(mode: mode, state: workspace)
        case .differential:
            DifferentialView(mode: mode, state: workspace)
        case .stochastics:
            StochasticsView(mode: mode, state: workspace)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [CalculationRecord.self, GraphFunction.self], inMemory: true)
}
