import Foundation

/// Grenzen, die den Rechner vor „unendlich langen“ Rechnungen schützen (z. B. 9^9^9).
enum MathLimits {
    /// Maximale Größe exakter Zahlen in Bit (≈ 12 000 Dezimalstellen).
    static let maxBits = 40_000
    /// Größtes n, für das n! exakt berechnet wird.
    static let maxFactorial = 3_000
}

/// Exakter Bruch aus zwei beliebig großen Ganzzahlen.
/// Invarianten: immer gekürzt, Nenner > 0, Null wird als 0/1 gespeichert.
struct Rational: Hashable, Codable, Sendable {
    let numerator: BigInt
    let denominator: BigInt

    /// Erzeugt einen gekürzten Bruch. Der Nenner darf nicht null sein (vorher prüfen!).
    init(_ numerator: BigInt, _ denominator: BigInt) {
        precondition(!denominator.isZero, "Nenner null")
        var n = numerator
        var d = denominator
        if d.isNegative {
            n = -n
            d = -d
        }
        let divisor = BigInt.gcd(n, d)
        if divisor != 1 && !divisor.isZero {
            n = n / divisor
            d = d / divisor
        }
        self.numerator = n
        self.denominator = d
    }

    init(_ value: BigInt) {
        numerator = value
        denominator = 1
    }

    init(_ value: Int) {
        self.init(BigInt(value))
    }

    /// Ohne Kürzen – nur verwenden, wenn Zähler und Nenner bereits teilerfremd sind und d > 0.
    private init(alreadyReduced numerator: BigInt, _ denominator: BigInt) {
        self.numerator = numerator
        self.denominator = denominator
    }

    /// Liest eine Dezimalzahl mit Punkt als Trennzeichen ("12.5", ".5", "3.") exakt ein: 12.5 → 25/2.
    init?(decimal text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        let integerPart = String(parts[0])
        let fractionPart = parts.count == 2 ? String(parts[1]) : ""
        guard !(integerPart.isEmpty && fractionPart.isEmpty) else { return nil }
        guard let digits = BigInt((integerPart.isEmpty ? "0" : integerPart) + fractionPart),
              !digits.isNegative else { return nil }
        self.init(digits, BigInt(10).power(fractionPart.count))
    }

    static let zero = Rational(0)
    static let one = Rational(1)

    // MARK: - Eigenschaften

    var isZero: Bool { numerator.isZero }
    var isNegative: Bool { numerator.isNegative }
    var isInteger: Bool { denominator == 1 }
    var absoluteValue: Rational { Rational(alreadyReduced: numerator.absoluteValue, denominator) }

    /// Größe in Bit – Maß für den Speicher-/Rechenaufwand.
    var bitSize: Int { numerator.bitWidth + denominator.bitWidth }

    var doubleValue: Double {
        let (mn, en) = numerator.approximation()
        let (md, ed) = denominator.approximation()
        return (mn / md) * pow(2.0, Double(en - ed))
    }

    // MARK: - Rechenoperationen

    static func + (lhs: Rational, rhs: Rational) -> Rational {
        if lhs.denominator == rhs.denominator {
            return Rational(lhs.numerator + rhs.numerator, lhs.denominator)
        }
        return Rational(lhs.numerator * rhs.denominator + rhs.numerator * lhs.denominator,
                        lhs.denominator * rhs.denominator)
    }

    static prefix func - (value: Rational) -> Rational {
        Rational(alreadyReduced: -value.numerator, value.denominator)
    }

    static func - (lhs: Rational, rhs: Rational) -> Rational {
        lhs + (-rhs)
    }

    static func * (lhs: Rational, rhs: Rational) -> Rational {
        Rational(lhs.numerator * rhs.numerator, lhs.denominator * rhs.denominator)
    }

    func divided(by other: Rational) throws -> Rational {
        guard !other.isZero else { throw MathError.divisionByZero }
        return Rational(numerator * other.denominator, denominator * other.numerator)
    }

    func reciprocal() throws -> Rational {
        guard !isZero else { throw MathError.divisionByZero }
        return Rational(denominator, numerator)
    }

    /// Ganzzahlige Potenz, auch negativ: (2/3)^−2 = 9/4.
    func power(_ exponent: Int) throws -> Rational {
        if exponent == Int.min { throw MathError.tooLarge }
        if exponent == 0 {
            if isZero { throw MathError.undefined("0⁰ ist nicht definiert") }
            return .one
        }
        if exponent < 0 {
            return try reciprocal().power(-exponent)
        }
        // Vorab abschätzen, ob das Ergebnis zu groß würde (Basis ±1 und 0 sind immer harmlos).
        let bits = max(numerator.bitWidth, denominator.bitWidth)
        if bits > 1 {
            let (estimate, overflow) = bits.multipliedReportingOverflow(by: exponent)
            if overflow || estimate > MathLimits.maxBits { throw MathError.tooLarge }
        }
        // Potenzen teilerfremder Zahlen sind wieder teilerfremd → kein Kürzen nötig.
        return Rational(alreadyReduced: numerator.power(exponent), denominator.power(exponent))
    }

    /// Exakte k-te Wurzel, falls Zähler und Nenner perfekte k-te Potenzen sind (negativ nur bei ungeradem k).
    func exactRoot(_ k: Int) -> Rational? {
        if isNegative {
            guard k % 2 == 1, let root = absoluteValue.exactRoot(k) else { return nil }
            return -root
        }
        guard let n = numerator.exactRoot(k), let d = denominator.exactRoot(k) else { return nil }
        return Rational(alreadyReduced: n, d)
    }
}

extension Rational: Comparable {
    static func < (lhs: Rational, rhs: Rational) -> Bool {
        lhs.numerator * rhs.denominator < rhs.numerator * lhs.denominator
    }
}

extension Rational: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension Rational: CustomStringConvertible {
    var description: String {
        isInteger ? numerator.description : "\(numerator)/\(denominator)"
    }
}
