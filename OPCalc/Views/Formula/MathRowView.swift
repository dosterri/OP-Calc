import SwiftUI

/// Was beim Zeichnen einer Formel hervorgehoben wird. Ohne Cursor = reine Anzeige (Ergebnis, Verlauf, Tasten).
struct RenderContext {
    var cursor: CursorPath?
    var selection: Range<Int>?

    static let display = RenderContext(cursor: nil, selection: nil)

    var isInteractive: Bool { cursor != nil }
}

/// Lage einer möglichen Cursorposition – wird für das Antippen gesammelt.
struct CaretAnchor {
    let path: CursorPath
    let anchor: Anchor<CGRect>
}

struct CaretAnchorKey: PreferenceKey {
    static let defaultValue: [CaretAnchor] = []

    static func reduce(value: inout [CaretAnchor], nextValue: () -> [CaretAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

/// Zeichnet eine Formelzeile rekursiv. Zwischen den Elementen liegen unsichtbare Marker
/// für jede Cursorposition; sie melden ihre Lage per Preference nach oben.
struct MathRowView: View {
    let row: MathRow
    let path: [PathStep]
    let context: RenderContext

    private var isCursorRow: Bool { context.cursor?.steps == path }

    var body: some View {
        if row.items.isEmpty {
            PlaceholderBox(isActive: isCursorRow && context.isInteractive)
                .overlay { marker(at: 0) }
        } else {
            MathRowLayout {
                ForEach(0..<(row.items.count * 2 + 1), id: \.self) { k in
                    if k % 2 == 0 {
                        marker(at: k / 2)
                    } else {
                        itemView(at: k / 2)
                    }
                }
            }
        }
    }

    private func marker(at offset: Int) -> some View {
        CaretMarker(path: CursorPath(steps: path, offset: offset),
                    isActive: isCursorRow && context.cursor?.offset == offset && context.selection == nil,
                    isInteractive: context.isInteractive)
    }

    private func itemView(at index: Int) -> some View {
        let isSelected = isCursorRow && (context.selection?.contains(index) ?? false)
        return MathItemView(item: row.items[index], rowPath: path, index: index, context: context)
            .background(isSelected ? Color.accentColor.opacity(0.28) : Color.clear)
    }
}

/// Zeichnet ein einzelnes Element (Ziffer, Operator, Bruch, Wurzel …).
struct MathItemView: View {
    let item: MathItem
    let rowPath: [PathStep]
    let index: Int
    let context: RenderContext

    @Environment(\.mathFontSize) private var fontSize

    var body: some View {
        switch item.kind {
        case .digit(let d):
            symbol(d == "." ? "," : d)
        case .op(let o):
            symbol(o.symbol)
                .padding(.horizontal, fontSize * 0.14)
        case .constant(let c):
            symbol(c.symbol)
        case .variable(let v):
            symbol(v, italic: true)
        case .ans:
            symbol("Ans")
        case .factorial:
            symbol("!")
        case .fraction:
            FractionLayout(barThickness: max(1, fontSize * 0.05),
                           gap: fontSize * 0.1,
                           sidePadding: fontSize * 0.08) {
                slot(0)
                Rectangle().fill(Color.primary)
                slot(1)
            }
            .environment(\.mathFontSize, Self.reduced(fontSize, by: 0.85))
            .padding(.horizontal, fontSize * 0.04)
        case .power:
            slot(0)
                .environment(\.mathFontSize, Self.reduced(fontSize, by: 0.68))
                .alignmentGuide(.mathAxis) { d in d.height - fontSize * 0.12 }
                .padding(.leading, fontSize * 0.03)
        case .squareRoot:
            RadicalLayout(fontSize: fontSize) {
                radicalSign
                Rectangle().fill(Color.primary)
                slot(0)
            }
        case .nthRoot:
            RadicalLayout(fontSize: fontSize) {
                radicalSign
                Rectangle().fill(Color.primary)
                slot(1)
                slot(0).environment(\.mathFontSize, Self.reduced(fontSize, by: 0.5))
            }
        case .parentheses:
            delimited(.parenthesis)
        case .absolute:
            delimited(.bar)
        case .function(let f):
            MathRowLayout {
                symbol(f.displayName)
                    .padding(.trailing, fontSize * 0.04)
                delimited(.parenthesis)
            }
        }
    }

    private static func reduced(_ size: CGFloat, by factor: CGFloat) -> CGFloat {
        max(size * factor, 11)
    }

    private func symbol(_ text: String, italic: Bool = false) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .regular))
            .italic(italic)
            .monospacedDigit()
            .foregroundStyle(Color.primary)
            .fixedSize()
    }

    private func slot(_ slotIndex: Int) -> some View {
        MathRowView(row: item.slots[slotIndex],
                    path: rowPath + [PathStep(item: index, slot: slotIndex)],
                    context: context)
    }

    private var radicalSign: some View {
        RadicalSignShape()
            .stroke(Color.primary, style: StrokeStyle(lineWidth: RadicalLayout.lineWidth(for: fontSize),
                                                      lineCap: .round, lineJoin: .round))
    }

    private func delimited(_ style: DelimiterStyle) -> some View {
        let stroke = StrokeStyle(lineWidth: max(1.2, fontSize * 0.055), lineCap: .round)
        return DelimitedLayout(fontSize: fontSize) {
            DelimiterShape(style: style, isLeft: true).stroke(Color.primary, style: stroke)
            slot(0)
            DelimiterShape(style: style, isLeft: false).stroke(Color.primary, style: stroke)
        }
    }
}

/// Unsichtbarer Marker (Breite 0) für eine Cursorposition; zeigt den blinkenden Cursor, wenn aktiv.
struct CaretMarker: View {
    let path: CursorPath
    let isActive: Bool
    let isInteractive: Bool

    @Environment(\.mathFontSize) private var fontSize

    var body: some View {
        Color.clear
            .frame(width: 0, height: fontSize * 1.1)
            .overlay {
                if isActive {
                    BlinkingCaret(height: fontSize * 1.1)
                        .id(FormulaEditorView.caretID)
                }
            }
            .anchorPreference(key: CaretAnchorKey.self, value: .bounds) { anchor in
                isInteractive ? [CaretAnchor(path: path, anchor: anchor)] : []
            }
    }
}

struct BlinkingCaret: View {
    let height: CGFloat
    @State private var isDimmed = false

    var body: some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(width: 2.5, height: height)
            .opacity(isDimmed ? 0.15 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// Platzhalter für einen leeren Slot (z. B. leerer Nenner).
struct PlaceholderBox: View {
    let isActive: Bool
    @Environment(\.mathFontSize) private var fontSize

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: fontSize * 0.1, style: .continuous)
        shape
            .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
            .overlay {
                shape.strokeBorder(isActive ? Color.accentColor : Color.secondary.opacity(0.6),
                                   style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            }
            .frame(width: fontSize * 0.6, height: fontSize * 0.8)
            .padding(.horizontal, fontSize * 0.05)
    }
}
