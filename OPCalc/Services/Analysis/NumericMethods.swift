import Foundation

/// Numerische Grundverfahren: Nullstellen, Minimum, Integral. Alle Funktionen sind reell
/// und dürfen `nan` liefern (nicht definiert); die Verfahren springen darüber hinweg.
enum NumericMethods {
    /// Abtastpunkte im Suchintervall. 2000 trennt Nullstellen, die enger als 1/2000 des
    /// sichtbaren Bereichs liegen, nicht mehr – feiner sieht man es im Graphen ohnehin nicht.
    static let defaultSamples = 2000
    /// Relative Genauigkeit der Nullstellensuche.
    static let tolerance = 1e-13

    struct Root: Equatable {
        var x: Double
        /// true = Vorzeichenwechsel (einfache Nullstelle), false = Berührpunkt
        var crossesSign: Bool
    }

    // MARK: - Nullstellen

    /// Alle Nullstellen von f in [a, b]: Vorzeichenwechsel (Brent) und Berührstellen
    /// (lokales Minimum von |f| mit Wert ≈ 0). Polstellen mit Vorzeichenwechsel (1/x) werden verworfen.
    static func roots(of f: (Double) -> Double, in a: Double, _ b: Double,
                      samples: Int = defaultSamples) -> [Root] {
        guard a < b, samples > 2 else { return [] }
        let step = (b - a) / Double(samples)
        let xs = (0...samples).map { a + Double($0) * step }
        let ys = xs.map(f)
        var result: [Root] = []

        for i in 0..<samples {
            let (y0, y1) = (ys[i], ys[i + 1])
            guard y0.isFinite, y1.isFinite else { continue }
            if y0 == 0 {
                let left = i > 0 ? ys[i - 1] : .nan
                result.append(Root(x: xs[i], crossesSign: left.isFinite && left * y1 < 0))
                continue
            }
            if y0 * y1 < 0 {
                guard let r = brent(f, xs[i], xs[i + 1]) else { continue }
                let fr = Swift.abs(f(r))
                // Polstelle: dort wird |f| groß statt klein.
                if fr.isFinite, fr <= 1e-6 * max(1, min(Swift.abs(y0), Swift.abs(y1))) {
                    result.append(Root(x: r, crossesSign: true))
                }
            }
        }

        // Berührstellen: |f| hat ein lokales Minimum nahe 0, ohne Vorzeichenwechsel.
        let scale = ys.filter(\.isFinite).map(Swift.abs).max() ?? 1
        if samples >= 2 {
            for i in 1..<samples {
                let (l, m, r) = (ys[i - 1], ys[i], ys[i + 1])
                guard l.isFinite, m.isFinite, r.isFinite, m != 0,
                      Swift.abs(m) <= Swift.abs(l), Swift.abs(m) < Swift.abs(r), l * m > 0, m * r > 0 else { continue }
                let x = minimize({ Swift.abs(f($0)) }, xs[i - 1], xs[i + 1])
                let fx = Swift.abs(f(x))
                if fx <= 1e-10 * max(1, scale) {
                    result.append(Root(x: x, crossesSign: false))
                }
            }
        }
        return deduplicated(result.sorted { $0.x < $1.x }, minimumGap: step * 0.5)
    }

    private static func deduplicated(_ roots: [Root], minimumGap: Double) -> [Root] {
        var result: [Root] = []
        for root in roots {
            if let last = result.last, root.x - last.x < minimumGap {
                if root.crossesSign && !last.crossesSign { result[result.count - 1] = root }
                continue
            }
            result.append(root)
        }
        return result
    }

    /// Brent-Verfahren: sichere Nullstelle bei Vorzeichenwechsel zwischen a und b.
    static func brent(_ f: (Double) -> Double, _ lower: Double, _ upper: Double, maxIterations: Int = 200) -> Double? {
        var a = lower, b = upper
        var fa = f(a), fb = f(b)
        guard fa.isFinite, fb.isFinite, fa * fb <= 0 else { return nil }
        if fa == 0 { return a }
        if fb == 0 { return b }
        if Swift.abs(fa) < Swift.abs(fb) { swap(&a, &b); swap(&fa, &fb) }
        var c = a, fc = fa
        var d = b - a
        var bisected = true
        for _ in 0..<maxIterations {
            if fb == 0 || Swift.abs(b - a) <= tolerance * max(1, Swift.abs(b)) { return b }
            var s: Double
            if fa != fc && fb != fc {
                s = a * fb * fc / ((fa - fb) * (fa - fc)) + b * fa * fc / ((fb - fa) * (fb - fc))
                    + c * fa * fb / ((fc - fa) * (fc - fb))
            } else {
                s = b - fb * (b - a) / (fb - fa)
            }
            let bound = (3 * a + b) / 4
            let outside = !((s > min(bound, b)) && (s < max(bound, b)))
            if outside
                || (bisected && Swift.abs(s - b) >= Swift.abs(b - c) / 2)
                || (!bisected && Swift.abs(s - b) >= Swift.abs(c - d) / 2) {
                s = (a + b) / 2
                bisected = true
            } else {
                bisected = false
            }
            var fs = f(s)
            if !fs.isFinite { s = (a + b) / 2; fs = f(s); bisected = true }
            guard fs.isFinite else { return nil }
            d = c
            c = b; fc = fb
            if fa * fs < 0 { b = s; fb = fs } else { a = s; fa = fs }
            if Swift.abs(fa) < Swift.abs(fb) { swap(&a, &b); swap(&fa, &fb) }
        }
        return b
    }

