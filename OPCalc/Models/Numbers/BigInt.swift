import Foundation

/// Ganzzahl beliebiger Größe.
///
/// Darstellung: Vorzeichen + Betrag in 32-Bit-Blöcken (niedrigstwertiger Block zuerst).
/// Bewusst schlank gehalten – nur die Operationen, die der Rechner wirklich braucht:
/// Addition, Subtraktion, Multiplikation, Division mit Rest (Knuth, Algorithmus D),
/// ggT, Potenz, ganzzahlige Wurzel und Dezimaldarstellung.
struct BigInt: Hashable, Codable, Sendable {
    /// Betrag, niedrigstwertiger Block zuerst, ohne führende Null-Blöcke. Null = leeres Array.
    private(set) var limbs: [UInt32]
    /// true bei negativen Zahlen. Null ist nie negativ.
    private(set) var isNegative: Bool

    // MARK: - Erzeugung

    init() {
        limbs = []
        isNegative = false
    }

    init(_ value: Int) {
        var magnitude = UInt64(value.magnitude)
        var result: [UInt32] = []
        while magnitude > 0 {
            result.append(UInt32(truncatingIfNeeded: magnitude))
            magnitude >>= 32
        }
        limbs = result
        isNegative = value < 0
    }

    /// Liest eine Dezimalzahl ("-123", "+42", "0007"). Gibt nil bei ungültigem Text zurück.
    init?(_ text: String) {
        var digits = Substring(text)
        var negative = false
        if digits.first == "-" {
            negative = true
            digits = digits.dropFirst()
        } else if digits.first == "+" {
            digits = digits.dropFirst()
        }
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }

