import Foundation

/// Übersetzt Formeln aus dem Editor für die numerischen Bereiche (Graph, Löser, DGL).
enum FormulaCompiler {
    enum Failure: Error, Equatable {
        case parse(ParseError)
        case unknownVariable(String)

        var message: String {
            switch self {
            case .parse(let error): return error.message
            case .unknownVariable(let name): return "„\(name)“ ist hier nicht erlaubt"
            }
        }

        var path: CursorPath? {
            if case .parse(let error) = self { return error.path }
            return nil
        }
    }

    /// Parst die Formel und prüft, dass nur die erlaubten Variablen vorkommen.
    static func expression(_ row: MathRow, allowed: Set<String>) -> Result<Expr, Failure> {
        do {
            let expression = try FormulaParser.parse(row)
            if let unknown = expression.variableNames.subtracting(allowed).sorted().first {
                return .failure(.unknownVariable(unknown))
            }
            return .success(expression)
        } catch let error as ParseError {
            return .failure(.parse(error))
        } catch {
            return .failure(.parse(ParseError(message: "Formel unvollständig", path: nil)))
        }
    }

    /// Zahl aus einem Textfeld: „2,5“, „−3“, „π/2“, „1/3“, „2e“. nil bei ungültiger Eingabe.
    static func number(_ text: String, angleMode: AngleMode = .radians) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "pi", with: "π")
        guard !cleaned.isEmpty else { return nil }
        guard case .success(let parsed) = Self.expression(MathRow(linear: cleaned), allowed: []) else { return nil }
        let value = NumericEvaluator(angleMode: angleMode).value(parsed)
        return value.isFinite ? value : nil
    }
}
