import Foundation
import SwiftData

/// Eine gespeicherte Funktion im Graphen (2D: f(x), 3D: z = f(x, y)).
/// Alle Eigenschaften haben Standardwerte, damit SwiftData beim Update migriert (Leitfaden §5).
@Model
final class GraphFunction {
    var uid: UUID = UUID()
    var order: Int = 0
    /// Formelbaum als JSON, wie im Verlauf – bleibt vollständig bearbeitbar.
    var formulaData: Data = Data()
    var colorIndex: Int = 0
    var isVisible: Bool = true
    var showsDerivative: Bool = false
    /// "2d" oder "3d"
    var kind: String = "2d"

    init(order: Int, formula: MathRow, colorIndex: Int, kind: String) {
        self.order = order
        self.formulaData = (try? JSONEncoder().encode(formula)) ?? Data()
        self.colorIndex = colorIndex
        self.kind = kind
    }

    var formula: MathRow {
        get { (try? JSONDecoder().decode(MathRow.self, from: formulaData)) ?? MathRow() }
        set { formulaData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// Funktionsname nach Position: f, g, h, p, q, r.
    static func name(at index: Int) -> String {
        let names = ["f", "g", "h", "p", "q", "r"]
        return index < names.count ? names[index] : "f\(index + 1)"
    }
}
