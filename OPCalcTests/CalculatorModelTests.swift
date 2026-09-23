import XCTest
@testable import OPCalc

final class CalculatorModelTests: XCTestCase {
    private func press(_ model: CalculatorModel, _ keys: CalculatorKey...) {
        for key in keys { model.press(key, context: nil) }
    }

    /// Das Beispiel aus dem Konzept, komplett über die Tastatur eingegeben: 3/4 + 1/3 = 13/12
    func testConceptExampleViaKeyboard() {
        let model = CalculatorModel()
        press(model, .digit("3"), .fraction, .digit("4"), .right, .op(.plus), .digit("1"), .fraction, .digit("3"), .equals)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.result?.exactText, "13/12")
        XCTAssertEqual(model.result?.decimalText, "1,083333333")
        XCTAssertFalse(model.showsDecimal)
    }

    func testApproximateKeyShowsDecimal() {
        let model = CalculatorModel()
        press(model, .digit("1"), .fraction, .digit("3"), .approximate)
        XCTAssertTrue(model.showsDecimal)
        XCTAssertEqual(model.result?.decimalText, "0,3333333333")
        press(model, .toggleDecimal)
        XCTAssertFalse(model.showsDecimal)
    }

    func testDigitsAreUndoneAsOneStep() {
        let model = CalculatorModel()
        press(model, .digit("1"), .digit("2"), .digit("3"), .op(.plus), .digit("4"))
        press(model, .undo)
        XCTAssertEqual(model.editor.root.linearText, "123+")
        press(model, .undo)
        XCTAssertEqual(model.editor.root.linearText, "123")
        press(model, .undo)
        XCTAssertTrue(model.editor.root.isEmpty)
        press(model, .redo, .redo)
        XCTAssertEqual(model.editor.root.linearText, "123+")
    }

    func testUndoRestoresFractionStructure() {
        let model = CalculatorModel()
        press(model, .digit("1"), .digit("2"), .fraction)
        press(model, .undo)
        XCTAssertEqual(model.editor.root.linearText, "12")
        XCTAssertEqual(model.editor.cursor.offset, 2)
    }

    func testClearIsUndoable() {
        let model = CalculatorModel()
        press(model, .digit("5"), .clear)
        XCTAssertTrue(model.editor.root.isEmpty)
        press(model, .undo)
        XCTAssertEqual(model.editor.root.linearText, "5")
    }

    func testParseErrorMovesCursorToEmptySlot() {
        let model = CalculatorModel()
        press(model, .digit("7"), .fraction, .equals)
        XCTAssertEqual(model.errorMessage, "Leeres Feld")
        XCTAssertEqual(model.editor.cursor, CursorPath(steps: [PathStep(item: 0, slot: 1)], offset: 0))
    }

    func testDivisionByZeroShowsMessage() {
        let model = CalculatorModel()
        press(model, .digit("1"), .op(.divide), .digit("0"), .equals)
        XCTAssertEqual(model.errorMessage, "Division durch null")
        XCTAssertNil(model.result)
    }

    func testAnsUsesLastResult() {
        let model = CalculatorModel()
        press(model, .digit("6"), .equals, .clear, .ans, .op(.times), .digit("2"), .equals)
        XCTAssertEqual(model.result?.exactText, "12")
    }

    func testEditingMarksResultStale() {
        let model = CalculatorModel()
        press(model, .digit("2"), .equals)
        XCTAssertFalse(model.resultIsStale)
        press(model, .digit("3"))
        XCTAssertTrue(model.resultIsStale)
    }

    func testFunctionLayerReturnsToBasic() {
        let model = CalculatorModel()
        press(model, .switchLayer)
        XCTAssertEqual(model.layer, .functions)
        press(model, .function(.sin))
        XCTAssertEqual(model.layer, .basic)
        XCTAssertEqual(model.editor.root.linearText, "sin()")
    }
}
