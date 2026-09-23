import Foundation

/// Fertig formatiertes Ergebnis für Anzeige und Verlauf.
struct CalculationResult: Equatable {
    var value: Value
    /// Exakte Darstellung als Formel (Bruch, Wurzel, π …) – nil bei reinen Näherungen.
    var exactRow: MathRow?
    var decimalRow: MathRow
    var decimalText: String
    /// true, wenn die Dezimaldarstellung den Wert exakt trifft (z. B. 1/4 = 0,25).
    var decimalIsExact: Bool

    var exactText: String? { exactRow?.linearText }
}

/// Wandelt Werte in Formelzeilen um, damit Ergebnisse genauso gerendert werden wie Eingaben.
enum ResultFormatter {
    static func format(_ value: Value) -> CalculationResult {
        let representation: DecimalRepresentation
        var exactRow: MathRow?
        switch value {
        case .exact(let v):
            exactRow = self.exactRow(v)
            if let r = v.rationalValue {
                representation = DecimalFormatting.representation(of: r)
            } else {
                representation = DecimalFormatting.representation(of: v.doubleValue)
            }
        case .approximate(let d):
            representation = DecimalFormatting.representation(of: d)
        }
        return CalculationResult(value: value,
                                 exactRow: exactRow,
                                 decimalRow: decimalRow(representation),
                                 decimalText: DecimalFormatting.text(representation),
                                 decimalIsExact: representation.isExact)
    }

    // MARK: - Exakte Darstellung

    /// z. B. 13/12 → Bruch; 2√3; 5π/6; (√6 − √2)/4 als „√6/4 − √2/4“
    static func exactRow(_ value: ExactValue) -> MathRow {
        if value.isZero { return MathRow(linear: "0") }
        var terms = value.sortedTerms
        // Möglichst mit einem positiven Term beginnen: „√2 − 1“ statt „−1 + √2“.
        if terms[0].coefficient.isNegative, let firstPositive = terms.firstIndex(where: { !$0.coefficient.isNegative }) {
            let term = terms.remove(at: firstPositive)
            terms.insert(term, at: 0)
        }
        var items: [MathItem] = []
        for (index, term) in terms.enumerated() {
            if term.coefficient.isNegative {
                items.append(MathItem(.op(.minus)))
            } else if index > 0 {
                items.append(MathItem(.op(.plus)))
            }
            items.append(contentsOf: termItems(term.monomial, term.coefficient.absoluteValue))
        }
        return MathRow(items)
    }

    /// Ein Term c · π^i · e^j · √n mit c > 0, negative Exponenten wandern in den Nenner.
    private static func termItems(_ monomial: Monomial, _ coefficient: Rational) -> [MathItem] {
        var numeratorFactors: [MathItem] = []
        var denominatorFactors: [MathItem] = []

        for (constant, exponent) in [(MathConstant.pi, monomial.piExponent), (MathConstant.e, monomial.eExponent)] where exponent != 0 {
            var factor = [MathItem(.constant(constant))]
            if Swift.abs(exponent) > 1 {
                factor.append(MathItem(.power, slots: [MathRow(MathRow.digits(BigInt(Swift.abs(exponent))))]))
            }
            if exponent > 0 {
                numeratorFactors += factor
            } else {
                denominatorFactors += factor
            }
        }
        if monomial.radicand > 1 {
            numeratorFactors.append(MathItem(.squareRoot, slots: [MathRow(MathRow.digits(BigInt(monomial.radicand)))]))
        }

        var numerator: [MathItem] = []
        if coefficient.numerator != 1 || numeratorFactors.isEmpty {
            numerator = MathRow.digits(coefficient.numerator)
        }
        numerator += numeratorFactors

        var denominator: [MathItem] = []
        if coefficient.denominator != 1 {
            denominator = MathRow.digits(coefficient.denominator)
        }
        denominator += denominatorFactors

        if denominator.isEmpty { return numerator }
        return [MathItem(.fraction, slots: [MathRow(numerator), MathRow(denominator)])]
    }

    // MARK: - Dezimaldarstellung

    static func decimalRow(_ representation: DecimalRepresentation) -> MathRow {
        let (mantissa, power) = DecimalFormatting.parts(representation)
        var items: [MathItem] = []
        if representation.isNegative { items.append(MathItem(.op(.minus))) }
        items += MathRow(linear: mantissa).items
        if let power {
            items.append(MathItem(.op(.times)))
            items += MathRow(linear: "10").items
            var exponent: [MathItem] = []
            if power < 0 { exponent.append(MathItem(.op(.minus))) }
            exponent += MathRow.digits(BigInt(Swift.abs(power)))
            items.append(MathItem(.power, slots: [MathRow(exponent)]))
        }
        return MathRow(items)
    }
}
