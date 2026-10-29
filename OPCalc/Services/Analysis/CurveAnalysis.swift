import Foundation

/// Ein markierter Punkt im Graphen (Nullstelle, Hochpunkt …).
struct CurvePoint: Equatable, Identifiable {
    enum Kind: Equatable {
        case root, maximum, minimum, saddle, inflection, intersection, yIntercept, value
    }

    var kind: Kind
    var x: Double
    var y: Double
    var id: String { "\(kind)-\(x)-\(y)" }

    var title: String {
        switch kind {
        case .root: return "Nullstelle"
        case .maximum: return "Hochpunkt"
        case .minimum: return "Tiefpunkt"
        case .saddle: return "Sattelpunkt"
        case .inflection: return "Wendepunkt"
        case .intersection: return "Schnittpunkt"
        case .yIntercept: return "y-Achsenabschnitt"
        case .value: return "Punkt"
        }
    }
}

/// Kurvendiskussion einer Funktion f mit Ableitungen f′ und f″ (AK-02).
/// Gesucht wird immer in einem Intervall – in der App ist das der sichtbare Bereich.
struct CurveAnalysis {
    let f: (Double) -> Double
    let firstDerivative: (Double) -> Double
    let secondDerivative: (Double) -> Double

    /// Baut die Analyse aus einem Ausdruck in x; Ableitungen symbolisch, notfalls numerisch.
    init(expression: Expr, evaluator: NumericEvaluator = NumericEvaluator()) {
        let f = evaluator.function(expression)
        let d1 = expression.derivative(by: "x", angleMode: evaluator.angleMode)
        let d2 = d1?.derivative(by: "x", angleMode: evaluator.angleMode)
        let first = d1.map { evaluator.function($0) } ?? NumericMethods.numericDerivative(f)
        self.f = f
        self.firstDerivative = first
        self.secondDerivative = d2.map { evaluator.function($0) } ?? NumericMethods.numericDerivative(first)
    }

    init(f: @escaping (Double) -> Double, firstDerivative: @escaping (Double) -> Double,
         secondDerivative: @escaping (Double) -> Double) {
        self.f = f
        self.firstDerivative = firstDerivative
        self.secondDerivative = secondDerivative
    }

    func roots(in a: Double, _ b: Double) -> [CurvePoint] {
        NumericMethods.roots(of: f, in: a, b).map { CurvePoint(kind: .root, x: $0.x, y: 0) }
    }

    /// Hoch- und Tiefpunkte: Nullstellen von f′ mit Vorzeichenwechsel.
    /// Berührstellen von f′ (f′ = 0 ohne Wechsel) sind Sattelpunkte.
    func extrema(in a: Double, _ b: Double) -> [CurvePoint] {
        NumericMethods.roots(of: firstDerivative, in: a, b).compactMap { root in
            let y = f(root.x)
            guard y.isFinite else { return nil }
            guard root.crossesSign else { return CurvePoint(kind: .saddle, x: root.x, y: y) }
            // Art über f″; ist f″ ≈ 0 oder nicht definiert, über f′ links und rechts
            let curvature = secondDerivative(root.x)
            if curvature.isFinite, Swift.abs(curvature) > 1e-12 {
                return CurvePoint(kind: curvature < 0 ? .maximum : .minimum, x: root.x, y: y)
            }
            let h = max(1e-9, (b - a) * 1e-6)
            let left = firstDerivative(root.x - h), right = firstDerivative(root.x + h)
            let isMaximum = left.isFinite ? left > 0 : right < 0
            return CurvePoint(kind: isMaximum ? .maximum : .minimum, x: root.x, y: y)
        }
    }

    /// Wendepunkte: Nullstellen von f″ mit Vorzeichenwechsel, an denen f definiert ist.
    func inflectionPoints(in a: Double, _ b: Double) -> [CurvePoint] {
        NumericMethods.roots(of: secondDerivative, in: a, b).compactMap { root in
            guard root.crossesSign else { return nil }
            let y = f(root.x)
            return y.isFinite ? CurvePoint(kind: .inflection, x: root.x, y: y) : nil
        }
    }

    func intersections(with g: @escaping (Double) -> Double, in a: Double, _ b: Double) -> [CurvePoint] {
        let f = self.f
        return NumericMethods.roots(of: { f($0) - g($0) }, in: a, b).compactMap { root in
            let y = f(root.x)
            return y.isFinite ? CurvePoint(kind: .intersection, x: root.x, y: y) : nil
        }
    }

    func yIntercept() -> CurvePoint? {
        let y = f(0)
        return y.isFinite ? CurvePoint(kind: .yIntercept, x: 0, y: y) : nil
    }

    func integral(from a: Double, to b: Double) -> Double? {
        NumericMethods.integral(of: f, from: a, to: b)
    }
}
