import Foundation

/// Kombinatorik und Wahrscheinlichkeitsverteilungen (AK-04).
enum Combinatorics {
    /// Größtes n, für das nCr und nPr exakt mit BigInt gerechnet werden.
    /// Darüber werden die Zahlen so lang, dass Anzeige und Rechenzeit leiden.
    static let maxExactN = 5_000

    static func binomial(_ n: Int, _ k: Int) -> BigInt? {
        guard n >= 0, n <= maxExactN else { return nil }
        guard k >= 0, k <= n else { return 0 }
        let r = min(k, n - k)
        var result = BigInt(1)
        if r == 0 { return result }
        for i in 1...r {
            result = result * BigInt(n - r + i) / BigInt(i)
        }
        return result
    }

    static func permutations(_ n: Int, _ k: Int) -> BigInt? {
        guard n >= 0, n <= maxExactN else { return nil }
        guard k >= 0, k <= n else { return 0 }
        var result = BigInt(1)
        var i = n - k + 1
        while i <= n { result = result * BigInt(i); i += 1 }
        return result
    }

    /// ln(n über k) für große n
    static func logBinomial(_ n: Double, _ k: Double) -> Double {
        lgamma(n + 1) - lgamma(k + 1) - lgamma(n - k + 1)
    }
}

/// Eine diskrete Verteilung mit ganzzahligen Werten.
protocol DiscreteDistribution {
    var support: ClosedRange<Int> { get }
    var mean: Double { get }
    var variance: Double { get }
    func probability(_ k: Int) -> Value
}

extension DiscreteDistribution {
    var standardDeviation: Double { variance.squareRoot() }

    /// P(a ≤ X ≤ b), exakt, wenn alle Einzelwahrscheinlichkeiten exakt sind.
    func probability(from a: Int, to b: Int) -> Value {
        var lower = max(a, support.lowerBound)
        var upper = min(b, support.upperBound)
        // Sehr viele Summanden (Poisson mit großem λ): außerhalb von μ ± 40σ ist die Masse < 10⁻³⁰⁰
        if upper - lower > Self.maxTerms / 50 {
            let sigma = standardDeviation
            if mean.isFinite, sigma.isFinite {
                lower = max(lower, Self.clampedInt(mean - 40 * sigma - 1))
                upper = min(upper, Self.clampedInt(mean + 40 * sigma + 1))
            }
        }
        upper = min(upper, lower + Self.maxTerms)
        guard lower <= upper else { return .exact(.zero) }
        var exact: Rational? = .zero
        var approximate = 0.0
        for k in lower...upper {
            let p = probability(k)
            approximate += p.doubleValue
            if case .exact(let v) = p, let r = v.rationalValue, let sum = exact {
                exact = sum + r
                // Brüche mit zehntausenden Stellen bringen nichts mehr
                if exact?.bitSize ?? 0 > 60_000 { exact = nil }
            } else {
                exact = nil
            }
        }
        if let exact { return .exact(ExactValue(exact)) }
        return .approximate(min(1, max(0, approximate)))
    }

    /// Obergrenze der Summanden – reicht für alle Verteilungen mit n ≤ 10⁶ im relevanten Bereich.
    static var maxTerms: Int { 1_000_000 }

    /// Bereich, in dem praktisch die ganze Wahrscheinlichkeit liegt (für Diagramme).
    var displayRange: ClosedRange<Int> {
        let spread = max(3, 4 * standardDeviation)
        // Erst als Double begrenzen: Int(±∞) oder Int(nan) würde abstürzen
        let lowerValue = (mean - spread).isFinite ? max(Double(support.lowerBound), (mean - spread).rounded(.down)) : Double(support.lowerBound)
        let upperValue = (mean + spread).isFinite ? min(Double(support.upperBound), (mean + spread).rounded(.up)) : Double(support.upperBound)
        let lower = Self.clampedInt(lowerValue)
        let upper = Self.clampedInt(upperValue)
        return lower...max(lower, upper)
    }

    /// Double → Int ohne Absturz (nan → 0, außerhalb des Bereichs → ±10¹²).
    static func clampedInt(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(min(max(value, -1e12), 1e12))
    }
}

/// Binomialverteilung B(n; p)
struct BinomialDistribution: DiscreteDistribution {
    let n: Int
    let p: Value

    var support: ClosedRange<Int> { 0...n }
    var mean: Double { Double(n) * p.doubleValue }
    var variance: Double { Double(n) * p.doubleValue * (1 - p.doubleValue) }

    /// Bis zu diesem n exakt mit Brüchen (Grenze M-C10: darüber werden die Brüche riesig).
    static let maxExactN = 200

    func probability(_ k: Int) -> Value {
        guard k >= 0, k <= n else { return .exact(.zero) }
        if n <= Self.maxExactN, case .exact(let v) = p, let q = v.rationalValue,
           let c = Combinatorics.binomial(n, k),
           let pk = try? q.power(k), let rest = try? (Rational.one - q).power(n - k) {
            return .exact(ExactValue(Rational(c) * pk * rest))
        }
        let pd = p.doubleValue
        if pd == 0 { return .approximate(k == 0 ? 1 : 0) }
        if pd == 1 { return .approximate(k == n ? 1 : 0) }
        let logValue = Combinatorics.logBinomial(Double(n), Double(k)) + Double(k) * log(pd) + Double(n - k) * log1p(-pd)
        return .approximate(exp(logValue))
    }
}

