import XCTest
@testable import OPCalc

/// AK-03 bis AK-06: Gleichungen, Stochastik, Statistik, DGL, 3D.
final class SolverTests: XCTestCase {

    // MARK: - LGS (AK-03)

    func testLinearSystemUniqueWithFractions() throws {
        // 2x + y − z = 8 · −3x − y + 2z = −11 · −2x + y + 2z = −3  → (2, 3, −1)
        let system = [[2, 1, -1, 8], [-3, -1, 2, -11], [-2, 1, 2, -3]].map { $0.map { exact($0) } }
        let solution = try XCTUnwrap(LinearSystemSolver.solve(system))
        XCTAssertEqual(solution.kind, .unique)
        XCTAssertTrue(solution.isExact)
        XCTAssertEqual(solution.variables.map(\.constant), [exact(2), exact(3), exact(-1)])
    }

    func testLinearSystemExactFractions() throws {
        // x/2 + y/3 = 1 · x − y = 1/6 → x = 19/15, y = 11/10
        let system: [[Value]] = [[exact(1, 2), exact(1, 3), exact(1)], [exact(1), exact(-1), exact(1, 6)]]
        let solution = try XCTUnwrap(LinearSystemSolver.solve(system))
        XCTAssertEqual(solution.variables.map(\.constant), [exact(19, 15), exact(11, 10)])
    }

    func testLinearSystemWithoutSolution() throws {
        let system = [[1, 1, 1], [2, 2, 3]].map { $0.map { exact($0) } }
        XCTAssertEqual(try XCTUnwrap(LinearSystemSolver.solve(system)).kind, .none)
    }

    func testLinearSystemInfinitelyMany() throws {
        // x + y = 2 · 2x + 2y = 4 → x = 2 − t, y = t
        let system = [[1, 1, 2], [2, 2, 4]].map { $0.map { exact($0) } }
        let solution = try XCTUnwrap(LinearSystemSolver.solve(system))
        XCTAssertEqual(solution.kind, .infinite)
        XCTAssertEqual(solution.freeVariables, [1])
        XCTAssertEqual(solution.variables[0].constant, exact(2))
        XCTAssertEqual(solution.variables[0].coefficients, [exact(-1)])
    }

    func testLinearSystemNumericWithRoot() throws {
        // √2·x = 2 → x = √2 (genähert, weil √2 nicht rational ist)
        let system: [[Value]] = [[.exact(.radical(2)), exact(2)]]
        let solution = try XCTUnwrap(LinearSystemSolver.solve(system))
        XCTAssertFalse(solution.isExact)
        XCTAssertEqual(solution.variables[0].constant.doubleValue, 2.0.squareRoot(), accuracy: 1e-12)
    }

    // MARK: - Polynome (AK-03)

    func testQuadraticWithSquareRoots() {
        // x² − 2 = 0 → ±√2 exakt
        let solution = PolynomialSolver.solve([exact(1), exact(0), exact(-2)])
        XCTAssertEqual(solution.roots.count, 2)
        XCTAssertTrue(solution.roots.allSatisfy { $0.value.isExact })
        XCTAssertEqual(solution.roots[0].value, .exact(-ExactValue.radical(2)))
        XCTAssertEqual(solution.roots[1].value, .exact(.radical(2)))
    }

    func testCubicWithRationalRoots() {
        // 2x³ − 3x² − 11x + 6 → −2, 1/2, 3
        let solution = PolynomialSolver.solve([exact(2), exact(-3), exact(-11), exact(6)])
        XCTAssertEqual(solution.roots.map(\.value), [exact(-2), exact(1, 2), exact(3)])
        XCTAssertEqual(solution.nonRealCount, 0)
    }

    func testMultipleRootsAndComplexCount() {
        // x⁴ − 2x³ + 2x² − 2x + 1 = (x − 1)²(x² + 1)
        let solution = PolynomialSolver.solve([exact(1), exact(-2), exact(2), exact(-2), exact(1)])
        XCTAssertEqual(solution.roots, [PolynomialSolver.Root(value: exact(1), multiplicity: 2)])
        XCTAssertEqual(solution.nonRealCount, 2)
    }

    func testQuinticNumeric() throws {
        // x⁵ − x − 1 hat genau eine reelle Lösung ≈ 1,1673
        let solution = PolynomialSolver.solve([exact(1), exact(0), exact(0), exact(0), exact(-1), exact(-1)])
        XCTAssertEqual(solution.roots.count, 1)
        XCTAssertFalse(solution.roots[0].value.isExact)
        XCTAssertEqual(solution.roots[0].value.doubleValue, 1.1673039782614187, accuracy: 1e-12)
        XCTAssertEqual(solution.nonRealCount, 4)
    }

    func testZeroPolynomialIsIdentity() {
        XCTAssertTrue(PolynomialSolver.solve([exact(0), exact(0)]).isIdentity)
        XCTAssertEqual(PolynomialSolver.solve([exact(0), exact(5)]).roots, [])
    }

    // MARK: - Stochastik (AK-04)

