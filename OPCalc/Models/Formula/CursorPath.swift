import Foundation

/// Ein Schritt in den Baum hinein: „Element Nr. item, dort Slot Nr. slot“.
struct PathStep: Codable, Hashable, Sendable {
    var item: Int
    var slot: Int
}

/// Cursorposition als Pfad: Schritte von der Wurzelzeile bis zur Zielzeile,
/// dann die Position zwischen den Elementen dieser Zeile (0 … Anzahl Elemente).
///
/// Beispiel: „im Nenner des 3. Elements, nach dem 2. Zeichen“ = steps [(2, 1)], offset 2.
struct CursorPath: Codable, Hashable, Sendable {
    var steps: [PathStep]
    var offset: Int

    static let start = CursorPath(steps: [], offset: 0)
}

extension MathRow {
    /// Die Zeile am Ende des Pfads, oder nil, wenn der Pfad nicht (mehr) existiert.
    func row(at steps: [PathStep]) -> MathRow? {
        var current = self
        for step in steps {
            guard step.item >= 0, step.item < current.items.count,
                  step.slot >= 0, step.slot < current.items[step.item].slots.count else { return nil }
            current = current.items[step.item].slots[step.slot]
        }
        return current
    }

    /// Ändert die Zeile am Ende des Pfads an Ort und Stelle.
    mutating func updateRow(at steps: ArraySlice<PathStep>, _ body: (inout MathRow) -> Void) {
        guard let first = steps.first else {
            body(&self)
            return
        }
        items[first.item].slots[first.slot].updateRow(at: steps.dropFirst(), body)
    }

    /// Prüft, ob ein Cursor gültig in diesen Baum zeigt.
    func isValid(_ cursor: CursorPath) -> Bool {
        guard let target = row(at: cursor.steps) else { return false }
        return cursor.offset >= 0 && cursor.offset <= target.items.count
    }
}
