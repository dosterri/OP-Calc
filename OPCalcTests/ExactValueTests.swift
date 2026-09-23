import XCTest
@testable import OPCalc

final class ExactValueTests: XCTestCase {
    private let sqrt2 = ExactValue.radical(2)
    private let sqrt3 = ExactValue.radical(3)

    func testSquareRootSimplification() throws {
        XCTAssertEqual(try ExactValue(q(12)).squareRoot(), ExactValue.radical(3, coefficient: 2))
        XCTAssertEqual(try ExactValue(q(49)).squareRoot(), ExactValue(q(7)))
        XCTAssertEqual(try ExactValue(q(3, 4)).squareRoot(), ExactValue.radical(3, coefficient: q(1, 2)))
        XCTAssertEqual(try ExactValue(q(1, 2)).squareRoot(), ExactValue.radical(2, coefficient: q(1, 2)))
        XCTAssertEqual(try ExactValue.zero.squareRoot(), .zero)
    }

    func testSquareRootOfNegativeIsNotReal() {
        XCTAssertThrowsError(try ExactValue(q(-1)).squareRoot()) { error in
            XCTAssertEqual(error as? MathError, .notReal)
        }
        XCTAssertThrowsError(try (ExactValue.one - sqrt2 - sqrt2).squareRoot()) { error in
            XCTAssertEqual(error as? MathError, .notReal)
        }
    }

    func testProductOfRoots() throws {
        let sqrt8 = try ExactValue(q(8)).squareRoot()
        XCTAssertEqual(try ExactValue.multiply(sqrt2, sqrt8), ExactValue(q(4)))
        XCTAssertEqual(try ExactValue.multiply(sqrt2, sqrt3), ExactValue.radical(6))
        XCTAssertEqual(try ExactValue.multiply(ExactValue.radical(6), ExactValue.radical(10)), ExactValue.radical(15, coefficient: 2))
    }

    func testPiArithmetic() throws {
        let half = try ExactValue.multiply(.pi, ExactValue(q(1, 2)))
        let third = try ExactValue.multiply(.pi, ExactValue(q(1, 3)))
        XCTAssertEqual(half + third, ExactValue(terms: [.pi: q(5, 6)]))
        XCTAssertEqual(ExactValue.pi - ExactValue.pi, .zero)
    }

    func testReciprocalRationalizes() throws {
        XCTAssertEqual(try sqrt2.reciprocal(), ExactValue.radical(2, coefficient: q(1, 2)))
        // 1/(1+√2) = √2 − 1
        XCTAssertEqual(try (ExactValue.one + sqrt2).reciprocal(), sqrt2 - .one)
        // 1/π
        XCTAssertEqual(try ExactValue.pi.reciprocal(),
                       ExactValue(terms: [Monomial(radicand: 1, piExponent: -1, eExponent: 0): .one]))
    }

    func testReciprocalOfZeroThrows() {
        XCTAssertThrowsError(try ExactValue.zero.reciprocal()) { error in
            XCTAssertEqual(error as? MathError, .divisionByZero)
        }
    }

    func testReciprocalOfThreeTermsIsNotExact() {
        XCTAssertThrowsError(try (ExactValue.one + sqrt2 + sqrt3).reciprocal()) { error in
            XCTAssertEqual(error as? MathError, .notExact)
        }
    }

    func testIntegerPowers() throws {
        XCTAssertEqual(try sqrt2.power(2), ExactValue(q(2)))
        XCTAssertEqual(try sqrt2.power(3), ExactValue.radical(2, coefficient: 2))
        XCTAssertEqual(try sqrt2.power(-2), ExactValue(q(1, 2)))
        // (1 + √2)² = 3 + 2√2
        XCTAssertEqual(try (ExactValue.one + sqrt2).power(2), ExactValue(q(3)) + ExactValue.radical(2, coefficient: 2))
        XCTAssertEqual(try ExactValue.pi.power(2), ExactValue(terms: [Monomial(radicand: 1, piExponent: 2, eExponent: 0): .one]))
    }

    func testRationalPowersAndRoots() throws {
        XCTAssertEqual(try ExactValue(q(8)).power(q(2, 3)), ExactValue(q(4)))
        XCTAssertEqual(try ExactValue(q(-8)).root(3), ExactValue(q(-2)))
        XCTAssertEqual(try ExactValue(q(27, 8)).root(3), ExactValue(q(3, 2)))
        // ∛(8π³) = 2π
        let value = try ExactValue.multiply(ExactValue(q(8)), ExactValue.pi.power(3))
        XCTAssertEqual(try value.root(3), try ExactValue.multiply(ExactValue(q(2)), .pi))
        XCTAssertThrowsError(try ExactValue(q(2)).root(3)) { error in
            XCTAssertEqual(error as? MathError, .notExact)
        }
        XCTAssertThrowsError(try ExactValue(q(-16)).root(4)) { error in
            XCTAssertEqual(error as? MathError, .notReal)
        }
    }

    func testTrigTables() throws {
        XCTAssertEqual(ExactTables.sine(steps: 2), ExactValue(q(1, 2)))                 // sin 30°
        XCTAssertEqual(ExactTables.cosine(steps: 4), ExactValue(q(1, 2)))               // cos 60°
        XCTAssertEqual(ExactTables.sine(steps: 14), ExactValue(q(-1, 2)))               // sin 210°
        XCTAssertEqual(ExactTables.cosine(steps: 12), ExactValue(q(-1)))                // cos 180°
        XCTAssertEqual(try ExactTables.tangent(steps: 3), .one)                         // tan 45°
        XCTAssertEqual(try ExactTables.tangent(steps: 1), ExactValue(q(2)) - sqrt3)     // tan 15° = 2 − √3
        XCTAssertEqual(ExactTables.sine(steps: -2), ExactValue(q(-1, 2)))               // sin(−30°)
        XCTAssertThrowsError(try ExactTables.tangent(steps: 6))                         // tan 90°
    }

    func testDoubleValue() {
        XCTAssertEqual((ExactValue.one + sqrt2).doubleValue, 1 + 2.0.squareRoot(), accuracy: 1e-14)
        XCTAssertEqual(ExactValue.pi.doubleValue, Double.pi, accuracy: 1e-15)
        XCTAssertEqual(ExactValue.e.doubleValue, exp(1.0), accuracy: 1e-15)
    }

    func testSquareFreeParts() {
        XCTAssertEqual(squareFreeParts(BigInt(72))?.outside, BigInt(6))
        XCTAssertEqual(squareFreeParts(BigInt(72))?.inside, 2)
        XCTAssertEqual(squareFreeParts(BigInt(97))?.inside, 97)
        XCTAssertEqual(squareFreeParts(BigInt(2).power(200))?.outside, BigInt(2).power(100))
    }
}
