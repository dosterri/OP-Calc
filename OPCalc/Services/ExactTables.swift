import Foundation

/// Exakte Werte für Winkelfunktionen und Logarithmen.
///
/// Winkel werden als Vielfache von 15° (= π/12) erkannt; für diese sind sin/cos/tan
/// exakt mit Wurzeln darstellbar, z. B. sin(15°) = (√6 − √2)/4.
enum ExactTables {
    /// sin(k · 15°) für k = 0 … 6
    private static let sineTable: [ExactValue] = [
        .zero,
        ExactValue.radical(6, coefficient: Rational(1, 4)) - ExactValue.radical(2, coefficient: Rational(1, 4)),
        ExactValue(Rational(1, 2)),
        ExactValue.radical(2, coefficient: Rational(1, 2)),
        ExactValue.radical(3, coefficient: Rational(1, 2)),
        ExactValue.radical(6, coefficient: Rational(1, 4)) + ExactValue.radical(2, coefficient: Rational(1, 4)),
        .one,
    ]

    /// Winkel als Anzahl von 15°-Schritten, falls der Wert ein solches Vielfaches ist.
    static func fifteenDegreeSteps(of value: ExactValue, mode: AngleMode) -> Int? {
        if value.isZero { return 0 }
        let steps: Rational
        switch mode {
        case .degrees:
            guard let degrees = value.rationalValue else { return nil }
            steps = degrees * Rational(1, 15)
        case .radians:
            guard let term = value.singleTerm, term.monomial == .pi else { return nil }
            steps = term.coefficient * 12
        }
        guard steps.isInteger else { return nil }
        return steps.numerator.asInt
    }

    static func sine(steps k: Int) -> ExactValue {
        let n = ((k % 24) + 24) % 24
        if n >= 12 { return -sine(steps: n - 12) }   // sin(θ + 180°) = −sin θ
        return sineTable[n <= 6 ? n : 12 - n]        // sin(180° − θ) = sin θ
    }

    static func cosine(steps k: Int) -> ExactValue {
        sine(steps: k % 24 + 6)                       // cos θ = sin(θ + 90°)
    }

    static func tangent(steps k: Int) throws -> ExactValue {
        let cos = cosine(steps: k)
        if cos.isZero { throw MathError.domain("tan ist bei ±90° nicht definiert") }
        return try ExactValue.multiply(sine(steps: k), cos.reciprocal())
    }

    static func value(of function: MathFunction, steps k: Int) throws -> ExactValue {
        switch function {
        case .sin: return sine(steps: k)
        case .cos: return cosine(steps: k)
        case .tan: return try tangent(steps: k)
        default: throw MathError.notExact
        }
    }

    /// Umkehrfunktionen: sucht den Tabellenwinkel im Hauptwertebereich.
    static func inverseSteps(of function: MathFunction, value: ExactValue) -> Int? {
        let range: ClosedRange<Int>
        let base: MathFunction
        switch function {
        case .asin:
            range = -6...6
            base = .sin
        case .acos:
            range = 0...12
            base = .cos
        case .atan:
            range = -5...5
            base = .tan
        default:
            return nil
        }
        for k in range {
            if let candidate = try? self.value(of: base, steps: k), candidate == value { return k }
        }
        return nil
    }

    /// k · 15° im gewählten Winkelmaß: Grad → 15k, Bogenmaß → kπ/12.
    static func angle(steps k: Int, mode: AngleMode) -> ExactValue {
        switch mode {
        case .degrees: return ExactValue(Rational(15 * k))
        case .radians: return ExactValue(terms: [.pi: Rational(BigInt(k), 12)])
        }
    }

    /// ln(1) = 0, ln(e^n) = n
    static func naturalLog(of value: ExactValue) -> ExactValue? {
        if value == .one { return .zero }
        guard let term = value.singleTerm,
              term.coefficient == .one,
              term.monomial.radicand == 1,
              term.monomial.piExponent == 0 else { return nil }
        return ExactValue(Rational(term.monomial.eExponent))
    }

    /// log(10^n) = n (auch für negative n, z. B. log(0,01) = −2)
    static func decimalLog(of value: ExactValue) -> ExactValue? {
        guard let r = value.rationalValue, !r.isNegative, !r.isZero else { return nil }
        if r.denominator == 1, let n = powerOfTen(r.numerator) { return ExactValue(Rational(n)) }
        if r.numerator == 1, let n = powerOfTen(r.denominator) { return ExactValue(Rational(-n)) }
        return nil
    }

    private static func powerOfTen(_ value: BigInt) -> Int? {
        let text = value.description
        guard text.first == "1", text.dropFirst().allSatisfy({ $0 == "0" }) else { return nil }
        return text.count - 1
    }
}
