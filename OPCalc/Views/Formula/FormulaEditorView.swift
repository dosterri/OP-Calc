import SwiftUI

/// Bearbeitbare Formel: zeigt den Baum mit Cursor und setzt den Cursor per Antippen.
///
/// Trefferflächen: Statt jedem Zeichen eine eigene Geste zu geben, sammeln wir die Lage
/// aller Cursorpositionen und wählen beim Antippen die nächstgelegene. So trifft man
/// auch kleine Exponenten und leere Nenner zuverlässig.
struct FormulaEditorView: View {
    let editor: FormulaEditor
    let onTap: (CursorPath) -> Void

    static let caretID = "formula-caret"
    static let fontSize: CGFloat = 34

    var body: some View {
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    MathRowView(row: editor.root,
                                path: [],
                                context: RenderContext(cursor: editor.cursor, selection: editor.selectionRange))
                        .environment(\.mathFontSize, Self.fontSize)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minWidth: outer.size.width, minHeight: outer.size.height, alignment: .leading)
                        .overlayPreferenceValue(CaretAnchorKey.self) { anchors in
                            GeometryReader { inner in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .gesture(
                                        SpatialTapGesture().onEnded { value in
                                            if let path = Self.nearestCaret(anchors, in: inner, to: value.location) {
                                                onTap(path)
                                            }
                                        }
                                    )
                            }
                        }
                }
                .onChange(of: editor.cursor) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(Self.caretID)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Formel")
        .accessibilityValue(editor.root.isEmpty ? "leer" : editor.root.linearText)
    }

    /// Wählt die Cursorposition mit dem geringsten Abstand zum Tippunkt.
    /// Vertikale Abweichung zählt doppelt, damit man bei übereinanderliegenden Zeilen
    /// (Zähler/Nenner) in der richtigen landet.
    static func nearestCaret(_ anchors: [CaretAnchor], in proxy: GeometryProxy, to point: CGPoint) -> CursorPath? {
        var best: (path: CursorPath, score: CGFloat)?
        for caret in anchors {
            let rect = proxy[caret.anchor]
            let dx = abs(point.x - rect.midX)
            let dy = max(0, abs(point.y - rect.midY) - rect.height / 2)
            let score = dx + 2 * dy
            if best == nil || score < best!.score {
                best = (caret.path, score)
            }
        }
        return best?.path
    }
}
