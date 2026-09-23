import Foundation

/// Wertet den Mathe-AST aus.
///
/// Grundsatz: Es wird exakt gerechnet, solange das Ergebnis als ExactValue darstellbar ist.
/// Erst wenn das nicht geht (z. B. sin(1), 2^π) oder das exakte Ergebnis zu groß würde,
/// wird mit Double genähert – das Ergebnis ist dann als Näherung (≈) gekennzeichnet.
/// Echte Fehler (Division durch null, nicht reell …) werden nie „weggenähert“.
struct Evaluator {
    var angleMode: AngleMode = .radians
    var ans: Value?

    init(angleMode: AngleMode = .radians, ans: Value? = nil) {
        self.angleMode = angleMode
        self.ans = ans
    }

    func evaluate(_ expression: Expr) throws -> Value {
        try eval(expression)
    }

    // MARK: - Rekursive Auswertung

    private func eval(_ expression: Expr) throws -> Value {
        switch expression {
        case .number(let r):
            return .exact(ExactValue(r))
        case .constant(let c):
            return .exact(c == .pi ? .pi : .e)
        case .variable(let name):
            throw MathError.undefined("Variable „\(name)“ ist nicht definiert")
        case .ans:
            guard let ans else { throw MathError.missingAns }
            return ans
        case .negate(let x):
            switch try eval(x) {
            case .exact(let v): return .exact(-v)
            case .approximate(let d): return .approximate(-d)
            }
        case .add(let a, let b):
            return try combine(eval(a), eval(b), exact: { $0 + $1 }, approximate: { $0 + $1 })
        case .subtract(let a, let b):
            return try combine(eval(a), eval(b), exact: { $0 - $1 }, approximate: { $0 - $1 })
        case .multiply(let a, let b):
            return try combine(eval(a), eval(b), exact: { try .multiply($0, $1) }, approximate: { $0 * $1 })
        case .divide(let a, let b):
            let dividend = try eval(a)
            let divisor = try eval(b)
            if divisor.isZero { throw MathError.divisionByZero }
            return try combine(dividend, divisor,
                               exact: { try .multiply($0, $1.reciprocal()) },
                               approximate: { $0 / $1 })
        case .power(let a, let b):
            return try power(eval(a), eval(b))
        case .root(let degree, let radicand):
            // n-te Wurzel = Potenz mit Exponent 1/n
            let n = try eval(degree)
            if n.isZero { throw MathError.domain("Wurzelexponent darf nicht 0 sein") }
            let exponent = try combine(.exact(.one), n,
                                       exact: { try .multiply($0, $1.reciprocal()) },
                                       approximate: { $0 / $1 })
            return try power(eval(radicand), exponent)
        case .function(let f, let argument):
            return try apply(f, to: eval(argument))
        case .absolute(let x):
            switch try eval(x) {
            case .exact(let v): return .exact(v.doubleValue < 0 ? -v : v)
            case .approximate(let d): return .approximate(Swift.abs(d))
            }
        case .factorial(let x):
            return try factorial(eval(x))
        }
    }

    // MARK: - Exakt rechnen, notfalls nähern

    private func combine(_ a: Value, _ b: Value,
                         exact: (ExactValue, ExactValue) throws -> ExactValue,
                         approximate: (Double, Double) -> Double) throws -> Value {
        if case .exact(let x) = a, case .exact(let y) = b {
            do {
                return try checkedExact(exact(x, y))
            } catch MathError.notExact {
                // weiter mit Näherung
            } catch MathError.tooLarge {
                // weiter mit Näherung
            }
        }
        return try checkedApproximation(approximate(a.doubleValue, b.doubleValue))
    }

    private func checkedExact(_ value: ExactValue) throws -> Value {
        if value.bitSize > MathLimits.maxBits { throw MathError.tooLarge }
        return .exact(value)
    }

    private func checkedApproximation(_ value: Double) throws -> Value {
        if value.isNaN { throw MathError.undefined("Ergebnis ist nicht definiert") }
        if value.isInfinite { throw MathError.overflow }
        return .approximate(value)
    }

    // MARK: - Potenzen

