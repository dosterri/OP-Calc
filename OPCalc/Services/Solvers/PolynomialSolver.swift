import Foundation

/// Reelle Nullstellen eines Polynoms aₙxⁿ + … + a₀ (AK-03).
/// Exakt, soweit möglich: rationale Nullstellen (Teilertest), Rest bis Grad 2 mit Wurzeln (√).
/// Was danach übrig bleibt (Grad ≥ 3 ohne rationale Nullstelle), wird numerisch gelöst.
enum PolynomialSolver {
    struct Root: Equatable {
        var value: Value
        var multiplicity: Int
    }

    struct Solution: Equatable {
        var roots: [Root]
        /// Anzahl nicht reeller Lösungen (mit Vielfachheit)
        var nonRealCount: Int
        /// 0 = 0: jede Zahl ist Lösung
        var isIdentity = false
    }

    /// Bis zu dieser Größe werden Teiler von a₀ und aₙ für den Teilertest aufgezählt.
    static let maxDivisorSearch = 1_000_000_000_000
    /// Höchstzahl der Paare p/q im Teilertest (je Paar ein Horner-Schema mit Brüchen).
    static let maxCandidates = 20_000

    /// `coefficients` vom höchsten Grad abwärts.
    static func solve(_ coefficients: [Value]) -> Solution {
        var list = coefficients
        while let first = list.first, first.isZero { list.removeFirst() }
        guard list.count > 1 else {
            return Solution(roots: [], nonRealCount: 0, isIdentity: list.isEmpty)
        }
        let rationals = list.map { value -> Rational? in
            if case .exact(let v) = value { return v.rationalValue }
            return nil
        }
        if rationals.allSatisfy({ $0 != nil }) {
            return solveExact(rationals.compactMap { $0 })
        }
        return finish(numeric: list.map(\.doubleValue), found: [], degree: list.count - 1)
    }

    // MARK: - Exakt

    private static func solveExact(_ input: [Rational]) -> Solution {
        let degree = input.count - 1
        var p = input
        var found: [Root] = []

        // Nullstelle 0 ausklammern
        var zeroCount = 0
        while let last = p.last, last.isZero { p.removeLast(); zeroCount += 1 }
        if zeroCount > 0 { found.append(Root(value: .exact(.zero), multiplicity: zeroCount)) }

        // Rationale Nullstellen ±p/q mit p | a₀, q | aₙ (nach Hauptnenner ganzzahlig)
        if p.count > 2, let candidates = rationalCandidates(p) {
            for candidate in candidates where p.count > 1 {
                var multiplicity = 0
                while p.count > 1, horner(p, candidate).isZero {
                    p = deflate(p, by: candidate)
                    multiplicity += 1
                }
                if multiplicity > 0 { found.append(Root(value: .exact(ExactValue(candidate)), multiplicity: multiplicity)) }
            }
        }

        switch p.count - 1 {
        case 0:
            return Solution(roots: sorted(found), nonRealCount: 0)
        case 1:
            let root = (-p[1]).over(p[0])
            found.append(Root(value: .exact(ExactValue(root)), multiplicity: 1))
            return Solution(roots: sorted(found), nonRealCount: 0)
        case 2:
            let (a, b, c) = (p[0], p[1], p[2])
            let discriminant = b * b - Rational(4) * a * c
            if discriminant.isNegative {
                return Solution(roots: sorted(found), nonRealCount: 2)
            }
            let twoA = Rational(2) * a
            if discriminant.isZero {
                found.append(Root(value: .exact(ExactValue((-b).over(twoA))), multiplicity: 2))
                return Solution(roots: sorted(found), nonRealCount: 0)
            }
            if let root = try? ExactValue(discriminant).squareRoot(),
               let factor = try? ExactValue(twoA).reciprocal(),
               let x1 = try? ExactValue.multiply(ExactValue(-b) - root, factor),
               let x2 = try? ExactValue.multiply(ExactValue(-b) + root, factor) {
                found.append(Root(value: .exact(x1), multiplicity: 1))
                found.append(Root(value: .exact(x2), multiplicity: 1))
                return Solution(roots: sorted(found), nonRealCount: 0)
            }
            return finish(numeric: p.map(\.doubleValue), found: found, degree: degree)
        default:
            return finish(numeric: p.map(\.doubleValue), found: found, degree: degree)
        }
    }

    static func horner(_ p: [Rational], _ x: Rational) -> Rational {
        p.dropFirst().reduce(p[0]) { $0 * x + $1 }
    }

