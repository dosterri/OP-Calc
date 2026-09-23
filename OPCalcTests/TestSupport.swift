import Foundation
@testable import OPCalc

// Kleine Bausteine, um Formelbäume in Tests kompakt aufzuschreiben.

/// Flache Elemente aus Text, z. B. lin("2+3×4")
func lin(_ text: String) -> [MathItem] {
    MathRow(linear: text).items
}

/// Setzt Zeilenteile zu einer Zeile zusammen.
func row(_ parts: [MathItem]...) -> MathRow {
    MathRow(parts.flatMap { $0 })
}

func frac(_ numerator: [MathItem], _ denominator: [MathItem]) -> [MathItem] {
    [MathItem(.fraction, slots: [MathRow(numerator), MathRow(denominator)])]
}

func frac(_ numerator: String, _ denominator: String) -> [MathItem] {
    frac(lin(numerator), lin(denominator))
}

/// Exponent (hochgestellt) – die Basis ist das Element davor.
func sup(_ exponent: [MathItem]) -> [MathItem] {
    [MathItem(.power, slots: [MathRow(exponent)])]
}

func sup(_ exponent: String) -> [MathItem] {
    sup(lin(exponent))
}

func sqrtOf(_ radicand: [MathItem]) -> [MathItem] {
    [MathItem(.squareRoot, slots: [MathRow(radicand)])]
}

func rootOf(_ degree: String, _ radicand: [MathItem]) -> [MathItem] {
    [MathItem(.nthRoot, slots: [MathRow(linear: degree), MathRow(radicand)])]
}

func paren(_ inner: [MathItem]) -> [MathItem] {
    [MathItem(.parentheses, slots: [MathRow(inner)])]
}

func absOf(_ inner: [MathItem]) -> [MathItem] {
    [MathItem(.absolute, slots: [MathRow(inner)])]
}

func fn(_ function: MathFunction, _ argument: [MathItem]) -> [MathItem] {
    [MathItem(.function(function), slots: [MathRow(argument)])]
}

func q(_ numerator: Int, _ denominator: Int = 1) -> Rational {
    Rational(BigInt(numerator), BigInt(denominator))
}

func exact(_ numerator: Int, _ denominator: Int = 1) -> Value {
    .exact(ExactValue(q(numerator, denominator)))
}

/// Parst und wertet eine Zeile aus.
func evaluate(_ formula: MathRow, mode: AngleMode = .radians, ans: Value? = nil) throws -> Value {
    try Evaluator(angleMode: mode, ans: ans).evaluate(FormulaParser.parse(formula))
}
