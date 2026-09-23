import XCTest
@testable import OPCalc

final class RationalTests: XCTestCase {
    private func r(_ n: Int, _ d: Int) -> Rational {
        Rational(BigInt(n), BigInt(d))
    }

    func testNormalization() {
        XCTAssertEqual(r(6, 8), r(3, 4))
        XCTAssertEqual(r(3, -4).numerator, BigInt(-3))
        XCTAssertEqual(r(3, -4).denominator, BigInt(4))
        XCTAssertEqual(r(-3, -4), r(3, 4))
        XCTAssertEqual(r(0, -5), Rational.zero)
        XCTAssertEqual(r(0, 7).denominator, BigInt(1))
    }

    func testArithmetic() throws {
        XCTAssertEqual(r(3, 4) + r(1, 3), r(13, 12))
        XCTAssertEqual(r(1, 2) - r(3, 4), r(-1, 4))
        XCTAssertEqual(r(2, 3) * r(9, 4), r(3, 2))
        XCTAssertEqual(try r(1, 2).divided(by: r(1, 4)), Rational(2))
        XCTAssertEqual(r(1, 6) + r(1, 6), r(1, 3))
    }

    func testDivisionByZeroThrows() {
        XCTAssertThrowsError(try r(1, 2).divided(by: .zero)) { error in
            XCTAssertEqual(error as? MathError, .divisionByZero)
        }
        XCTAssertThrowsError(try Rational.zero.reciprocal()) { error in
            XCTAssertEqual(error as? MathError, .divisionByZero)
        }
    }

    func testNegativeExponents() throws {
        XCTAssertEqual(try Rational(2).power(-3), r(1, 8))
        XCTAssertEqual(try r(-2, 3).power(-2), r(9, 4))
        XCTAssertEqual(try r(-2, 3).power(-3), r(-27, 8))
        XCTAssertEqual(try Rational(5).power(0), .one)
    }

    func testZeroPowers() {
        XCTAssertThrowsError(try Rational.zero.power(0)) { error in
            XCTAssertEqual(error as? MathError, .undefined("0⁰ ist nicht definiert"))
        }
        XCTAssertThrowsError(try Rational.zero.power(-1)) { error in
            XCTAssertEqual(error as? MathError, .divisionByZero)
        }
        XCTAssertEqual(try Rational.zero.power(5), .zero)
    }

    /// Ergebnisse jenseits von Int64 bleiben exakt (kein Überlauf wie bei Int).
    func testNoOverflowBeyondInt64() throws {
        let big = try Rational(2).power(64) * Rational(2).power(64)
        XCTAssertEqual(big.numerator.description, "340282366920938463463374607431768211456")
        let product = Rational(Int.max) * Rational(Int.max)
        XCTAssertEqual(product.numerator.description, "85070591730234615847396907784232501249")
    }

    /// Absurd große Potenzen werden vorab abgelehnt statt die App einzufrieren.
    func testHugePowerIsRejected() {
        XCTAssertThrowsError(try Rational(9).power(1_000_000)) { error in
            XCTAssertEqual(error as? MathError, .tooLarge)
        }
        XCTAssertEqual(try Rational(1).power(1_000_000_000), .one)
        XCTAssertEqual(try Rational(-1).power(1_000_001), Rational(-1))
    }

    func testDecimalParsing() {
        XCTAssertEqual(Rational(decimal: "0.1"), r(1, 10))
        XCTAssertEqual(Rational(decimal: "12.50"), r(25, 2))
        XCTAssertEqual(Rational(decimal: ".5"), r(1, 2))
        XCTAssertEqual(Rational(decimal: "3."), Rational(3))
        XCTAssertEqual(Rational(decimal: "007"), Rational(7))
        XCTAssertNil(Rational(decimal: "."))
        XCTAssertNil(Rational(decimal: "1.2.3"))
        XCTAssertNil(Rational(decimal: ""))
    }

    func testComparison() {
        XCTAssertTrue(r(1, 3) < r(1, 2))
        XCTAssertTrue(r(-1, 2) < r(-1, 3))
        XCTAssertFalse(r(2, 4) < r(1, 2))
    }

    func testExactRoots() {
        XCTAssertEqual(r(8, 27).exactRoot(3), r(2, 3))
        XCTAssertEqual(r(-8, 27).exactRoot(3), r(-2, 3))
        XCTAssertNil(r(-4, 9).exactRoot(2))
        XCTAssertNil(r(2, 1).exactRoot(2))
    }

    func testDoubleValue() {
        XCTAssertEqual(r(1, 3).doubleValue, 1.0 / 3.0, accuracy: 1e-15)
        // Riesiger Zähler und Nenner: kein inf/inf = NaN
        let huge = Rational(BigInt(10).power(400) * 3, BigInt(10).power(400) * 4)
        XCTAssertEqual(huge.doubleValue, 0.75, accuracy: 1e-15)
        let ratio = Rational(BigInt(10).power(400) + 1, BigInt(10).power(400))
        XCTAssertEqual(ratio.doubleValue, 1.0, accuracy: 1e-12)
    }
}
