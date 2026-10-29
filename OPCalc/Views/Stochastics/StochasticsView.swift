import SwiftUI
import SwiftData
import UIKit

/// Stochastik (AK-04): Verteilungen, Kombinatorik, Statistik mit Regression.
struct StochasticsView: View {
    @Binding var mode: AppMode
    @Bindable var state: WorkspaceState

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Bereich", selection: $state.stochasticsTab) {
                    Text("Verteilung").tag(0)
                    Text("Kombinatorik").tag(1)
                    Text("Statistik").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 14) {
                        switch state.stochasticsTab {
                        case 0: DistributionPanel(state: state)
                        case 1: CombinatoricsPanel(state: state)
                        default: StatisticsPanel(state: state, mode: $mode)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)

                ModeBar(mode: $mode) { EmptyView() }
            }
            .background(Color.black)
            .navigationTitle("Stochastik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Fertig") { hideKeyboard() }
                    }
                }
            }
        }
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// Exakter Wert aus einem Textfeld („0,5“, „1/6“), sonst nil.
func exactInput(_ text: String) -> Value? {
    let cleaned = text.trimmingCharacters(in: .whitespaces)
    guard !cleaned.isEmpty, case .success(let expression) = FormulaCompiler.expression(MathRow(linear: cleaned), allowed: []),
          let value = try? Evaluator().evaluate(expression) else { return nil }
    return value.doubleValue.isFinite ? value : nil
}

/// Ganze Zahl aus einem Textfeld.
func integerInput(_ text: String) -> Int? {
    guard let value = FormulaCompiler.number(text), value == value.rounded(), Swift.abs(value) < 1e9 else { return nil }
    return Int(value)
}

// MARK: - Verteilungen

private struct DistributionPanel: View {
    @Bindable var state: WorkspaceState

    private static let names = ["Binomial", "Normal", "Poisson", "Hypergeometrisch", "Geometrisch"]
    private static let defaults: [[String]] = [["10", "0,5"], ["0", "1"], ["2"], ["49", "6", "6"], ["1/6"]]
    private static let labels: [[String]] = [["n", "p"], ["μ", "σ"], ["λ"], ["N", "M", "n"], ["p"]]

    private var isNormal: Bool { state.distribution == 1 }

    private var queryTitles: [String] {
        isNormal ? ["P(X ≤ x)", "P(X ≥ x)", "P(a ≤ X ≤ b)", "Quantil"]
                 : ["P(X = k)", "P(X ≤ k)", "P(X ≥ k)", "P(a ≤ X ≤ b)"]
    }

