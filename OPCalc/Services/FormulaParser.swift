import Foundation

/// Fehler beim Übersetzen des Editor-Baums. Der Pfad zeigt auf die Problemstelle,
/// damit der Cursor direkt dorthin springen kann (z. B. in einen leeren Nenner).
struct ParseError: Error, Equatable {
    let message: String
    let path: CursorPath?
}

/// Übersetzt den Editor-Baum (MathRow) in den Mathe-AST (Expr).
///
/// Grammatik je Zeile (rekursiver Abstieg):
///   Summe     := Produkt (("+" | "−") Produkt)*
///   Produkt   := Vorzeichen (("×" | "÷") Vorzeichen | implizit Postfix)*
///   Vorzeichen:= ("−" | "+") Vorzeichen | Postfix         → −2² = −(2²)
///   Postfix   := Primär (Exponent | "!")*
///   Primär    := Zahl | Konstante | Variable | Ans | Bruch | Wurzel | Klammer | Betrag | Funktion
/// Slots (Zähler, Exponent, Klammerinhalt …) werden jeweils als eigene Summe geparst.
enum FormulaParser {
    static func parse(_ row: MathRow) throws -> Expr {
        var parser = RowParser(items: row.items, path: [])
        return try parser.parseComplete()
    }
}

private struct RowParser {
    let items: [MathItem]
    let path: [PathStep]
    var index = 0

    init(items: [MathItem], path: [PathStep]) {
        self.items = items
        self.path = path
    }

    mutating func parseComplete() throws -> Expr {
        guard !items.isEmpty else { throw error("Leeres Feld", at: 0) }
        let expression = try parseSum()
        if index < items.count { throw error("Unerwartetes Zeichen", at: index) }
        return expression
    }

    private func error(_ message: String, at offset: Int) -> ParseError {
        ParseError(message: message, path: CursorPath(steps: path, offset: offset))
    }

    private func parseSlot(_ slot: Int, of item: MathItem, at itemIndex: Int) throws -> Expr {
        var parser = RowParser(items: item.slots[slot].items,
                               path: path + [PathStep(item: itemIndex, slot: slot)])
        return try parser.parseComplete()
    }

    private mutating func parseSum() throws -> Expr {
        var left = try parseProduct()
        while index < items.count, case .op(let o) = items[index].kind, o == .plus || o == .minus {
            index += 1
            let right = try parseProduct()
            left = o == .plus ? .add(left, right) : .subtract(left, right)
        }
        return left
    }

    private mutating func parseProduct() throws -> Expr {
        var left = try parseSigned()
        while index < items.count {
            let kind = items[index].kind
            if case .op(let o) = kind, o == .times || o == .divide {
                index += 1
                let right = try parseSigned()
                left = o == .times ? .multiply(left, right) : .divide(left, right)
            } else if startsOperand(kind) {
                // Implizite Multiplikation: 2π, 3(x+1), ½√2
                let right = try parsePostfix()
                left = .multiply(left, right)
            } else {
                break
            }
        }
        return left
    }

    private mutating func parseSigned() throws -> Expr {
        guard index < items.count else { throw error("Operand fehlt", at: index) }
        if case .op(let o) = items[index].kind {
            switch o {
            case .minus:
                index += 1
                return .negate(try parseSigned())
            case .plus:
                index += 1
                return try parseSigned()
            case .times, .divide:
                throw error("Operand fehlt vor „\(o.symbol)“", at: index)
            }
        }
        return try parsePostfix()
    }

    private mutating func parsePostfix() throws -> Expr {
        var base = try parsePrimary()
        while index < items.count {
            let item = items[index]
            switch item.kind {
            case .power:
                let exponent = try parseSlot(0, of: item, at: index)
                index += 1
                base = .power(base, exponent)
            case .factorial:
                index += 1
                base = .factorial(base)
            default:
                return base
            }
        }
        return base
    }

    private mutating func parsePrimary() throws -> Expr {
        guard index < items.count else { throw error("Operand fehlt", at: index) }
        let start = index
        let item = items[start]
        switch item.kind {
        case .digit:
            var text = ""
            while index < items.count, case .digit(let d) = items[index].kind {
                text += d
                index += 1
            }
            guard let value = Rational(decimal: text) else { throw error("Ungültige Zahl", at: start) }
            return .number(value)
        case .constant(let c):
            index += 1
            return .constant(c)
        case .variable(let name):
            index += 1
            return .variable(name)
        case .ans:
            index += 1
            return .ans
        case .fraction:
            let numerator = try parseSlot(0, of: item, at: start)
            let denominator = try parseSlot(1, of: item, at: start)
            index += 1
            return .divide(numerator, denominator)
        case .squareRoot:
            let radicand = try parseSlot(0, of: item, at: start)
            index += 1
            return .root(degree: .number(2), radicand: radicand)
        case .nthRoot:
            let degree = try parseSlot(0, of: item, at: start)
            let radicand = try parseSlot(1, of: item, at: start)
            index += 1
            return .root(degree: degree, radicand: radicand)
        case .parentheses:
            let inner = try parseSlot(0, of: item, at: start)
            index += 1
            return inner
        case .absolute:
            let inner = try parseSlot(0, of: item, at: start)
            index += 1
            return .absolute(inner)
        case .function(let f):
            let argument = try parseSlot(0, of: item, at: start)
            index += 1
            return .function(f, argument)
        case .power:
            throw error("Basis fehlt vor dem Exponenten", at: start)
        case .factorial:
            throw error("Zahl fehlt vor „!“", at: start)
        case .op:
            throw error("Operand fehlt", at: start)
        }
    }

    private func startsOperand(_ kind: ItemKind) -> Bool {
        switch kind {
        case .op, .power, .factorial: return false
        default: return true
        }
    }
}
