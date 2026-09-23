import SwiftUI

// Eigene Layouts für den Formelsatz.
//
// Alle Elemente einer Zeile werden an der „Mathe-Achse“ ausgerichtet – der Höhe, auf der
// Bruchstriche und das Pluszeichen liegen. Jedes Layout meldet seine Achse über
// explicitAlignment, sodass sich Brüche, Wurzeln und Klammern beliebig verschachteln lassen.

extension VerticalAlignment {
    private enum MathAxis: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context.height / 2
        }
    }

    /// Die Mathe-Achse (Höhe des Bruchstrichs).
    static let mathAxis = VerticalAlignment(MathAxis.self)
}

/// Schriftgröße für Formeln, wird beim Verschachteln (Exponent, Bruch) verkleinert.
private struct MathFontSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 32
}

extension EnvironmentValues {
    var mathFontSize: CGFloat {
        get { self[MathFontSizeKey.self] }
        set { self[MathFontSizeKey.self] = newValue }
    }
}

/// Eine Formelzeile: Elemente nebeneinander, an der Mathe-Achse ausgerichtet.
struct MathRowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let m = measure(subviews)
        return CGSize(width: m.width, height: m.ascent + m.descent)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let m = measure(subviews)
        var x = bounds.minX
        for (subview, d) in zip(subviews, m.dimensions) {
            subview.place(at: CGPoint(x: x, y: bounds.minY + m.ascent - d[.mathAxis]),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(width: d.width, height: d.height))
            x += d.width
        }
    }

    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) -> CGFloat? {
        guard guide == .mathAxis else { return nil }
        return bounds.minY + measure(subviews).ascent
    }

    private func measure(_ subviews: Subviews) -> (dimensions: [ViewDimensions], width: CGFloat, ascent: CGFloat, descent: CGFloat) {
        let dimensions = subviews.map { $0.dimensions(in: .unspecified) }
        var width: CGFloat = 0
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        for d in dimensions {
            width += d.width
            ascent = max(ascent, d[.mathAxis])
            descent = max(descent, d.height - d[.mathAxis])
        }
        return (dimensions, width, ascent, descent)
    }
}

/// Bruch. Erwartet genau drei Unteransichten: Zähler, Bruchstrich, Nenner.
struct FractionLayout: Layout {
    var barThickness: CGFloat
    var gap: CGFloat
    var sidePadding: CGFloat

    private func metrics(_ subviews: Subviews) -> (numerator: CGSize, denominator: CGSize, width: CGFloat) {
        let numerator = subviews[0].sizeThatFits(.unspecified)
        let denominator = subviews[2].sizeThatFits(.unspecified)
        return (numerator, denominator, max(numerator.width, denominator.width) + 2 * sidePadding)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else { return .zero }
        let m = metrics(subviews)
        return CGSize(width: m.width, height: m.numerator.height + m.denominator.height + 2 * gap + barThickness)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let m = metrics(subviews)
        subviews[0].place(at: CGPoint(x: bounds.midX, y: bounds.minY), anchor: .top,
                          proposal: ProposedViewSize(m.numerator))
        let barY = bounds.minY + m.numerator.height + gap
        subviews[1].place(at: CGPoint(x: bounds.minX, y: barY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: m.width, height: barThickness))
        subviews[2].place(at: CGPoint(x: bounds.midX, y: barY + barThickness + gap), anchor: .top,
                          proposal: ProposedViewSize(m.denominator))
    }

    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) -> CGFloat? {
        guard guide == .mathAxis, subviews.count == 3 else { return nil }
        let m = metrics(subviews)
        return bounds.minY + m.numerator.height + gap + barThickness / 2
    }
}

/// Wurzel. Unteransichten: Wurzelzeichen, Überstrich, Radikand und optional der Wurzelexponent.
struct RadicalLayout: Layout {
    var fontSize: CGFloat

    static func lineWidth(for fontSize: CGFloat) -> CGFloat { max(1, fontSize * 0.055) }

