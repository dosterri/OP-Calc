import SwiftUI
import UIKit

/// Oberer Bereich: Statuszeile, bearbeitbare Formel und Ergebnis bzw. Fehlermeldung.
struct DisplayView: View {
    let model: CalculatorModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 6) {
                StatusBadge(text: model.angleMode.shortName)
                if model.layer == .functions {
                    StatusBadge(text: "f(x)")
                }
                if model.isSelecting {
                    StatusBadge(text: "MARKIEREN", isHighlighted: true)
                }
                Spacer()
            }

            FormulaEditorView(editor: model.editor) { path in
                model.setCursor(path)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            resultArea
                .frame(minHeight: 56)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var resultArea: some View {
        if let message = model.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(.opacity)
        } else if let result = model.result {
            ResultView(result: result, showsDecimal: model.showsDecimal)
                .opacity(model.resultIsStale ? 0.35 : 1)
                .onTapGesture {
                    model.press(.toggleDecimal, context: nil)
                }
        } else {
            Color.clear
        }
    }
}

/// Ergebnis rechtsbündig mit „=“ (exakt) oder „≈“ (Näherung); lange Ergebnisse sind scrollbar.
struct ResultView: View {
    let result: CalculationResult
    let showsDecimal: Bool

    private var useDecimal: Bool { showsDecimal || result.exactRow == nil }
    private var row: MathRow { useDecimal ? result.decimalRow : (result.exactRow ?? result.decimalRow) }
    private var prefix: String { useDecimal && !result.decimalIsExact ? "≈" : "=" }
    private var plainText: String { useDecimal ? result.decimalText : (result.exactText ?? result.decimalText) }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            content
                .frame(maxWidth: .infinity, alignment: .trailing)
            ScrollView(.horizontal, showsIndicators: false) {
                content
            }
            .defaultScrollAnchor(.trailing)
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = plainText
            } label: {
                Label("Ergebnis kopieren", systemImage: "doc.on.doc")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(prefix == "=" ? "Ergebnis" : "Ergebnis ungefähr")
        .accessibilityValue(plainText)
    }

    private var content: some View {
        HStack(spacing: 10) {
            Text(prefix)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            MathRowView(row: row, path: [], context: .display)
                .environment(\.mathFontSize, 38)
                .fixedSize()
        }
    }
}

struct StatusBadge: View {
    let text: String
    var isHighlighted = false

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold).monospaced())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(isHighlighted ? Color.white : Color.secondary)
            .background(
                Capsule().fill(isHighlighted ? Color.accentColor : Color(.tertiarySystemFill))
            )
    }
}
