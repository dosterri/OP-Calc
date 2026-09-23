import Foundation
import SwiftData

/// Ein Eintrag im Verlauf. Eingabe und Ergebnis werden als JSON des Formelbaums gespeichert,
/// damit eine alte Rechnung später wieder vollständig bearbeitbar geladen werden kann.
@Model
final class CalculationRecord {
    var createdAt: Date
    var inputData: Data
    var resultData: Data
    /// Kurzer Text des Ergebnisses (für Barrierefreiheit und Kopieren)
    var resultText: String
    /// true = exaktes Ergebnis, false = Näherung
    var isExact: Bool

    init(createdAt: Date = .now, input: MathRow, result: MathRow, resultText: String, isExact: Bool) {
        self.createdAt = createdAt
        self.inputData = (try? JSONEncoder().encode(input)) ?? Data()
        self.resultData = (try? JSONEncoder().encode(result)) ?? Data()
        self.resultText = resultText
        self.isExact = isExact
    }

    var input: MathRow {
        (try? JSONDecoder().decode(MathRow.self, from: inputData)) ?? MathRow()
    }

    var result: MathRow {
        (try? JSONDecoder().decode(MathRow.self, from: resultData)) ?? MathRow()
    }
}
