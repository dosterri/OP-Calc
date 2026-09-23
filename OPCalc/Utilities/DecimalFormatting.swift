import Foundation

/// Dezimaldarstellung mit fester Anzahl signifikanter Stellen.
/// Wert = ±0,digits · 10^(exponent+1), d. h. die erste Ziffer steht an der Stelle 10^exponent.
struct DecimalRepresentation: Equatable {
    var isNegative: Bool
    /// Signifikante Ziffern ohne abschließende Nullen, z. B. "1083333333"
    var digits: String
    /// Zehnerexponent der ersten Ziffer, z. B. 0 für 1,08…; −1 für 0,25
    var exponent: Int
    /// true, wenn die Darstellung den Wert exakt wiedergibt (kein Runden nötig war)
    var isExact: Bool

    static let zero = DecimalRepresentation(isNegative: false, digits: "0", exponent: 0, isExact: true)

    /// Bereich, in dem ohne Zehnerpotenz geschrieben wird.
    static let plainRange = -5...11
}

enum DecimalFormatting {
    static let significantDigits = 10

    /// Exakte Rundung eines Bruchs – funktioniert auch für Zahlen mit Tausenden Stellen.
    static func representation(of value: Rational, digits: Int = significantDigits) -> DecimalRepresentation {
        if value.isZero { return .zero }
        let n = value.numerator.absoluteValue
        let d = value.denominator

        // Schätzung des Zehnerexponenten über die Stellenzahl; sie ist höchstens um 1 zu groß.
        var exponent = n.description.count - d.description.count
        func scaled(_ e: Int) -> (quotient: BigInt, remainder: BigInt, divisor: BigInt) {
            let shift = digits - 1 - e
            let (a, b) = shift >= 0 ? (n * BigInt(10).power(shift), d) : (n, d * BigInt(10).power(-shift))
            let (q, r) = a.quotientAndRemainder(dividingBy: b)
            return (q, r, b)
        }
        var result = scaled(exponent)
        if result.quotient.description.count < digits {
            exponent -= 1
            result = scaled(exponent)
        }

        var quotient = result.quotient
        let isExact = result.remainder.isZero
        // Kaufmännisch runden
        if result.remainder * 2 >= result.divisor {
            quotient = quotient + 1
            if quotient.description.count > digits {
                quotient = quotient / 10
                exponent += 1
            }
        }
        return DecimalRepresentation(isNegative: value.isNegative,
                                     digits: trimmingZeros(quotient.description),
                                     exponent: exponent,
                                     isExact: isExact)
    }

    /// Rundung einer Double-Näherung (immer als nicht exakt markiert).
    static func representation(of value: Double, digits: Int = significantDigits) -> DecimalRepresentation {
        if value == 0 { return DecimalRepresentation(isNegative: false, digits: "0", exponent: 0, isExact: false) }
        let text = String(format: "%.\(digits - 1)e", Swift.abs(value))   // z. B. "1.083333333e+00"
        let parts = text.split(separator: "e")
        let mantissa = parts[0].replacingOccurrences(of: ".", with: "")
        let exponent = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        return DecimalRepresentation(isNegative: value < 0,
                                     digits: trimmingZeros(mantissa),
                                     exponent: exponent,
                                     isExact: false)
    }

    private static func trimmingZeros(_ digits: String) -> String {
        var result = digits
        while result.count > 1, result.last == "0" { result.removeLast() }
        return result
    }

    /// Mantisse und Zehnerexponent für die Anzeige, z. B. ("1,5", nil) oder ("1,5", 15) für 1,5·10¹⁵.
    static func parts(_ r: DecimalRepresentation) -> (mantissa: String, powerOfTen: Int?) {
        let digits = Array(r.digits)
        if DecimalRepresentation.plainRange.contains(r.exponent) {
            if r.exponent >= 0 {
                let integerCount = r.exponent + 1
                if digits.count <= integerCount {
                    return (String(digits) + String(repeating: "0", count: integerCount - digits.count), nil)
                }
                return (String(digits[..<integerCount]) + "," + String(digits[integerCount...]), nil)
            }
            return ("0," + String(repeating: "0", count: -r.exponent - 1) + String(digits), nil)
        }
        let mantissa = digits.count > 1 ? "\(digits[0]),\(String(digits[1...]))" : String(digits)
        return (mantissa, r.exponent)
    }

    /// Einzeiliger Text, z. B. "−1,25" oder "1,5×10^15".
    static func text(_ r: DecimalRepresentation) -> String {
        let (mantissa, power) = parts(r)
        let sign = r.isNegative ? "−" : ""
        guard let power else { return sign + mantissa }
        return sign + mantissa + "×10^" + (power < 0 ? "−\(-power)" : "\(power)")
    }
}