    func testBinomialExact() {
        let b = BinomialDistribution(n: 10, p: exact(1, 2))
        XCTAssertEqual(b.probability(from: 0, to: 3), exact(176, 1024))
        XCTAssertEqual(b.mean, 5, accuracy: 1e-12)
    }

    func testBinomialLargeNumeric() {
        let b = BinomialDistribution(n: 5000, p: .approximate(0.3))
        XCTAssertEqual(b.probability(1500).doubleValue, 0.01231, accuracy: 3e-5)
    }

    func testCombinatorics() {
        XCTAssertEqual(Combinatorics.binomial(49, 6), BigInt(13_983_816))
        XCTAssertEqual(Combinatorics.permutations(10, 3), BigInt(720))
        XCTAssertEqual(Combinatorics.binomial(5, 7), BigInt(0))
    }

    func testNormalDistribution() throws {
        let standard = NormalDistribution(mean: 0, standardDeviation: 1)
        XCTAssertEqual(standard.cumulative(1.96), 0.9750021048517795, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(standard.quantile(0.975)), 1.959963984540054, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(standard.quantile(0.001)), -3.090232306167813, accuracy: 1e-10)
        XCTAssertNil(standard.quantile(1))
    }

    func testPoissonAndHypergeometric() {
        XCTAssertEqual(PoissonDistribution(lambda: 2).probability(3).doubleValue, 0.18044704431548356, accuracy: 1e-14)
        // Lotto: genau 3 Richtige aus 6 von 49
        let lotto = HypergeometricDistribution(populationSize: 49, successes: 6, draws: 6)
        XCTAssertEqual(lotto.probability(3), .exact(ExactValue(q(246820, 13983816))))
        XCTAssertEqual(lotto.probability(from: 0, to: 6), exact(1))
    }

    func testGeometric() {
        let g = GeometricDistribution(p: exact(1, 6))
        XCTAssertEqual(g.probability(2), exact(5, 36))
        XCTAssertEqual(g.mean, 6, accuracy: 1e-12)
    }

    func testDescriptiveStatistics() throws {
        let stats = try XCTUnwrap(DescriptiveStatistics([2, 4, 4, 4, 5, 5, 7, 9]))
        XCTAssertEqual(stats.mean, 5)
        XCTAssertEqual(stats.populationVariance, 4)
        XCTAssertEqual(try XCTUnwrap(stats.sampleVariance).squareRoot(), 2.138089935299395, accuracy: 1e-12)
        XCTAssertEqual(stats.median, 4.5)
        XCTAssertEqual(stats.lowerQuartile, 4)
        XCTAssertEqual(stats.upperQuartile, 6)
        XCTAssertEqual(stats.modes, [4])
    }

    func testRegression() throws {
        let x: [Double] = [1, 2, 3, 4, 5]
        let linear = try XCTUnwrap(Regression.fit(.linear, x: x, y: x.map { 2 * $0 + 1 }))
        XCTAssertEqual(linear.coefficients[0], 2, accuracy: 1e-12)
        XCTAssertEqual(linear.coefficients[1], 1, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(linear.r), 1, accuracy: 1e-12)
        let quadratic = try XCTUnwrap(Regression.fit(.quadratic, x: x, y: x.map { $0 * $0 - 3 }))
        XCTAssertEqual(quadratic.coefficients[0], 1, accuracy: 1e-9)
        XCTAssertEqual(quadratic.coefficients[2], -3, accuracy: 1e-9)
        let exponential = try XCTUnwrap(Regression.fit(.exponential, x: x, y: x.map { 3 * exp(0.5 * $0) }))
        XCTAssertEqual(exponential.coefficients[0], 3, accuracy: 1e-9)
        XCTAssertEqual(exponential.coefficients[1], 0.5, accuracy: 1e-12)
    }

    func testNumberList() {
        XCTAssertEqual(NumberList.parse("1,5; 2 −3\n4"), [1.5, 2, -3, 4])
        XCTAssertNil(NumberList.parse("1 a"))
    }

    // MARK: - DGL (AK-05)

    func testExponentialGrowth() throws {
        let trajectory = ODESolver.solve({ u, _ in [u[0]] }, u0: [1], from: 0, to: 1)
        XCTAssertNil(trajectory.stoppedAt)
        XCTAssertEqual(try XCTUnwrap(trajectory.samples.last?.u[0]), M_E, accuracy: 1e-8)
    }

    func testOscillatorSecondOrder() throws {
        // y″ = −y, y(0) = 0, y′(0) = 1 → y = sin x
        let trajectory = ODESolver.solve({ u, _ in [u[1], -u[0]] }, u0: [0, 1], from: 0, to: .pi)
        XCTAssertEqual(try XCTUnwrap(trajectory.samples.last?.u[0]), 0, accuracy: 1e-7)
        XCTAssertEqual(try XCTUnwrap(ODESolver.value(of: trajectory, at: .pi / 2)), 1, accuracy: 1e-3)
    }

    func testBlowUpStops() throws {
        // y′ = y², y(0) = 1 → y = 1/(1 − x), Pol bei x = 1
        let trajectory = ODESolver.solve({ u, _ in [u[0] * u[0]] }, u0: [1], from: 0, to: 2)
        let stop = try XCTUnwrap(trajectory.stoppedAt)
        XCTAssertLessThan(stop, 1)
        XCTAssertGreaterThan(stop, 0.99)
    }

