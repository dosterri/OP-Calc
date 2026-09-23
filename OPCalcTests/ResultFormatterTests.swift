import XCTest
@testable import OPCalc

final class ResultFormatterTests: XCTestCase {
    private func exactText(_ value: ExactValue) -> String {
        ResultFormatter.exactRow(value).linearText
    }

    private func decimalText(_ value: Rational) -> String {
        DecimalFormatting.text(DecimalFormatting.representation(of: value))
    }

    func testExactRows() throws {
        XCTAssertEqual(exactText(ExactValue(q(13, 12))), "13/12")
        XCTAssertEqual(exactText(ExactValue(q(-7))), "−7")
        XCTAssertEqual(exactText(.zero), "0")
        XCTAssertEqual(exactText(ExactValue(terms: [.pi: q(5, 6)])), "5π/6")
        XCTAssertEqual(exactText(ExactValue(terms: [.pi: q(-1)])), "−π")
        XCTAssertEqual(exactText(ExactValue.radical(3, coefficient: 2)), "2√3")
        XCTAssertEqual(exactText(ExactValue.radical(2, coefficient: q(1, 2))), "√2/2")
        XCTAssertEqual(exactText(try ExactValue.pi.reciprocal()), "1/π")
        XCTAssertEqual(exactText(try ExactValue.pi.power(2)), "π^2")
    }

    func testExactSumStartsWithPositiveTerm() {
        XCTAssertEqual(exactText(ExactValue.radical(2) - .one), "√2−1")
        XCTAssertEqual(exactText(ExactValue.one + ExactValue.radical(2)), "1+√2")
        let sin15 = ExactValue.radical(6, coefficient: q(1, 4)) - ExactValue.radical(2, coefficient: q(1, 4))
        XCTAssertEqual(exactText(sin15), "√6/4−√2/4")
    }

    func testDecimalRounding() {
        XCTAssertEqual(decimalText(q(13, 12)), "1,083333333")
        XCTAssertEqual(decimalText(q(2, 3)), "0,6666666667")
        XCTAssertEqual(decimalText(q(1, 4)), "0,25")
        XCTAssertEqual(decimalText(q(-5, 2)), "−2,5")
        XCTAssertEqual(decimalText(q(1_000_000)), "1000000")
        XCTAssertEqual(decimalText(q(99_999_999_999, 100_000_000_000)), "1")   // Rundung mit Übertrag
    }

    func testDecimalExactness() {
        XCTAssertTrue(DecimalFormatting.representation(of: q(1, 4)).isExact)
        XCTAssertFalse(DecimalFormatting.representation(of: q(1, 3)).isExact)
    }

    func testScientificNotation() {
        XCTAssertEqual(decimalText(Rational(BigInt(10).power(12))), "1×10^12")
        XCTAssertEqual(decimalText(q(1, 8_000_000)), "1,25×10^−7")
        // 2^100 = 1267650600228… → 10 signifikante Stellen, abschließende Nullen entfernt
        XCTAssertEqual(decimalText(Rational(BigInt(2).power(100))), "1,2676506×10^30")
    }

    func testDoubleRepresentation() {
        let r = DecimalFormatting.representation(of: sin(1.0))
        XCTAssertEqual(DecimalFormatting.text(r), "0,8414709848")
        XCTAssertFalse(r.isExact)
        XCTAssertEqual(DecimalFormatting.text(DecimalFormatting.representation(of: -1.5e20)), "−1,5×10^20")
    }

    func testFormatMarksApproximation() {
        let exactResult = ResultFormatter.format(.exact(ExactValue(q(1, 4))))
        XCTAssertEqual(exactResult.exactText, "1/4")
        XCTAssertEqual(exactResult.decimalText, "0,25")
        XCTAssertTrue(exactResult.decimalIsExact)

        let approximate = ResultFormatter.format(.approximate(0.1))
        XCTAssertNil(approximate.exactRow)
        XCTAssertFalse(approximate.decimalIsExact)
    }
}