    private var signWidth: CGFloat { fontSize * 0.55 }
    private var thickness: CGFloat { Self.lineWidth(for: fontSize) }
    private var gap: CGFloat { fontSize * 0.1 }
    private var contentPadding: CGFloat { fontSize * 0.08 }

    private struct Metrics {
        var content: ViewDimensions
        var index: CGSize
        var left: CGFloat
        var top: CGFloat
        var innerHeight: CGFloat
    }

    private func metrics(_ subviews: Subviews) -> Metrics {
        let content = subviews[2].dimensions(in: .unspecified)
        let index = subviews.count > 3 ? subviews[3].sizeThatFits(.unspecified) : .zero
        let innerHeight = content.height + gap + thickness
        // Der Exponent sitzt mit seiner rechten unteren Ecke im Haken des Wurzelzeichens.
        let left = max(0, index.width - signWidth * 0.5)
        let top = max(0, index.height - innerHeight * 0.55)
        return Metrics(content: content, index: index, left: left, top: top, innerHeight: innerHeight)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count >= 3 else { return .zero }
        let m = metrics(subviews)
        return CGSize(width: m.left + signWidth + m.content.width + 2 * contentPadding,
                      height: m.top + m.innerHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count >= 3 else { return }
        let m = metrics(subviews)
        let originX = bounds.minX + m.left
        let originY = bounds.minY + m.top
        subviews[0].place(at: CGPoint(x: originX, y: originY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: signWidth, height: m.innerHeight))
        subviews[1].place(at: CGPoint(x: originX + signWidth, y: originY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: m.content.width + 2 * contentPadding, height: thickness))
        subviews[2].place(at: CGPoint(x: originX + signWidth + contentPadding, y: originY + thickness + gap),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(width: m.content.width, height: m.content.height))
        if subviews.count > 3 {
            subviews[3].place(at: CGPoint(x: originX + signWidth * 0.5, y: originY + m.innerHeight * 0.55),
                              anchor: .bottomTrailing,
                              proposal: ProposedViewSize(m.index))
        }
    }

    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) -> CGFloat? {
        guard guide == .mathAxis, subviews.count >= 3 else { return nil }
        let m = metrics(subviews)
        return bounds.minY + m.top + thickness + gap + m.content[.mathAxis]
    }
}

/// Inhalt zwischen zwei mitwachsenden Begrenzern (Klammern, Betragsstriche).
/// Unteransichten: linker Begrenzer, Inhalt, rechter Begrenzer.
struct DelimitedLayout: Layout {
    var fontSize: CGFloat

    private var delimiterWidth: CGFloat { fontSize * 0.3 }
    private var spacing: CGFloat { fontSize * 0.04 }
    private var overshoot: CGFloat { fontSize * 0.06 }

    private func metrics(_ subviews: Subviews) -> (content: ViewDimensions, height: CGFloat) {
        let content = subviews[1].dimensions(in: .unspecified)
        return (content, max(content.height, fontSize) + 2 * overshoot)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else { return .zero }
        let m = metrics(subviews)
        return CGSize(width: 2 * (delimiterWidth + spacing) + m.content.width, height: m.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let m = metrics(subviews)
        let delimiterSize = ProposedViewSize(width: delimiterWidth, height: m.height)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading, proposal: delimiterSize)
        subviews[1].place(at: CGPoint(x: bounds.minX + delimiterWidth + spacing,
                                      y: bounds.minY + (m.height - m.content.height) / 2),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(width: m.content.width, height: m.content.height))
        subviews[2].place(at: CGPoint(x: bounds.maxX - delimiterWidth, y: bounds.minY), anchor: .topLeading,
                          proposal: delimiterSize)
    }

    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) -> CGFloat? {
        guard guide == .mathAxis, subviews.count == 3 else { return nil }
        let m = metrics(subviews)
        return bounds.minY + (m.height - m.content.height) / 2 + m.content[.mathAxis]
    }
}
