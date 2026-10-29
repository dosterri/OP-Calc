import CoreGraphics
import Foundation

/// Sichtbarer Ausschnitt eines 2D-Graphen in Weltkoordinaten.
struct Viewport: Equatable {
    var xMin: Double
    var xMax: Double
    var yMin: Double
    var yMax: Double

    var width: Double { xMax - xMin }
    var height: Double { yMax - yMin }

    /// Standardfenster: x von −10 bis 10, y mit gleichem Maßstab wie x.
    static func standard(aspect: Double) -> Viewport {
        let halfHeight = 10 * (aspect.isFinite && aspect > 0 ? aspect : 1)
        return Viewport(xMin: -10, xMax: 10, yMin: -halfHeight, yMax: halfHeight)
    }

    func point(x: Double, y: Double, in size: CGSize) -> CGPoint {
        CGPoint(x: (x - xMin) / width * size.width, y: (yMax - y) / height * size.height)
    }

    func world(_ p: CGPoint, in size: CGSize) -> (x: Double, y: Double) {
        (xMin + Double(p.x / size.width) * width, yMax - Double(p.y / size.height) * height)
    }

    /// Verschiebt um eine Bildschirmstrecke (Finger nach rechts → Inhalt nach rechts).
    func panned(by translation: CGSize, in size: CGSize) -> Viewport {
        let dx = Double(translation.width / size.width) * width
        let dy = Double(translation.height / size.height) * height
        return Viewport(xMin: xMin - dx, xMax: xMax - dx, yMin: yMin + dy, yMax: yMax + dy)
    }

    /// Zoomt um einen Weltpunkt; Faktor > 1 vergrößert.
    func zoomed(by factor: Double, around center: (x: Double, y: Double)) -> Viewport {
        guard factor.isFinite, factor > 0 else { return self }
        let f = 1 / factor
        let next = Viewport(xMin: center.x - (center.x - xMin) * f, xMax: center.x + (xMax - center.x) * f,
                            yMin: center.y - (center.y - yMin) * f, yMax: center.y + (yMax - center.y) * f)
        // Grenzen, damit Double-Auflösung und Beschriftung sinnvoll bleiben.
        guard next.width > 1e-9, next.width < 1e9 else { return self }
        return next
    }

    func centered(at x: Double, _ y: Double) -> Viewport {
        Viewport(xMin: x - width / 2, xMax: x + width / 2, yMin: y - height / 2, yMax: y + height / 2)
    }
}

enum PlotGeometry {
    /// „Runde“ Schrittweite (1, 2 oder 5 · 10ᵏ), sodass etwa `target` Gitterlinien entstehen.
    static func niceStep(span: Double, target: Int = 8) -> Double {
        guard span > 0, span.isFinite, target > 0 else { return 1 }
        let raw = span / Double(target)
        let magnitude = pow(10, floor(log10(raw)))
        let fraction = raw / magnitude
        let nice: Double = fraction < 1.5 ? 1 : fraction < 3.5 ? 2 : fraction < 7.5 ? 5 : 10
        return nice * magnitude
    }

    static func ticks(from lower: Double, to upper: Double, step: Double) -> [Double] {
        guard step > 0, upper > lower, (upper - lower) / step < 1000 else { return [] }
        var result: [Double] = []
        var value = (lower / step).rounded(.up) * step
        while value <= upper {
            result.append(Swift.abs(value) < step * 1e-9 ? 0 : value)
            value += step
        }
        return result
    }

    /// Kurvenzüge eines Graphen. Ein Zug endet an Definitionslücken und Sprungstellen
    /// (tan, 1/x), damit dort keine senkrechten Verbindungslinien entstehen.
    /// `samples` ≈ Bildbreite in Punkten; an steilen Stellen wird zusätzlich verfeinert.
    static func polylines(_ f: (Double) -> Double, viewport: Viewport, size: CGSize, samples: Int) -> [[CGPoint]] {
        guard samples > 1, size.width > 0, size.height > 0 else { return [] }
        var lines: [[CGPoint]] = []
        var current: [CGPoint] = []
        let step = viewport.width / Double(samples)
        // Darüber gilt ein Sprung als Lücke: höher als der doppelte sichtbare Bereich.
        let jumpLimit = viewport.height * 2
        let clampY = viewport.height * 50

        func flush() {
            if current.count > 1 { lines.append(current) }
            current = []
        }
        func add(_ x: Double, _ y: Double) {
            let clamped = min(max(y, viewport.yMin - clampY), viewport.yMax + clampY)
            current.append(viewport.point(x: x, y: clamped, in: size))
        }

        var previous: (x: Double, y: Double)?
        for i in 0...samples {
            let x = viewport.xMin + Double(i) * step
            let y = f(x)
            guard y.isFinite else { flush(); previous = nil; continue }
            if let p = previous {
                if Swift.abs(y - p.y) > jumpLimit {
                    // Steil oder Sprung? Liegt der Mittelwert zwischen beiden, ist es nur steil.
                    let mid = f((p.x + x) / 2)
                    let between = mid.isFinite && mid >= min(p.y, y) && mid <= max(p.y, y)
                    if !between { flush() }
                } else if Swift.abs(y - p.y) > viewport.height / 20 {
                    // Steiler Abschnitt: vier Zwischenpunkte für eine glatte Kurve.
                    for k in 1...4 {
                        let xi = p.x + (x - p.x) * Double(k) / 5
                        let yi = f(xi)
                        if yi.isFinite { add(xi, yi) }
                    }
                }
            }
            add(x, y)
            previous = (x, y)
        }
        flush()
        return lines
    }

    /// Zahl für Achsen und Ergebnisse: höchstens `digits` gültige Stellen, deutsches Komma.
    static func label(_ value: Double, digits: Int = 6) -> String {
        if value == 0 || Swift.abs(value) < 1e-12 { return "0" }
        let representation = DecimalFormatting.representation(of: value, digits: digits)
        return DecimalFormatting.text(representation)
    }
}