    private func power(_ base: Value, _ exponent: Value) throws -> Value {
        var rationalExponent: Rational?
        if case .exact(let x) = exponent { rationalExponent = x.rationalValue }

        if case .exact(let b) = base, let r = rationalExponent {
            if b.isZero {
                if r.isZero { throw MathError.undefined("0⁰ ist nicht definiert") }
                if r.isNegative { throw MathError.divisionByZero }
                return .exact(.zero)
            }
            do {
                return try checkedExact(b.power(r))
            } catch MathError.notExact {
                // weiter mit Näherung
            } catch MathError.tooLarge {
                // weiter mit Näherung
            }
        }

        let b = base.doubleValue
        let x = exponent.doubleValue
        if b == 0 {
            if x == 0 { throw MathError.undefined("0⁰ ist nicht definiert") }
            if x < 0 { throw MathError.divisionByZero }
        }
        guard b < 0 else { return try checkedApproximation(pow(b, x)) }

        // Negative Basis ist nur reell, wenn der Exponent einen ungeraden Nenner hat,
        // z. B. (−8)^(1/3) = −2 oder (−2)^3 = −8.
        let oddNumerator: Bool
        if let r = rationalExponent {
            guard r.denominator.isOdd else { throw MathError.notReal }
            oddNumerator = r.numerator.isOdd
        } else {
            guard x == x.rounded() else { throw MathError.notReal }
            oddNumerator = x.truncatingRemainder(dividingBy: 2) != 0
        }
        let magnitude = pow(-b, x)
        return try checkedApproximation(oddNumerator ? -magnitude : magnitude)
    }

    // MARK: - Funktionen

    private func apply(_ function: MathFunction, to argument: Value) throws -> Value {
        switch function {
        case .sin, .cos, .tan:
            if case .exact(let v) = argument, let k = ExactTables.fifteenDegreeSteps(of: v, mode: angleMode) {
                return .exact(try ExactTables.value(of: function, steps: k))
            }
            let radians = toRadians(argument.doubleValue)
            switch function {
            case .sin: return try checkedApproximation(sin(radians))
            case .cos: return try checkedApproximation(cos(radians))
            default: return try checkedApproximation(tan(radians))
            }

        case .asin, .acos:
            let d = argument.doubleValue
            guard d >= -1 && d <= 1 else {
                throw MathError.domain("\(function.displayName) ist nur für Werte von −1 bis 1 definiert")
            }
            if case .exact(let v) = argument, let k = ExactTables.inverseSteps(of: function, value: v) {
                return .exact(ExactTables.angle(steps: k, mode: angleMode))
            }
            return try checkedApproximation(fromRadians(function == .asin ? asin(d) : acos(d)))

        case .atan:
            if case .exact(let v) = argument, let k = ExactTables.inverseSteps(of: .atan, value: v) {
                return .exact(ExactTables.angle(steps: k, mode: angleMode))
            }
            return try checkedApproximation(fromRadians(atan(argument.doubleValue)))

        case .ln, .log:
            let d = argument.doubleValue
            guard d > 0 else { throw MathError.domain("Logarithmus ist nur für positive Zahlen definiert") }
            if case .exact(let v) = argument {
                let exact = function == .ln ? ExactTables.naturalLog(of: v) : ExactTables.decimalLog(of: v)
                if let exact { return .exact(exact) }
            }
            return try checkedApproximation(function == .ln ? log(d) : log10(d))
        }
    }

    private func toRadians(_ angle: Double) -> Double {
        angleMode == .degrees ? angle * .pi / 180 : angle
    }

    private func fromRadians(_ angle: Double) -> Double {
        angleMode == .degrees ? angle * 180 / .pi : angle
    }

    // MARK: - Fakultät

    private func factorial(_ argument: Value) throws -> Value {
        let n: Int
        switch argument {
        case .exact(let v):
            guard let r = v.rationalValue, r.isInteger, !r.isNegative, let k = r.numerator.asInt else {
                throw MathError.domain("n! ist nur für natürliche Zahlen definiert")
            }
            n = k
        case .approximate(let d):
            guard d >= 0, d == d.rounded(), d <= Double(MathLimits.maxFactorial) else {
                throw MathError.domain("n! ist nur für natürliche Zahlen definiert")
            }
            n = Int(d)
        }
        guard n <= MathLimits.maxFactorial else { throw MathError.overflow }
        var product = BigInt(1)
        if n >= 2 {
            for i in 2...n { product = product * BigInt(i) }
        }
        return .exact(ExactValue(Rational(product)))
    }
}
