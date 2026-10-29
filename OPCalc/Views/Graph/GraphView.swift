import SwiftUI
import SwiftData

/// Graph 2D (AK-02): bis zu sechs Funktionen zeichnen und untersuchen.
struct GraphView: View {
    @Binding var mode: AppMode

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<GraphFunction> { $0.kind == "2d" }, sort: \GraphFunction.order)
    private var functions: [GraphFunction]
    @AppStorage("angleMode") private var angleModeRaw = "radians"

    @State private var viewport: Viewport?
    @State private var editing: EditTarget?
    @State private var result: AnalysisOutcome?
    @State private var tracedID: UUID?
    @State private var valuePrompt: GraphFunction?
    @State private var integralPrompt: GraphFunction?
    @State private var inputA = ""
    @State private var inputB = ""

    static let maxFunctions = 6

    /// Funktion mit Position (für den Namen f, g, h …). Struktur statt Tupel (Leitfaden §6).
    struct IndexedFunction: Identifiable {
        let index: Int
        let function: GraphFunction
        var id: UUID { function.uid }
        var name: String { GraphFunction.name(at: index) }
    }

    private var indexed: [IndexedFunction] {
        functions.enumerated().map { IndexedFunction(index: $0.offset, function: $0.element) }
    }

    struct EditTarget: Identifiable {
        let id: UUID
        let function: GraphFunction?
    }

    /// Ergebnis einer Analyse: Liste unter dem Graphen, Punkte im Graphen.
    struct AnalysisOutcome {
        var title: String
        var points: [CurvePoint]
        var lines: [String] = []
        var color: Color
        var area: (uid: UUID, a: Double, b: Double)?
    }

    private var angleMode: AngleMode { AngleMode(rawValue: angleModeRaw) ?? .radians }
    private var evaluator: NumericEvaluator { NumericEvaluator(angleMode: angleMode) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvas
                    .frame(maxHeight: .infinity)
                if let result { resultPanel(result) }
                functionList
                ModeBar(mode: $mode) { bottomActions }
            }
            .background(Color.black)
            .navigationTitle("Graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { toolbarContent }
            .sheet(item: $editing) { target in
                FormulaInputView(title: target.function == nil ? "Neue Funktion" : "Funktion bearbeiten",
                                 prefix: name(of: target.function) + "(x) =",
                                 variables: ["x"],
                                 initial: target.function?.formula ?? MathRow()) { row in
                    save(row, into: target.function)
                }
            }
            .alert("Wert berechnen", isPresented: isShowing($valuePrompt)) {
                TextField("x", text: $inputA).keyboardType(.numbersAndPunctuation)
                Button("Berechnen") { if let f = valuePrompt { computeValue(f) } }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("An welcher Stelle x?")
            }
            .alert("Integral", isPresented: isShowing($integralPrompt)) {
                TextField("von", text: $inputA).keyboardType(.numbersAndPunctuation)
                TextField("bis", text: $inputB).keyboardType(.numbersAndPunctuation)
                Button("Berechnen") { if let f = integralPrompt { computeIntegral(f) } }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Untere und obere Grenze, z. B. 0 und π")
            }
        }
    }

    private func isShowing(_ binding: Binding<GraphFunction?>) -> Binding<Bool> {
        Binding(get: { binding.wrappedValue != nil }, set: { if !$0 { binding.wrappedValue = nil } })
    }

    // MARK: - Kurven

    private func expression(of function: GraphFunction) -> Expr? {
        if case .success(let e) = FormulaCompiler.expression(function.formula, allowed: ["x"]) { return e }
        return nil
    }

    private var curves: [PlotCurve] {
        var result: [PlotCurve] = []
        for function in functions where function.isVisible {
            guard let e = expression(of: function) else { continue }
            let color = GraphPalette.color(function.colorIndex)
            result.append(PlotCurve(id: function.uid.uuidString, color: color, f: evaluator.function(e)))
            if function.showsDerivative {
                let analysis = CurveAnalysis(expression: e, evaluator: evaluator)
                result.append(PlotCurve(id: function.uid.uuidString + "′", color: color,
                                        f: analysis.firstDerivative, dashed: true))
            }
        }
        return result
    }

    private var canvas: some View {
        let all = curves
        let traced = tracedID.flatMap { id in all.first { $0.id == id.uuidString } }
        let markers = (result?.points ?? []).map {
            PlotMarker(id: $0.id, x: $0.x, y: $0.y, color: result?.color ?? .white)
        }
        return GraphCanvas(viewport: $viewport, curves: all, markers: markers, area: plotArea, traceCurve: traced)
            .overlay(alignment: .topLeading) {
                if angleMode == .degrees {
                    StatusBadge(text: "DEG").padding(10)
                }
            }
    }

    private var plotArea: PlotArea? {
        guard let area = result?.area,
              let function = functions.first(where: { $0.uid == area.uid }),
              let e = expression(of: function) else { return nil }
        return PlotArea(f: evaluator.function(e), a: area.a, b: area.b, color: GraphPalette.color(function.colorIndex))
    }

    // MARK: - Funktionsliste

    private var functionList: some View {
        Group {
            if functions.isEmpty {
                Text("Tippe auf +, um eine Funktion einzugeben.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 70)
            } else {
                List {
                    ForEach(indexed) { item in
                        let function = item.function
                        FunctionRow(name: item.name, variables: "x", function: function,
                                    isValid: expression(of: function) != nil) {
                            editing = EditTarget(id: function.uid, function: function)
                        }
                        .listRowBackground(Color(white: 0.1))
                        .swipeActions {
                            Button(role: .destructive) { delete(function) } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: min(CGFloat(functions.count) * 58 + 8, 190))
            }
        }
    }

    private func name(of function: GraphFunction?) -> String {
        guard let function, let index = functions.firstIndex(where: { $0.uid == function.uid }) else {
            return GraphFunction.name(at: functions.count)
        }
        return GraphFunction.name(at: index)
    }

    private func save(_ row: MathRow, into function: GraphFunction?) {
        if let function {
            function.formula = row
        } else {
            let used = Set(functions.map(\.colorIndex))
            let color = (0..<GraphPalette.colors.count).first { !used.contains($0) } ?? functions.count
            let next = GraphFunction(order: (functions.last?.order ?? -1) + 1, formula: row, colorIndex: color, kind: "2d")
            modelContext.insert(next)
        }
        result = nil
    }

    private func delete(_ function: GraphFunction) {
        if result?.area?.uid == function.uid || tracedID == function.uid { result = nil; tracedID = nil }
        modelContext.delete(function)
    }

    // MARK: - Aktionen

    @ViewBuilder
    private var bottomActions: some View {
        if !functions.isEmpty {
            Menu {
                analysisMenu
            } label: {
                CapsuleMenuLabel(title: "Analyse", systemImage: "function")
            }
        }
        RoundActionButton(systemImage: "plus", accessibilityLabel: "Funktion hinzufügen", isProminent: true) {
            editing = EditTarget(id: UUID(), function: nil)
        }
        .disabled(functions.count >= Self.maxFunctions)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewport = nil
            } label: {
                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
            }
            .accessibilityLabel("Standardansicht")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Aus") { tracedID = nil }
                ForEach(indexed) { item in
                    Button(item.name + "(x)") { tracedID = item.function.uid }
                }
            } label: {
                Image(systemName: tracedID == nil ? "hand.point.up.left" : "hand.point.up.left.fill")
            }
            .accessibilityLabel("Spur")
        }
    }

    @ViewBuilder
    private var analysisMenu: some View {
        let valid = indexed.filter { expression(of: $0.function) != nil }
        if valid.count == 1, let only = valid.first {
            analysisItems(only.function, index: only.index)
        } else {
            ForEach(valid) { item in
                Menu(item.name + "(x)") {
                    analysisItems(item.function, index: item.index)
                }
            }
        }
    }

    @ViewBuilder
    private func analysisItems(_ function: GraphFunction, index: Int) -> some View {
        Button("Nullstellen") { analyze(function, index: index, kind: .roots) }
        Button("Hoch- und Tiefpunkte") { analyze(function, index: index, kind: .extrema) }
        Button("Wendepunkte") { analyze(function, index: index, kind: .inflections) }
        Button("y-Achsenabschnitt") { analyze(function, index: index, kind: .yIntercept) }
        ForEach(indexed.filter { $0.function.uid != function.uid }) { other in
            Button("Schnittpunkte mit " + other.name + "(x)") {
                intersect(function, index: index, with: other.function, otherIndex: other.index)
            }
        }
        Button("Wert berechnen …") { inputA = ""; valuePrompt = function }
        Button("Integral …") { inputA = ""; inputB = ""; integralPrompt = function }
        Button(function.showsDerivative ? "Ableitung ausblenden" : "Ableitung zeigen") {
            function.showsDerivative.toggle()
        }
    }

    private enum AnalysisKind { case roots, extrema, inflections, yIntercept }

    /// Gesucht wird im sichtbaren x-Bereich.
    private var searchRange: (Double, Double) {
        let v = viewport ?? .standard(aspect: 1)
        return (v.xMin, v.xMax)
    }

    private func analyze(_ function: GraphFunction, index: Int, kind: AnalysisKind) {
        guard let e = expression(of: function) else { return }
        let analysis = CurveAnalysis(expression: e, evaluator: evaluator)
        let (a, b) = searchRange
        let name = GraphFunction.name(at: index)
        let color = GraphPalette.color(function.colorIndex)
        switch kind {
        case .roots:
            result = AnalysisOutcome(title: "Nullstellen von " + name, points: analysis.roots(in: a, b), color: color)
        case .extrema:
            result = AnalysisOutcome(title: "Hoch- und Tiefpunkte von " + name,
                                     points: analysis.extrema(in: a, b), color: color)
        case .inflections:
            result = AnalysisOutcome(title: "Wendepunkte von " + name,
                                     points: analysis.inflectionPoints(in: a, b), color: color)
        case .yIntercept:
            result = AnalysisOutcome(title: "y-Achsenabschnitt von " + name,
                                     points: analysis.yIntercept().map { [$0] } ?? [], color: color)
        }
    }

    private func intersect(_ function: GraphFunction, index: Int, with other: GraphFunction, otherIndex: Int) {
        guard let e = expression(of: function), let g = expression(of: other) else { return }
        let (a, b) = searchRange
        let points = CurveAnalysis(expression: e, evaluator: evaluator)
            .intersections(with: evaluator.function(g), in: a, b)
        result = AnalysisOutcome(title: "Schnittpunkte von " + GraphFunction.name(at: index) + " und "
                                 + GraphFunction.name(at: otherIndex),
                                 points: points, color: .white)
    }

    private func computeValue(_ function: GraphFunction) {
        guard let e = expression(of: function), let index = functions.firstIndex(where: { $0.uid == function.uid }) else { return }
        let name = GraphFunction.name(at: index)
        guard let x = FormulaCompiler.number(inputA, angleMode: angleMode) else {
            result = AnalysisOutcome(title: "Wert von " + name, points: [], lines: ["Bitte eine Zahl eingeben."], color: .white)
            return
        }
        let y = evaluator.function(e)(x)
        let color = GraphPalette.color(function.colorIndex)
        if y.isFinite {
            result = AnalysisOutcome(title: "Wert von " + name, points: [CurvePoint(kind: .value, x: x, y: y)], color: color)
        } else {
            result = AnalysisOutcome(title: "Wert von " + name, points: [],
                                     lines: [name + "(" + PlotGeometry.label(x) + ") ist nicht definiert."], color: color)
        }
    }

    private func computeIntegral(_ function: GraphFunction) {
        guard let e = expression(of: function), let index = functions.firstIndex(where: { $0.uid == function.uid }) else { return }
        let name = GraphFunction.name(at: index)
        let color = GraphPalette.color(function.colorIndex)
        guard let a = FormulaCompiler.number(inputA, angleMode: angleMode),
              let b = FormulaCompiler.number(inputB, angleMode: angleMode) else {
            result = AnalysisOutcome(title: "Integral von " + name, points: [], lines: ["Bitte zwei Zahlen eingeben."], color: color)
            return
        }
        let f = evaluator.function(e)
        guard let value = NumericMethods.integral(of: f, from: a, to: b) else {
            result = AnalysisOutcome(title: "Integral von " + name, points: [],
                                     lines: ["Das Integral existiert in diesem Bereich nicht."], color: color)
            return
        }
        var lines = [approxText("∫ " + name + "(x) dx", value)]
        if let area = NumericMethods.integral(of: { Swift.abs(f($0)) }, from: min(a, b), to: max(a, b)),
           Swift.abs(area - Swift.abs(value)) > 1e-9 * max(1, area) {
            lines.append(approxText("Fläche", area))
        }
        result = AnalysisOutcome(title: "Integral von " + name + " von " + PlotGeometry.label(a) + " bis "
                                 + PlotGeometry.label(b), points: [], lines: lines, color: color,
                                 area: (function.uid, a, b))
    }

    // MARK: - Ergebnisliste

    private func resultPanel(_ outcome: AnalysisOutcome) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(outcome.title + (outcome.area == nil && outcome.lines.isEmpty ? " (sichtbarer Bereich)" : ""))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Button {
                    result = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Schließen")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(outcome.lines, id: \.self) { line in
                        Text(line).font(.body.monospacedDigit())
                    }
                    if outcome.points.isEmpty && outcome.lines.isEmpty {
                        Text("Keine gefunden.").foregroundStyle(.secondary)
                    }
                    ForEach(outcome.points) { point in
                        Button {
                            viewport = viewport?.centered(at: point.x, point.y)
                        } label: {
                            PointRow(point: point)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 110)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.12)))
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }
}

