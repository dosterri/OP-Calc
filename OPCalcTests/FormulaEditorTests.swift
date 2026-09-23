import XCTest
@testable import OPCalc

final class FormulaEditorTests: XCTestCase {
    private func type(_ text: String, into editor: inout FormulaEditor) {
        for item in MathRow(linear: text).items { editor.insert(item) }
    }

    private func path(_ steps: (Int, Int)..., offset: Int) -> CursorPath {
        CursorPath(steps: steps.map { PathStep(item: $0.0, slot: $0.1) }, offset: offset)
    }

    func testTypingAppendsAtCursor() {
        var editor = FormulaEditor()
        type("12+3", into: &editor)
        XCTAssertEqual(editor.root.linearText, "12+3")
        XCTAssertEqual(editor.cursor, path(offset: 4))
    }

    /// Operator mitten in einen bestehenden Term einfügen, ohne etwas zu löschen.
    func testInsertOperatorInTheMiddle() {
        var editor = FormulaEditor()
        type("34", into: &editor)
        editor.setCursor(path(offset: 1))
        type("+", into: &editor)
        XCTAssertEqual(editor.root.linearText, "3+4")
        XCTAssertEqual(editor.cursor.offset, 2)
    }

    func testFractionTakesPrecedingNumberAsNumerator() {
        var editor = FormulaEditor()
        type("2+12", into: &editor)
        editor.insertFraction()
        XCTAssertEqual(editor.root.items.count, 3)
        XCTAssertEqual(editor.cursor, path((2, 1), offset: 0), "Cursor muss im Nenner stehen")
        type("5", into: &editor)
        XCTAssertEqual(editor.root.linearText, "2+12/5")
    }

    func testFractionWithoutOperandPutsCursorInNumerator() {
        var editor = FormulaEditor()
        type("2+", into: &editor)
        editor.insertFraction()
        XCTAssertEqual(editor.cursor, path((2, 0), offset: 0))
    }

    func testSelectionBecomesNumerator() {
        var editor = FormulaEditor()
        type("1+2", into: &editor)
        editor.moveLeft(selecting: true)
        editor.moveLeft(selecting: true)
        editor.moveLeft(selecting: true)
        XCTAssertEqual(editor.selectionRange, 0..<3)
        editor.insertFraction()
        XCTAssertEqual(editor.root.linearText, "(1+2)/")
        XCTAssertEqual(editor.cursor, path((0, 1), offset: 0))
    }

    func testRightArrowWalksThroughFraction() {
        var editor = FormulaEditor(root: row(frac("1", "2")))
        editor.setCursor(.start)
        editor.moveRight()                                   // in den Zähler
        XCTAssertEqual(editor.cursor, path((0, 0), offset: 0))
        editor.moveRight()                                   // hinter die 1
        editor.moveRight()                                   // in den Nenner
        XCTAssertEqual(editor.cursor, path((0, 1), offset: 0))
        editor.moveRight()
        editor.moveRight()                                   // hinter den Bruch
        XCTAssertEqual(editor.cursor, path(offset: 1))
        XCTAssertFalse(editor.moveRight(), "Am Ende geht es nicht weiter")
    }

    func testLeftArrowWalksBackIntoDenominator() {
        var editor = FormulaEditor(root: row(frac("1", "23")))
        editor.moveLeft()
        XCTAssertEqual(editor.cursor, path((0, 1), offset: 2))
        editor.moveLeft()
        editor.moveLeft()
        editor.moveLeft()                                    // vom Nennerbeginn ans Zählerende
        XCTAssertEqual(editor.cursor, path((0, 0), offset: 1))
        editor.moveLeft()
        editor.moveLeft()                                    // vor den Bruch
        XCTAssertEqual(editor.cursor, path(offset: 0))
    }

    func testUpDownSwitchesNumeratorAndDenominator() {
        var editor = FormulaEditor(root: row(frac("12", "3")))
        editor.setCursor(path((0, 0), offset: 1))
        editor.moveVertically(up: false)
        XCTAssertEqual(editor.cursor, path((0, 1), offset: 1))
        editor.moveVertically(up: true)
        XCTAssertEqual(editor.cursor, path((0, 0), offset: 1))
    }

    func testDownLeavesExponent() {
        var editor = FormulaEditor(root: row(lin("2"), sup("10")))
        editor.setCursor(path((1, 0), offset: 1))
        editor.moveVertically(up: false)
        XCTAssertEqual(editor.cursor, path(offset: 2))
        editor.moveVertically(up: true)                       // zurück in den Exponenten
        XCTAssertEqual(editor.cursor, path((1, 0), offset: 2))
    }

    func testDeleteAtSlotStartUnwrapsFraction() {
        var editor = FormulaEditor(root: row(lin("1+"), frac("3", "4")))
        editor.setCursor(path((2, 1), offset: 0))
        XCTAssertTrue(editor.deleteBackward())
        XCTAssertEqual(editor.root.linearText, "1+3÷4")
        XCTAssertEqual(editor.cursor, path(offset: 4))
    }

    func testDeleteAfterFilledStructureEntersIt() {
        var editor = FormulaEditor(root: row(sqrtOf(lin("9"))))
        editor.deleteBackward()
        XCTAssertEqual(editor.root.linearText, "√9", "Inhalt darf nicht verloren gehen")
        XCTAssertEqual(editor.cursor, path((0, 0), offset: 1))
        editor.deleteBackward()                               // löscht die 9
        editor.deleteBackward()                               // löst die leere Wurzel auf
        XCTAssertTrue(editor.root.isEmpty)
    }

    func testDeleteRemovesEmptyStructure() {
        var editor = FormulaEditor(root: row(lin("2"), frac("", "")))
        editor.deleteBackward()
        XCTAssertEqual(editor.root.linearText, "2")
    }

    func testDeleteAtStartReturnsFalse() {
        var editor = FormulaEditor()
        XCTAssertFalse(editor.deleteBackward())
    }

    func testPowerWithoutBaseCreatesParentheses() {
        var editor = FormulaEditor()
        editor.insertPower(exponent: MathRow(linear: "2"), cursorInExponent: false)
        XCTAssertEqual(editor.root.linearText, "()^2")
        XCTAssertEqual(editor.cursor, path((0, 0), offset: 0))
    }

    func testSquareAfterNumber() {
        var editor = FormulaEditor()
        type("3", into: &editor)
        editor.insertPower(exponent: MathRow(linear: "2"), cursorInExponent: false)
        XCTAssertEqual(editor.root.linearText, "3^2")
        XCTAssertEqual(editor.cursor, path(offset: 2))
    }

    func testWrappingSelectionInSquareRoot() {
        var editor = FormulaEditor()
        type("2+7", into: &editor)
        editor.moveLeft(selecting: true)
        editor.insertWrapping(.squareRoot)
        XCTAssertEqual(editor.root.linearText, "2+√7")
        XCTAssertEqual(editor.cursor, path(offset: 3))
    }

    func testTypingReplacesSelection() {
        var editor = FormulaEditor()
        type("123", into: &editor)
        editor.moveLeft(selecting: true)
        editor.moveLeft(selecting: true)
        type("9", into: &editor)
        XCTAssertEqual(editor.root.linearText, "19")
    }

    func testInvalidCursorIsIgnored() {
        var editor = FormulaEditor()
        type("12", into: &editor)
        editor.setCursor(path((5, 0), offset: 0))
        XCTAssertEqual(editor.cursor, path(offset: 2))
    }
}