        // In Blöcken zu höchstens 9 Ziffern einlesen: Ergebnis = Ergebnis · 10^9 + Block
        var result: [UInt32] = []
        var index = digits.startIndex
        var chunkLength = digits.count % 9 == 0 ? 9 : digits.count % 9
        while index < digits.endIndex {
            let end = digits.index(index, offsetBy: chunkLength)
            guard let chunk = UInt32(digits[index..<end]) else { return nil }
            var multiplier: UInt32 = 1
            for _ in 0..<chunkLength { multiplier *= 10 }
            BigInt.multiplyAdd(&result, multiplier: multiplier, addend: chunk)
            index = end
            chunkLength = 9
        }
        self.init(limbs: result, isNegative: negative)
    }

    private init(limbs: [UInt32], isNegative: Bool) {
        var trimmed = limbs
        BigInt.trim(&trimmed)
        self.limbs = trimmed
        self.isNegative = trimmed.isEmpty ? false : isNegative
    }

    // MARK: - Eigenschaften

    var isZero: Bool { limbs.isEmpty }
    var isOdd: Bool { !limbs.isEmpty && limbs[0] & 1 == 1 }
    var absoluteValue: BigInt { BigInt(limbs: limbs, isNegative: false) }

    /// Anzahl der Bits des Betrags (0 für null).
    var bitWidth: Int {
        guard let top = limbs.last else { return 0 }
        return limbs.count * 32 - top.leadingZeroBitCount
    }

    /// Wert als Int, falls er hineinpasst.
    var asInt: Int? {
        if limbs.isEmpty { return 0 }
        if limbs.count > 2 { return nil }
        let magnitude = UInt64(limbs[0]) | (limbs.count > 1 ? UInt64(limbs[1]) << 32 : 0)
        if isNegative {
            let limit = UInt64(Int64.max) + 1
            if magnitude > limit { return nil }
            return magnitude == limit ? Int.min : -Int(magnitude)
        }
        return magnitude <= UInt64(Int.max) ? Int(magnitude) : nil
    }

    /// Näherung als Mantisse · 2^Exponent (Mantisse aus den obersten 96 Bit).
    /// So lassen sich auch riesige Zähler/Nenner ohne Überlauf dividieren.
    func approximation() -> (mantissa: Double, exponent: Int) {
        guard !limbs.isEmpty else { return (0, 0) }
        let count = limbs.count
        let take = min(3, count)
        var mantissa: Double = 0
        for i in stride(from: count - 1, through: count - take, by: -1) {
            mantissa = mantissa * 4_294_967_296.0 + Double(limbs[i])
        }
        return (isNegative ? -mantissa : mantissa, (count - take) * 32)
    }

    var doubleValue: Double {
        let (mantissa, exponent) = approximation()
        return mantissa * pow(2.0, Double(exponent))
    }

    // MARK: - Rechenoperationen

    static func + (lhs: BigInt, rhs: BigInt) -> BigInt {
        if lhs.isNegative == rhs.isNegative {
            return BigInt(limbs: addMagnitudes(lhs.limbs, rhs.limbs), isNegative: lhs.isNegative)
        }
        let comparison = compareMagnitudes(lhs.limbs, rhs.limbs)
        if comparison == 0 { return BigInt() }
        if comparison > 0 {
            return BigInt(limbs: subtractMagnitudes(lhs.limbs, rhs.limbs), isNegative: lhs.isNegative)
        }
        return BigInt(limbs: subtractMagnitudes(rhs.limbs, lhs.limbs), isNegative: rhs.isNegative)
    }

    static prefix func - (value: BigInt) -> BigInt {
        BigInt(limbs: value.limbs, isNegative: !value.isNegative)
    }

    static func - (lhs: BigInt, rhs: BigInt) -> BigInt {
        lhs + (-rhs)
    }

    static func * (lhs: BigInt, rhs: BigInt) -> BigInt {
        BigInt(limbs: multiplyMagnitudes(lhs.limbs, rhs.limbs), isNegative: lhs.isNegative != rhs.isNegative)
    }

    /// Ganzzahlige Division, Richtung null gerundet (wie bei Int).
    /// Der Rest hat das Vorzeichen des Dividenden. Divisor darf nicht null sein.
    func quotientAndRemainder(dividingBy divisor: BigInt) -> (quotient: BigInt, remainder: BigInt) {
        let (q, r) = BigInt.divideMagnitudes(limbs, divisor.limbs)
        return (BigInt(limbs: q, isNegative: isNegative != divisor.isNegative),
                BigInt(limbs: r, isNegative: isNegative))
    }

    static func / (lhs: BigInt, rhs: BigInt) -> BigInt {
        lhs.quotientAndRemainder(dividingBy: rhs).quotient
    }

    static func % (lhs: BigInt, rhs: BigInt) -> BigInt {
        lhs.quotientAndRemainder(dividingBy: rhs).remainder
    }

    /// Größter gemeinsamer Teiler (immer ≥ 0).
    static func gcd(_ a: BigInt, _ b: BigInt) -> BigInt {
        var x = a.absoluteValue
        var y = b.absoluteValue
        while !y.isZero {
            (x, y) = (y, x % y)
        }
        return x
    }

    /// Potenz mit nicht-negativem Exponenten (Quadrieren und Multiplizieren).
    func power(_ exponent: Int) -> BigInt {
        precondition(exponent >= 0, "Negativer Exponent bei BigInt.power")
        var result = BigInt(1)
        var base = self
        var e = exponent
        while e > 0 {
            if e & 1 == 1 { result = result * base }
            e >>= 1
            if e > 0 { base = base * base }
        }
        return result
    }

    /// Ganzzahlige k-te Wurzel (abgerundet) einer nicht-negativen Zahl, per Newton-Verfahren.
    func integerRoot(_ k: Int) -> BigInt {
        precondition(k >= 1 && !isNegative)
        if isZero || k == 1 { return self }
        // Startwert 2^⌈bits/k⌉ liegt sicher über der Wurzel; Newton fällt dann monoton.
        var x = BigInt(2).power((bitWidth + k - 1) / k)
        let kBig = BigInt(k)
        let kMinusOne = BigInt(k - 1)
        while true {
            let y = (kMinusOne * x + self / x.power(k - 1)) / kBig
            if y >= x { return x }
            x = y
        }
    }

    /// Exakte k-te Wurzel, falls die Zahl eine perfekte k-te Potenz ist.
    func exactRoot(_ k: Int) -> BigInt? {
        if isNegative { return nil }
        let root = integerRoot(k)
        return root.power(k) == self ? root : nil
    }

    // MARK: - Hilfsfunktionen auf Beträgen

    private static func trim(_ value: inout [UInt32]) {
        while let last = value.last, last == 0 { value.removeLast() }
    }

    /// value = value · multiplier + addend
    private static func multiplyAdd(_ value: inout [UInt32], multiplier: UInt32, addend: UInt32) {
        var carry = UInt64(addend)
        for i in value.indices {
            let t = UInt64(value[i]) * UInt64(multiplier) + carry
            value[i] = UInt32(truncatingIfNeeded: t)
            carry = t >> 32
        }
        if carry > 0 { value.append(UInt32(carry)) }
    }

    /// Teilt value durch einen einzelnen Block und gibt den Rest zurück.
    private static func divideSmall(_ value: inout [UInt32], by divisor: UInt32) -> UInt32 {
        var remainder: UInt64 = 0
        let d = UInt64(divisor)
        for i in stride(from: value.count - 1, through: 0, by: -1) {
            let current = (remainder << 32) | UInt64(value[i])
            value[i] = UInt32(current / d)
            remainder = current % d
        }
        trim(&value)
        return UInt32(remainder)
    }

    static func compareMagnitudes(_ a: [UInt32], _ b: [UInt32]) -> Int {
        if a.count != b.count { return a.count < b.count ? -1 : 1 }
        for i in stride(from: a.count - 1, through: 0, by: -1) where a[i] != b[i] {
            return a[i] < b[i] ? -1 : 1
        }
        return 0
    }

    private static func addMagnitudes(_ a: [UInt32], _ b: [UInt32]) -> [UInt32] {
        let count = max(a.count, b.count)
        var result: [UInt32] = []
        result.reserveCapacity(count + 1)
        var carry: UInt64 = 0
        for i in 0..<count {
            let sum = UInt64(i < a.count ? a[i] : 0) + UInt64(i < b.count ? b[i] : 0) + carry
            result.append(UInt32(truncatingIfNeeded: sum))
            carry = sum >> 32
        }
        if carry > 0 { result.append(UInt32(carry)) }
        return result
    }

    /// a − b, Voraussetzung |a| ≥ |b|.
    private static func subtractMagnitudes(_ a: [UInt32], _ b: [UInt32]) -> [UInt32] {
        var result = a
        var borrow: Int64 = 0
        for i in 0..<a.count {
            let t = Int64(a[i]) - Int64(i < b.count ? b[i] : 0) - borrow
            result[i] = UInt32(truncatingIfNeeded: t)
            borrow = t < 0 ? 1 : 0
        }
        trim(&result)
        return result
    }

    private static func multiplyMagnitudes(_ a: [UInt32], _ b: [UInt32]) -> [UInt32] {
        if a.isEmpty || b.isEmpty { return [] }
        var result = [UInt32](repeating: 0, count: a.count + b.count)
        for i in a.indices {
            let ai = UInt64(a[i])
            if ai == 0 { continue }
            var carry: UInt64 = 0
            for j in b.indices {
                // Maximal (2^32−1)² + 2·(2^32−1) = 2^64 − 1 → passt genau in UInt64.
                let t = ai * UInt64(b[j]) + UInt64(result[i + j]) + carry
                result[i + j] = UInt32(truncatingIfNeeded: t)
                carry = t >> 32
            }
            result[i + b.count] = UInt32(carry)
        }
        trim(&result)
        return result
    }

    /// Verschiebt um s Bits (0…31) nach links; mit extraLimb wird ein zusätzlicher oberer Block angehängt.
    private static func shiftedLeft(_ x: [UInt32], by s: Int, extraLimb: Bool) -> [UInt32] {
        var result = [UInt32](repeating: 0, count: x.count + (extraLimb ? 1 : 0))
        if s == 0 {
            for i in x.indices { result[i] = x[i] }
            return result
        }
        var carry: UInt32 = 0
        for i in x.indices {
            result[i] = (x[i] << UInt32(s)) | carry
            carry = x[i] >> UInt32(32 - s)
        }
        if extraLimb { result[x.count] = carry }
        return result
    }

    /// Division mit Rest auf Beträgen (Knuth, TAOCP Band 2, Algorithmus D).
    static func divideMagnitudes(_ a: [UInt32], _ b: [UInt32]) -> (quotient: [UInt32], remainder: [UInt32]) {
        precondition(!b.isEmpty, "Division durch null")
        if compareMagnitudes(a, b) < 0 { return ([], a) }
        if b.count == 1 {
            var q = a
            let r = divideSmall(&q, by: b[0])
            return (q, r == 0 ? [] : [r])
        }

        let n = b.count
        let m = a.count
        // Normalisieren, sodass das oberste Bit des Divisors gesetzt ist.
        let s = b[n - 1].leadingZeroBitCount
        let vn = shiftedLeft(b, by: s, extraLimb: false)
        var un = shiftedLeft(a, by: s, extraLimb: true)
        var q = [UInt32](repeating: 0, count: m - n + 1)

        let base: UInt64 = 1 << 32
        let vTop = UInt64(vn[n - 1])
        let vNext = UInt64(vn[n - 2])

        for j in stride(from: m - n, through: 0, by: -1) {
            // Quotientenziffer schätzen …
            let numerator = (UInt64(un[j + n]) << 32) | UInt64(un[j + n - 1])
            var qhat = numerator / vTop
            var rhat = numerator % vTop
            // … und korrigieren (höchstens zweimal nötig).
            while qhat >= base || qhat * vNext > ((rhat << 32) | UInt64(un[j + n - 2])) {
                qhat -= 1
                rhat += vTop
                if rhat >= base { break }
            }

            // Multiplizieren und subtrahieren: un[j…j+n] −= qhat · vn
            var borrow: Int64 = 0
            var carry: UInt64 = 0
            for i in 0..<n {
                let product = qhat * UInt64(vn[i]) + carry
                carry = product >> 32
                let t = Int64(un[i + j]) - borrow - Int64(product & 0xFFFF_FFFF)
                un[i + j] = UInt32(truncatingIfNeeded: t)
                borrow = t < 0 ? 1 : 0
            }
            let t = Int64(un[j + n]) - borrow - Int64(carry)
            un[j + n] = UInt32(truncatingIfNeeded: t)

            // Zu viel abgezogen → einmal zurückaddieren.
            if t < 0 {
                qhat -= 1
                var c: UInt64 = 0
                for i in 0..<n {
                    let sum = UInt64(un[i + j]) + UInt64(vn[i]) + c
                    un[i + j] = UInt32(truncatingIfNeeded: sum)
                    c = sum >> 32
                }
                un[j + n] = UInt32(truncatingIfNeeded: UInt64(un[j + n]) + c)
            }
            q[j] = UInt32(qhat)
        }

        // Rest zurück-normalisieren.
        var r = [UInt32](repeating: 0, count: n)
        for i in 0..<n {
            if s == 0 {
                r[i] = un[i]
            } else {
                r[i] = (un[i] >> UInt32(s)) | (un[i + 1] << UInt32(32 - s))
            }
        }
        trim(&q)
        trim(&r)
        return (q, r)
    }
}

// MARK: - Protokolle

extension BigInt: Comparable {
    static func < (lhs: BigInt, rhs: BigInt) -> Bool {
        if lhs.isNegative != rhs.isNegative { return lhs.isNegative }
        let comparison = compareMagnitudes(lhs.limbs, rhs.limbs)
        return lhs.isNegative ? comparison > 0 : comparison < 0
    }
}

extension BigInt: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension BigInt: CustomStringConvertible {
    /// Dezimaldarstellung (ohne Tausendertrennzeichen).
    var description: String {
        if limbs.isEmpty { return "0" }
        var magnitude = limbs
        var chunks: [UInt32] = []
        while !magnitude.isEmpty {
            chunks.append(BigInt.divideSmall(&magnitude, by: 1_000_000_000))
        }
        var text = isNegative ? "-" : ""
        text += String(chunks[chunks.count - 1])
        for chunk in chunks.dropLast().reversed() {
            let part = String(chunk)
            text += String(repeating: "0", count: 9 - part.count) + part
        }
        return text
    }
}
