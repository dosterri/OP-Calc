import Foundation

/// Ergebnis einer Auswertung: exakt (Bruch/Wurzel/π …) oder nur als Dezimalnäherung.
enum Value: Equatable, Sendable {
    case exact(ExactValue)
    case approximate(Double)

    var doubleValue: Double {
        switch self {
        case .exact(let value): return value.doubleValue
        case .approximate(let value): return value
        }
    }

    var isZero: Bool {
        switch self {
        case .exact(let value): return value.isZero
        case .approximate(let value): return value == 0
        }
    }

    var isExact: Bool {
        if case .exact = self { return true }
        return false
    }
}

/// Rechenfehler mit deutschsprachiger Meldung für die Anzeige.
enum MathError: Error, Equatable {
    case divisionByZero
    case notReal
    case overflow
    /// Intern: exaktes Ergebnis wäre zu groß → Auswertung weicht auf Näherung aus.
    case tooLarge
    /// Intern: Ergebnis ist nicht exakt darstellbar → Auswertung weicht auf Näherung aus.
    case notExact
    case missingAns
    case undefined(String)
    case domain(String)

    var message: String {
        switch self {
        case .divisionByZero: return "Division durch null"
        case .notReal: return "Ergebnis ist nicht reell"
        case .overflow: return "Zahl zu groß (Überlauf)"
        case .tooLarge: return "Zahl zu groß – bitte ≈ verwenden"
        case .notExact: return "Nicht exakt darstellbar"
        case .missingAns: return "Noch kein Ergebnis für Ans vorhanden"
        case .undefined(let text): return text
        case .domain(let text): return text
        }
    }
}

/// Winkelmaß für trigonometrische Funktionen.
enum AngleMode: String, Codable, Sendable {
    case radians
    case degrees

    var shortName: String { self == .radians ? "RAD" : "DEG" }
}