    // MARK: - Minimum

    /// Goldener Schnitt: Minimum einer unimodalen Funktion in [a, b].
    static func minimize(_ f: (Double) -> Double, _ lower: Double, _ upper: Double) -> Double {
        let ratio = (sqrt(5.0) - 1) / 2
        var a = lower, b = upper
        var c = b - ratio * (b - a), d = a + ratio * (b - a)
        var fc = f(c), fd = f(d)
        for _ in 0..<200 where Swift.abs(b - a) > 1e-15 * max(1, Swift.abs(a) + Swift.abs(b)) {
            if fc.isNaN || fc < fd {
                b = d; d = c; fd = fc
                c = b - ratio * (b - a); fc = f(c)
            } else {
                a = c; c = d; fc = fd
                d = a + ratio * (b - a); fd = f(d)
            }
        }
        return (a + b) / 2
    }

    // MARK: - Integral

    /// Bestimmtes Integral mit adaptivem Gauß-Kronrod (7/15 Punkte).
    /// nil, wenn das Integral nicht konvergiert oder f im Intervall nicht definiert ist.
    static func integral(of f: (Double) -> Double, from a: Double, to b: Double,
                         tolerance: Double = 1e-11) -> Double? {
        if a == b { return 0 }
        if a > b { return integral(of: f, from: b, to: a, tolerance: tolerance).map { -$0 } }
        let whole = kronrod(f, a, b)
        guard whole.value.isFinite else { return nil }
        var unresolved = 0.0
        guard let value = adaptive(f, a, b, whole, tolerance: max(tolerance, tolerance * Swift.abs(whole.value)),
                                   depth: 0, unresolved: &unresolved), value.isFinite else { return nil }
        // Wurzel- und Log-Ränder (√x, ln x bei 0) bleiben bis zur Höchsttiefe ungenau, aber der Rest
        // ist winzig. Eine Polstelle hinterlässt dagegen einen großen Restfehler → kein Integral.
        return unresolved <= 1e-7 * max(1, Swift.abs(value)) ? value : nil
    }

    /// Rekursionstiefe: 2⁴⁰ Teilintervalle sind weit jenseits jeder sinnvollen Genauigkeit.
    private static let maxDepth = 40

    private static func adaptive(_ f: (Double) -> Double, _ a: Double, _ b: Double,
                                 _ estimate: (value: Double, error: Double), tolerance: Double, depth: Int,
                                 unresolved: inout Double) -> Double? {
        if estimate.error <= tolerance { return estimate.value }
        if depth >= maxDepth || b - a < 1e-14 * max(1, Swift.abs(a)) {
            unresolved += estimate.error
            return estimate.value
        }
        let m = (a + b) / 2
        let left = kronrod(f, a, m), right = kronrod(f, m, b)
        guard left.value.isFinite, right.value.isFinite else { return nil }
        guard let l = adaptive(f, a, m, left, tolerance: tolerance / 2, depth: depth + 1, unresolved: &unresolved),
              let r = adaptive(f, m, b, right, tolerance: tolerance / 2, depth: depth + 1, unresolved: &unresolved)
        else { return nil }
        return l + r
    }

    // Stützstellen und Gewichte G7/K15 (Standardtabelle, z. B. QUADPACK).
    private static let kronrodNodes: [Double] = [
        0.991455371120812639206854697526329, 0.949107912342758524526189684047851,
        0.864864423359769072789712788640926, 0.741531185599394439863864773280788,
        0.586087235467691130294144845693013, 0.405845151377397166906606412076961,
        0.207784955007898467600689403773245, 0.0,
    ]
    private static let kronrodWeights: [Double] = [
        0.022935322010529224963732008058970, 0.063092092629978553290700663189204,
        0.104790010322250183839876322541518, 0.140653259715525918745189590510238,
        0.169004726639267902826583426598550, 0.190350578064785409913256402421014,
        0.204432940075298892414161999234649, 0.209482141084727828012999174891714,
    ]
    private static let gaussWeights: [Double] = [
        0.129484966168869693270611432679082, 0.279705391489276667901467771423780,
        0.381830050505118944950369775488975, 0.417959183673469387755102040816327,
    ]

    private static func kronrod(_ f: (Double) -> Double, _ a: Double, _ b: Double) -> (value: Double, error: Double) {
        let center = (a + b) / 2, half = (b - a) / 2
        let fc = f(center)
        var kronrod = fc * kronrodWeights[7]
        var gauss = fc * gaussWeights[3]
        for i in 0..<7 {
            let dx = half * kronrodNodes[i]
            let sum = f(center - dx) + f(center + dx)
            kronrod += kronrodWeights[i] * sum
            if i % 2 == 1 { gauss += gaussWeights[i / 2] * sum }
        }
        return (kronrod * half, Swift.abs((kronrod - gauss) * half))
    }

    /// Ableitung per zentralem Differenzenquotienten – Rückfall, wenn die symbolische nicht geht.
    static func numericDerivative(_ f: @escaping (Double) -> Double) -> (Double) -> Double {
        { x in
            let h = 1e-5 * max(1, Swift.abs(x))
            return (f(x + h) - f(x - h)) / (2 * h)
        }
    }
}
