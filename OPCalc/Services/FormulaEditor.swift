import Foundation

/// Der bearbeitbare Formelzustand: Baum, Cursor und Auswahl.
///
/// Reiner Werttyp ohne UI-Abhängigkeiten → vollständig per Unit-Test prüfbar.
/// Undo/Redo speichert einfach Kopien dieses Structs (billig dank Copy-on-Write).
struct FormulaEditor: Equatable {
    var root: MathRow
    var cursor: CursorPath
    /// Anker der Auswahl (Position in der Cursor-Zeile). Auswahl = Bereich zwischen Anker und Cursor.
    var selectionAnchor: Int?

    init(root: MathRow = MathRow()) {
        self.root = root
        self.cursor = CursorPath(steps: [], offset: root.items.count)
        self.selectionAnchor = nil
    }

    var currentRow: MathRow { root.row(at: cursor.steps) ?? MathRow() }

    /// Ausgewählter Bereich in der Cursor-Zeile (Auswahl geht nie über Strukturgrenzen hinweg).
    var selectionRange: Range<Int>? {
        guard let anchor = selectionAnchor, anchor != cursor.offset else { return nil }
        return min(anchor, cursor.offset)..<max(anchor, cursor.offset)
    }

    // MARK: - Cursor setzen

    mutating func setCursor(_ path: CursorPath) {
        guard root.isValid(path) else { return }
        cursor = path
        selectionAnchor = nil
    }

    // MARK: - Einfügen

    /// Fügt ein einfaches Element (Ziffer, Operator, Konstante …) an der Cursorposition ein.
    /// Eine vorhandene Auswahl wird dabei ersetzt.
    mutating func insert(_ item: MathItem) {
        deleteSelection()
        insertAtCursor(item)
        cursor.offset += 1
    }

    /// Bruch-Taste: Auswahl → Zähler; sonst wird der Operand links vom Cursor zum Zähler
    /// (z. B. „12“ → 12/▢). Danach steht der Cursor im Nenner bzw. im leeren Zähler.
    mutating func insertFraction() {
        var numerator = MathRow(deleteSelection())
        if numerator.isEmpty {
            numerator = MathRow(takeOperandLeftOfCursor())
        }
        let index = cursor.offset
        insertAtCursor(MathItem(.fraction, slots: [numerator, MathRow()]))
        cursor = CursorPath(steps: cursor.steps + [PathStep(item: index, slot: numerator.isEmpty ? 0 : 1)],
                            offset: 0)
    }

    /// Potenz-Tasten (x², xʸ, x⁻¹ …). Die Basis ist das Element links vom Cursor.
    /// Mit Auswahl wird die Auswahl eingeklammert und zur Basis. Ohne Basis entsteht eine
    /// leere Klammer als Basis, in die der Cursor springt.
    mutating func insertPower(exponent: MathRow, cursorInExponent: Bool) {
        let selected = deleteSelection()
        if !selected.isEmpty {
            insertAtCursor(MathItem(.parentheses, slots: [MathRow(selected)]))
            cursor.offset += 1
        } else if !hasBaseLeftOfCursor {
            let index = cursor.offset
            insertAtCursor(MathItem(.parentheses))
            cursor.offset += 1
            insertAtCursor(MathItem(.power, slots: [exponent]))
            cursor = CursorPath(steps: cursor.steps + [PathStep(item: index, slot: 0)], offset: 0)
            return
        }
        let index = cursor.offset
        insertAtCursor(MathItem(.power, slots: [exponent]))
        if cursorInExponent {
            cursor = CursorPath(steps: cursor.steps + [PathStep(item: index, slot: 0)],
                                offset: exponent.items.count)
        } else {
            cursor.offset += 1
        }
    }

    /// Einslot-Strukturen (Wurzel, Klammer, Betrag, Funktion). Auswahl wird zum Inhalt.
    mutating func insertWrapping(_ kind: ItemKind) {
        let selected = deleteSelection()
        let index = cursor.offset
        insertAtCursor(MathItem(kind, slots: [MathRow(selected)]))
        if selected.isEmpty {
            cursor = CursorPath(steps: cursor.steps + [PathStep(item: index, slot: 0)], offset: 0)
        } else {
            cursor.offset += 1
        }
    }

    /// n-te Wurzel: Auswahl wird zum Radikanden, der Cursor steht im Wurzelexponenten.
    mutating func insertNthRoot() {
        let selected = deleteSelection()
        let index = cursor.offset
        insertAtCursor(MathItem(.nthRoot, slots: [MathRow(), MathRow(selected)]))
        cursor = CursorPath(steps: cursor.steps + [PathStep(item: index, slot: 0)], offset: 0)
    }

