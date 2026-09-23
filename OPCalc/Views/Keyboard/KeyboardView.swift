import SwiftUI

/// Die eigene Rechner-Tastatur: Navigationsleiste oben, darunter 5 × 6 Tasten.
/// Ebene „123“ für Grundrechnen, Ebene „f(x)“ für Funktionen (springt nach einer Eingabe zurück).
struct KeyboardView: View {
    let layer: CalculatorKey.Layer
    let angleMode: AngleMode
    let isSelecting: Bool
    let onKey: (CalculatorKey) -> Void

    private static let navigationKeys: [CalculatorKey] = [.left, .right, .up, .down, .toggleSelection, .undo, .redo]

    private static let bottomRow: [CalculatorKey] = [.approximate, .digit("0"), .decimalSeparator, .timesTenPower, .op(.plus), .equals]

    private static let basicRows: [[CalculatorKey]] = [
        [.switchLayer, .square, .power, .squareRoot, .fraction, .delete],
        [.parentheses, .digit("7"), .digit("8"), .digit("9"), .op(.divide), .clear],
        [.constant(.pi), .digit("4"), .digit("5"), .digit("6"), .op(.times), .ans],
        [.constant(.e), .digit("1"), .digit("2"), .digit("3"), .op(.minus), .toggleDecimal],
        bottomRow,
    ]

    private static let functionRows: [[CalculatorKey]] = [
        [.switchLayer, .nthRoot, .expPower, .tenPower, .absolute, .delete],
        [.function(.sin), .function(.cos), .function(.tan), .function(.ln), .function(.log), .clear],
        [.function(.asin), .function(.acos), .function(.atan), .factorial, .inverse, .ans],
        [.constant(.pi), .constant(.e), .parentheses, .toggleAngleMode, .fraction, .toggleDecimal],
        bottomRow,
    ]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Self.navigationKeys, id: \.self) { key in
                    KeyButton(key: key, label: label(for: key), style: .navigation,
                              isHighlighted: key == .toggleSelection && isSelecting) {
                        onKey(key)
                    }
                    .frame(height: 38)
                }
            }

            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(row, id: \.self) { key in
                            KeyButton(key: key, label: label(for: key), style: style(for: key),
                                      isHighlighted: key == .switchLayer && layer == .functions) {
                                onKey(key)
                            }
                            .frame(minHeight: 46, maxHeight: 60)
                            // ⌫ lange drücken = alles löschen (bei allen anderen Tasten deaktiviert)
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5).onEnded { _ in onKey(.clear) },
                                including: key == .delete ? .all : .subviews
                            )
                        }
                    }
                }
            }
        }
    }

    private var rows: [[CalculatorKey]] {
        layer == .basic ? Self.basicRows : Self.functionRows
    }

    private func style(for key: CalculatorKey) -> KeyStyle {
        switch key {
        case .digit, .decimalSeparator: return .number
        case .op: return .operation
        case .equals: return .primary
        case .delete, .clear: return .destructive
        default: return .function
        }
    }

    // MARK: - Beschriftungen

    private func label(for key: CalculatorKey) -> KeyLabel {
        switch key {
        case .digit(let d): return .text(d)
        case .decimalSeparator: return .text(",")
        case .op(let o): return .text(o.symbol)
        case .constant(let c): return .text(c.symbol)
        case .ans: return .text("Ans")
        case .fraction: return .math(MathRow([MathItem(.fraction)]))
        case .square: return .math(Self.power(base: "x", exponent: MathRow(linear: "2")))
        case .power: return .math(Self.power(base: "x", exponent: MathRow(linear: "y")))
        case .inverse: return .math(Self.power(base: "x", exponent: MathRow(linear: "−1")))
        case .squareRoot: return .math(MathRow([MathItem(.squareRoot)]))
        case .nthRoot: return .math(MathRow([MathItem(.nthRoot, slots: [MathRow(linear: "x"), MathRow()])]))
        case .parentheses: return .text("( )")
        case .absolute: return .math(MathRow([MathItem(.absolute)]))
        case .factorial: return .text("n!")
        case .function(let f): return .text(f.displayName)
        case .expPower: return .math(Self.power(base: "e", exponent: MathRow(linear: "x")))
        case .tenPower: return .math(Self.power(base: "10", exponent: MathRow(linear: "x")))
        case .timesTenPower: return .math(Self.power(base: "×10", exponent: MathRow(linear: "x")))
        case .delete: return .symbol("delete.left")
        case .clear: return .text("AC")
        case .left: return .symbol("chevron.left")
        case .right: return .symbol("chevron.right")
        case .up: return .symbol("chevron.up")
        case .down: return .symbol("chevron.down")
        case .toggleSelection: return .symbol("selection.pin.in.out")
        case .undo: return .symbol("arrow.uturn.backward")
        case .redo: return .symbol("arrow.uturn.forward")
        case .toggleDecimal: return .text("S⇔D")
        case .toggleAngleMode: return .text(angleMode == .radians ? "RAD" : "DEG")
        case .switchLayer: return .text(layer == .basic ? "f(x)" : "123")
        case .equals: return .text("=")
        case .approximate: return .text("≈")
        }
    }

    private static func power(base: String, exponent: MathRow) -> MathRow {
        MathRow(MathRow(linear: base).items + [MathItem(.power, slots: [exponent])])
    }
}

// MARK: - Einzelne Taste

enum KeyStyle {
    case number, operation, function, primary, destructive, navigation
}

enum KeyLabel {
    case text(String)
    case symbol(String)
    case math(MathRow)
}

struct KeyButton: View {
    let key: CalculatorKey
    let label: KeyLabel
    let style: KeyStyle
    var isHighlighted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(KeyButtonStyle(style: style, isHighlighted: isHighlighted))
        .accessibilityLabel(key.accessibilityLabel)
    }

    @ViewBuilder
    private var content: some View {
        switch label {
        case .text(let text):
            Text(text)
                .font(font)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: style == .navigation ? 16 : 20, weight: .medium))
        case .math(let row):
            MathRowView(row: row, path: [], context: .display)
                .environment(\.mathFontSize, 19)
        }
    }

    private var font: Font {
        switch style {
        case .number: return .system(size: 26, weight: .regular)
        case .primary: return .system(size: 30, weight: .medium)
        case .operation: return .system(size: 26, weight: .regular)
        default: return .system(size: 18, weight: .medium)
        }
    }
}

struct KeyButtonStyle: ButtonStyle {
    let style: KeyStyle
    let isHighlighted: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(background)
                    .opacity(configuration.isPressed ? 0.55 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var background: Color {
        if isHighlighted { return Color.accentColor.opacity(0.35) }
        switch style {
        case .number: return Color(.secondarySystemBackground)
        case .operation: return Color.accentColor.opacity(0.18)
        case .function, .navigation: return Color(.tertiarySystemFill)
        case .primary: return Color.accentColor
        case .destructive: return Color.red.opacity(0.15)
        }
    }

    private var foreground: Color {
        switch style {
        case .primary: return .white
        case .operation: return .accentColor
        case .destructive: return .red
        default: return .primary
        }
    }
}
