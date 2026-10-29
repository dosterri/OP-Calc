import Foundation

/// Beschreibende Statistik einer Messreihe (AK-04).
struct DescriptiveStatistics: Equatable {
    let values: [Double]
    let sorted: [Double]

    init?(_ values: [Double]) {
        guard !values.isEmpty, values.allSatisfy(\.isFinite) else { return nil }
        self.values = values
        self.sorted = values.sorted()
    }

    var count: Int { values.count }
    var sum: Double { values.reduce(0, +) }
    var mean: Double { sum / Double(count) }
    var minimum: Double { sorted[0] }
    var maximum: Double { sorted[count - 1] }
    var range: Double { maximum - minimum }
    var median: Double { quantile(0.5) }
    var lowerQuartile: Double { quantile(0.25) }
    var upperQuartile: Double { quantile(0.75) }

    /// Empirische Varianz (Division durch n)
    var populationVariance: Double {
        let m = mean
        return values.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(count)
    }

    /// Stichprobenvarianz (Division durch n − 1); bei n = 1 nicht definiert.
    var sampleVariance: Double? {
        guard count > 1 else { return nil }
        return populationVariance * Double(count) / Double(count - 1)
    }

    /// Quantil wie in der Schulmathematik (A-001): ist n·p ganzzahlig, das Mittel aus dem
    /// (n·p)-ten und dem folgenden Wert, sonst der Wert an Stelle ⌈n·p⌉.
    func quantile(_ p: Double) -> Double {
        let position = Double(count) * p
        let rounded = position.rounded()
        if Swift.abs(position - rounded) < 1e-9 {
            let i = Int(rounded)
            if i <= 0 { return sorted[0] }
            if i >= count { return sorted[count - 1] }
            return (sorted[i - 1] + sorted[i]) / 2
        }
        let i = Int(position.rounded(.up))
        return sorted[min(max(i, 1), count) - 1]
    }

    /// Häufigste Werte (leer, wenn jeder Wert nur einmal vorkommt).
    var modes: [Double] {
        var counts: [Double: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }
        guard let top = counts.values.max(), top > 1 else { return [] }
        return counts.filter { $0.value == top }.keys.sorted()
    }
}

/// Regression y ≈ f(x) nach der Methode der kleinsten Quadrate.
struct Regression: Equatable {
    enum Model: String, CaseIterable, Identifiable {
        case linear, quadratic, exponential
        var id: String { rawValue }
        var title: String {
            switch self {
            case .linear: return "Linear"
            case .quadratic: return "Quadratisch"
            case .exponential: return "Exponentiell"
            }
        }
    }

    let model: Model
    /// linear: [a, b] für a·x + b · quadratisch: [a, b, c] für a·x² + b·x + c · exponentiell: [a, b] für a·e^(b·x)
    let coefficients: [Double]
    /// Bestimmtheitsmaß R²
    let rSquared: Double
    /// Korrelationskoeffizient r (nur linear)
    let r: Double?

    func value(at x: Double) -> Double {
        switch model {
        case .linear: return coefficients[0] * x + coefficients[1]
        case .quadratic: return (coefficients[0] * x + coefficients[1]) * x + coefficients[2]
        case .exponential: return coefficients[0] * exp(coefficients[1] * x)
        }
    }

    static func fit(_ model: Model, x: [Double], y: [Double]) -> Regression? {
        guard x.count == y.count, x.count >= (model == .quadratic ? 3 : 2) else { return nil }
        switch model {
        case .linear:
            guard let line = linear(x, y) else { return nil }
            let (a, b) = (line.slope, line.intercept)
            let fitted = Regression(model: .linear, coefficients: [a, b], rSquared: 0, r: nil)
            let r2 = rSquared(fitted, x, y)
            let r = (a >= 0 ? 1.0 : -1.0) * r2.squareRoot()
            return Regression(model: .linear, coefficients: [a, b], rSquared: r2, r: r)
        case .quadratic:
            // Normalgleichungen 3×3 mit zentrierten x (sonst ist Σx⁴ bei Jahreszahlen so groß,
            // dass die Pivots als null gelten), danach auf die ursprünglichen x zurückrechnen.
            let mx = x.reduce(0, +) / Double(x.count)
            var s = [Double](repeating: 0, count: 5), t = [Double](repeating: 0, count: 3)
            for (rawX, yi) in zip(x, y) {
                let xi = rawX - mx
                var power = 1.0
                for k in 0..<5 {
                    s[k] += power
                    if k < 3 { t[k] += power * yi }
                    power *= xi
                }
            }
            let system: [[Double]] = [[s[4], s[3], s[2], t[2]], [s[3], s[2], s[1], t[1]], [s[2], s[1], s[0], t[0]]]
            let solution = LinearSystemSolver.solve(system, exact: false)
            guard solution.kind == .unique else { return nil }
            let centered = solution.variables.map(\.constant.doubleValue)
            let (a, b, c) = (centered[0], centered[1], centered[2])
            let coefficients = [a, b - 2 * a * mx, c - b * mx + a * mx * mx]
            let fitted = Regression(model: .quadratic, coefficients: coefficients, rSquared: 0, r: nil)
            return Regression(model: .quadratic, coefficients: coefficients, rSquared: rSquared(fitted, x, y), r: nil)
        case .exponential:
            // ln y = ln a + b·x – nur für positive y
            guard y.allSatisfy({ $0 > 0 }), let line = linear(x, y.map { log($0) }) else { return nil }
            let fitted = Regression(model: .exponential, coefficients: [exp(line.intercept), line.slope], rSquared: 0, r: nil)
            return Regression(model: .exponential, coefficients: fitted.coefficients, rSquared: rSquared(fitted, x, y), r: nil)
        }
    }

    private struct Line { let slope: Double; let intercept: Double }

    private static func linear(_ x: [Double], _ y: [Double]) -> Line? {
        let n = Double(x.count)
        let mx = x.reduce(0, +) / n, my = y.reduce(0, +) / n
        let sxx = x.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
        guard sxx > 0 else { return nil }
        let sxy = zip(x, y).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        let a = sxy / sxx
        return Line(slope: a, intercept: my - a * mx)
    }

    private static func rSquared(_ fit: Regression, _ x: [Double], _ y: [Double]) -> Double {
        let my = y.reduce(0, +) / Double(y.count)
        let total = y.reduce(0) { $0 + ($1 - my) * ($1 - my) }
        guard total > 0 else { return 1 }
        let residual = zip(x, y).reduce(0) { $0 + pow($1.1 - fit.value(at: $1.0), 2) }
        return max(0, 1 - residual / total)
    }
}

/// Zahlenlisten aus Text: getrennt durch Leerzeichen, Semikolon oder Zeilenumbruch; Komma = Dezimalzeichen.
enum NumberList {
    static func parse(_ text: String) -> [Double]? {
        let separators = CharacterSet(charactersIn: " ;\n\t")
        let parts = text.components(separatedBy: separators).filter { !$0.isEmpty }
        var result: [Double] = []
        for part in parts {
            let normalized = part.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "−", with: "-")
            guard let value = Double(normalized), value.isFinite else { return nil }
            result.append(value)
        }
        return result
    }
}