    // MARK: - Löschen

    /// DEL-Taste. Gibt false zurück, wenn nichts zu löschen war.
    ///
    /// - Auswahl vorhanden → Auswahl löschen.
    /// - Links vom Cursor ein einfaches Element oder eine leere Struktur → löschen.
    /// - Links eine gefüllte Struktur → Cursor springt hinein (nichts geht versehentlich verloren).
    /// - Cursor am Anfang eines Slots → Struktur auflösen, Inhalt bleibt erhalten (3/4 → 3÷4).
    @discardableResult
    mutating func deleteBackward() -> Bool {
        if selectionRange != nil {
            deleteSelection()
            return true
        }
        selectionAnchor = nil
        let row = currentRow

        if cursor.offset > 0 {
            let index = cursor.offset - 1
            let item = row.items[index]
            if item.slots.allSatisfy(\.isEmpty) {
                root.updateRow(at: cursor.steps[...]) { $0.items.remove(at: index) }
                cursor.offset = index
            } else {
                let last = item.slots.count - 1
                cursor = CursorPath(steps: cursor.steps + [PathStep(item: index, slot: last)],
                                    offset: item.slots[last].items.count)
            }
            return true
        }

        guard let step = cursor.steps.last else { return false }
        let parentSteps = Array(cursor.steps.dropLast())
        guard let parentRow = root.row(at: parentSteps) else { return false }
        let item = parentRow.items[step.item]

        var replacement: [MathItem] = []
        var newOffset = step.item
        for (slotIndex, slot) in item.slots.enumerated() {
            // Beim Wurzelexponenten gibt es keine sinnvolle flache Form → er entfällt.
            if item.kind == .nthRoot && slotIndex == 0 { continue }
            if item.kind == .fraction && slotIndex == 1 && !replacement.isEmpty && !slot.isEmpty {
                replacement.append(MathItem(.op(.divide)))
            }
            if slotIndex == step.slot { newOffset = step.item + replacement.count }
            replacement.append(contentsOf: slot.items)
        }
        let itemIndex = step.item
        let newItems = replacement
        root.updateRow(at: parentSteps[...]) { $0.items.replaceSubrange(itemIndex...itemIndex, with: newItems) }
        cursor = CursorPath(steps: parentSteps, offset: newOffset)
        return true
    }

    /// Löscht die Auswahl und gibt die entfernten Elemente zurück.
    @discardableResult
    mutating func deleteSelection() -> [MathItem] {
        guard let range = selectionRange else {
            selectionAnchor = nil
            return []
        }
        var removed: [MathItem] = []
        root.updateRow(at: cursor.steps[...]) { row in
            removed = Array(row.items[range])
            row.items.removeSubrange(range)
        }
        cursor.offset = range.lowerBound
        selectionAnchor = nil
        return removed
    }

    // MARK: - Navigation

    /// ▶: Durch alle Cursorpositionen in Lesereihenfolge (hinein in Strukturen, Slot für Slot, wieder hinaus).
    /// Mit selecting wird die Auswahl innerhalb der aktuellen Zeile erweitert.
    @discardableResult
    mutating func moveRight(selecting: Bool = false) -> Bool {
        if selecting {
            if selectionAnchor == nil { selectionAnchor = cursor.offset }
            guard cursor.offset < currentRow.items.count else { return false }
            cursor.offset += 1
            return true
        }
        if let range = selectionRange {
            cursor.offset = range.upperBound
            selectionAnchor = nil
            return true
        }
        selectionAnchor = nil

        let row = currentRow
        if cursor.offset < row.items.count {
            let item = row.items[cursor.offset]
            if item.isStructure {
                cursor = CursorPath(steps: cursor.steps + [PathStep(item: cursor.offset, slot: 0)], offset: 0)
            } else {
                cursor.offset += 1
            }
            return true
        }
        guard let step = cursor.steps.last else { return false }
        let parentSteps = Array(cursor.steps.dropLast())
        guard let parent = root.row(at: parentSteps) else { return false }
        if step.slot + 1 < parent.items[step.item].slots.count {
            cursor = CursorPath(steps: parentSteps + [PathStep(item: step.item, slot: step.slot + 1)], offset: 0)
        } else {
            cursor = CursorPath(steps: parentSteps, offset: step.item + 1)
        }
        return true
    }

