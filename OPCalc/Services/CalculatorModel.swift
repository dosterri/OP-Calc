import Foundation
import Observation
import SwiftData

/// Zentraler Zustand des Rechners: Formel-Editor, Ergebnis, Undo/Redo, Tastenebene.
/// Die Views rufen nur press(_:context:) auf; hier wird entschieden, was passiert.
@Observable
final class CalculatorModel {
    private(set) var editor = FormulaEditor()
    private(set) var result: CalculationResult?
    private(set) var errorMessage: String?
    /// Ergebnis stammt von einer älteren Version der Formel (wird dann blasser angezeigt).
    private(set) var resultIsStale = false
    private(set) var showsDecimal = false
    private(set) var isSelecting = false
    private(set) var layer: CalculatorKey.Layer = .basic
    private(set) var angleMode: AngleMode

    /// Zähler, die bei jeder Taste bzw. jedem Fehler hochzählen → Auslöser für haptisches Feedback.
    private(set) var feedbackTick = 0
    private(set) var errorTick = 0

    private var undoStack: [FormulaEditor] = []
    private var redoStack: [FormulaEditor] = []
    private var lastEditWasDigit = false
    private var ans: Value?
    private var lastSavedInput: MathRow?

    private static let undoLimit = 200
    private static let angleModeKey = "angleMode"

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.angleModeKey)
        angleMode = stored.flatMap(AngleMode.init(rawValue:)) ?? .radians
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Tasten

    func press(_ key: CalculatorKey, context: ModelContext?) {
        switch key {
        case .digit(let d):
            edit(groupingDigits: true) { $0.insert(MathItem(.digit(d))); return true }
        case .decimalSeparator:
            edit(groupingDigits: true) { $0.insert(MathItem(.digit("."))); return true }
        case .op(let o):
            edit { $0.insert(MathItem(.op(o))); return true }
        case .constant(let c):
            edit { $0.insert(MathItem(.constant(c))); return true }
        case .ans:
            edit { $0.insert(MathItem(.ans)); return true }
        case .factorial:
            edit { $0.insert(MathItem(.factorial)); return true }
        case .fraction:
            edit { $0.insertFraction(); return true }
        case .square:
            edit { $0.insertPower(exponent: MathRow(linear: "2"), cursorInExponent: false); return true }
        case .power:
            edit { $0.insertPower(exponent: MathRow(), cursorInExponent: true); return true }
        case .inverse:
            edit { $0.insertPower(exponent: MathRow(linear: "−1"), cursorInExponent: false); return true }
        case .squareRoot:
            edit { $0.insertWrapping(.squareRoot); return true }
        case .nthRoot:
            edit { $0.insertNthRoot(); return true }
        case .parentheses:
            edit { $0.insertWrapping(.parentheses); return true }
        case .absolute:
            edit { $0.insertWrapping(.absolute); return true }
        case .function(let f):
            edit { $0.insertWrapping(.function(f)); return true }
        case .expPower:
            edit {
                $0.insert(MathItem(.constant(.e)))
                $0.insertPower(exponent: MathRow(), cursorInExponent: true)
                return true
            }
        case .tenPower:
            edit {
                for item in MathRow(linear: "10").items { $0.insert(item) }
                $0.insertPower(exponent: MathRow(), cursorInExponent: true)
                return true
            }
        case .timesTenPower:
            edit {
                for item in MathRow(linear: "×10").items { $0.insert(item) }
                $0.insertPower(exponent: MathRow(), cursorInExponent: true)
                return true
            }
        case .delete:
            edit { $0.deleteBackward() }
        case .clear:
            clearAll()
        case .left:
            let selecting = isSelecting
            navigate { $0.moveLeft(selecting: selecting) }
        case .right:
            let selecting = isSelecting
            navigate { $0.moveRight(selecting: selecting) }
        case .up:
            navigate { $0.moveVertically(up: true) }
        case .down:
            navigate { $0.moveVertically(up: false) }
        case .toggleSelection:
            isSelecting.toggle()
            if !isSelecting { editor.selectionAnchor = nil }
            feedbackTick += 1
        case .undo:
            undo()
        case .redo:
            redo()
        case .toggleDecimal:
            guard result != nil else { return fail() }
            showsDecimal.toggle()
            feedbackTick += 1
        case .toggleAngleMode:
            angleMode = angleMode == .radians ? .degrees : .radians
            UserDefaults.standard.set(angleMode.rawValue, forKey: Self.angleModeKey)
            feedbackTick += 1
        case .switchLayer:
            layer = layer == .basic ? .functions : .basic
            feedbackTick += 1
        case .equals:
            evaluate(approximately: false, context: context)
        case .approximate:
            evaluate(approximately: true, context: context)
        case .modeMenu:
            // Das Menü öffnet die Tastatur selbst; hier gibt es nichts zu tun.
            break
        }

        if key.returnsToBasicLayer { layer = .basic }
    }

    /// Cursor per Antippen in der Formel setzen.
    func setCursor(_ path: CursorPath) {
        editor.setCursor(path)
        isSelecting = false
        lastEditWasDigit = false
        feedbackTick += 1
    }

    /// Rechnung aus dem Verlauf wieder in den Editor laden (rückgängig machbar).
    func load(_ record: CalculationRecord) {
        pushUndo(editor)
        editor = FormulaEditor(root: record.input)
        result = nil
        errorMessage = nil
        resultIsStale = false
        isSelecting = false
        lastEditWasDigit = false
        feedbackTick += 1
    }

    // MARK: - Bearbeiten, Undo/Redo

    /// Führt eine Änderung auf einer Kopie aus und übernimmt sie nur bei Erfolg.
    private func edit(groupingDigits: Bool = false, _ change: (inout FormulaEditor) -> Bool) {
        var copy = editor
        guard change(&copy) else { return fail() }
        if copy.root != editor.root {
            // Aufeinanderfolgende Ziffern bilden einen einzigen Undo-Schritt.
            if !(groupingDigits && lastEditWasDigit) { pushUndo(editor) }
            redoStack.removeAll()
            markFormulaChanged()
        }
        editor = copy
        lastEditWasDigit = groupingDigits
        isSelecting = false
        feedbackTick += 1
    }

    private func navigate(_ move: (inout FormulaEditor) -> Bool) {
        var copy = editor
        guard move(&copy) else { return fail() }
        editor = copy
        lastEditWasDigit = false
        feedbackTick += 1
    }

    private func pushUndo(_ state: FormulaEditor) {
        undoStack.append(state)
        if undoStack.count > Self.undoLimit { undoStack.removeFirst() }
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return fail() }
        redoStack.append(editor)
        editor = previous
        markFormulaChanged()
        lastEditWasDigit = false
        feedbackTick += 1
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return fail() }
        pushUndo(editor)
        editor = next
        markFormulaChanged()
        lastEditWasDigit = false
        feedbackTick += 1
    }

    private func clearAll() {
        if !editor.root.isEmpty { pushUndo(editor) }
        redoStack.removeAll()
        editor = FormulaEditor()
        result = nil
        errorMessage = nil
        resultIsStale = false
        showsDecimal = false
        isSelecting = false
        lastEditWasDigit = false
        feedbackTick += 1
    }

    private func markFormulaChanged() {
        if result != nil { resultIsStale = true }
        errorMessage = nil
    }

    private func fail() {
        errorTick += 1
    }

    // MARK: - Auswerten

    private func evaluate(approximately: Bool, context: ModelContext?) {
        do {
            let expression = try FormulaParser.parse(editor.root)
            let evaluator = Evaluator(angleMode: angleMode, ans: ans)
            let value = try evaluator.evaluate(expression)
            let formatted = ResultFormatter.format(value)
            result = formatted
            showsDecimal = approximately || formatted.exactRow == nil
            resultIsStale = false
            errorMessage = nil
            ans = value
            lastEditWasDigit = false
            save(formatted, context: context)
            feedbackTick += 1
        } catch let error as ParseError {
            errorMessage = error.message
            if let path = error.path { editor.setCursor(path) }
            fail()
        } catch let error as MathError {
            errorMessage = error.message
            fail()
        } catch {
            errorMessage = "Unbekannter Fehler"
            fail()
        }
    }

    private func save(_ formatted: CalculationResult, context: ModelContext?) {
        guard let context, lastSavedInput != editor.root else { return }
        let record = CalculationRecord(input: editor.root,
                                       result: formatted.exactRow ?? formatted.decimalRow,
                                       resultText: formatted.exactText ?? formatted.decimalText,
                                       isExact: formatted.exactRow != nil)
        context.insert(record)
        lastSavedInput = editor.root
    }
}
