import SwiftUI

/// Einstiegspunkt der Oberfläche: zeigt den Bereich, der über die Modus-Taste gewählt ist (E-006).
struct RootView: View {
    @AppStorage(AppSettings.Key.mode) private var storedMode = "calculator"

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
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: CalculationRecord.self, inMemory: true)
}
