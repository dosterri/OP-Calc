import Foundation

/// Basis eines exakten Terms: √radicand · π^piExponent · e^eExponent.
/// Der Radikand ist immer quadratfrei (z. B. 2, 3, 6 – nie 4 oder 12).
struct Monomial: Hashable, Codable, Sendable {
    var radicand: Int
    var piExponent: Int
    var eExponent: Int

    static let one = Monomial(radicand: 1, piExponent: 0, eExponent: 0)
    static let pi = Monomial(radicand: 1, piExponent: 1, eExponent: 0)
    static let e = Monomial(radicand: 1, piExponent: 0, eExponent: 1)

    /// Produkt zweier Basen. √a·√b = g·√(a'b') mit g = ggT(a, b) – das Ergebnis bleibt quadratfrei.
    func times(_ other: Monomial) throws -> (factor: Int, monomial: Monomial) {
        let g = integerGCD(radicand, other.radicand)
        let (product, overflow) = (radicand / g).multipliedReportingOverflow(by: other.radicand / g)
        // Exponenten mit Überlaufprüfung addieren – „+“ würde bei Überlauf abstürzen.
        let (piSum, piOverflow) = piExponent.addingReportingOverflow(other.piExponent)
        let (eSum, eOverflow) = eExponent.addingReportingOverflow(other.eExponent)
        if overflow || piOverflow || eOverflow { throw MathError.notExact }
        return (g, Monomial(radicand: product, piExponent: piSum, eExponent: eSum))
    }

    var doubleValue: Double {
        Double(radicand).squareRoot() * pow(Double.pi, Double(piExponent)) * exp(Double(eExponent))
    }
}

extension Monomial: Comparable {
    /// Reihenfolge für die Anzeige: erst reine Zahlen und Wurzeln, dann e-, dann π-Potenzen.
    static func < (lhs: Monomial, rhs: Monomial) -> Bool {
        (lhs.piExponent, lhs.eExponent, lhs.radicand) < (rhs.piExponent, rhs.eExponent, rhs.radicand)
    }
}

/// Exakter Wert als Summe von Termen „Bruch · √n · π^i · e^j“.
///
/// Damit bleiben z. B. 13/12, 2√3, 5π/6 oder (√6 − √2)/4 exakt, bis „≈“ gedrückt wird.
/// Die Darstellung ist kanonisch (gleiche Werte ⇔ gleiche Terme), solange man – wie
/// allgemein angenommen – π und e als algebraisch unabhängig betrachtet.
struct ExactValue: Hashable, Codable, Sendable {
    /// Koeffizient je Basis; enthält nie Einträge mit Koeffizient 0.
    private(set) var terms: [Monomial: Rational]

    init(terms: [Monomial: Rational]) {
        self.terms = terms.filter { !$0.value.isZero }
    }

    init(_ value: Rational) {
        terms = value.isZero ? [:] : [.one: value]
    }

    /// c · √n für quadratfreies n (Hilfsfunktion für Tabellen und Tests).
    static func radical(_ n: Int, coefficient: Rational = .one) -> ExactValue {
        ExactValue(terms: [Monomial(radicand: n, piExponent: 0, eExponent: 0): coefficient])
    }

    static let zero = ExactValue(terms: [:])
    static let one = ExactValue(Rational.one)
    static let pi = ExactValue(terms: [.pi: .one])
    static let e = ExactValue(terms: [.e: .one])

    // MARK: - Eigenschaften

    var isZero: Bool { terms.isEmpty }

    /// Der Wert als Bruch, falls er rational ist.
    var rationalValue: Rational? {
        if terms.isEmpty { return .zero }
        if terms.count == 1, let c = terms[.one] { return c }
        return nil
    }

    /// Einziger Term, falls der Wert aus genau einem Term besteht.
    var singleTerm: (monomial: Monomial, coefficient: Rational)? {
        guard terms.count == 1, let first = terms.first else { return nil }
        return (monomial: first.key, coefficient: first.value)
    }

