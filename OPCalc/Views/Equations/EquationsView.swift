import SwiftUI
import SwiftData

/// Gleichungen (AK-03): lineares Gleichungssystem, Polynom, beliebige Gleichung.
struct EquationsView: View {
    @Binding var mode: AppMode
    @Bindable var state: WorkspaceState

    @Environment(\.modelContext) private var modelContext
    @AppStorage("angleMode") private var angleModeRaw = "radians"
    @State private var editing: CellTarget?
    @State private var outcome: Outcome?

    private var angleMode: AngleMode { AngleMode(rawValue: angleModeRaw) ?? .radians }

    enum CellTarget: Identifiable, Equatable {
        case matrix(Int, Int), coefficient(Int), left, right

        var id: String {
            switch self {
            case .matrix(let r, let c): return "m\(r)-\(c)"
            case .coefficient(let k): return "c\(k)"
            case .left: return "l"
            case .right: return "r"
            }
        }
    }

    /// Ergebnis einer Rechnung, fertig für die Anzeige.
    enum Outcome {
        case message(String)
        case system(LinearSystemSolution, names: [String])
        case polynomial(PolynomialSolver.Solution)
        case general([Double])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Art", selection: $state.equationKind) {
                    ForEach(WorkspaceState.EquationKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 14) {
                        switch state.equationKind {
                        case .system: systemInput
                        case .polynomial: polynomialInput
                        case .general: generalInput
                        }
                        if let outcome { resultCard(outcome) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)

                ModeBar(mode: $mode) {
                    if state.equationKind == .general {
                        RoundActionButton(systemImage: "chart.xyaxis.line", accessibilityLabel: "Im Graph zeigen") {
                            showInGraph()
                        }
                    }
                    Button(action: solve) {
                        CapsuleMenuLabel(title: "Lösen", systemImage: "equal")
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.black)
            .navigationTitle("Gleichungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onChange(of: state.equationKind) { outcome = nil }
            .sheet(item: $editing) { target in
                FormulaInputView(title: title(of: target), prefix: prefix(of: target),
                                 variables: target == .left || target == .right ? ["x"] : [],
                                 initial: row(of: target), allowsEmpty: true) { row in
                    store(row, in: target)
                    outcome = nil
                }
            }
        }
    }

    // MARK: - LGS

    private var unknownNames: [String] {
        let count = state.unknownCount
        if count <= 3 { return Array(["x", "y", "z"].prefix(count)) }
        return (1...count).map { "x" + subscriptDigits($0) }
    }

    private var systemInput: some View {
        Card {
            HStack {
                Stepper("Gleichungen: \(state.equationCount)", value: $state.equationCount, in: 1...WorkspaceState.maxSize)
            }
            Stepper("Unbekannte: \(state.unknownCount)", value: $state.unknownCount, in: 1...WorkspaceState.maxSize)
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<state.equationCount, id: \.self) { r in
                        HStack(spacing: 4) {
                            ForEach(0..<state.unknownCount, id: \.self) { c in
                                if c > 0 { Text("+").foregroundStyle(.secondary) }
                                FormulaCell(row: state.matrix[r][c], fontSize: 18, minWidth: 44) {
                                    editing = .matrix(r, c)
                                }
                                Text(unknownNames[c]).italic().foregroundStyle(.secondary)
                            }
                            Text("=").foregroundStyle(.secondary)
                            FormulaCell(row: state.matrix[r][WorkspaceState.maxSize], fontSize: 18, minWidth: 44) {
                                editing = .matrix(r, WorkspaceState.maxSize)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Text("Leere Felder zählen als 0. Brüche und Wurzeln sind erlaubt.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .onChange(of: state.equationCount) { outcome = nil }
        .onChange(of: state.unknownCount) { outcome = nil }
    }

    // MARK: - Polynom

    private var polynomialInput: some View {
        Card {
            Stepper("Grad: \(state.degree)", value: $state.degree, in: 1...WorkspaceState.maxDegree)
                .onChange(of: state.degree) { outcome = nil }
            ForEach(Array((0...state.degree).reversed()), id: \.self) { k in
                HStack {
                    FormulaCell(row: state.coefficients[k], minWidth: 70) { editing = .coefficient(k) }
                    // Beim konstanten Glied nichts zeigen (eine leere Zeile wäre ein Platzhalter-Kästchen)
                    if k > 0 {
                        MathRowView(row: Self.powerOfX(k), path: [], context: .display)
                            .environment(\.mathFontSize, 20)
                    }
                    Spacer()
                    if k > 0 { Text("+").foregroundStyle(.secondary) } else { Text("= 0").foregroundStyle(.secondary) }
                }
            }
        }
    }

    static func powerOfX(_ k: Int) -> MathRow {
        switch k {
        case 0: return MathRow()
        case 1: return MathRow(linear: "x")
        default: return MathRow([MathItem(.variable("x")), MathItem(.power, slots: [MathRow(linear: "\(k)")])])
        }
    }

    // MARK: - Allgemeine Gleichung

    private var generalInput: some View {
        Card {
            HStack(spacing: 8) {
                FormulaCell(row: state.left, placeholder: "links", minWidth: 100) { editing = .left }
                Text("=").foregroundStyle(.secondary)
                FormulaCell(row: state.right, placeholder: "rechts", minWidth: 100) { editing = .right }
            }
            HStack {
                NumberField(label: "x von", text: $state.searchFrom, width: 70)
                Spacer()
                NumberField(label: "bis", text: $state.searchTo, width: 70)
            }
            Text("Gesucht wird zwischen den beiden Grenzen, die Lösungen sind gerundet.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: - Zellen

    private func row(of target: CellTarget) -> MathRow {
        switch target {
        case .matrix(let r, let c): return state.matrix[r][c]
        case .coefficient(let k): return state.coefficients[k]
        case .left: return state.left
        case .right: return state.right
        }
    }

    private func store(_ row: MathRow, in target: CellTarget) {
        switch target {
        case .matrix(let r, let c): state.matrix[r][c] = row
        case .coefficient(let k): state.coefficients[k] = row
        case .left: state.left = row
        case .right: state.right = row
        }
    }

    private func title(of target: CellTarget) -> String {
        switch target {
        case .matrix(let r, let c):
            return "Gleichung \(r + 1), " + (c == WorkspaceState.maxSize ? "rechte Seite" : unknownNames[c])
        case .coefficient: return "Koeffizient"
        case .left: return "Linke Seite"
        case .right: return "Rechte Seite"
        }
    }

    private func prefix(of target: CellTarget) -> String {
        switch target {
        case .coefficient(let k): return k == 0 ? "Zahl:" : (k == 1 ? "vor x:" : "vor x" + superscriptDigits(k) + ":")
        default: return ""
        }
    }

    /// Wert einer Zelle (leer = 0); bei Fehlern die Meldung mit Ort.
    private func value(_ row: MathRow, place: String) -> Result<Value, CellError> {
        if row.isEmpty { return .success(.exact(.zero)) }
        do {
            let expression = try FormulaParser.parse(row)
            return .success(try Evaluator(angleMode: angleMode).evaluate(expression))
        } catch let error as ParseError {
            return .failure(CellError(message: place + ": " + error.message))
        } catch let error as MathError {
            return .failure(CellError(message: place + ": " + error.message))
        } catch {
            return .failure(CellError(message: place + ": Eingabe prüfen"))
        }
    }

    struct CellError: Error { let message: String }

    // MARK: - Lösen

    private func solve() {
        switch state.equationKind {
        case .system: solveSystem()
        case .polynomial: solvePolynomial()
        case .general: solveGeneral()
        }
    }

    private func solveSystem() {
        var augmented: [[Value]] = []
        for r in 0..<state.equationCount {
            var line: [Value] = []
            for c in Array(0..<state.unknownCount) + [WorkspaceState.maxSize] {
                switch value(state.matrix[r][c], place: "Gleichung \(r + 1)") {
                case .success(let v): line.append(v)
                case .failure(let error): outcome = .message(error.message); return
                }
            }
            augmented.append(line)
        }
        if let solution = LinearSystemSolver.solve(augmented) {
            outcome = .system(solution, names: unknownNames)
        }
    }

    private func solvePolynomial() {
        var list: [Value] = []
        for k in (0...state.degree).reversed() {
            switch value(state.coefficients[k], place: "Koeffizient") {
            case .success(let v): list.append(v)
            case .failure(let error): outcome = .message(error.message); return
            }
        }
        outcome = .polynomial(PolynomialSolver.solve(list))
    }

    private func solveGeneral() {
        guard case .success(let l) = FormulaCompiler.expression(state.left, allowed: ["x"]),
              case .success(let r) = FormulaCompiler.expression(state.right, allowed: ["x"]) else {
            outcome = .message("Bitte beide Seiten vollständig eingeben (Variable x).")
            return
        }
        guard let a = FormulaCompiler.number(state.searchFrom, angleMode: angleMode),
              let b = FormulaCompiler.number(state.searchTo, angleMode: angleMode), a < b else {
            outcome = .message("Die Grenzen sind ungültig: „von“ muss kleiner als „bis“ sein.")
            return
        }
        let evaluator = NumericEvaluator(angleMode: angleMode)
        let f = evaluator.function(l), g = evaluator.function(r)
        outcome = .general(NumericMethods.roots(of: { f($0) - g($0) }, in: a, b).map(\.x))
    }

    private func showInGraph() {
        let existing = (try? modelContext.fetch(FetchDescriptor<GraphFunction>(predicate: #Predicate { $0.kind == "2d" }))) ?? []
        let rows = [state.left, state.right].filter { !$0.isEmpty }
        guard !rows.isEmpty else { return }
        guard existing.count + rows.count <= GraphView.maxFunctions else {
            outcome = .message("Im Graph ist kein Platz mehr. Lösche dort zuerst eine Funktion.")
            return
        }
        var order = (existing.map(\.order).max() ?? -1) + 1
        var used = Set(existing.map(\.colorIndex))
        for row in rows {
            let color = (0..<GraphPalette.colors.count).first { !used.contains($0) } ?? order
            used.insert(color)
            modelContext.insert(GraphFunction(order: order, formula: row, colorIndex: color, kind: "2d"))
            order += 1
        }
        mode = .graph
    }

    // MARK: - Ergebnis

    @ViewBuilder
    private func resultCard(_ outcome: Outcome) -> some View {
        Card {
            SectionTitle(text: "Lösung")
            switch outcome {
            case .message(let text):
                Text(text).foregroundStyle(.red)
            case .system(let solution, let names):
                systemResult(solution, names: names)
            case .polynomial(let solution):
                polynomialResult(solution)
            case .general(let roots):
                if roots.isEmpty {
                    Text("Keine Lösung zwischen den Grenzen gefunden.").foregroundStyle(.secondary)
                }
                ForEach(roots.indices, id: \.self) { index in
                    Text(approxText("x" + subscriptDigits(index + 1), roots[index], digits: 10))
                        .font(.title3.monospacedDigit())
                }
            }
        }
    }

    @ViewBuilder
    private func systemResult(_ solution: LinearSystemSolution, names: [String]) -> some View {
        switch solution.kind {
        case .none:
            Text("Keine Lösung: Die Gleichungen widersprechen sich.")
        case .unique, .infinite:
            if solution.kind == .infinite {
                Text("Unendlich viele Lösungen. Frei wählbar: " + parameterList(solution.freeVariables.count) + ".")
                    .foregroundStyle(.secondary)
            }
            ForEach(names.indices, id: \.self) { index in
                if index < solution.variables.count {
                    HStack(spacing: 6) {
                        Text(names[index]).italic().font(.system(size: 22))
                        if solution.kind == .unique {
                            ValueView(value: solution.variables[index].constant)
                        } else {
                            Text("=").font(.system(size: 22, weight: .light)).foregroundStyle(.secondary)
                            MathRowView(row: parametricRow(solution.variables[index]), path: [], context: .display)
                                .environment(\.mathFontSize, 22)
                        }
                    }
                }
            }
        }
    }

    private static let parameterNames = ["t", "s", "r", "u", "v", "w"]

    private func parameterList(_ count: Int) -> String {
        Self.parameterNames.prefix(count).joined(separator: ", ")
    }

    /// Konstante + Koeffizient·t + … als Formelzeile.
    private func parametricRow(_ term: LinearSystemSolution.VariableTerm) -> MathRow {
        var items: [MathItem] = []
        if !term.constant.isZero { items += displayRow(term.constant).items }
        for (j, coefficient) in term.coefficients.enumerated() where !coefficient.isZero {
            let negative = coefficient.doubleValue < 0
            if !items.isEmpty || negative { items.append(MathItem(.op(negative ? .minus : .plus))) }
            let magnitude = negative ? coefficient.negated : coefficient
            if magnitude != .exact(.one) && magnitude != .approximate(1) { items += displayRow(magnitude).items }
            items.append(MathItem(.variable(Self.parameterNames[min(j, Self.parameterNames.count - 1)])))
        }
        return items.isEmpty ? MathRow(linear: "0") : MathRow(items)
    }

    private func displayRow(_ value: Value) -> MathRow {
        let formatted = ResultFormatter.format(value)
        return formatted.exactRow ?? formatted.decimalRow
    }

    @ViewBuilder
    private func polynomialResult(_ solution: PolynomialSolver.Solution) -> some View {
        if solution.isIdentity {
            Text("Jede Zahl ist eine Lösung.")
        } else if solution.roots.isEmpty && solution.nonRealCount == 0 {
            Text("Keine Lösung.")
        } else if solution.roots.isEmpty {
            Text("Keine reelle Lösung.")
        }
        ForEach(solution.roots.indices, id: \.self) { index in
            let root = solution.roots[index]
            HStack(spacing: 6) {
                Text("x" + subscriptDigits(index + 1)).italic().font(.system(size: 22))
                ValueView(value: root.value)
                if root.multiplicity > 1 {
                    Text(root.multiplicity == 2 ? "doppelt" : "\(root.multiplicity)-fach")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        if solution.nonRealCount > 0 && !solution.roots.isEmpty {
            Text(solution.nonRealCount == 1 ? "Dazu 1 nicht reelle Lösung."
                 : "Dazu \(solution.nonRealCount) nicht reelle Lösungen.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// Hochgestellte Ziffern: 12 → „¹²“
func superscriptDigits(_ n: Int) -> String {
    let map: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
                                       "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"]
    return String(String(n).map { map[$0] ?? $0 })
}

/// Tiefgestellte Ziffern: 12 → „₁₂“
func subscriptDigits(_ n: Int) -> String {
    let map: [Character: Character] = ["0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
                                       "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉"]
    return String(String(n).map { map[$0] ?? $0 })
}
