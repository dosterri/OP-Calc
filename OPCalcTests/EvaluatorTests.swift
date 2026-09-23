import XCTest
@testable import OPCalc

final class EvaluatorTests: XCTestCase {
    private func assertError(_ formula: MathRow, _ expected: MathError, mode: AngleMode = .radians,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try evaluate(formula, mode: mode), file: file, line: line) { error in
            XCTAssertEqual(error as? MathError, expected, file: file, line: line)
        }
    }

    private func assertApproximately(_ formula: MathRow, _ expected: Double, mode: AngleMode = .radians,
                                     file: StaticString = #filePath, line: UInt = #line) {
        do {
            let value = try evaluate(formula, mode: mode)
            XCTAssertFalse(value.isExact, "Erwartet Näherung, erhalten: \(value)", file: file, line: line)
            XCTAssertEqual(value.doubleValue, expected, accuracy: 1e-9, file: file, line: line)
        } catch {
            XCTFail("Unerwarteter Fehler: \(error)", file: file, line: line)
        }
    }

    // MARK: - Brüche bleiben Brüche

    func testFractionsStayExact() throws {
        XCTAssertEqual(try evaluate(row(frac("3", "4"), lin("+"), frac("1", "3"))), exact(13, 12))
        XCTAssertEqual(try evaluate(row(lin("0,1+0,2"))), exact(3, 10))
        XCTAssertEqual(try evaluate(row(frac("1", "3"), lin("+"), frac("1", "3"), lin("+"), frac("1", "3"))), exact(1))
        XCTAssertEqual(try evaluate(row(lin("2+3×4"))), exact(14))
        XCTAssertEqual(try evaluate(row(lin("7÷2"))), exact(7, 2))
    }

    func testBeyondInt64StaysExact() throws {
        XCTAssertEqual(try evaluate(row(lin("9223372036854775807+1"))),
                       .exact(ExactValue(Rational(BigInt("9223372036854775808")!))))
        let value = try evaluate(row(lin("2"), sup("100")))
        guard case .exact(let v) = value else { return XCTFail("Nicht exakt") }
        XCTAssertEqual(v.rationalValue?.numerator.description, "1267650600228229401496703205376")
    }

    // MARK: - Randfälle

    func testDivisionByZero() {
        assertError(row(frac("1", "0")), .divisionByZero)
        assertError(row(lin("5÷"), paren(lin("2−2"))), .divisionByZero)
        assertError(row(lin("0"), sup("−1")), .divisionByZero)
    }

    func testNegativeExponents() throws {
        XCTAssertEqual(try evaluate(row(lin("2"), sup("−3"))), exact(1, 8))
        XCTAssertEqual(try evaluate(row(paren(frac("2", "3")), sup("−2"))), exact(9, 4))
        XCTAssertEqual(try evaluate(row(lin("10"), sup("−2"))), exact(1, 100))
    }

    func testUnaryMinusAndPower() throws {
        XCTAssertEqual(try evaluate(row(lin("−2"), sup("2"))), exact(-4))
        XCTAssertEqual(try evaluate(row(paren(lin("−2")), sup("2"))), exact(4))
        XCTAssertEqual(try evaluate(row(paren(lin("−2")), sup("3"))), exact(-8))
    }

    func testZeroToTheZeroIsUndefined() {
        assertError(row(lin("0"), sup("0")), .undefined("0⁰ ist nicht definiert"))
    }

    func testOverflowFallsBackAndReportsError() {
        // 2^100000 ist exakt zu groß, als Double unendlich → klare Fehlermeldung
        assertError(row(lin("2"), sup("100000")), .overflow)
        assertError(row(lin("5000!")), .overflow)
    }

    func testHugeButRepresentableFactorial() throws {
        XCTAssertEqual(try evaluate(row(lin("20!"))), exact(2_432_902_008_176_640_000))
        let value = try evaluate(row(lin("25!")))
        guard case .exact(let v) = value else { return XCTFail("Nicht exakt") }
        XCTAssertEqual(v.rationalValue?.numerator.description, "15511210043330985984000000")
        XCTAssertEqual(try evaluate(row(lin("0!"))), exact(1))
        assertError(row(frac("1", "2"), lin("!")), .domain("n! ist nur für natürliche Zahlen definiert"))
    }

    // MARK: - Wurzeln, π, e

    func testRootsStayExact() throws {
        XCTAssertEqual(try evaluate(row(sqrtOf(lin("8")))), .exact(ExactValue.radical(2, coefficient: 2)))
        XCTAssertEqual(try evaluate(row(sqrtOf(lin("2")), sqrtOf(lin("8")))), exact(4))
        XCTAssertEqual(try evaluate(row(rootOf("3", lin("−8")))), exact(-2))
        XCTAssertEqual(try evaluate(row(paren(lin("−8")), sup(frac("1", "3")))), exact(-2))
        XCTAssertEqual(try evaluate(row(lin("2"), sup("0,5"))), .exact(ExactValue.radical(2)))
        XCTAssertEqual(try evaluate(row(frac(lin("1"), sqrtOf(lin("2"))))), .exact(ExactValue.radical(2, coefficient: q(1, 2))))
    }

    func testRootOfNegativeIsNotReal() {
        assertError(row(sqrtOf(lin("−4"))), .notReal)
        assertError(row(paren(lin("−2")), sup("0,5")), .notReal)
    }

    func testIrrationalOddRootOfNegativeIsApproximated() {
        assertApproximately(row(rootOf("3", lin("−2"))), -pow(2.0, 1.0 / 3.0))
    }

    func testPiStaysExact() throws {
        let value = try evaluate(row(frac("π", "2"), lin("+"), frac("π", "3")))
        XCTAssertEqual(value, .exact(ExactValue(terms: [.pi: q(5, 6)])))
        XCTAssertEqual(try evaluate(row(lin("2π"))), .exact(ExactValue(terms: [.pi: q(2)])))
    }

    func testLogarithms() throws {
        XCTAssertEqual(try evaluate(row(fn(.ln, lin("e") + sup("2")))), exact(2))
        XCTAssertEqual(try evaluate(row(fn(.ln, lin("1")))), exact(0))
        XCTAssertEqual(try evaluate(row(fn(.log, lin("1000")))), exact(3))
        XCTAssertEqual(try evaluate(row(fn(.log, lin("0,01")))), exact(-2))
        assertApproximately(row(fn(.ln, lin("2"))), log(2.0))
        assertError(row(fn(.ln, lin("0"))), .domain("Logarithmus ist nur für positive Zahlen definiert"))
        assertError(row(fn(.log, lin("−5"))), .domain("Logarithmus ist nur für positive Zahlen definiert"))
    }

    // MARK: - Winkelfunktionen

    func testTrigExactInRadians() throws {
        XCTAssertEqual(try evaluate(row(fn(.sin, frac("π", "6")))), exact(1, 2))
        XCTAssertEqual(try evaluate(row(fn(.cos, lin("π")))), exact(-1))
        XCTAssertEqual(try evaluate(row(fn(.sin, lin("π")))), exact(0))
        XCTAssertEqual(try evaluate(row(fn(.cos, frac("π", "4")))), .exact(ExactValue.radical(2, coefficient: q(1, 2))))
        XCTAssertEqual(try evaluate(row(fn(.asin, frac("1", "2")))), .exact(ExactValue(terms: [.pi: q(1, 6)])))
    }

    func testTrigExactInDegrees() throws {
        XCTAssertEqual(try evaluate(row(fn(.sin, lin("30"))), mode: .degrees), exact(1, 2))
        XCTAssertEqual(try evaluate(row(fn(.cos, lin("60"))), mode: .degrees), exact(1, 2))
        XCTAssertEqual(try evaluate(row(fn(.tan, lin("45"))), mode: .degrees), exact(1))
        XCTAssertEqual(try evaluate(row(fn(.acos, lin("0"))), mode: .degrees), exact(90))
        XCTAssertEqual(try evaluate(row(fn(.atan, lin("1"))), mode: .degrees), exact(45))
        assertError(row(fn(.tan, lin("90"))), .domain("tan ist bei ±90° nicht definiert"), mode: .degrees)
    }

    func testTrigApproximations() {
        assertApproximately(row(fn(.sin, lin("1"))), sin(1.0))
        assertApproximately(row(fn(.cos, lin("10"))), cos(10.0 * .pi / 180), mode: .degrees)
        assertApproximately(row(fn(.asin, frac("1", "3"))), asin(1.0 / 3.0))
        assertError(row(fn(.asin, lin("2"))), .domain("sin⁻¹ ist nur für Werte von −1 bis 1 definiert"))
    }

    // MARK: - Sonstiges

    func testAbsoluteValue() throws {
        XCTAssertEqual(try evaluate(row(absOf(lin("−3")))), exact(3))
        XCTAssertEqual(try evaluate(row(absOf(lin("1−") + sqrtOf(lin("2"))))),
                       .exact(ExactValue.radical(2) - .one))
    }

    func testAns() throws {
        XCTAssertEqual(try evaluate(row([MathItem(.ans)], lin("×2")), ans: exact(5)), exact(10))
        assertError(row([MathItem(.ans)]), .missingAns)
    }

    func testIrrationalExponentIsApproximated() {
        assertApproximately(row(lin("2"), sup("π")), pow(2.0, .pi))
    }

    func testConjugateProduct() throws {
        // (1+√2)(1−√2) = −1
        let formula = row(paren(lin("1+") + sqrtOf(lin("2"))), paren(lin("1−") + sqrtOf(lin("2"))))
        XCTAssertEqual(try evaluate(formula), exact(-1))
    }
}