    /// Synthetische Division durch (x − r); setzt voraus, dass r Nullstelle ist.
    static func deflate(_ p: [Rational], by r: Rational) -> [Rational] {
        var result: [Rational] = [p[0]]
        for coefficient in p.dropFirst().dropLast() {
            result.append(coefficient + (result.last ?? .zero) * r)
        }
        return result
    }

    private static func rationalCandidates(_ p: [Rational]) -> [Rational]? {
        // Hauptnenner, damit alle Koeffizienten ganzzahlig werden
        var common = BigInt(1)
        for c in p { common = common / BigInt.gcd(common, c.denominator) * c.denominator }
        let integers = p.map { $0.numerator * (common / $0.denominator) }
        guard let a0 = integers.last?.absoluteValue.asInt, let an = integers.first?.absoluteValue.asInt,
              a0 > 0, an > 0, a0 <= maxDivisorSearch, an <= maxDivisorSearch else { return nil }
        let numerators = divisors(a0), denominators = divisors(an)
        // Zu viele Kandidaten würden die App blockieren – dann gleich numerisch lösen
        guard numerators.count * denominators.count <= maxCandidates else { return nil }
        var result = Set<Rational>()
        for numerator in numerators {
            for denominator in denominators {
                let r = Rational(BigInt(numerator), BigInt(denominator))
                result.insert(r)
                result.insert(-r)
            }
        }
        return result.sorted { $0 < $1 }
    }

    static func divisors(_ n: Int) -> [Int] {
        var small: [Int] = [], large: [Int] = []
        var d = 1
        while d * d <= n {
            if n % d == 0 {
                small.append(d)
                if d != n / d { large.append(n / d) }
            }
            d += 1
        }
        return small + large.reversed()
    }

    private static func sorted(_ roots: [Root]) -> [Root] {
        roots.sorted { $0.value.doubleValue < $1.value.doubleValue }
    }

    // MARK: - Numerisch

    private static func finish(numeric p: [Double], found: [Root], degree: Int) -> Solution {
        var roots = found
        for (x, multiplicity) in realRoots(p) {
            roots.append(Root(value: .approximate(x), multiplicity: multiplicity))
        }
        let realCount = roots.reduce(0) { $0 + $1.multiplicity }
        return Solution(roots: sorted(roots), nonRealCount: max(0, degree - realCount))
    }

    static func evaluate(_ p: [Double], _ x: Double) -> Double {
        p.dropFirst().reduce(p[0]) { $0 * x + $1 }
    }

    static func derivative(_ p: [Double]) -> [Double] {
        let n = p.count - 1
        return p.dropLast().enumerated().map { Double(n - $0.offset) * $0.element }
    }

    /// Verschiedene reelle Nullstellen mit Vielfachheit: zwischen den Extremstellen
    /// (Nullstellen der Ableitung, rekursiv) liegt höchstens eine Nullstelle.
    static func realRoots(_ p: [Double]) -> [(Double, Int)] {
        guard p.count > 1, p[0] != 0 else { return [] }
        if p.count == 2 { return [(-p[1] / p[0], 1)] }
        let bound = 1 + (p.dropFirst().map { Swift.abs($0 / p[0]) }.max() ?? 0)
        let critical = realRoots(derivative(p)).map(\.0).filter { Swift.abs($0) < bound }
        let points = [-bound] + critical + [bound]
        let size = { (x: Double) in p.enumerated().reduce(0.0) { $0 + Swift.abs($1.element) * pow(Swift.abs(x), Double(p.count - 1 - $1.offset)) } }
        var roots: [Double] = []
        for c in critical where Swift.abs(evaluate(p, c)) <= 1e-9 * size(c) {
            roots.append(c)
        }
        for i in 0..<(points.count - 1) {
            let (u, v) = (points[i], points[i + 1])
            let (fu, fv) = (evaluate(p, u), evaluate(p, v))
            if fu * fv < 0, let r = NumericMethods.brent({ evaluate(p, $0) }, u, v) {
                roots.append(r)
            }
        }
        roots.sort()
        var distinct: [Double] = []
        for r in roots where distinct.last.map({ Swift.abs($0 - r) > 1e-9 * max(1, Swift.abs(r)) }) ?? true {
            distinct.append(r)
        }
        return distinct.map { r in (r, multiplicity(p, at: r)) }
    }

    private static func multiplicity(_ p: [Double], at r: Double) -> Int {
        var q = derivative(p)
        var count = 1
        while q.count > 1 {
            let scale = q.enumerated().reduce(0.0) { $0 + Swift.abs($1.element) * pow(Swift.abs(r), Double(q.count - 1 - $1.offset)) }
            guard Swift.abs(evaluate(q, r)) <= 1e-6 * max(scale, 1e-300) else { break }
            count += 1
            q = derivative(q)
        }
        return count
    }
}
