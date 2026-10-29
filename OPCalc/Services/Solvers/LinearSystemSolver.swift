import Foundation

/// Zahlbereich für das Gauß-Jordan-Verfahren: exakt (Rational) oder genähert (Double).
protocol LinearField {
    static var zero: Self { get }
    static var one: Self { get }
    static func + (lhs: Self, rhs: Self) -> Self
    static func - (lhs: Self, rhs: Self) -> Self
    static func * (lhs: Self, rhs: Self) -> Self
    func over(_ divisor: Self) -> Self
    /// Gilt als null (exakt: == 0; Double: kleiner als die Toleranz)
    func isNegligible(scale: Double) -> Bool
    var magnitude: Double { get }
    var value: Value { get }
}

extension Rational: LinearField {
    func over(_ divisor: Rational) -> Rational { (try? divided(by: divisor)) ?? .zero }
    func isNegligible(scale: Double) -> Bool { isZero }
    var magnitude: Double { Swift.abs(doubleValue) }
    var value: Value { .exact(ExactValue(self)) }
}

extension Double: LinearField {
    static var one: Double { 1 }
    func over(_ divisor: Double) -> Double { self / divisor }
    /// Relative Toleranz zur größten Matrixzahl: darunter ist der Unterschied Rundungsrauschen.
    func isNegligible(scale: Double) -> Bool { Swift.abs(self) <= 1e-11 * max(1, scale) }
    var value: Value { .approximate(self) }
}

/// Lösung eines linearen Gleichungssystems A·x = b.
struct LinearSystemSolution: Equatable {
    enum Kind: Equatable { case unique, none, infinite }

    /// Jede Variable: xᵢ = Konstante + Σ Koeffizientⱼ · tⱼ (tⱼ = freie Parameter)
    struct VariableTerm: Equatable {
        var constant: Value
        var coefficients: [Value]
    }

    var kind: Kind
    var variables: [VariableTerm]
    /// Indizes der Variablen, die frei gewählt werden (tⱼ gehört zur j-ten freien Variable)
    var freeVariables: [Int]
    var isExact: Bool
}

enum LinearSystemSolver {
    /// `augmented` hat n Zeilen und m + 1 Spalten (letzte Spalte = rechte Seite).
    /// Exakt, wenn alle Einträge rational sind; sonst mit Double und Spaltenpivotsuche.
    static func solve(_ augmented: [[Value]]) -> LinearSystemSolution? {
        guard let width = augmented.first?.count, width >= 2, augmented.allSatisfy({ $0.count == width }) else { return nil }
        let rationals = augmented.map { row in row.map { value -> Rational? in
            if case .exact(let v) = value { return v.rationalValue }
            return nil
        } }
        if rationals.allSatisfy({ $0.allSatisfy { $0 != nil } }) {
            return solve(rationals.map { $0.compactMap { $0 } }, exact: true)
        }
        return solve(augmented.map { $0.map(\.doubleValue) }, exact: false)
    }

    static func solve<T: LinearField>(_ augmented: [[T]], exact: Bool) -> LinearSystemSolution {
        var a = augmented
        let rows = a.count
        let columns = a[0].count - 1
        let scale = a.flatMap { $0 }.map(\.magnitude).max() ?? 1
        var pivotColumns: [Int] = []
        var pivotRow = 0

        for column in 0..<columns where pivotRow < rows {
            // Exakt reicht der erste Nicht-Null-Eintrag; genähert der betragsgrößte (stabiler).
            var best: Int?
            for r in pivotRow..<rows where !a[r][column].isNegligible(scale: scale) {
                if best == nil || (!exact && a[r][column].magnitude > a[best ?? r][column].magnitude) { best = r }
                if exact { break }
            }
            guard let found = best else { continue }
            a.swapAt(pivotRow, found)
            let pivot = a[pivotRow][column]
            a[pivotRow] = a[pivotRow].map { $0.over(pivot) }
            for r in 0..<rows where r != pivotRow {
                let factor = a[r][column]
                if factor.isNegligible(scale: scale) { continue }
                for c in 0...columns { a[r][c] = a[r][c] - factor * a[pivotRow][c] }
            }
            pivotColumns.append(column)
            pivotRow += 1
        }

        // Widerspruch: Zeile 0 = b mit b ≠ 0
        for r in pivotRow..<rows where !a[r][columns].isNegligible(scale: scale) {
            return LinearSystemSolution(kind: .none, variables: [], freeVariables: [], isExact: exact)
        }

        let free = (0..<columns).filter { !pivotColumns.contains($0) }
        var terms = (0..<columns).map { _ in
            LinearSystemSolution.VariableTerm(constant: T.zero.value, coefficients: free.map { _ in T.zero.value })
        }
        for (r, column) in pivotColumns.enumerated() {
            terms[column] = LinearSystemSolution.VariableTerm(
                constant: a[r][columns].value,
                coefficients: free.map { (T.zero - a[r][$0]).value })
        }
        for (j, column) in free.enumerated() {
            var coefficients = free.map { _ in T.zero.value }
            coefficients[j] = T.one.value
            terms[column] = LinearSystemSolution.VariableTerm(constant: T.zero.value, coefficients: coefficients)
        }
        return LinearSystemSolution(kind: free.isEmpty ? .unique : .infinite, variables: terms,
                                    freeVariables: free, isExact: exact)
    }
}
