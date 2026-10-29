import Foundation
import Observation

/// Eingaben der Bereiche Gleichungen, Stochastik und DGL. Liegt in der RootView,
/// damit beim Wechsel über das Modus-Menü nichts verloren geht (nur für die laufende Sitzung).
@Observable
final class WorkspaceState {
    // MARK: Gleichungen (AK-03)
    enum EquationKind: String, CaseIterable, Identifiable {
        case system, polynomial, general
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: return "LGS"
            case .polynomial: return "Polynom"
            case .general: return "Gleichung"
            }
        }
    }

    /// Größte Matrix: 6 Gleichungen mit 6 Unbekannten (passt noch auf den Bildschirm).
    static let maxSize = 6
    /// Höchster Polynomgrad
    static let maxDegree = 6

    var equationKind: EquationKind = .system
    var equationCount = 3
    var unknownCount = 3
    /// 6 Zeilen × 7 Spalten; Spalte 6 ist die rechte Seite
    var matrix: [[MathRow]] = Array(repeating: Array(repeating: MathRow(), count: maxSize + 1), count: maxSize)
    var degree = 2
    /// coefficients[k] gehört zu xᵏ
    var coefficients: [MathRow] = Array(repeating: MathRow(), count: maxDegree + 1)
    var left = MathRow()
    var right = MathRow()
    var searchFrom = "−10"
    var searchTo = "10"

    // MARK: Stochastik (AK-04)
    var stochasticsTab = 0
    var distribution = 0
    var parameters: [String] = ["10", "0,5", "0", "1"]
    var queryKind = 1
    var queryA = "3"
    var queryB = "6"
    var combinatoricsN = "49"
    var combinatoricsK = "6"
    var listX = ""
    var listY = ""
    var regressionModel: Regression.Model = .linear

    // MARK: DGL (AK-05)
    var odeKind = 0
    var odeFirst = MathRow()
    var odeSecond = MathRow()
    var odeSystemX = MathRow()
    var odeSystemY = MathRow()
    var odeX0 = "0"
    var odeY0 = "1"
    var odeYPrime0 = "0"
    var odeTEnd = "20"
    var odeEvaluateAt = ""
}