    /// Terme in Anzeigereihenfolge.
    var sortedTerms: [(monomial: Monomial, coefficient: Rational)] {
        terms.sorted { $0.key < $1.key }.map { (monomial: $0.key, coefficient: $0.value) }
    }

    var bitSize: Int { terms.values.reduce(0) { $0 + $1.bitSize } }

    var doubleValue: Double {
        terms.reduce(0.0) { sum, term in sum + term.value.doubleValue * term.key.doubleValue }
    }

    // MARK: - Addition und Multiplikation

    static func + (lhs: ExactValue, rhs: ExactValue) -> ExactValue {
        var result = lhs.terms
        for (monomial, coefficient) in rhs.terms {
            let sum = (result[monomial] ?? .zero) + coefficient
            result[monomial] = sum.isZero ? nil : sum
        }
        return ExactValue(terms: result)
    }

    static prefix func - (value: ExactValue) -> ExactValue {
        ExactValue(terms: value.terms.mapValues { -$0 })
    }

    static func - (lhs: ExactValue, rhs: ExactValue) -> ExactValue {
        lhs + (-rhs)
    }

    static func multiply(_ lhs: ExactValue, _ rhs: ExactValue) throws -> ExactValue {
        var result: [Monomial: Rational] = [:]
        for (m1, c1) in lhs.terms {
            for (m2, c2) in rhs.terms {
                let (factor, monomial) = try m1.times(m2)
                let product = c1 * c2 * Rational(factor)
                let sum = (result[monomial] ?? .zero) + product
                result[monomial] = sum.isZero ? nil : sum
            }
        }
        return ExactValue(terms: result)
    }

    // MARK: - Kehrwert, Potenzen, Wurzeln

    /// Kehrwert. Einzelne Terme immer; Summen aus zwei Termen über die „dritte binomische Formel“
    /// (z. B. 1/(1+√2) = √2 − 1). Alles andere ist nicht exakt darstellbar.
    func reciprocal() throws -> ExactValue {
        if isZero { throw MathError.divisionByZero }
        if let term = singleTerm {
            // 1/(c·√n·π^i·e^j) = 1/(c·n) · √n · π^−i · e^−j
            let m = term.monomial
            let inverse = try (term.coefficient * Rational(m.radicand)).reciprocal()
            let monomial = Monomial(radicand: m.radicand, piExponent: -m.piExponent, eExponent: -m.eExponent)
            return ExactValue(terms: [monomial: inverse])
        }
        if terms.count == 2 {
            let sorted = sortedTerms
            let a = ExactValue(terms: [sorted[0].monomial: sorted[0].coefficient])
            let b = ExactValue(terms: [sorted[1].monomial: sorted[1].coefficient])
            let conjugate = a - b
            let denominator = try ExactValue.multiply(self, conjugate)   // = a² − b²
            if denominator.terms.count == 1 {
                return try ExactValue.multiply(conjugate, denominator.reciprocal())
            }
        }
        throw MathError.notExact
    }

    /// Ganzzahlige Potenz.
    func power(_ n: Int) throws -> ExactValue {
        if n == Int.min { throw MathError.tooLarge }
        if let r = rationalValue { return ExactValue(try r.power(n)) }
        if n == 0 { return .one }
        if n < 0 { return try reciprocal().power(-n) }

        if let term = singleTerm {
            // (c·√r·π^i·e^j)^n = c^n · r^(n/2) · (√r bei ungeradem n) · π^(i·n) · e^(j·n)
            guard n <= 100_000 else { throw MathError.tooLarge }
            let m = term.monomial
            let coefficient = try term.coefficient.power(n) * Rational(m.radicand).power(n / 2)
            // Verschachtelte Potenzen wie ((π^100000)^100000)^… würden „*“ überlaufen lassen (Absturz).
            let (piExponent, piOverflow) = m.piExponent.multipliedReportingOverflow(by: n)
            let (eExponent, eOverflow) = m.eExponent.multipliedReportingOverflow(by: n)
            if piOverflow || eOverflow { throw MathError.tooLarge }
            let monomial = Monomial(radicand: n % 2 == 1 ? m.radicand : 1,
                                    piExponent: piExponent,
                                    eExponent: eExponent)
            return ExactValue(terms: [monomial: coefficient])
        }

        // Summen nur für kleine Exponenten ausmultiplizieren.
        guard n <= 64 else { throw MathError.notExact }
        var result = ExactValue.one
        var base = self
        var e = n
        while e > 0 {
            if e & 1 == 1 { result = try .multiply(result, base) }
            e >>= 1
            if e > 0 { base = try .multiply(base, base) }
        }
        return result
    }

