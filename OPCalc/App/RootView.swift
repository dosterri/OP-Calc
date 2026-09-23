import SwiftUI

/// Einstiegspunkt der Oberfläche. Ab Etappe 2/3 kommen hier LGS-Löser und Plotter als Tabs hinzu.
struct RootView: View {
    var body: some View {
        CalculatorView()
    }
}

#Preview {
    RootView()
        .modelContainer(for: CalculationRecord.self, inMemory: true)
}
