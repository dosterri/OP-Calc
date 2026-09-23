import XCTest
@testable import OPCalc

final class BigIntTests: XCTestCase {
    func testParsingAndDescription() {
        XCTAssertEqual(BigInt("0")?.description, "0")
        XCTAssertEqual(BigInt("-0")?.description, "0")
        XCTAssertEqual(BigInt("000123")?.description, "123")
        XCTAssertEqual(BigInt("-987654321987654321987654321")?.description, "-987654321987654321987654321")
        XCTAssertEqual(BigInt("+42")?.description, "42")
        XCTAssertNil(BigInt(""))
        XCTAssertNil(BigInt("-"))
        XCTAssertNil(BigInt("12a"))
        XCTAssertNil(BigInt("1.5"))
    }

    func testIntRoundTrip() {
        for value in [0, 1, -1, 4_294_967_295, 4_294_967_296, Int.max, Int.min, -123_456_789_012] {
            XCTAssertEqual(BigInt(value).asInt, value)
            XCTAssertEqual(BigInt(value).description, String(value))
        }
        XCTAssertNil((BigInt(Int.max) + 1).asInt)
        XCTAssertNil((BigInt(Int.min) - 1).asInt)
    }

    func testAdditionCarriesAcrossLimbs() {
        let a = BigInt(4_294_967_295)          // 2^32 − 1
        XCTAssertEqual((a + 1).description, "4294967296")
        XCTAssertEqual((BigInt(Int.max) + BigInt(Int.max)).description, "18446744073709551614")
    }

    func testSignedAdditionAndSubtraction() {
        XCTAssertEqual(BigInt(5) - BigInt(8), BigInt(-3))
        XCTAssertEqual(BigInt(-5) + BigInt(8), BigInt(3))
        XCTAssertEqual(BigInt(-5) - BigInt(-5), BigInt(0))
        XCTAssertFalse((BigInt(-5) + BigInt(5)).isNegative, "Null darf nicht negativ sein")
        let big = BigInt("100000000000000000000000000000")!
        XCTAssertEqual((big - 1).description, "99999999999999999999999999999")
    }

    func testMultiplication() {
        let a = BigInt("123456789012345678901234567890")!
        let b = BigInt("987654321098765432109876543210")!
        XCTAssertEqual((a * b).description, "121932631137021795226185032733622923332237463801111263526900")
        XCTAssertEqual((a * BigInt(-1)).description, "-123456789012345678901234567890")
        XCTAssertEqual(a * 0, BigInt(0))
    }

    func testPower() {
        XCTAssertEqual(BigInt(2).power(64).description, "18446744073709551616")
        XCTAssertEqual(BigInt(2).power(128).description, "340282366920938463463374607431768211456")
        XCTAssertEqual(BigInt(-3).power(3), BigInt(-27))
        XCTAssertEqual(BigInt(7).power(0), BigInt(1))
    }

    func testDivisionSmallDivisor() {
        let (q, r) = BigInt("1000000000000000000000")!.quotientAndRemainder(dividingBy: 7)
        XCTAssertEqual(q.description, "142857142857142857142")
        XCTAssertEqual(r, BigInt(6))
    }

    func testDivisionTruncatesTowardZero() {
        XCTAssertEqual(BigInt(-7) / BigInt(2), BigInt(-3))
        XCTAssertEqual(BigInt(-7) % BigInt(2), BigInt(-1))
        XCTAssertEqual(BigInt(7) / BigInt(-2), BigInt(-3))
        XCTAssertEqual(BigInt(7) % BigInt(-2), BigInt(1))
    }

    /// Prüft die Knuth-Division mit vielen mehrstelligen Divisoren über die Identität a = q·b + r, 0 ≤ r < b.
    func testLongDivisionIdentity() {
        var seed: UInt64 = 0x1234_5678_9ABC_DEF0
        func next() -> UInt32 {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return UInt32(truncatingIfNeeded: seed >> 33)
        }
        func random(limbs: Int) -> BigInt {
            var value = BigInt(0)
            for _ in 0..<limbs {
                value = value * BigInt(4_294_967_296) + BigInt(Int(next()))
            }
            return value
        }
        for _ in 0..<300 {
            let a = random(limbs: Int(next() % 8) + 2)
            var b = random(limbs: Int(next() % 5) + 2)
            if b.isZero { b = 1 }
            let (q, r) = a.quotientAndRemainder(dividingBy: b)
            XCTAssertEqual(q * b + r, a)
            XCTAssertTrue(r >= 0 && r < b, "Rest außerhalb des Bereichs: \(r) bei Divisor \(b)")
        }
    }

    /// Mehrblöckige Division mit Rest null: (2^128 − 1) / (2^64 + 1) = 2^64 − 1.
    func testDivisionExactMultiLimb() {
        let a = BigInt("340282366920938463463374607431768211455")!   // 2^128 − 1
        let b = BigInt("18446744073709551617")!                      // 2^64 + 1
        let (q, r) = a.quotientAndRemainder(dividingBy: b)
        XCTAssertEqual(q * b + r, a)
        XCTAssertEqual(q.description, "18446744073709551615")
        XCTAssertEqual(r, BigInt(0))
    }

    func testGCD() {
        XCTAssertEqual(BigInt.gcd(48, 18), BigInt(6))
        XCTAssertEqual(BigInt.gcd(-48, 18), BigInt(6))
        XCTAssertEqual(BigInt.gcd(0, 5), BigInt(5))
        let a = BigInt(2).power(100) * 3
        let b = BigInt(2).power(90) * 9
        XCTAssertEqual(BigInt.gcd(a, b), BigInt(2).power(90) * 3)
    }

    func testComparison() {
        XCTAssertTrue(BigInt(-10) < BigInt(-2))
        XCTAssertTrue(BigInt(-1) < BigInt(0))
        XCTAssertTrue(BigInt(2).power(70) > BigInt(2).power(69))
        XCTAssertFalse(BigInt(5) < BigInt(5))
    }

    func testIntegerRoots() {
        XCTAssertEqual(BigInt(1_000_000).integerRoot(2), BigInt(1000))
        XCTAssertEqual(BigInt(999_999).integerRoot(2), BigInt(999))
        XCTAssertEqual(BigInt(2).power(300).exactRoot(3), BigInt(2).power(100))
        XCTAssertNil(BigInt(2).power(301).exactRoot(3))
        XCTAssertEqual(BigInt(0).exactRoot(5), BigInt(0))
        XCTAssertEqual(BigInt(1).exactRoot(7), BigInt(1))
    }

    func testDoubleApproximation() {
        XCTAssertEqual(BigInt(2).power(64).doubleValue, 18_446_744_073_709_551_616.0)
        XCTAssertEqual(BigInt(-12345).doubleValue, -12345.0)
    }
}
