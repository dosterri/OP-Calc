import Foundation

/// Belegung der Variablen für die numerische Auswertung.
/// Feste Felder statt Wörterbuch: Graphen werten tausende Male pro Bild aus.
struct VariableValues {
    var x = 0.0
    var y = 0.0
    var t = 0.0
    /// y′ in Differentialgleichungen 2. Ordnung
    var yPrime = 0.0

    static let names: Set<String> = ["x", "y", "t", "y′"]

    func value(of name: String) -> Double {
        switch name {
        case "x": return x
        case "y": return y
        case "t": return t
        case "y′": return yPrime
        default: return .nan
        }
    }
}

/// Schnelle Auswertung eines Ausdrucks mit Double – für Graphen, Löser und Analyse.
/// Kein exaktes Rechnen, keine Fehler: Wo der Ausdruck nicht definiert ist, kommt `nan` heraus.
struct NumericEvaluator {
    var angleMode: AngleMode = .radians
    var ans: Double = .nan

    func value(_ expression: Expr, _ variables: VariableValues = VariableValues()) -> Double {
        switch expression {
        case .number(let r):
            return r.doubleValue
        case .constant(let c):
            return c == .pi ? Double.pi : M_E
        case .variable(let name):
            return variables.value(of: name)
        case .ans:
            return ans
        case .negate(let a):
            return -value(a, variables)
        case .add(let a, let b):
            return value(a, variables) + value(b, variables)
        case .subtract(let a, let b):
            return value(a, variables) - value(b, variables)
        case .multiply(let a, let b):
            return value(a, variables) * value(b, variables)
        case .divide(let a, let b):
            let divisor = value(b, variables)
            return divisor == 0 ? .nan : value(a, variables) / divisor
        case .power(let a, let b):
            return Self.realPower(value(a, variables), value(b, variables), exponent: b)
        case .root(let degree, let radicand):
            let n = value(degree, variables)
            let r = value(radicand, variables)
            if n == 0 { return .nan }
            // Ungerade ganzzahlige Wurzel aus negativer Zahl ist reell: ³√−8 = −2
            if r < 0, n == n.rounded(), Int(exactly: n).map({ $0 % 2 != 0 }) == true {
                return -pow(-r, 1 / n)
            }
            return pow(r, 1 / n)
        case .function(let f, let a):
            return apply(f, value(a, variables))
        case .absolute(let a):
            return Swift.abs(value(a, variables))
        case .factorial(let a):
            let n = value(a, variables)
            if n < 0, n == n.rounded() { return .nan }
            return tgamma(n + 1)
        }
    }

    /// Potenz mit reellem Ergebnis auch für negative Basis, wenn der Exponent ein Bruch
    /// mit ungeradem Nenner ist (x^(1/3), x^(2/3)). Den Bruch liest man am Ausdruck ab,
    /// weil 1/3 als Double nicht mehr als „ungerader Nenner“ erkennbar ist.
    static func realPower(_ base: Double, _ exponent: Double, exponent expression: Expr) -> Double {
        if base >= 0 || exponent == exponent.rounded() { return pow(base, exponent) }
        guard let r = expression.constantRational, r.denominator.isOdd else { return .nan }
        let magnitude = pow(-base, exponent)
        return r.numerator.isOdd ? -magnitude : magnitude
    }

    private func apply(_ f: MathFunction, _ x: Double) -> Double {
        let toRadians = angleMode == .degrees ? Double.pi / 180 : 1
        let fromRadians = angleMode == .degrees ? 180 / Double.pi : 1
        switch f {
        case .sin: return sin(x * toRadians)
        case .cos: return cos(x * toRadians)
        case .tan:
            let c = cos(x * toRadians)
            return Swift.abs(c) < 1e-15 ? .nan : sin(x * toRadians) / c
        case .asin: return Swift.abs(x) > 1 ? .nan : asin(x) * fromRadians
        case .acos: return Swift.abs(x) > 1 ? .nan : acos(x) * fromRadians
        case .atan: return atan(x) * fromRadians
        case .ln: return x <= 0 ? .nan : log(x)
        case .log: return x <= 0 ? .nan : log10(x)
        }
    }

    /// Ausdruck als Funktion einer Variablen.
    func function(_ expression: Expr, variable: String = "x") -> (Double) -> Double {
        let evaluator = self
        switch variable {
        case "t": return { t in var v = VariableValues(); v.t = t; return evaluator.value(expression, v) }
        case "y": return { y in var v = VariableValues(); v.y = y; return evaluator.value(expression, v) }
        default: return { x in var v = VariableValues(); v.x = x; return evaluator.value(expression, v) }
        }
    }
}

extension Expr {
    /// Der Wert, wenn der Ausdruck eine feste rationale Zahl ist (3, −2/3, 1÷3), sonst nil.
    var constantRational: Rational? {
        switch self {
        case .number(let r): return r
        case .negate(let a): return a.constantRational.map { -$0 }
        case .divide(let a, let b):
            guard let p = a.constantRational, let q = b.constantRational else { return nil }
            return try? p.divided(by: q)
        case .multiply(let a, let b):
            guard let p = a.constantRational, let q = b.constantRational else { return nil }
            return p * q
        case .add(let a, let b):
            guard let p = a.constantRational, let q = b.constantRational else { return nil }
            return p + q
        case .subtract(let a, let b):
            guard let p = a.constantRational, let q = b.constantRational else { return nil }
            return p - q
        default: return nil
        }
    }

    /// Kommt die Variable im Ausdruck vor?
    func contains(variable name: String) -> Bool {
        switch self {
        case .variable(let v): return v == name
        case .number, .constant, .ans: return false
        case .negate(let a), .function(_, let a), .absolute(let a), .factorial(let a):
            return a.contains(variable: name)
        case .add(let a, let b), .subtract(let a, let b), .multiply(let a, let b),
             .divide(let a, let b), .power(let a, let b):
            return a.contains(variable: name) || b.contains(variable: name)
        case .root(let a, let b):
            return a.contains(variable: name) || b.contains(variable: name)
        }
    }

    /// Alle vorkommenden Variablennamen.
    var variableNames: Set<String> {
        switch self {
        case .variable(let v): return [v]
        case .number, .constant, .ans: return []
        case .negate(let a), .function(_, let a), .absolute(let a), .factorial(let a):
            return a.variableNames
        case .add(let a, let b), .subtract(let a, let b), .multiply(let a, let b),
             .divide(let a, let b), .power(let a, let b), .root(let a, let b):
            return a.variableNames.union(b.variableNames)
        }
    }
}