    /// Rationale Potenz x^(p/q) = (q-te Wurzel von x)^p.
    func power(_ exponent: Rational) throws -> ExactValue {
        guard let p = exponent.numerator.asInt, let q = exponent.denominator.asInt else {
            throw MathError.notExact
        }
        if q == 1 { return try power(p) }
        return try root(q).power(p)
    }

    /// Quadratwurzel: √12 = 2√3, √(3/4) = √3/2, √(π²) = π.
    func squareRoot() throws -> ExactValue {
        if isZero { return .zero }
        if let term = singleTerm,
           term.monomial.radicand == 1,
           term.monomial.piExponent % 2 == 0,
           term.monomial.eExponent % 2 == 0 {
            let c = term.coefficient
            if c.isNegative { throw MathError.notReal }
            // √(p/q) = √(p·q) / q
            guard let parts = squareFreeParts(c.numerator * c.denominator) else { throw MathError.notExact }
            let monomial = Monomial(radicand: parts.inside,
                                    piExponent: term.monomial.piExponent / 2,
                                    eExponent: term.monomial.eExponent / 2)
            return ExactValue(terms: [monomial: Rational(parts.outside, c.denominator)])
        }
        if doubleValue < 0 { throw MathError.notReal }
        throw MathError.notExact
    }

    /// k-te Wurzel (reell; bei ungeradem k auch für negative Werte).
    func root(_ k: Int) throws -> ExactValue {
        guard k >= 1 else { throw MathError.undefined("Ungültiger Wurzelexponent") }
        if k == 1 || isZero { return self }
        if k == 2 { return try squareRoot() }
        guard k <= 4_096,
              let term = singleTerm,
              term.monomial.radicand == 1,
              term.monomial.piExponent % k == 0,
              term.monomial.eExponent % k == 0 else {
            if k % 2 == 0 && doubleValue < 0 { throw MathError.notReal }
            throw MathError.notExact
        }
        if term.coefficient.isNegative && k % 2 == 0 { throw MathError.notReal }
        guard let coefficient = term.coefficient.exactRoot(k) else { throw MathError.notExact }
        let monomial = Monomial(radicand: 1,
                                piExponent: term.monomial.piExponent / k,
                                eExponent: term.monomial.eExponent / k)
        return ExactValue(terms: [monomial: coefficient])
    }
}

// MARK: - Zahlentheoretische Hilfsfunktionen

func integerGCD(_ a: Int, _ b: Int) -> Int {
    var x = a.magnitude
    var y = b.magnitude
    while y != 0 { (x, y) = (y, x % y) }
    return Int(x)
}

/// Zerlegt n ≥ 0 in outside² · inside mit quadratfreiem inside.
/// Für sehr große Zahlen nur, wenn n ein perfektes Quadrat ist (sonst nil → nicht exakt).
func squareFreeParts(_ n: BigInt) -> (outside: BigInt, inside: Int)? {
    if n.isNegative { return nil }
    if let root = n.exactRoot(2) { return (root, 1) }
    // Probedivision bis 10^6 – schnell genug für Radikanden bis 10^12.
    guard let value = n.asInt, value <= 1_000_000_000_000 else { return nil }
    var rest = value
    var outside = 1
    var inside = 1
    var factor = 2
    while factor * factor <= rest {
        var count = 0
        while rest % factor == 0 {
            rest /= factor
            count += 1
        }
        for _ in 0..<(count / 2) { outside *= factor }
        if count % 2 == 1 { inside *= factor }
        factor += factor == 2 ? 1 : 2
    }
    inside *= rest
    return (BigInt(outside), inside)
}