    var body: some View {
        Card {
            Picker("Verteilung", selection: $state.distribution) {
                ForEach(Self.names.indices, id: \.self) { Text(Self.names[$0]).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(KeyPalette.operation)
            .onChange(of: state.distribution) {
                state.parameters = Self.defaults[state.distribution] + ["", "", ""]
                state.queryKind = isNormal ? 0 : 1
            }
            HStack(spacing: 12) {
                ForEach(Self.labels[state.distribution].indices, id: \.self) { i in
                    NumberField(label: Self.labels[state.distribution][i], text: $state.parameters[i], width: 64)
                }
            }
            Picker("Frage", selection: $state.queryKind) {
                ForEach(queryTitles.indices, id: \.self) { Text(queryTitles[$0]).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack(spacing: 12) {
                NumberField(label: firstLabel, text: $state.queryA, width: 80)
                if needsSecondBound {
                    NumberField(label: "b", text: $state.queryB, width: 80)
                }
            }
        }
        resultCard
    }

    private var needsSecondBound: Bool { isNormal ? state.queryKind == 2 : state.queryKind == 3 }

    private var firstLabel: String {
        if needsSecondBound { return "a" }
        if isNormal { return state.queryKind == 3 ? "p" : "x" }
        return "k"
    }

    // MARK: Rechnen

    private enum Model {
        case discrete(any DiscreteDistribution)
        case normal(NormalDistribution)
    }

    private var model: Result<Model, MessageError> {
        let p = state.parameters
        switch state.distribution {
        case 0:
            guard let n = integerInput(p[0]), n >= 0, n <= 1_000_000 else { return .failure("n muss eine ganze Zahl ab 0 sein.") }
            guard let prob = exactInput(p[1]), (0...1).contains(prob.doubleValue) else { return .failure("p muss zwischen 0 und 1 liegen.") }
            return .success(.discrete(BinomialDistribution(n: n, p: prob)))
        case 1:
            guard let mu = FormulaCompiler.number(p[0]) else { return .failure("μ ist keine Zahl.") }
            guard let sigma = FormulaCompiler.number(p[1]), sigma > 0 else { return .failure("σ muss größer als 0 sein.") }
            return .success(.normal(NormalDistribution(mean: mu, standardDeviation: sigma)))
        case 2:
            guard let lambda = FormulaCompiler.number(p[0]), lambda >= 0, lambda <= 1e6 else { return .failure("λ muss mindestens 0 sein.") }
            return .success(.discrete(PoissonDistribution(lambda: lambda)))
        case 3:
            guard let N = integerInput(p[0]), let M = integerInput(p[1]), let n = integerInput(p[2]),
                  N >= 1, M >= 0, M <= N, n >= 0, n <= N, N <= 1_000_000 else {
                return .failure("Es muss gelten: 0 ≤ M ≤ N und 0 ≤ n ≤ N.")
            }
            return .success(.discrete(HypergeometricDistribution(populationSize: N, successes: M, draws: n)))
        default:
            // Untergrenze 10⁻¹²: darunter werden Erwartungswert und Diagrammbereich unbrauchbar groß
            guard let prob = exactInput(p[0]), prob.doubleValue >= 1e-12, prob.doubleValue <= 1 else {
                return .failure("p muss zwischen 0,000000000001 und 1 liegen.")
            }
            return .success(.discrete(GeometricDistribution(p: prob)))
        }
    }

    private struct Answer {
        var value: Value?
        var text: String?
        var highlight: ClosedRange<Double>?
    }

    private func answer(_ model: Model) -> Result<Answer, MessageError> {
        switch model {
        case .discrete(let d):
            guard let a = integerInput(state.queryA) else { return .failure("Bitte eine ganze Zahl eingeben.") }
            switch state.queryKind {
            case 0: return .success(Answer(value: d.probability(a), highlight: Double(a)...Double(a)))
            case 1: return .success(Answer(value: d.probability(from: Int.min / 2, to: a), highlight: -.infinity...Double(a)))
            case 2: return .success(Answer(value: complement(d.probability(from: Int.min / 2, to: a - 1)),
                                           highlight: Double(a)...Double.infinity))
            default:
                guard let b = integerInput(state.queryB), b >= a else { return .failure("b muss mindestens a sein.") }
                return .success(Answer(value: d.probability(from: a, to: b), highlight: Double(a)...Double(b)))
            }
        case .normal(let n):
            guard let a = FormulaCompiler.number(state.queryA) else { return .failure("Bitte eine Zahl eingeben.") }
            switch state.queryKind {
            case 0: return .success(Answer(value: .approximate(n.cumulative(a)), highlight: -.infinity...a))
            case 1: return .success(Answer(value: .approximate(1 - n.cumulative(a)), highlight: a...Double.infinity))
            case 2:
                guard let b = FormulaCompiler.number(state.queryB), b >= a else { return .failure("b muss mindestens a sein.") }
                return .success(Answer(value: .approximate(n.cumulative(b) - n.cumulative(a)), highlight: a...b))
            default:
                guard let x = n.quantile(a) else { return .failure("p muss zwischen 0 und 1 liegen (ohne 0 und 1).") }
                return .success(Answer(text: approxText("x", x, digits: 10), highlight: -.infinity...x))
            }
        }
    }

    private func complement(_ value: Value) -> Value {
        if case .exact(let v) = value, let r = v.rationalValue { return .exact(ExactValue(Rational.one - r)) }
        return .approximate(max(0, 1 - value.doubleValue))
    }

    // MARK: Anzeige

    @ViewBuilder
    private var resultCard: some View {
        Card {
            switch model {
            case .failure(let error):
                Text(error.message).foregroundStyle(.red)
            case .success(let m):
                switch answer(m) {
                case .failure(let error):
                    Text(error.message).foregroundStyle(.red)
                case .success(let result):
                    HStack(spacing: 6) {
                        Text(state.queryKind == 3 && isNormal ? "Quantil" : queryTitles[state.queryKind])
                            .font(.system(size: 20)).foregroundStyle(.secondary)
                        if let value = result.value { ValueView(value: value) }
                    }
                    if let value = result.value, value.isExact, value.exactBits <= ValueView.maxExactBits {
                        Text(approxText("", value.doubleValue, digits: 10).trimmingCharacters(in: .whitespaces))
                            .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    if let text = result.text { Text(text).font(.title3.monospacedDigit()) }
                    DistributionChart(model: chartModel(m), highlight: result.highlight)
                        .frame(height: 170)
                    Text(summary(m)).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func chartModel(_ m: Model) -> DistributionChart.Model {
        switch m {
        case .discrete(let d):
            let range = d.displayRange
            let step = max(1, (range.upperBound - range.lowerBound + 1) / 120)
            let ks = stride(from: range.lowerBound, through: range.upperBound, by: step).map { $0 }
            return .bars(ks.map { DistributionChart.Bar(k: $0, p: d.probability($0).doubleValue) })
        case .normal(let n):
            return .curve(n)
        }
    }

    private func summary(_ m: Model) -> String {
        switch m {
        case .discrete(let d):
            return approxText("E(X)", d.mean) + "   " + approxText("σ", d.standardDeviation)
        case .normal(let n):
            return "E(X) = " + PlotGeometry.label(n.mean) + "   σ = " + PlotGeometry.label(n.standardDeviation)
        }
    }
}

struct MessageError: Error, ExpressibleByStringLiteral {
    let message: String
    init(stringLiteral value: String) { message = value }
}

/// Säulendiagramm (diskret) oder Glockenkurve (normal) mit markiertem Bereich.
struct DistributionChart: View {
    struct Bar { let k: Int; let p: Double }
    enum Model {
        case bars([Bar])
        case curve(NormalDistribution)
    }

    let model: Model
    let highlight: ClosedRange<Double>?

    var body: some View {
        Canvas { context, size in
            let plot = CGRect(x: 0, y: 4, width: size.width, height: size.height - 22)
            switch model {
            case .bars(let bars):
                guard let first = bars.first, let last = bars.last else { return }
                let maxP = max(bars.map(\.p).max() ?? 0, 1e-300)
                let width = plot.width / CGFloat(bars.count)
                for (i, bar) in bars.enumerated() {
                    let h = CGFloat(bar.p / maxP) * plot.height
                    let rect = CGRect(x: plot.minX + CGFloat(i) * width + width * 0.1, y: plot.maxY - h,
                                      width: max(1, width * 0.8), height: h)
                    let isMarked = highlight?.contains(Double(bar.k)) ?? false
                    context.fill(Path(rect), with: .color(isMarked ? KeyPalette.operation : Color(white: 0.35)))
                }
                drawLabel(String(first.k), at: CGPoint(x: plot.minX + width / 2, y: plot.maxY + 4), in: context)
                drawLabel(String(last.k), at: CGPoint(x: plot.maxX - width / 2, y: plot.maxY + 4), in: context)
            case .curve(let n):
                let lower = n.mean - 4 * n.standardDeviation, upper = n.mean + 4 * n.standardDeviation
                let peak = n.density(n.mean)
                func point(_ x: Double) -> CGPoint {
                    CGPoint(x: plot.minX + CGFloat((x - lower) / (upper - lower)) * plot.width,
                            y: plot.maxY - CGFloat(n.density(x) / peak) * plot.height)
                }
                if let highlight {
                    let a = max(lower, highlight.lowerBound), b = min(upper, highlight.upperBound)
                    if b > a {
                        var area = Path()
                        area.move(to: CGPoint(x: point(a).x, y: plot.maxY))
                        for i in 0...200 { area.addLine(to: point(a + (b - a) * Double(i) / 200)) }
                        area.addLine(to: CGPoint(x: point(b).x, y: plot.maxY))
                        area.closeSubpath()
                        context.fill(area, with: .color(KeyPalette.operation.opacity(0.5)))
                    }
                }
                var curve = Path()
                curve.move(to: point(lower))
                for i in 1...300 { curve.addLine(to: point(lower + (upper - lower) * Double(i) / 300)) }
                context.stroke(curve, with: .color(.white), lineWidth: 2)
                drawLabel(PlotGeometry.label(n.mean, digits: 4), at: CGPoint(x: plot.midX, y: plot.maxY + 4), in: context)
            }
            var axis = Path()
            axis.move(to: CGPoint(x: plot.minX, y: plot.maxY))
            axis.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
            context.stroke(axis, with: .color(Color(white: 0.5)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private func drawLabel(_ text: String, at point: CGPoint, in context: GraphicsContext) {
        context.draw(Text(text).font(.caption2.monospacedDigit()).foregroundStyle(Color(white: 0.6)), at: point, anchor: .top)
    }
}

// MARK: - Kombinatorik

private struct CombinatoricsPanel: View {
    @Bindable var state: WorkspaceState

    var body: some View {
        Card {
            HStack(spacing: 16) {
                NumberField(label: "n", text: $state.combinatoricsN, width: 80)
                NumberField(label: "k", text: $state.combinatoricsK, width: 80)
            }
            if let n = integerInput(state.combinatoricsN), let k = integerInput(state.combinatoricsK), n >= 0, k >= 0 {
                row("Kombinationen (n über k)", Combinatorics.binomial(n, k))
                row("Variationen n!/(n−k)!", Combinatorics.permutations(n, k))
                row("Fakultät n!", Combinatorics.permutations(n, n))
                // Mehr als 20 000 Bit (≈ 6000 Stellen) sind nicht mehr lesbar und kosten Rechenzeit
                row("Mit Wiederholung nᵏ", Double(k) * log2(Double(max(n, 2))) <= 20_000 ? BigInt(n).power(k) : nil)
            } else {
                Text("Bitte ganze Zahlen ab 0 eingeben.").foregroundStyle(.red)
            }
            Text("Exakt bis n = \(Combinatorics.maxExactN).").font(.footnote).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func row(_ title: String, _ value: BigInt?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(.secondary)
            if let value {
                let exact = Value.exact(ExactValue(Rational(value)))
                if value.description.count <= 30 {
                    Text(value.description).font(.title3.monospacedDigit()).textSelection(.enabled)
                } else {
                    ValueView(value: exact, fontSize: 20)
                }
            } else {
                Text("zu groß").foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Statistik

private struct StatisticsPanel: View {
    @Bindable var state: WorkspaceState
    @Binding var mode: AppMode
    @Environment(\.modelContext) private var modelContext
    @State private var viewport: Viewport?
    @State private var message: String?

    var body: some View {
        Card {
            SectionTitle(text: "Werte (x)")
            listEditor($state.listX)
            SectionTitle(text: "Zweite Reihe (y), für Regression")
            listEditor($state.listY)
            Text("Zahlen durch Leerzeichen, Semikolon oder Zeilen trennen; Komma als Dezimalzeichen.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        if let xs = NumberList.parse(state.listX), let stats = DescriptiveStatistics(xs) {
            statisticsCard(stats)
            if let ys = NumberList.parse(state.listY), !ys.isEmpty {
                regressionCard(x: xs, y: ys)
            }
        } else if !state.listX.isEmpty {
            Card { Text("Die Werte enthalten etwas, das keine Zahl ist.").foregroundStyle(.red) }
        }
    }

    private func listEditor(_ text: Binding<String>) -> some View {
        TextField("z. B. 2 4 4 5 7", text: text, axis: .vertical)
            .keyboardType(.numbersAndPunctuation)
            .autocorrectionDisabled()
            .lineLimit(2...5)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.17)))
    }

    private func statisticsCard(_ s: DescriptiveStatistics) -> some View {
        Card {
            SectionTitle(text: "Kennzahlen")
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                statRow("Anzahl n", String(s.count))
                statRow("Summe", PlotGeometry.label(s.sum, digits: 10))
                statRow("Mittelwert x̄", PlotGeometry.label(s.mean, digits: 10))
                statRow("Median", PlotGeometry.label(s.median, digits: 10))
                statRow("Modus", s.modes.isEmpty ? "–" : s.modes.map { PlotGeometry.label($0) }.joined(separator: "; "))
                statRow("Minimum / Maximum", PlotGeometry.label(s.minimum) + " / " + PlotGeometry.label(s.maximum))
                statRow("Spannweite", PlotGeometry.label(s.range))
                statRow("Quartile Q₁ / Q₃", PlotGeometry.label(s.lowerQuartile) + " / " + PlotGeometry.label(s.upperQuartile))
                statRow("Standardabw. σ (n)", PlotGeometry.label(s.populationVariance.squareRoot(), digits: 8))
                statRow("Standardabw. s (n − 1)", s.sampleVariance.map { PlotGeometry.label($0.squareRoot(), digits: 8) } ?? "–")
                statRow("Varianz σ²", PlotGeometry.label(s.populationVariance, digits: 8))
            }
            BoxPlot(statistics: s).frame(height: 56)
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).font(.body.monospacedDigit()).textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func regressionCard(x: [Double], y: [Double]) -> some View {
        Card {
            SectionTitle(text: "Regression")
            if x.count != y.count {
                Text("x und y brauchen gleich viele Werte (\(x.count) und \(y.count)).").foregroundStyle(.red)
            } else {
                Picker("Modell", selection: $state.regressionModel) {
                    ForEach(Regression.Model.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if let fit = Regression.fit(state.regressionModel, x: x, y: y) {
                    MathRowView(row: Self.formula(fit), path: [], context: .display)
                        .environment(\.mathFontSize, 22)
                    Text(regressionSummary(fit)).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                    GraphCanvas(viewport: $viewport,
                                curves: [PlotCurve(id: "fit", color: KeyPalette.operation, f: fit.value(at:))],
                                markers: zip(x, y).enumerated().map { PlotMarker(id: "p\($0.offset)", x: $0.element.0,
                                                                                   y: $0.element.1, color: .white) })
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onAppear { viewport = Self.fittingViewport(x, y) }
                        .onChange(of: state.listX) { viewport = Self.fittingViewport(x, y) }
                        .onChange(of: state.listY) { viewport = Self.fittingViewport(x, y) }
                    Button {
                        showInGraph(fit)
                    } label: {
                        Label("Im Graph zeigen", systemImage: "chart.xyaxis.line")
                    }
                    .tint(KeyPalette.operation)
                    if let message { Text(message).font(.footnote).foregroundStyle(.red) }
                } else {
                    Text(state.regressionModel == .exponential
                         ? "Exponentiell geht nur mit positiven y-Werten und verschiedenen x-Werten."
                         : "Dafür reichen die Werte nicht (verschiedene x-Werte nötig).")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func regressionSummary(_ fit: Regression) -> String {
        var parts: [String] = []
        if let r = fit.r { parts.append(approxText("r", r)) }
        parts.append(approxText("R²", fit.rSquared))
        return parts.joined(separator: "   ")
    }

    static func fittingViewport(_ x: [Double], _ y: [Double]) -> Viewport {
        let (x0, x1) = (x.min() ?? 0, x.max() ?? 1), (y0, y1) = (y.min() ?? 0, y.max() ?? 1)
        let dx = max(x1 - x0, 1) * 0.15, dy = max(y1 - y0, 1) * 0.15
        return Viewport(xMin: x0 - dx, xMax: x1 + dx, yMin: y0 - dy, yMax: y1 + dy)
    }

    /// Regressionsgleichung als Formel, z. B. y = 2,1x + 0,3
    static func formula(_ fit: Regression) -> MathRow {
        var items = MathRow(linear: "y=").items
        items.append(contentsOf: functionRow(fit).items)
        return MathRow(items)
    }

    /// Nur die rechte Seite – auch als Funktion für den Graphen.
    static func functionRow(_ fit: Regression) -> MathRow {
        let c = fit.coefficients
        var items: [MathItem] = []
        func number(_ value: Double, leading: Bool) {
            if !leading { items.append(MathItem(.op(value < 0 ? .minus : .plus))) } else if value < 0 { items.append(MathItem(.op(.minus))) }
            items.append(contentsOf: MathRow(linear: plainDecimal(Swift.abs(value))).items)
        }
        let x = MathItem(.variable("x"))
        switch fit.model {
        case .linear:
            number(c[0], leading: true); items.append(x)
            number(c[1], leading: false)
        case .quadratic:
            number(c[0], leading: true); items.append(x); items.append(MathItem(.power, slots: [MathRow(linear: "2")]))
            number(c[1], leading: false); items.append(x)
            number(c[2], leading: false)
        case .exponential:
            number(c[0], leading: true)
            items.append(MathItem(.constant(.e)))
            var exponent = MathRow(linear: c[1] < 0 ? "−" : "").items
            exponent.append(contentsOf: MathRow(linear: plainDecimal(Swift.abs(c[1]))).items)
            exponent.append(x)
            items.append(MathItem(.power, slots: [MathRow(exponent)]))
        }
        return MathRow(items)
    }

    /// Dezimalzahl ohne Zehnerpotenz, 6 gültige Stellen (für Formeln, die weiterverwendet werden).
    static func plainDecimal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 6
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    private func showInGraph(_ fit: Regression) {
        let existing = (try? modelContext.fetch(FetchDescriptor<GraphFunction>(predicate: #Predicate { $0.kind == "2d" }))) ?? []
        guard existing.count < GraphView.maxFunctions else {
            message = "Im Graph ist kein Platz mehr. Lösche dort zuerst eine Funktion."
            return
        }
        let used = Set(existing.map(\.colorIndex))
        let color = (0..<GraphPalette.colors.count).first { !used.contains($0) } ?? existing.count
        modelContext.insert(GraphFunction(order: (existing.map(\.order).max() ?? -1) + 1,
                                          formula: Self.functionRow(fit), colorIndex: color, kind: "2d"))
        mode = .graph
    }
}

/// Boxplot: Minimum, Q₁, Median, Q₃, Maximum.
private struct BoxPlot: View {
    let statistics: DescriptiveStatistics

    var body: some View {
        Canvas { context, size in
            let s = statistics
            let span = max(s.range, 1e-12)
            func x(_ v: Double) -> CGFloat { 10 + CGFloat((v - s.minimum) / span) * (size.width - 20) }
            let mid = size.height / 2 - 6
            var whisker = Path()
            whisker.move(to: CGPoint(x: x(s.minimum), y: mid)); whisker.addLine(to: CGPoint(x: x(s.lowerQuartile), y: mid))
            whisker.move(to: CGPoint(x: x(s.upperQuartile), y: mid)); whisker.addLine(to: CGPoint(x: x(s.maximum), y: mid))
            for v in [s.minimum, s.maximum] {
                whisker.move(to: CGPoint(x: x(v), y: mid - 8)); whisker.addLine(to: CGPoint(x: x(v), y: mid + 8))
            }
            context.stroke(whisker, with: .color(.white), lineWidth: 1.5)
            let box = CGRect(x: x(s.lowerQuartile), y: mid - 14, width: max(1, x(s.upperQuartile) - x(s.lowerQuartile)), height: 28)
            context.fill(Path(box), with: .color(KeyPalette.operation.opacity(0.35)))
            context.stroke(Path(box), with: .color(KeyPalette.operation), lineWidth: 1.5)
            var median = Path()
            median.move(to: CGPoint(x: x(s.median), y: mid - 14)); median.addLine(to: CGPoint(x: x(s.median), y: mid + 14))
            context.stroke(median, with: .color(.white), lineWidth: 2)
            for v in [s.minimum, s.maximum] {
                context.draw(Text(PlotGeometry.label(v, digits: 4)).font(.caption2).foregroundStyle(Color(white: 0.6)),
                             at: CGPoint(x: x(v), y: size.height - 2), anchor: .bottom)
            }
        }
        .accessibilityLabel("Boxplot")
    }
}