    func testBackwardIntegration() throws {
        let trajectory = ODESolver.solve({ u, _ in [u[0]] }, u0: [1], from: 0, to: -1)
        XCTAssertEqual(try XCTUnwrap(trajectory.samples.last?.u[0]), 1 / M_E, accuracy: 1e-9)
    }

    // MARK: - 3D (AK-06)

    func testSurfaceMeshMarksUndefinedValues() {
        let mesh = SurfaceMesh({ x, y in 1 / (x * x + y * y) - 100 * Double(x == 0 && y == 0 ? 1 : 0) }, x: -1...1, y: -1...1, resolution: 2)
        XCTAssertTrue(mesh.z(1, 1).isNaN)
        XCTAssertEqual(mesh.z(0, 0), 0.5, accuracy: 1e-12)
    }

    func testProjectionAndDepthOrder() {
        let camera = Camera3D(yaw: 0, pitch: 0.5, zoom: 1)
        let size = CGSize(width: 300, height: 300)
        let center = camera.project(0, 0, 0, size: size)
        XCTAssertEqual(center.point.x, 150, accuracy: 1e-9)
        XCTAssertEqual(center.point.y, 150, accuracy: 1e-9)
        // Von vorn oben betrachtet: hinten (+y) ist weiter weg als vorn (−y), oben näher als unten
        XCTAssertGreaterThan(camera.project(0, 1, 0, size: size).depth, camera.project(0, -1, 0, size: size).depth)
        XCTAssertLessThan(camera.project(0, 0, 1, size: size).depth, camera.project(0, 0, -1, size: size).depth)
        XCTAssertLessThan(camera.project(0, 0, 1, size: size).point.y, center.point.y)

        let mesh = SurfaceMesh({ x, y in x + y }, x: -1...1, y: -1...1, resolution: 4)
        let quads = SurfaceRenderer.quads([mesh], zRange: mesh.zRange, camera: camera, size: size)
        XCTAssertEqual(quads.count, 16)
        XCTAssertEqual(quads.map(\.depth), quads.map(\.depth).sorted(by: >))
    }

    // MARK: - Befunde aus dem Review (R02)

    func testIntegralsWithRootAndLogEndpoints() throws {
        XCTAssertEqual(try XCTUnwrap(NumericMethods.integral(of: { $0.squareRoot() }, from: 0, to: 1)), 2.0 / 3, accuracy: 1e-9)
        // Halbkreisfläche
        XCTAssertEqual(try XCTUnwrap(NumericMethods.integral(of: { (1 - $0 * $0).squareRoot() }, from: -1, to: 1)),
                       Double.pi / 2, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(NumericMethods.integral(of: { $0 > 0 ? log($0) : .nan }, from: 0, to: 1)), -1, accuracy: 1e-8)
        // Polstelle neben einer Stützstelle bleibt „existiert nicht“
        XCTAssertNil(NumericMethods.integral(of: { 1 / ($0 - 0.3) }, from: 0, to: 1))
    }

    func testODEReachesEndWithoutFalseStop() {
        for x0 in stride(from: -3.0, through: 3.0, by: 0.37) {
            let trajectory = ODESolver.solve({ _, x in [sin(x)] }, u0: [0], from: x0, to: 10.0, maxStep: 20.0 / 300)
            XCTAssertNil(trajectory.stoppedAt, "x₀ = \(x0)")
        }
        XCTAssertNil(ODESolver.solve({ _, _ in [1] }, u0: [0], from: 0, to: 15, maxStep: 30.0 / 300).stoppedAt)
    }

    func testQuadraticRegressionWithLargeX() throws {
        let x = (0...10).map { Double(2000 + $0) }
        let fit = try XCTUnwrap(Regression.fit(.quadratic, x: x, y: x.map { 0.5 * ($0 - 2005) * ($0 - 2005) + 3 }))
        XCTAssertEqual(fit.value(at: 2005), 3, accuracy: 1e-6)
        XCTAssertEqual(fit.value(at: 2010), 15.5, accuracy: 1e-6)
        XCTAssertEqual(fit.rSquared, 1, accuracy: 1e-9)
    }

    func testDistributionsDoNotCrashAtExtremes() {
        _ = GeometricDistribution(p: .approximate(1e-20)).displayRange
        _ = GeometricDistribution(p: .approximate(0)).support
        _ = PoissonDistribution(lambda: -1).support
        _ = HypergeometricDistribution(populationSize: 5, successes: 9, draws: 7).support
        let poisson = PoissonDistribution(lambda: 1_000_000)
        XCTAssertEqual(poisson.probability(from: 0, to: 1_000_500).doubleValue, 0.6915, accuracy: 2e-3)
    }

    func testExtremumKindFromCurvature() throws {
        let analysis = CurveAnalysis(expression: try parsed(row(lin("−x"), sup("2"), lin("+4x"))))
        XCTAssertEqual(analysis.extrema(in: -10, 10).map(\.kind), [.maximum])
    }
}