/// Eine Zeile mit Punktart und Koordinaten.
struct PointRow: View {
    let point: CurvePoint

    private var coordinates: String {
        "(" + PlotGeometry.label(point.x) + " | " + PlotGeometry.label(point.y) + ")"
    }

    var body: some View {
        HStack {
            Text(point.title).foregroundStyle(.secondary)
            Spacer()
            Text("≈ " + coordinates).font(.body.monospacedDigit())
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Funktion in der Liste: Farbpunkt (Antippen blendet aus), Name, Formel.
struct FunctionRow: View {
    let name: String
    let variables: String
    let function: GraphFunction
    let isValid: Bool
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                function.isVisible.toggle()
            } label: {
                Circle()
                    .fill(function.isVisible ? GraphPalette.color(function.colorIndex) : Color.clear)
                    .overlay(Circle().stroke(GraphPalette.color(function.colorIndex), lineWidth: 2))
                    .frame(width: 20, height: 20)
                    .padding(6)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(function.isVisible ? "Ausblenden" : "Einblenden")

            Button(action: onEdit) {
                HStack(spacing: 6) {
                    Text(name + "(" + variables + ") =")
                        .foregroundStyle(Color.gray)
                        .fixedSize()
                    ScrollView(.horizontal, showsIndicators: false) {
                        MathRowView(row: function.formula, path: [], context: .display)
                            .environment(\.mathFontSize, 20)
                    }
                    Spacer(minLength: 0)
                    if !isValid {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                            .accessibilityLabel("Formel unvollständig")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        .frame(minHeight: 46)
    }
}
