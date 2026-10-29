import XCTest
@testable import OPCalc

func parsed(_ row: MathRow) throws -> Expr {
    try FormulaParser.parse(row)
}

final class AnalysisTests: XCTestCase {
    let evaluator = NumericEvaluator()

    private func f(_ row: MathRow) throws -> (Double) -> Double {
        evaluator.function(try parsed(row))
    }

    // MARK: - Auswertung mit Variablen

    func testNumericEvaluationWithImplicitMultiplication() throws {
        let g = try f(row(lin("2x"), sup("2"), lin("+3x−1")))   // 2x² + 3x − 1
        XCTAssertEqual(g(2), 13, accuracy: 1e-12)
        XCTAssertEqual(g(-1), -2, accuracy: 1e-12)
    }

    func testOddRootOfNegativeIsReal() throws {
        let g = try f(row(rootOf("3", lin("x"))))
        XCTAssertEqual(g(-8), -2, accuracy: 1e-12)
        let h = try f(row(lin("x"), sup(frac("2", "3"))))   // x^(2/3)
        XCTAssertEqual(h(-8), 4, accuracy: 1e-12)
        let k = try f(row(sqrtOf(lin("x"))))
        XCTAssertTrue(k(-1).isNaN)
    }

    func testDegreesMode() throws {
        let g = NumericEvaluator(angleMode: .degrees).function(try parsed(row(fn(.sin, lin("x")))))
        XCTAssertEqual(g(30), 0.5, accuracy: 1e-12)
    }

    // MARK: - Ableitung

    private func assertDerivative(_ row: MathRow, matches expected: (Double) -> Double,
                                  at points: [Double], file: StaticString = #filePath, line: UInt = #line) throws {
        let e = try parsed(row)
        let d = try XCTUnwrap(e.derivative(by: "x"), file: file, line: line)
        let g = evaluator.function(d)
        for x in points {
            XCTAssertEqual(g(x), expected(x), accuracy: 1e-9 * max(1, Swift.abs(expected(x))), file: file, line: line)
        }
    }

    func testDerivativePolynomial() throws {
        // (x³ − 3x)′ = 3x² − 3
        try assertDerivative(row(lin("x"), sup("3"), lin("−3x")), matches: { 3 * $0 * $0 - 3 }, at: [-2, 0, 1.5])
    }

    func testDerivativeTrigExpLnAndChainRule() throws {
        try assertDerivative(row(fn(.sin, lin("x"))), matches: { cos($0) }, at: [0, 1, 2])
        try assertDerivative(row(lin("e"), sup("x")), matches: { exp($0) }, at: [0, 1, -1])
        try assertDerivative(row(fn(.ln, lin("x"))), matches: { 1 / $0 }, at: [0.5, 2])
        // sin(x²)′ = 2x·cos(x²)
        try assertDerivative(row(fn(.sin, row(lin("x"), sup("2")).items)), matches: { 2 * $0 * cos($0 * $0) },
                             at: [0.3, 1.2])
        // (x/(x+1))′ = 1/(x+1)²
        try assertDerivative(row(frac(lin("x"), lin("x+1"))), matches: { 1 / (($0 + 1) * ($0 + 1)) }, at: [0, 2])
        // (x^x)′ = x^x (ln x + 1)
        try assertDerivative(row(lin("x"), sup("x")), matches: { pow($0, $0) * (log($0) + 1) }, at: [0.5, 2])
    }

    func testDerivativeInDegreesCarriesFactor() throws {
        let e = try parsed(row(fn(.sin, lin("x"))))
        let d = try XCTUnwrap(e.derivative(by: "x", angleMode: .degrees))
        let g = NumericEvaluator(angleMode: .degrees).function(d)
        XCTAssertEqual(g(60), Double.pi / 180 * 0.5, accuracy: 1e-12)
    }

    func testFactorialIsNotDerivable() throws {
        XCTAssertNil(try parsed(row(lin("x!"))).derivative(by: "x"))
    }

    // MARK: - Kurvendiskussion

    func testRootsOfCubic() throws {
        let analysis = CurveAnalysis(expression: try parsed(row(lin("x"), sup("3"), lin("−x"))))
        let xs = analysis.roots(in: -10, 10).map(\.x)
        XCTAssertEqual(xs.count, 3)
        for (found, expected) in zip(xs, [-1.0, 0, 1]) { XCTAssertEqual(found, expected, accuracy: 1e-10) }
    }

