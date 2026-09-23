import Foundation

// Der Editor-Baum: das, was man sieht und bearbeitet.
//
// Eine Zeile (MathRow) ist eine Liste von Elementen (MathItem). Strukturelemente wie Brüche
// haben „Slots“, und jeder Slot ist wieder eine Zeile. Der Baum darf unfertig sein
// (leere Slots, „3 +“) – erst der Parser prüft, ob sich daraus eine Rechnung ergibt.

enum MathOperator: String, Codable, Hashable, Sendable, CaseIterable {
    case plus, minus, times, divide

    var symbol: String {
        switch self {
        case .plus: return "+"
        case .minus: return "−"
        case .times: return "×"
        case .divide: return "÷"
        }
    }
}

enum MathConstant: String, Codable, Hashable, Sendable {
    case pi, e

    var symbol: String { self == .pi ? "π" : "e" }
}

enum MathFunction: String, Codable, Hashable, Sendable, CaseIterable {
    case sin, cos, tan, asin, acos, atan, ln, log

    var displayName: String {
        switch self {
        case .sin: return "sin"
        case .cos: return "cos"
        case .tan: return "tan"
        case .asin: return "sin⁻¹"
        case .acos: return "cos⁻¹"
        case .atan: return "tan⁻¹"
        case .ln: return "ln"
        case .log: return "log"
        }
    }
}

enum ItemKind: Codable, Hashable, Sendable {
    /// "0"–"9" oder "." (Dezimaltrennzeichen, angezeigt als Komma)
    case digit(String)
    case op(MathOperator)
    case constant(MathConstant)
    case variable(String)
    case ans
    /// Nachgestelltes „!“
    case factorial
    /// Slots: Zähler, Nenner
    case fraction
    /// Slot: Exponent. Die Basis ist das Element links davon.
    case power
    /// Slot: Radikand
    case squareRoot
    /// Slots: Wurzelexponent, Radikand
    case nthRoot
    /// Slot: Inhalt
    case parentheses
    /// Slot: Inhalt (Betrag |x|)
    case absolute
    /// Slot: Argument
    case function(MathFunction)

    var slotCount: Int {
        switch self {
        case .fraction, .nthRoot: return 2
        case .power, .squareRoot, .parentheses, .absolute, .function: return 1
        case .digit, .op, .constant, .variable, .ans, .factorial: return 0
        }
    }

    var isOperator: Bool {
        if case .op = self { return true }
        return false
    }

    var isDigit: Bool {
        if case .digit = self { return true }
        return false
    }
}

struct MathItem: Codable, Hashable, Sendable {
    var kind: ItemKind
    var slots: [MathRow]

    init(_ kind: ItemKind, slots: [MathRow]? = nil) {
        self.kind = kind
        self.slots = slots ?? Array(repeating: MathRow(), count: kind.slotCount)
    }

    var isStructure: Bool { !slots.isEmpty }
}

struct MathRow: Codable, Hashable, Sendable {
    var items: [MathItem]

    init(_ items: [MathItem] = []) {
        self.items = items
    }

    var isEmpty: Bool { items.isEmpty }

    /// Baut eine flache Zeile aus Text – praktisch für Tests und feste Inhalte.
    /// Erkennt Ziffern, „.“/„,“, + − × ÷ (auch - * /), π, e, ! sowie x und y als Variablen.
    init(linear text: String) {
        var result: [MathItem] = []
        for character in text {
            switch character {
            case "0"..."9": result.append(MathItem(.digit(String(character))))
            case ".", ",": result.append(MathItem(.digit(".")))
            case "+": result.append(MathItem(.op(.plus)))
            case "-", "−": result.append(MathItem(.op(.minus)))
            case "*", "×", "·": result.append(MathItem(.op(.times)))
            case "/", "÷": result.append(MathItem(.op(.divide)))
            case "π": result.append(MathItem(.constant(.pi)))
            case "e": result.append(MathItem(.constant(.e)))
            case "!": result.append(MathItem(.factorial))
            case "x", "y": result.append(MathItem(.variable(String(character))))
            default: continue
            }
        }
        items = result
    }

    /// Zahl als Ziffernfolge (nicht-negativ).
    static func digits(_ value: BigInt) -> [MathItem] {
        value.absoluteValue.description.map { MathItem(.digit(String($0))) }
    }

    /// Einzeilige Textdarstellung, z. B. „13/12“, „(√6−√2)/4“, „2^(−1)“.
    var linearText: String {
        items.map(\.linearText).joined()
    }

    /// Klammert den Text, wenn die Zeile einen Operator enthält.
    fileprivate var groupedText: String {
        items.contains(where: { $0.kind.isOperator }) ? "(\(linearText))" : linearText
    }
}

extension MathItem {
    var linearText: String {
        switch kind {
        case .digit(let d): return d == "." ? "," : d
        case .op(let o): return o.symbol
        case .constant(let c): return c.symbol
        case .variable(let v): return v
        case .ans: return "Ans"
        case .factorial: return "!"
        case .fraction: return "\(slots[0].groupedText)/\(slots[1].groupedText)"
        case .power: return "^\(slots[0].groupedText)"
        case .squareRoot: return "√\(slots[0].groupedText)"
        case .nthRoot: return "\(slots[0].groupedText)√\(slots[1].groupedText)"
        case .parentheses: return "(\(slots[0].linearText))"
        case .absolute: return "|\(slots[0].linearText)|"
        case .function(let f): return "\(f.displayName)(\(slots[0].linearText))"
        }
    }
}