    /// ◀: Spiegelbild von moveRight.
    @discardableResult
    mutating func moveLeft(selecting: Bool = false) -> Bool {
        if selecting {
            if selectionAnchor == nil { selectionAnchor = cursor.offset }
            guard cursor.offset > 0 else { return false }
            cursor.offset -= 1
            return true
        }
        if let range = selectionRange {
            cursor.offset = range.lowerBound
            selectionAnchor = nil
            return true
        }
        selectionAnchor = nil

        let row = currentRow
        if cursor.offset > 0 {
            let index = cursor.offset - 1
            let item = row.items[index]
            if item.isStructure {
                let last = item.slots.count - 1
                cursor = CursorPath(steps: cursor.steps + [PathStep(item: index, slot: last)],
                                    offset: item.slots[last].items.count)
            } else {
                cursor.offset = index
            }
            return true
        }
        guard let step = cursor.steps.last else { return false }
        let parentSteps = Array(cursor.steps.dropLast())
        guard let parent = root.row(at: parentSteps) else { return false }
        if step.slot > 0 {
            let previous = parent.items[step.item].slots[step.slot - 1]
            cursor = CursorPath(steps: parentSteps + [PathStep(item: step.item, slot: step.slot - 1)],
                                offset: previous.items.count)
        } else {
            cursor = CursorPath(steps: parentSteps, offset: step.item)
        }
        return true
    }

    /// ▲/▼: Zähler ↔ Nenner, raus aus dem Exponenten, Wurzelexponent → Radikand,
    /// oder in einen benachbarten Bruch/Exponenten hinein.
    @discardableResult
    mutating func moveVertically(up: Bool) -> Bool {
        selectionAnchor = nil

        // 1) Innerhalb einer Struktur (innerste zuerst)
        for depth in stride(from: cursor.steps.count - 1, through: 0, by: -1) {
            let step = cursor.steps[depth]
            let parentSteps = Array(cursor.steps.prefix(depth))
            guard let parent = root.row(at: parentSteps) else { continue }
            let item = parent.items[step.item]
            let isInnermost = depth == cursor.steps.count - 1

            switch item.kind {
            case .fraction where (up && step.slot == 1) || (!up && step.slot == 0):
                let target = up ? 0 : 1
                let count = item.slots[target].items.count
                cursor = CursorPath(steps: parentSteps + [PathStep(item: step.item, slot: target)],
                                    offset: isInnermost ? min(cursor.offset, count) : count)
                return true
            case .power where !up:
                cursor = CursorPath(steps: parentSteps, offset: step.item + 1)
                return true
            case .nthRoot where !up && step.slot == 0:
                cursor = CursorPath(steps: parentSteps + [PathStep(item: step.item, slot: 1)], offset: 0)
                return true
            default:
                continue
            }
        }

        // 2) Direkt neben einem Bruch oder Exponenten: hineinspringen
        let row = currentRow
        for (index, atEnd) in [(cursor.offset, false), (cursor.offset - 1, true)] where index >= 0 && index < row.items.count {
            let item = row.items[index]
            switch item.kind {
            case .fraction:
                let slot = up ? 0 : 1
                cursor = CursorPath(steps: cursor.steps + [PathStep(item: index, slot: slot)],
                                    offset: atEnd ? item.slots[slot].items.count : 0)
                return true
            case .power where up:
                cursor = CursorPath(steps: cursor.steps + [PathStep(item: index, slot: 0)],
                                    offset: atEnd ? item.slots[0].items.count : 0)
                return true
            default:
                continue
            }
        }
        return false
    }

    // MARK: - Hilfsfunktionen

    private mutating func insertAtCursor(_ item: MathItem) {
        let offset = cursor.offset
        root.updateRow(at: cursor.steps[...]) { $0.items.insert(item, at: offset) }
    }

    /// Gibt es links vom Cursor ein Element, das als Basis einer Potenz taugt?
    private var hasBaseLeftOfCursor: Bool {
        guard cursor.offset > 0 else { return false }
        return !currentRow.items[cursor.offset - 1].kind.isOperator
    }

    /// Entfernt den Operanden links vom Cursor (alles bis zum nächsten Operator) und gibt ihn zurück.
    private mutating func takeOperandLeftOfCursor() -> [MathItem] {
        let items = currentRow.items
        var start = cursor.offset
        while start > 0, !items[start - 1].kind.isOperator {
            start -= 1
        }
        guard start < cursor.offset else { return [] }
        let range = start..<cursor.offset
        root.updateRow(at: cursor.steps[...]) { $0.items.removeSubrange(range) }
        cursor.offset = start
        return Array(items[range])
    }
}
