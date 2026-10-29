import SwiftUI

/// Untere Leiste der Bereiche außerhalb des Rechners: links die Modus-Taste (E-006),
/// rechts die Aktionen des Bereichs als runde Tasten.
struct ModeBar<Actions: View>: View {
    @Binding var mode: AppMode
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(spacing: 10) {
            ModeMenuKey(mode: $mode)
                .frame(width: 56, height: 56)
            Spacer(minLength: 0)
            actions()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// Runde Aktionstaste im Stil der Rechnertasten.
struct RoundActionButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var isProminent = false
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 56, height: 56)
                .contentShape(Circle())
        }
        .buttonStyle(KeyButtonStyle(style: isProminent ? .operation : .function, isHighlighted: isActive))
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Text-Aktion mit Menü in Kapselform (z. B. „Analyse“).
struct CapsuleMenuLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(Capsule(style: .continuous).fill(KeyPalette.operation))
    }
}

/// Farben der Graphen: gut unterscheidbar auf Schwarz.
enum GraphPalette {
    static let colors: [Color] = [
        KeyPalette.operation,
        Color(red: 0.25, green: 0.6, blue: 1),
        Color(red: 0.3, green: 0.85, blue: 0.4),
        Color(red: 1, green: 0.35, blue: 0.6),
        Color(red: 0.7, green: 0.5, blue: 1),
        Color(red: 1, green: 0.85, blue: 0.2),
    ]

    static func color(_ index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }
}

/// Wert mit „≈“ für Näherungen (M-E06), z. B. „x ≈ 1,41421“.
func approxText(_ name: String, _ value: Double, digits: Int = 6) -> String {
    name + " ≈ " + PlotGeometry.label(value, digits: digits)
}