    func testDoubleRootIsFound() throws {
        // (x − 2)² berührt die x-Achse
        let analysis = CurveAnalysis(expression: try parsed(row(paren(lin("x−2")), sup("2"))))
        let roots = analysis.roots(in: -10, 10)
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0].x, 2, accuracy: 1e-6)
    }

    func testPoleIsNoRoot() throws {
        let analysis = CurveAnalysis(expression: try parsed(row(frac("1", "x"))))
        XCTAssertTrue(analysis.roots(in: -10, 10).isEmpty)
    }

    func testExtremaAndInflectionOfCubic() throws {
        // x³ − 3x: Hochpunkt (−1 | 2), Tiefpunkt (1 | −2), Wendepunkt (0 | 0)
        let analysis = CurveAnalysis(expression: try parsed(row(lin("x"), sup("3"), lin("−3x"))))
        let extrema = analysis.extrema(in: -10, 10)
        XCTAssertEqual(extrema.map(\.kind), [.maximum, .minimum])
        XCTAssertEqual(extrema[0].x, -1, accuracy: 1e-10)
        XCTAssertEqual(extrema[0].y, 2, accuracy: 1e-10)
        XCTAssertEqual(extrema[1].x, 1, accuracy: 1e-10)
        let inflections = analysis.inflectionPoints(in: -10, 10)
        XCTAssertEqual(inflections.count, 1)
        XCTAssertEqual(inflections[0].x, 0, accuracy: 1e-10)
    }

    func testSaddlePoint() throws {
        let analysis = CurveAnalysis(expression: try parsed(row(lin("x"), sup("3"))))
        XCTAssertEqual(analysis.extrema(in: -5, 5).map(\.kind), [.saddle])
    }

    func testIntersectionOfParabolaAndLine() throws {
        // x² = x + 2 → x = −1, x = 2
        let analysis = CurveAnalysis(expression: try parsed(row(lin("x"), sup("2"))))
        let points = analysis.intersections(with: try f(MathRow(linear: "x+2")), in: -10, 10)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].x, -1, accuracy: 1e-10)
        XCTAssertEqual(points[1].x, 2, accuracy: 1e-10)
        XCTAssertEqual(points[1].y, 4, accuracy: 1e-9)
    }

    func testIntegralOfSine() throws {
        let value = try XCTUnwrap(NumericMethods.integral(of: sin, from: 0, to: .pi))
        XCTAssertEqual(value, 2, accuracy: 1e-9)
        let reversed = try XCTUnwrap(NumericMethods.integral(of: { $0 * $0 }, from: 3, to: 0))
        XCTAssertEqual(reversed, -9, accuracy: 1e-10)
    }

    func testIntegralAcrossPoleFails() {
        XCTAssertNil(NumericMethods.integral(of: { 1 / $0 }, from: -1, to: 1))
    }

    // MARK: - Zeichnen

    func testNiceStep() {
        XCTAssertEqual(PlotGeometry.niceStep(span: 20, target: 8), 2)
        XCTAssertEqual(PlotGeometry.niceStep(span: 0.9, target: 8), 0.1, accuracy: 1e-15)
        XCTAssertEqual(PlotGeometry.niceStep(span: 400, target: 8), 50)
    }

    func testTangentIsSplitAtPoles() {
        let viewport = Viewport(xMin: -5, xMax: 5, yMin: -5, yMax: 5)
        let lines = PlotGeometry.polylines(tan, viewport: viewport, size: CGSize(width: 400, height: 400), samples: 400)
        // Polstellen bei ±π/2 und ±3π/2 → fünf Äste, keine senkrechten Verbindungen
        XCTAssertEqual(lines.count, 5)
    }

    func testFormulaCompilerRejectsUnknownVariable() {
        guard case .failure(let failure) = FormulaCompiler.expression(MathRow(linear: "x+y"), allowed: ["x"]) else {
            return XCTFail("y sollte abgelehnt werden")
        }
        XCTAssertEqual(failure, .unknownVariable("y"))
        XCTAssertEqual(FormulaCompiler.number("2,5"), 2.5)
        XCTAssertEqual(try XCTUnwrap(FormulaCompiler.number("π/2")), Double.pi / 2, accuracy: 1e-15)
        XCTAssertNil(FormulaCompiler.number(""))
    }
}
