import XCTest
@testable import OPCalc

final class FormulaParserTests: XCTestCase {
    private func n(_ value: Int) -> Expr { .number(Rational(value)) }

    private func parse(_ formula: MathRow) throws -> Expr {
        try FormulaParser.parse(formula)
    }

    private func assertParseError(_ formula: MathRow, message: String, path: CursorPath,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try parse(formula), file: file, line: line) { error in
            guard let parseError = error as? ParseError else {
                return XCTFail("Falscher Fehlertyp: \(error)", file: file, line: line)
            }
            XCTAssertEqual(parseError.message, message, file: file, line: line)
            XCTAssertEqual(parseError.path, path, file: file, line: line)
        }
    }

    func testOperatorPrecedence() throws {
        XCTAssertEqual(try parse(row(lin("2+3×4"))), .add(n(2), .multiply(n(3), n(4))))
        XCTAssertEqual(try parse(row(lin("8−3−2"))), .subtract(.subtract(n(8), n(3)), n(2)))
        XCTAssertEqual(try parse(row(lin("8÷4×2"))), .multiply(.divide(n(8), n(4)), n(2)))
    }

    func testMultiDigitAndDecimalNumbers() throws {
        XCTAssertEqual(try parse(row(lin("123"))), n(123))
        XCTAssertEqual(try parse(row(lin("1,25"))), .number(q(5, 4)))
    }

    func testUnaryMinusBindsWeakerThanPower() throws {
        // −2² = −(2²)
        XCTAssertEqual(try parse(row(lin("−2"), sup("2"))), .negate(.power(n(2), n(2))))
        // (−2)²
        XCTAssertEqual(try parse(row(paren(lin("−2")), sup("2"))), .power(.negate(n(2)), n(2)))
        XCTAssertEqual(try parse(row(lin("2−−3"))), .subtract(n(2), .negate(n(3))))
        XCTAssertEqual(try parse(row(lin("2×−3"))), .multiply(n(2), .negate(n(3))))
    }

    func testImplicitMultiplication() throws {
        XCTAssertEqual(try parse(row(lin("2π"))), .multiply(n(2), .constant(.pi)))
        XCTAssertEqual(try parse(row(lin("3"), paren(lin("1+2")))), .multiply(n(3), .add(n(1), n(2))))
        XCTAssertEqual(try parse(row(frac("1", "2"), sqrtOf(lin("2")))),
                       .multiply(.divide(n(1), n(2)), .root(degree: n(2), radicand: n(2))))
    }

    func testStructures() throws {
        XCTAssertEqual(try parse(row(frac("3", "4"))), .divide(n(3), n(4)))
        XCTAssertEqual(try parse(row(rootOf("3", lin("8")))), .root(degree: n(3), radicand: n(8)))
        XCTAssertEqual(try parse(row(fn(.sin, lin("π")))), .function(.sin, .constant(.pi)))
        XCTAssertEqual(try parse(row(absOf(lin("−1")))), .absolute(.negate(n(1))))
        XCTAssertEqual(try parse(row(lin("3!"))), .factorial(n(3)))
        XCTAssertEqual(try parse(row(lin("2"), sup("3"), sup("2"))), .power(.power(n(2), n(3)), n(2)))
    }

    func testEmptyInputIsError() {
        assertParseError(MathRow(), message: "Leeres Feld", path: .start)
    }

    func testEmptyDenominatorPointsIntoSlot() {
        assertParseError(row(frac("3", "")), message: "Leeres Feld",
                         path: CursorPath(steps: [PathStep(item: 0, slot: 1)], offset: 0))
    }

    func testNestedEmptySlotPath() {
        // (1/▢) / 2 → Pfad: Element 0 Zähler → Element 0 Nenner
        let formula = row(frac(frac("1", ""), lin("2")))
        assertParseError(formula, message: "Leeres Feld",
                         path: CursorPath(steps: [PathStep(item: 0, slot: 0), PathStep(item: 0, slot: 1)], offset: 0))
    }

    func testMissingOperand() {
        assertParseError(row(lin("3+")), message: "Operand fehlt", path: CursorPath(steps: [], offset: 2))
        assertParseError(row(lin("×3")), message: "Operand fehlt vor „×“", path: CursorPath(steps: [], offset: 0))
    }

    func testInvalidNumber() {
        assertParseError(row(lin("1,2,3")), message: "Ungültige Zahl", path: CursorPath(steps: [], offset: 0))
        assertParseError(row(lin(",")), message: "Ungültige Zahl", path: CursorPath(steps: [], offset: 0))
    }

    func testPowerWithoutBase() {
        assertParseError(row(sup("2")), message: "Basis fehlt vor dem Exponenten", path: CursorPath(steps: [], offset: 0))
    }
}