/// Hypergeometrische Verteilung: Ziehen ohne Zurücklegen, N Kugeln, davon M Treffer, n Züge.
struct HypergeometricDistribution: DiscreteDistribution {
    let populationSize: Int
    let successes: Int
    let draws: Int

    var support: ClosedRange<Int> {
        let lower = max(0, draws - (populationSize - successes)), upper = min(draws, successes)
        return lower <= upper ? lower...upper : 0...0
    }

    /// Bis zu dieser Grundgesamtheit exakt; darüber werden die Binomialkoeffizienten zu teuer.
    static let maxExactPopulation = 1_000
    var mean: Double { Double(draws) * Double(successes) / Double(populationSize) }
    var variance: Double {
        let N = Double(populationSize), M = Double(successes), n = Double(draws)
        guard N > 1 else { return 0 }
        return n * (M / N) * (1 - M / N) * (N - n) / (N - 1)
    }

    func probability(_ k: Int) -> Value {
        guard support.contains(k), populationSize > 0 else { return .exact(.zero) }
        if populationSize <= Self.maxExactPopulation, let a = Combinatorics.binomial(successes, k),
           let b = Combinatorics.binomial(populationSize - successes, draws - k),
           let c = Combinatorics.binomial(populationSize, draws), !c.isZero {
            return .exact(ExactValue(Rational(a * b, c)))
        }
        let logValue = Combinatorics.logBinomial(Double(successes), Double(k))
            + Combinatorics.logBinomial(Double(populationSize - successes), Double(draws - k))
            - Combinatorics.logBinomial(Double(populationSize), Double(draws))
        return .approximate(exp(logValue))
    }
}

/// Poisson-Verteilung mit Parameter λ
struct PoissonDistribution: DiscreteDistribution {
    let lambda: Double

    /// Nach oben offen; für Summen reicht λ + 40·√λ + 40 (Rest < 10⁻³⁰⁰).
    var support: ClosedRange<Int> {
        guard lambda.isFinite, lambda >= 0 else { return 0...0 }
        return 0...Int(min(lambda + 40 * lambda.squareRoot() + 40, 1e9))
    }
    var mean: Double { lambda }
    var variance: Double { lambda }

    func probability(_ k: Int) -> Value {
        guard k >= 0 else { return .exact(.zero) }
        if lambda == 0 { return .approximate(k == 0 ? 1 : 0) }
        return .approximate(exp(Double(k) * log(lambda) - lambda - lgamma(Double(k) + 1)))
    }
}

/// Geometrische Verteilung: Anzahl der Versuche bis zum ersten Treffer (k ≥ 1).
struct GeometricDistribution: DiscreteDistribution {
    let p: Value

    var support: ClosedRange<Int> {
        let pd = p.doubleValue
        guard pd > 0, pd < 1 else { return 1...1 }
        // Rest (1−p)^k unter 10⁻¹⁶ ist für die Anzeige bedeutungslos
        let bound = (log(1e-16) / log1p(-pd)).rounded(.up)
        let upper = bound.isFinite ? Int(min(1_000_000, max(1, bound))) : 1_000_000
        return 1...upper
    }
    var mean: Double { 1 / p.doubleValue }
    var variance: Double { (1 - p.doubleValue) / (p.doubleValue * p.doubleValue) }

    func probability(_ k: Int) -> Value {
        guard k >= 1 else { return .exact(.zero) }
        // Exakt nur für kleine k: (1−p)^(k−1) wächst sonst auf zehntausende Stellen
        if k <= 200, case .exact(let v) = p, let q = v.rationalValue, q.bitSize <= 64,
           let rest = try? (Rational.one - q).power(k - 1) {
            return .exact(ExactValue(rest * q))
        }
        let pd = p.doubleValue
        return .approximate(exp(Double(k - 1) * log1p(-pd)) * pd)
    }
}

/// Normalverteilung N(μ; σ)
struct NormalDistribution {
    let mean: Double
    let standardDeviation: Double

    func density(_ x: Double) -> Double {
        let z = (x - mean) / standardDeviation
        return exp(-z * z / 2) / (standardDeviation * (2 * Double.pi).squareRoot())
    }

    /// P(X ≤ x)
    func cumulative(_ x: Double) -> Double {
        if x == .infinity { return 1 }
        if x == -.infinity { return 0 }
        return 0.5 * erfc(-(x - mean) / (standardDeviation * 2.0.squareRoot()))
    }

    /// x mit P(X ≤ x) = p (Quantil)
    func quantile(_ p: Double) -> Double? {
        guard p > 0, p < 1 else { return nil }
        return mean + standardDeviation * Self.standardQuantile(p)
    }

    /// Quantil der Standardnormalverteilung: Näherung nach Acklam, danach ein Halley-Schritt
    /// (Genauigkeit dann etwa 1e−15).
    static func standardQuantile(_ p: Double) -> Double {
        let a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
                 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
        let b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
                 6.680131188771972e+01, -1.328068155288572e+01]
        let c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
                 -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
        let d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00]
        let low = 0.02425
        var x: Double
        if p < low {
            let q = (-2 * log(p)).squareRoot()
            x = (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
                / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        } else if p <= 1 - low {
            let q = p - 0.5, r = q * q
            x = (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q
                / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
        } else {
            let q = (-2 * log1p(-p)).squareRoot()
            x = -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
                / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }
        let e = 0.5 * erfc(-x / 2.0.squareRoot()) - p
        let u = e * (2 * Double.pi).squareRoot() * exp(x * x / 2)
        x -= u / (1 + x * u / 2)
        return x
    }
}
