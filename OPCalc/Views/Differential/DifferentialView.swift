import SwiftUI

/// Differentialgleichungen (AK-05): 1. Ordnung mit Richtungsfeld, 2. Ordnung, System mit Phasenbild.
/// Antippen im Graphen setzt den Anfangswert.
struct DifferentialView: View {
    @Binding var mode: AppMode
    @Bindable var state: WorkspaceState

    @AppStorage("angleMode") private var angleModeRaw = "radians"
    @State private var viewport: Viewport?
    @State private var editing: Field?
    @State private var cache = SolutionCache()

    /// Merkt sich die letzte Lösung: Beim Verschieben wird nur neu gerechnet, wenn sich die
    /// Eingaben ändern oder der sichtbare Bereich den berechneten verlässt.
    final class SolutionCache {
        var key = ""
        var covered: ClosedRange<Double> = 0...0
        var width = 0.0
        var solution = Solution()
    }

    private var angleMode: AngleMode { AngleMode(rawValue: angleModeRaw) ?? .radians }
    private var evaluator: NumericEvaluator { NumericEvaluator(angleMode: angleMode) }

    enum Field: String, Identifiable {
        case first, second, systemX, systemY
        var id: String { rawValue }
    }

    /// Pfeile des Richtungsfelds je Bildbreite.
    static let fieldColumns = 18

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                let solution = self.solution
                GraphCanvas(viewport: $viewport, curves: [], paths: solution.paths, markers: solution.markers,
                            onTap: setInitialValue, underlay: directionField)
                    .frame(maxHeight: .infinity)
                ScrollView {
                    VStack(spacing: 12) {
                        inputCard
                        resultCard(solution)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                .frame(maxHeight: 300)
                .scrollDismissesKeyboard(.interactively)
                ModeBar(mode: $mode) {
                    RoundActionButton(systemImage: "arrow.up.left.and.down.right.magnifyingglass",
                                      accessibilityLabel: "Standardansicht") { viewport = nil }
                }
            }
            .background(Color.black)
            .navigationTitle("Differentialgleichung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack { Spacer(); Button("Fertig") { hideKeyboard() } }
                }
            }
            .sheet(item: $editing) { field in
                FormulaInputView(title: "Gleichung", prefix: prefix(field), variables: variables,
                                 initial: row(field)) { store($0, field) }
            }
        }
    }

    // MARK: - Eingabe

    private var variables: [String] {
        switch state.odeKind {
        case 0: return ["x", "y"]
        case 1: return ["x", "y", "y′"]
        default: return ["t", "x", "y"]
        }
    }

    private func prefix(_ field: Field) -> String {
        switch field {
        case .first: return "y′ ="
        case .second: return "y″ ="
        case .systemX: return "x′ ="
        case .systemY: return "y′ ="
        }
    }

    private func row(_ field: Field) -> MathRow {
        switch field {
        case .first: return state.odeFirst
        case .second: return state.odeSecond
        case .systemX: return state.odeSystemX
        case .systemY: return state.odeSystemY
        }
    }

    private func store(_ row: MathRow, _ field: Field) {
        switch field {
        case .first: state.odeFirst = row
        case .second: state.odeSecond = row
        case .systemX: state.odeSystemX = row
        case .systemY: state.odeSystemY = row
        }
    }

    private var inputCard: some View {
        Card {
            Picker("Art", selection: $state.odeKind) {
                Text("1. Ordnung").tag(0)
                Text("2. Ordnung").tag(1)
                Text("System").tag(2)
            }
            .pickerStyle(.segmented)
            .onChange(of: state.odeKind) { viewport = nil }
            switch state.odeKind {
            case 0: equationRow(.first, placeholder: "z. B. x − y")
            case 1: equationRow(.second, placeholder: "z. B. −y")
            default:
                equationRow(.systemX, placeholder: "z. B. y")
                equationRow(.systemY, placeholder: "z. B. −x")
            }
            HStack(spacing: 10) {
                NumberField(label: state.odeKind == 2 ? "x(0)" : "x₀", text: $state.odeX0, width: 60)
                NumberField(label: state.odeKind == 2 ? "y(0)" : "y₀", text: $state.odeY0, width: 60)
                if state.odeKind == 1 { NumberField(label: "y′₀", text: $state.odeYPrime0, width: 60) }
                if state.odeKind == 2 { NumberField(label: "t bis", text: $state.odeTEnd, width: 60) }
            }
            Text(state.odeKind == 1 ? "Tippe in den Graphen, um x₀ und y₀ zu setzen."
                 : "Tippe in den Graphen, um den Startpunkt zu setzen.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func equationRow(_ field: Field, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Text(prefix(field)).font(.system(size: 20)).foregroundStyle(.secondary)
            FormulaCell(row: row(field), placeholder: placeholder, minWidth: 120,
                        isInvalid: !row(field).isEmpty && expression(row(field)) == nil) { editing = field }
            Spacer(minLength: 0)
        }
    }

    private func expression(_ row: MathRow) -> Expr? {
        if case .success(let e) = FormulaCompiler.expression(row, allowed: Set(variables)) { return e }
        return nil
    }

    private func setInitialValue(_ x: Double, _ y: Double) {
        state.odeX0 = PlotGeometry.label(x, digits: 3)
        state.odeY0 = PlotGeometry.label(y, digits: 3)
    }

    // MARK: - Lösen

    struct Solution {
        var paths: [PlotPath] = []
        var markers: [PlotMarker] = []
        var lines: [String] = []
        var problem: String?
    }

    /// Rechte Seite F(u, t) des Systems u′ = F; nil, wenn die Eingabe unvollständig ist.
    private var system: (([Double], Double) -> [Double])? {
        let ev = evaluator
        switch state.odeKind {
        case 0:
            guard let f = expression(state.odeFirst) else { return nil }
            return { u, x in
                var v = VariableValues(); v.x = x; v.y = u[0]
                return [ev.value(f, v)]
            }
        case 1:
            guard let f = expression(state.odeSecond) else { return nil }
            return { u, x in
                var v = VariableValues(); v.x = x; v.y = u[0]; v.yPrime = u[1]
                return [u[1], ev.value(f, v)]
            }
        default:
            guard let f = expression(state.odeSystemX), let g = expression(state.odeSystemY) else { return nil }
            return { u, t in
                var v = VariableValues(); v.t = t; v.x = u[0]; v.y = u[1]
                return [ev.value(f, v), ev.value(g, v)]
            }
        }
    }

    private var inputKey: String {
        [String(state.odeKind), state.odeFirst.linearText, state.odeSecond.linearText, state.odeSystemX.linearText,
         state.odeSystemY.linearText, state.odeX0, state.odeY0, state.odeYPrime0, state.odeTEnd,
         state.odeEvaluateAt, angleModeRaw].joined(separator: "|")
    }

    private var solution: Solution {
        let view = viewport ?? .standard(aspect: 1)
        let key = inputKey
        // System: unabhängig vom Ausschnitt. Sonst reicht die Lösung, solange der Ausschnitt
        // im berechneten Bereich liegt und nicht stark hineingezoomt wurde (Kurve bliebe eckig).
        let fits = state.odeKind == 2 || (cache.covered.contains(view.xMin) && cache.covered.contains(view.xMax)
                                           && view.width > cache.width / 4)
        if cache.key == key && fits { return cache.solution }
        // Doppelte Breite rechnen, damit kleines Verschieben nichts auslöst
        let computeView = Viewport(xMin: view.xMin - view.width / 2, xMax: view.xMax + view.width / 2,
                                   yMin: view.yMin, yMax: view.yMax)
        let result = computeSolution(in: computeView)
        cache.key = key
        cache.covered = computeView.xMin...computeView.xMax
        cache.width = view.width
        cache.solution = result
        return result
    }

    private func computeSolution(in view: Viewport) -> Solution {
        guard let F = system else { return Solution(problem: "Gib die Gleichung ein.") }
        guard let x0 = FormulaCompiler.number(state.odeX0, angleMode: angleMode),
              let y0 = FormulaCompiler.number(state.odeY0, angleMode: angleMode) else {
            return Solution(problem: "Die Startwerte sind keine Zahlen.")
        }
        var result = Solution()
        let color = KeyPalette.operation

        if state.odeKind == 2 {
            guard let tEnd = FormulaCompiler.number(state.odeTEnd, angleMode: angleMode), tEnd > 0 else {
                return Solution(problem: "„t bis“ muss größer als 0 sein.")
            }
            let trajectory = ODESolver.solve(F, u0: [x0, y0], from: 0, to: tEnd, maxStep: tEnd / 400)
            result.paths = [PlotPath(id: "phase", color: color, points: trajectory.samples.map { (x: $0.u[0], y: $0.u[1]) })]
            result.markers = [PlotMarker(id: "start", x: x0, y: y0, color: .white)]
            if let stop = trajectory.stoppedAt {
                result.lines.append(trajectory.ranOutOfSteps
                    ? "Die Rechnung endet bei t ≈ " + PlotGeometry.label(stop, digits: 4) + " (zu viele Schritte)."
                    : "Die Lösung wächst bei t ≈ " + PlotGeometry.label(stop, digits: 4) + " über alle Grenzen.")
            }
            if let t = FormulaCompiler.number(state.odeEvaluateAt, angleMode: angleMode), t >= 0, t <= tEnd {
                let toPoint = exact(F, [x0, y0], 0, t)
                if let xt = ODESolver.value(of: toPoint, at: t, component: 0),
                   let yt = ODESolver.value(of: toPoint, at: t, component: 1) {
                    result.lines.append(approxText("x(" + PlotGeometry.label(t) + ")", xt, digits: 10))
                    result.lines.append(approxText("y(" + PlotGeometry.label(t) + ")", yt, digits: 10))
                }
            }
            return result
        }
        var u0 = [y0]
        if state.odeKind == 1 {
            guard let yp = FormulaCompiler.number(state.odeYPrime0, angleMode: angleMode) else {
                return Solution(problem: "y′₀ ist keine Zahl.")
            }
            u0.append(yp)
        }
        // Feine Schritte für glatte Kurven, aber höchstens etwa 20 000 Schritte je Richtung
        let reach = max(Swift.abs(view.xMax - x0), Swift.abs(view.xMin - x0), view.width)
        let maxStep = max(view.width / 300, reach / 20_000)
        let forward = ODESolver.solve(F, u0: u0, from: x0, to: max(view.xMax, x0), maxStep: maxStep)
        let backward = ODESolver.solve(F, u0: u0, from: x0, to: min(view.xMin, x0), maxStep: maxStep)
        let points: [(x: Double, y: Double)] = backward.samples.reversed().map { (x: $0.t, y: $0.u[0]) }
            + forward.samples.dropFirst().map { (x: $0.t, y: $0.u[0]) }
        result.paths = [PlotPath(id: "solution", color: color, points: points)]
        result.markers = [PlotMarker(id: "start", x: x0, y: y0, color: .white)]
        for (stop, side) in [(forward.stoppedAt, "rechts"), (backward.stoppedAt, "links")] {
            if let stop {
                let ranOut = side == "rechts" ? forward.ranOutOfSteps : backward.ranOutOfSteps
                result.lines.append(ranOut
                    ? "Nach " + side + " endet die Rechnung bei x ≈ " + PlotGeometry.label(stop, digits: 4) + " (zu viele Schritte)."
                    : "Nach " + side + " bricht die Lösung bei x ≈ " + PlotGeometry.label(stop, digits: 4) + " ab.")
            }
        }
        if let x = FormulaCompiler.number(state.odeEvaluateAt, angleMode: angleMode) {
            let trajectory = exact(F, u0, x0, x)
            if trajectory.stoppedAt == nil, let y = trajectory.samples.last?.u[0] {
                result.lines.append(approxText("y(" + PlotGeometry.label(x) + ")", y, digits: 10))
                result.markers.append(PlotMarker(id: "value", x: x, y: y, color: color))
            } else {
                result.lines.append("y(" + PlotGeometry.label(x) + ") lässt sich nicht berechnen: Die Lösung bricht vorher ab.")
            }
        }
        return result
    }

    /// Lösung genau bis zur Stelle (ohne Begrenzung durch den sichtbaren Bereich).
    private func exact(_ F: ([Double], Double) -> [Double], _ u0: [Double], _ t0: Double, _ t1: Double) -> ODESolver.Trajectory {
        ODESolver.solve(F, u0: u0, from: t0, to: t1, maxStep: max(Swift.abs(t1 - t0), 1e-9) / 50)
    }

    private func resultCard(_ solution: Solution) -> some View {
        Card {
            if let problem = solution.problem {
                Text(problem).foregroundStyle(.secondary)
            } else {
                NumberField(label: state.odeKind == 2 ? "Wert bei t =" : "Wert bei x =", text: $state.odeEvaluateAt, width: 90)
                ForEach(solution.lines, id: \.self) { line in
                    Text(line).font(.body.monospacedDigit())
                }
            }
        }
    }

    // MARK: - Richtungsfeld

    private func directionField(_ context: GraphicsContext, _ size: CGSize, _ view: Viewport) {
        guard state.odeKind != 1, let F = system else { return }
        let columns = Self.fieldColumns
        let cell = Double(size.width) / Double(columns)
        let rows = max(1, Int(Double(size.height) / cell))
        var path = Path()
        for i in 0..<columns {
            for j in 0..<rows {
                let center = CGPoint(x: (Double(i) + 0.5) * cell, y: (Double(j) + 0.5) * cell)
                let w = view.world(center, in: size)
                // 1. Ordnung: Richtung (1, f); System: (x′, y′) bei t = 0
                let d = state.odeKind == 0 ? [1, F([w.y], w.x)[0]] : F([w.x, w.y], 0)
                guard d.count == 2, d[0].isFinite, d[1].isFinite else { continue }
                // In Bildschirmrichtung umrechnen (y nach unten)
                let dx = d[0] / view.width * Double(size.width)
                let dy = -d[1] / view.height * Double(size.height)
                let length = (dx * dx + dy * dy).squareRoot()
                guard length > 0 else { continue }
                let half = cell * 0.35
                let ux = dx / length * half, uy = dy / length * half
                path.move(to: CGPoint(x: center.x - ux, y: center.y - uy))
                path.addLine(to: CGPoint(x: center.x + ux, y: center.y + uy))
            }
        }
        context.stroke(path, with: .color(Color(white: 0.4)), lineWidth: 1.2)
    }
}
