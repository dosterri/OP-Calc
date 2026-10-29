import Foundation

// Symbolische Ableitung für Graph und Kurvendiskussion (AK-02).
// Symbolisch statt Differenzenquotient, weil Extrema und Wendestellen Nullstellen von f′ und f″
// sind – Rundungsfehler eines zweifachen Differenzenquotienten würden die Suche verfälschen.

extension Expr {
    /// Ableitung nach `name`. Im Gradmaß tragen die Winkelfunktionen den Faktor π/180.
    /// nil, wenn ein Baustein nicht ableitbar ist (n!, Ans) – dann numerisch ableiten.
    func derivative(by name: String, angleMode: AngleMode = .radians) -> Expr? {
        derive(name, angleMode)?.simplified()
    }

    private func derive(_ v: String, _ mode: AngleMode) -> Expr? {
        if !contains(variable: v) {
            if case .ans = self { return nil }
            return .number(.zero)
        }
        switch self {
        case .number, .constant, .ans:
            return .number(.zero)
        case .variable(let name):
            return .number(name == v ? .one : .zero)
        case .negate(let a):
            return a.derive(v, mode).map { .negate($0) }
        case .add(let a, let b):
            guard let da = a.derive(v, mode), let db = b.derive(v, mode) else { return nil }
            return .add(da, db)
        case .subtract(let a, let b):
            guard let da = a.derive(v, mode), let db = b.derive(v, mode) else { return nil }
            return .subtract(da, db)
        case .multiply(let a, let b):
            guard let da = a.derive(v, mode), let db = b.derive(v, mode) else { return nil }
            return .add(.multiply(da, b), .multiply(a, db))
        case .divide(let a, let b):
            guard let da = a.derive(v, mode), let db = b.derive(v, mode) else { return nil }
            return .divide(.subtract(.multiply(da, b), .multiply(a, db)), .power(b, .number(Rational(2))))
        case .power(let a, let b):
            if !b.contains(variable: v) {
                // (aⁿ)′ = n·aⁿ⁻¹·a′
                guard let da = a.derive(v, mode) else { return nil }
                return .multiply(.multiply(b, .power(a, .subtract(b, .number(.one)))), da)
            }
            guard let da = a.derive(v, mode), let db = b.derive(v, mode) else { return nil }
            if !a.contains(variable: v) {
                // (cᵘ)′ = cᵘ·ln c·u′
                return .multiply(.multiply(self, .function(.ln, a)), db)
            }
            // (aᵇ)′ = aᵇ·(b′·ln a + b·a′/a)
            return .multiply(self, .add(.multiply(db, .function(.ln, a)), .divide(.multiply(b, da), a)))
        case .root(let degree, let radicand):
            return Expr.power(radicand, .divide(.number(.one), degree)).derive(v, mode)
        case .function(let f, let u):
            guard let du = u.derive(v, mode) else { return nil }
            return .multiply(Self.outerDerivative(f, u, mode), du)
        case .absolute(let u):
            // |u|′ = u·u′/|u|
            guard let du = u.derive(v, mode) else { return nil }
            return .divide(.multiply(u, du), .absolute(u))
        case .factorial:
            return nil
        }
    }

    private static func outerDerivative(_ f: MathFunction, _ u: Expr, _ mode: AngleMode) -> Expr {
        let one = Expr.number(.one)
        let square = { (e: Expr) in Expr.power(e, .number(Rational(2))) }
        // Gradmaß: sin(x°)′ = π/180·cos(x°); Umkehrfunktionen liefern Grad → Faktor 180/π
        let inner = mode == .degrees ? Expr.divide(.constant(.pi), .number(Rational(180))) : one
        let outer = mode == .degrees ? Expr.divide(.number(Rational(180)), .constant(.pi)) : one
        switch f {
        case .sin: return .multiply(inner, .function(.cos, u))
        case .cos: return .negate(.multiply(inner, .function(.sin, u)))
        case .tan: return .divide(inner, square(.function(.cos, u)))
        case .asin: return .divide(outer, .root(degree: .number(Rational(2)), radicand: .subtract(one, square(u))))
        case .acos: return .negate(.divide(outer, .root(degree: .number(Rational(2)), radicand: .subtract(one, square(u)))))
        case .atan: return .divide(outer, .add(one, square(u)))
        case .ln: return .divide(one, u)
        case .log: return .divide(one, .multiply(u, .function(.ln, .number(Rational(10)))))
        }
    }

    /// Leichte Vereinfachung: Zahlen zusammenfassen, 0 und 1 als neutrale Elemente entfernen.
    /// Hält die Ableitungsbäume klein (schnelleres Zeichnen) und Exponenten wie 1/3 − 1 als Zahl −2/3,
    /// damit negative Basen mit ungeradem Nenner reell bleiben.
    func simplified() -> Expr {
        switch self {
        case .number, .constant, .variable, .ans:
            return self
        case .negate(let a):
            let s = a.simplified()
            if case .number(let r) = s { return .number(-r) }
            if case .negate(let inner) = s { return inner }
            return .negate(s)
        case .add(let a, let b):
            let (x, y) = (a.simplified(), b.simplified())
            if let p = x.constantRational, let q = y.constantRational { return .number(p + q) }
            if x.isZero { return y }
            if y.isZero { return x }
            if case .negate(let inner) = y { return .subtract(x, inner) }
            return .add(x, y)
        case .subtract(let a, let b):
            let (x, y) = (a.simplified(), b.simplified())
            if let p = x.constantRational, let q = y.constantRational { return .number(p - q) }
            if y.isZero { return x }
            if x.isZero { return Expr.negate(y).simplified() }
            return .subtract(x, y)
        case .multiply(let a, let b):
            let (x, y) = (a.simplified(), b.simplified())
            if let p = x.constantRational, let q = y.constantRational { return .number(p * q) }
            if x.isZero || y.isZero { return .number(.zero) }
            if x.isOne { return y }
            if y.isOne { return x }
            return .multiply(x, y)
        case .divide(let a, let b):
            let (x, y) = (a.simplified(), b.simplified())
            if let p = x.constantRational, let q = y.constantRational, !q.isZero, let r = try? p.divided(by: q) {
                return .number(r)
            }
            if x.isZero, !(y.constantRational?.isZero ?? false) { return .number(.zero) }
            if y.isOne { return x }
            return .divide(x, y)
        case .power(let a, let b):
            let (x, y) = (a.simplified(), b.simplified())
            if y.isZero { return .number(.one) }
            if y.isOne { return x }
            if let p = x.constantRational, let n = y.constantRational, n.isInteger,
               let k = n.numerator.asInt, Swift.abs(k) <= 64, let r = try? p.power(k) {
                return .number(r)
            }
            return .power(x, y)
        case .root(let d, let r):
            return .root(degree: d.simplified(), radicand: r.simplified())
        case .function(let f, let a):
            return .function(f, a.simplified())
        case .absolute(let a):
            return .absolute(a.simplified())
        case .factorial(let a):
            return .factorial(a.simplified())
        }
    }

    private var isZero: Bool { constantRational?.isZero ?? false }
    private var isOne: Bool { constantRational == .one }
}
