import Foundation

/// Alle Tasten der eigenen Tastatur.
enum CalculatorKey: Hashable {
    case digit(String)
    case decimalSeparator
    case op(MathOperator)
    case constant(MathConstant)
    case ans
    case fraction
    case square
    case power
    case inverse
    case squareRoot
    case nthRoot
    case parentheses
    case absolute
    case factorial
    case function(MathFunction)
    /// eˣ
    case expPower
    /// 10ˣ
    case tenPower
    /// ×10ˣ (wissenschaftliche Schreibweise)
    case timesTenPower
    case delete
    case clear
    case left, right, up, down
    case toggleSelection
    case undo, redo
    case toggleDecimal
    case toggleAngleMode
    case switchLayer
    case equals
    case approximate
    /// Öffnet das Menü der Bereiche; die Tastatur zeigt dafür ein Menü statt einer Taste.
    case modeMenu

    /// Tastenebenen der Tastatur.
    enum Layer {
        case basic
        case functions
    }

    /// Ziffern werden beim Undo zu einem Schritt zusammengefasst.
    var groupsWithPreviousDigit: Bool {
        switch self {
        case .digit, .decimalSeparator: return true
        default: return false
        }
    }

    /// Nach diesen Tasten springt die Funktionsebene automatisch zurück auf „123“.
    var returnsToBasicLayer: Bool {
        switch self {
        case .delete, .clear, .left, .right, .up, .down, .toggleSelection, .undo, .redo,
             .toggleDecimal, .toggleAngleMode, .switchLayer, .modeMenu:
            return false
        default:
            return true
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .digit(let d): return d
        case .decimalSeparator: return "Komma"
        case .op(.plus): return "plus"
        case .op(.minus): return "minus"
        case .op(.times): return "mal"
        case .op(.divide): return "geteilt durch"
        case .constant(.pi): return "Pi"
        case .constant(.e): return "Eulersche Zahl"
        case .ans: return "Letztes Ergebnis"
        case .fraction: return "Bruch"
        case .square: return "Quadrat"
        case .power: return "Potenz"
        case .inverse: return "Kehrwert"
        case .squareRoot: return "Quadratwurzel"
        case .nthRoot: return "n-te Wurzel"
        case .parentheses: return "Klammer"
        case .absolute: return "Betrag"
        case .factorial: return "Fakultät"
        case .function(let f): return f.displayName
        case .expPower: return "e hoch x"
        case .tenPower: return "10 hoch x"
        case .timesTenPower: return "mal 10 hoch x"
        case .delete: return "Löschen"
        case .clear: return "Alles löschen"
        case .left: return "Cursor links"
        case .right: return "Cursor rechts"
        case .up: return "Cursor hoch"
        case .down: return "Cursor runter"
        case .toggleSelection: return "Markieren"
        case .undo: return "Rückgängig"
        case .redo: return "Wiederholen"
        case .toggleDecimal: return "Bruch oder Dezimalzahl"
        case .toggleAngleMode: return "Winkelmaß umschalten"
        case .switchLayer: return "Tastenebene wechseln"
        case .equals: return "Ist gleich"
        case .approximate: return "Ungefähr, als Dezimalzahl"
        case .modeMenu: return "Bereich wählen"
        }
    }
}
