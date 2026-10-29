import SwiftUI

/// Antippbares Feld mit einer Formel (Zelle im Gleichungslöser, Funktion in DGL und 3D).
struct FormulaCell: View {
    let row: MathRow
    var placeholder = "0"
    var fontSize: CGFloat = 20
    var minWidth: CGFloat = 52
    var isInvalid = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if row.isEmpty {
                    Text(placeholder).font(.system(size: fontSize)).foregroundStyle(.secondary)
                } else {
                    MathRowView(row: row, path: [], context: .display)
                        .environment(\.mathFontSize, fontSize)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minWidth: minWidth, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.17)))
            .overlay {
                if isInvalid {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.red, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.isEmpty ? placeholder : row.linearText)
        .accessibilityHint("Zum Bearbeiten tippen")
    }
}

/// Ergebnis als Formel: exakt mit „=“, sonst Dezimalzahl mit „≈“ (M-E06).
struct ValueView: View {
    let value: Value
    var fontSize: CGFloat = 22
    var showsSign = true

    /// Brüche mit mehr Stellen sind als Bruch nicht mehr lesbar; dann Dezimalzahl.
    static let maxExactBits = 160

    var body: some View {
        let formatted = ResultFormatter.format(value)
        let exactRow = value.exactBits <= Self.maxExactBits ? formatted.exactRow : nil
        let row = exactRow ?? formatted.decimalRow
        let isApproximate = exactRow == nil && !formatted.decimalIsExact
        HStack(spacing: 6) {
            if showsSign {
                Text(isApproximate ? "≈" : "=")
                    .font(.system(size: fontSize, weight: .light))
                    .foregroundStyle(.secondary)
            }
            MathRowView(row: row, path: [], context: .display)
                .environment(\.mathFontSize, fontSize)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((isApproximate ? "ungefähr " : "") + row.linearText)
    }
}

extension Value {
    /// Größe eines exakten Werts in Bit (0 für Näherungen).
    var exactBits: Int {
        if case .exact(let v) = self { return v.bitSize }
        return 0
    }

    var negated: Value {
        switch self {
        case .exact(let v): return .exact(-v)
        case .approximate(let d): return .approximate(-d)
        }
    }
}

/// Überschrift eines Abschnitts im dunklen Stil.
struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Karte (abgerundeter dunkler Kasten) für Eingaben und Ergebnisse.
struct Card<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(white: 0.11)))
    }
}

/// Zahlenfeld mit Beschriftung (Parameter, Grenzen).
struct NumberField: View {
    let label: String
    @Binding var text: String
    var width: CGFloat = 90

    var body: some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(.secondary).fixedSize()
            TextField("", text: $text)
                .accessibilityLabel(label)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 8)
                .frame(width: width, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.17)))
        }
    }
}
