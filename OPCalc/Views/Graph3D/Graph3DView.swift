import SwiftUI
import SwiftData

/// Graph 3D (AK-06): Flächen z = f(x, y), mit einem Finger drehen, mit zwei Fingern zoomen.
struct Graph3DView: View {
    @Binding var mode: AppMode

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<GraphFunction> { $0.kind == "3d" }, sort: \GraphFunction.order)
    private var functions: [GraphFunction]
    @AppStorage("angleMode") private var angleModeRaw = "radians"
    /// Halbe Kantenlänge des Bereichs für x und y
    @AppStorage("graph3DRange") private var range = 5.0

    @State private var camera = Camera3D()
    @State private var dragStart: Camera3D?
    @State private var zoomStart: Camera3D?
    @State private var editing: GraphView.EditTarget?
    @State private var cache = MeshCache()

    /// Mehr Flächen machen das Bild unübersichtlich und das Drehen langsam.
    static let maxSurfaces = 3
    static let ranges: [Double] = [1, 2, 5, 10, 20, 50]
    /// Farbtöne der Flächen bei mehreren Funktionen (orange, blau, grün wie im 2D-Graphen)
    static let hues: [Double] = [0.09, 0.58, 0.36]

    private var angleMode: AngleMode { AngleMode(rawValue: angleModeRaw) ?? .radians }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                surfaceCanvas
                    .frame(maxHeight: .infinity)
                functionList
                ModeBar(mode: $mode) {
                    Menu {
                        Picker("Bereich", selection: $range) {
                            ForEach(Self.ranges, id: \.self) { r in
                                Text("−" + PlotGeometry.label(r) + " bis " + PlotGeometry.label(r)).tag(r)
                            }
                        }
                    } label: {
                        CapsuleMenuLabel(title: "±" + PlotGeometry.label(range), systemImage: "square.dashed")
                    }
                    .accessibilityLabel("Bereich für x und y")
                    RoundActionButton(systemImage: "plus", accessibilityLabel: "Fläche hinzufügen", isProminent: true) {
                        editing = GraphView.EditTarget(id: UUID(), function: nil)
                    }
                    .disabled(functions.count >= Self.maxSurfaces)
                }
            }
            .background(Color.black)
            .navigationTitle("Graph 3D")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { camera = Camera3D() } label: { Image(systemName: "rotate.3d") }
                        .accessibilityLabel("Ansicht zurücksetzen")
                }
            }
            .sheet(item: $editing) { target in
                FormulaInputView(title: target.function == nil ? "Neue Fläche" : "Fläche bearbeiten",
                                 prefix: "z =", variables: ["x", "y"],
                                 initial: target.function?.formula ?? MathRow()) { row in
                    save(row, into: target.function)
                }
            }
        }
    }

    // MARK: - Flächen

    private struct Surface {
        let mesh: SurfaceMesh
        let colorIndex: Int
    }

    private var surfaces: [Surface] {
        let evaluator = NumericEvaluator(angleMode: angleMode)
        let resolution = functions.count > 1 ? 30 : SurfaceMesh.defaultResolution
        let variant = "\(range)|\(resolution)|" + angleModeRaw
        return functions.filter(\.isVisible).compactMap { function in
            guard case .success(let e) = FormulaCompiler.expression(function.formula, allowed: ["x", "y"]) else { return nil }
            let mesh = cache.mesh(for: function.formulaData, variant: variant) {
                SurfaceMesh({ x, y in
                    var v = VariableValues(); v.x = x; v.y = y
                    return evaluator.value(e, v)
                }, x: -range...range, y: -range...range, resolution: resolution)
            }
            return Surface(mesh: mesh, colorIndex: function.colorIndex)
        }
    }

    private var surfaceCanvas: some View {
        let list = surfaces
        let zRange = Self.commonZRange(list.map(\.mesh))
        return Canvas { context, size in
            drawFloor(in: context, size: size, zRange: zRange)
            let quads = SurfaceRenderer.quads(list.map(\.mesh), zRange: zRange, camera: camera, size: size)
            let single = list.count == 1
            for quad in quads {
                var path = Path()
                path.addLines(quad.corners)
                path.closeSubpath()
                let hue = single ? 0.66 * (1 - quad.height) : Self.hues[quad.surface % Self.hues.count]
                context.fill(path, with: .color(Color(hue: hue, saturation: 0.8, brightness: quad.shade)))
                context.stroke(path, with: .color(.black.opacity(0.25)), lineWidth: 0.5)
            }
        }
        .contentShape(Rectangle())
        .gesture(rotateGesture.simultaneously(with: zoomGesture))
        .overlay(alignment: .top) {
            if list.isEmpty {
                Text(functions.isEmpty ? "Tippe auf +, um eine Fläche z = f(x, y) einzugeben." : "Keine Fläche sichtbar.")
                    .font(.callout).foregroundStyle(.secondary).padding(.top, 40)
            } else {
                Text("z von " + PlotGeometry.label(zRange.lowerBound, digits: 4) + " bis "
                     + PlotGeometry.label(zRange.upperBound, digits: 4))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary).padding(.top, 6)
            }
        }
        .accessibilityLabel("3D-Graph")
        .accessibilityHint("Mit einem Finger drehen, mit zwei Fingern zoomen")
    }

    static func commonZRange(_ meshes: [SurfaceMesh]) -> ClosedRange<Double> {
        let ranges = meshes.map(\.zRange)
        guard let lo = ranges.map(\.lowerBound).min(), let hi = ranges.map(\.upperBound).max() else { return -1...1 }
        return lo...hi
    }

    /// Boden (z unten) mit Achsenbeschriftung, hinter der Fläche gezeichnet.
    private func drawFloor(in context: GraphicsContext, size: CGSize, zRange: ClosedRange<Double>) {
        let corners = [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)]
        var floor = Path()
        floor.addLines(corners.map { camera.project($0.0, $0.1, -1, size: size).point })
        floor.closeSubpath()
        context.fill(floor, with: .color(Color(white: 0.08)))
        context.stroke(floor, with: .color(Color(white: 0.35)), lineWidth: 1)
        // Senkrechte Kante hinten links für z
        var edge = Path()
        edge.move(to: camera.project(-1, 1, -1, size: size).point)
        edge.addLine(to: camera.project(-1, 1, 1, size: size).point)
        context.stroke(edge, with: .color(Color(white: 0.35)), lineWidth: 1)

        let label = { (text: String, x: Double, y: Double, z: Double) in
            context.draw(Text(text).font(.caption2.monospacedDigit()).foregroundStyle(Color(white: 0.65)),
                         at: camera.project(x, y, z, size: size).point)
        }
        label("x", 1.2, -1, -1)
        label("y", -1, 1.2, -1)
        label(PlotGeometry.label(range), 1, -1.15, -1)
        label(PlotGeometry.label(-range), -1, -1.15, -1)
        label(PlotGeometry.label(zRange.upperBound, digits: 3), -1.12, 1.12, 1)
        label(PlotGeometry.label(zRange.lowerBound, digits: 3), -1.12, 1.12, -1)
    }

    private var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard zoomStart == nil else { return }
                if dragStart == nil { dragStart = camera }
                guard let start = dragStart else { return }
                camera.yaw = start.yaw + Double(value.translation.width) * 0.01
                camera.pitch = min(max(start.pitch + Double(value.translation.height) * 0.01, -0.3), Double.pi / 2)
            }
            .onEnded { _ in dragStart = nil }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if zoomStart == nil { zoomStart = camera; dragStart = nil }
                guard let start = zoomStart else { return }
                camera.zoom = min(max(start.zoom * Double(value.magnification), 0.4), 4)
            }
            .onEnded { _ in zoomStart = nil }
    }

    // MARK: - Liste

    private var functionList: some View {
        Group {
            if !functions.isEmpty {
                List {
                    ForEach(functions, id: \.uid) { function in
                        FunctionRow(name: "z", variables: "x, y", function: function,
                                    isValid: FormulaCompiler.expression(function.formula, allowed: ["x", "y"]).isSuccess) {
                            editing = GraphView.EditTarget(id: function.uid, function: function)
                        }
                        .listRowBackground(Color(white: 0.1))
                        .swipeActions {
                            Button(role: .destructive) { modelContext.delete(function) } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(functions.count) * 58 + 8)
            }
        }
    }

    private func save(_ row: MathRow, into function: GraphFunction?) {
        if let function {
            function.formula = row
        } else {
            let used = Set(functions.map(\.colorIndex))
            let color = (0..<Self.hues.count).first { !used.contains($0) } ?? functions.count
            modelContext.insert(GraphFunction(order: (functions.last?.order ?? -1) + 1, formula: row,
                                              colorIndex: color, kind: "3d"))
        }
    }
}

extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

/// Zwischenspeicher der Gitter: Drehen soll nicht jedes Mal neu rechnen.
final class MeshCache {
    private var meshes: [String: SurfaceMesh] = [:]

    /// `variant` enthält alles außer der Formel, was das Gitter verändert (Bereich, Auflösung, Winkelmaß).
    func mesh(for data: Data, variant: String, make: () -> SurfaceMesh) -> SurfaceMesh {
        let key = data.base64EncodedString() + "|" + variant
        if let mesh = meshes[key] { return mesh }
        if meshes.count > 20 { meshes.removeAll() }
        let mesh = make()
        meshes[key] = mesh
        return mesh
    }
}
