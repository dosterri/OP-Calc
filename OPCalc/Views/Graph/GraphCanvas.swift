import SwiftUI

/// Eine zu zeichnende Kurve.
struct PlotCurve: Identifiable {
    let id: String
    let color: Color
    let f: (Double) -> Double
    var dashed = false
}

/// Kurvenzug aus Punkten in Weltkoordinaten (Lösung einer DGL, Phasenbild).
/// Nicht endliche Punkte trennen den Zug.
struct PlotPath: Identifiable {
    let id: String
    let color: Color
    let points: [(x: Double, y: Double)]
}

/// Markierter Punkt (Ergebnis einer Analyse).
struct PlotMarker: Identifiable {
    let id: String
    let x: Double
    let y: Double
    let color: Color
}

/// Fläche zwischen Kurve und x-Achse (Integral).
struct PlotArea {
    let f: (Double) -> Double
    let a: Double
    let b: Double
    let color: Color
}

/// Koordinatensystem mit Kurven. Ein Finger verschiebt, zwei Finger zoomen.
/// Mit `traceCurve` folgt ein Punkt dem Finger auf der Kurve (Spur) statt zu verschieben.
struct GraphCanvas: View {
    @Binding var viewport: Viewport?
    var curves: [PlotCurve]
    var paths: [PlotPath] = []
    var markers: [PlotMarker] = []
    var area: PlotArea?
    var traceCurve: PlotCurve?
    var onTap: ((Double, Double) -> Void)?
    /// Zusätzliche Ebene unter den Kurven (z. B. Richtungsfeld der DGL).
    var underlay: ((GraphicsContext, CGSize, Viewport) -> Void)?

    @State private var dragStart: Viewport?
    @State private var zoomStart: Viewport?
    @State private var traceX: Double?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Canvas { context, size in
                guard let viewport else { return }
                draw(in: context, size: size, viewport: viewport)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(size: size).simultaneously(with: zoomGesture(size: size)))
            .onTapGesture { location in
                guard let onTap, let viewport else { return }
                let p = viewport.world(location, in: size)
                onTap(p.x, p.y)
            }
            .onAppear { resetIfNeeded(size: size) }
            .onChange(of: size) { old, new in keepScale(from: old, to: new) }
            .onChange(of: traceCurve == nil) { traceX = nil }
        }
        .background(Color.black)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Graph")
        .accessibilityHint("Mit einem Finger verschieben, mit zwei Fingern zoomen")
    }

    /// Ändert sich die Größe (Ergebnisliste ein-/ausgeblendet), bleibt der Maßstab pro Punkt gleich,
    /// statt den Graphen zu stauchen.
    private func keepScale(from old: CGSize, to new: CGSize) {
        guard let current = viewport, old.width > 0, old.height > 0, new.width > 0, new.height > 0 else {
            resetIfNeeded(size: new)
            return
        }
        let width = current.width * Double(new.width / old.width)
        let height = current.height * Double(new.height / old.height)
        let cx = (current.xMin + current.xMax) / 2, cy = (current.yMin + current.yMax) / 2
        viewport = Viewport(xMin: cx - width / 2, xMax: cx + width / 2, yMin: cy - height / 2, yMax: cy + height / 2)
    }

    private func resetIfNeeded(size: CGSize) {
        if viewport == nil, size.width > 0 {
            viewport = .standard(aspect: Double(size.height / size.width))
        }
    }

    // MARK: - Gesten

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard let current = viewport, zoomStart == nil else { return }
                if traceCurve != nil {
                    traceX = current.world(value.location, in: size).x
                    return
                }
                if dragStart == nil { dragStart = current }
                viewport = dragStart?.panned(by: value.translation, in: size)
            }
            .onEnded { _ in dragStart = nil }
    }

    private func zoomGesture(size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard let current = viewport else { return }
                if zoomStart == nil { zoomStart = current; dragStart = nil }
                guard let start = zoomStart else { return }
                let center = start.world(value.startLocation, in: size)
                viewport = start.zoomed(by: Double(value.magnification), around: center)
            }
            .onEnded { _ in zoomStart = nil }
    }

    // MARK: - Zeichnen

    private func draw(in context: GraphicsContext, size: CGSize, viewport: Viewport) {
        drawGrid(in: context, size: size, viewport: viewport)
        underlay?(context, size, viewport)
        if let area { drawArea(area, in: context, size: size, viewport: viewport) }

        let samples = max(100, Int(size.width))
        for curve in curves {
            var path = Path()
            for line in PlotGeometry.polylines(curve.f, viewport: viewport, size: size, samples: samples) {
                path.addLines(line)
            }
            let style = StrokeStyle(lineWidth: curve.dashed ? 1.8 : 2.6, lineCap: .round, lineJoin: .round,
                                    dash: curve.dashed ? [6, 5] : [])
            context.stroke(path, with: .color(curve.color), style: style)
        }

        for item in paths {
            var path = Path()
            var isDrawing = false
            for p in item.points {
                guard p.x.isFinite, p.y.isFinite else { isDrawing = false; continue }
                let clampedY = min(max(p.y, viewport.yMin - viewport.height * 50), viewport.yMax + viewport.height * 50)
                let point = viewport.point(x: p.x, y: clampedY, in: size)
                if isDrawing { path.addLine(to: point) } else { path.move(to: point); isDrawing = true }
            }
            context.stroke(path, with: .color(item.color), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
        }

        for marker in markers {
            drawDot(at: viewport.point(x: marker.x, y: marker.y, in: size), color: marker.color, in: context)
        }

        if let traceCurve, let x = traceX {
            let y = traceCurve.f(x)
            if y.isFinite {
                let p = viewport.point(x: x, y: y, in: size)
                drawDot(at: p, color: traceCurve.color, in: context)
                let text = "x ≈ " + PlotGeometry.label(x, digits: 5) + "   y ≈ " + PlotGeometry.label(y, digits: 5)
                let label = context.resolve(Text(text).font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.white))
                let labelSize = label.measure(in: size)
                let origin = CGPoint(x: min(max(p.x - labelSize.width / 2, 6), size.width - labelSize.width - 6),
                                     y: p.y - labelSize.height - 16 < 4 ? p.y + 14 : p.y - labelSize.height - 16)
                let box = CGRect(origin: origin, size: labelSize).insetBy(dx: -8, dy: -4)
                context.fill(Path(roundedRect: box, cornerRadius: 8), with: .color(Color(white: 0.2)))
                context.draw(label, in: CGRect(origin: origin, size: labelSize))
            }
        }
    }

    private func drawDot(at p: CGPoint, color: Color, in context: GraphicsContext) {
        let rect = CGRect(x: p.x - 5.5, y: p.y - 5.5, width: 11, height: 11)
        context.fill(Path(ellipseIn: rect), with: .color(color))
        context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 1.5)
    }

    private func drawGrid(in context: GraphicsContext, size: CGSize, viewport: Viewport) {
        let xStep = PlotGeometry.niceStep(span: viewport.width, target: 6)
        let yStep = PlotGeometry.niceStep(span: viewport.height, target: max(4, Int(6 * size.height / max(size.width, 1))))
        let xTicks = PlotGeometry.ticks(from: viewport.xMin, to: viewport.xMax, step: xStep)
        let yTicks = PlotGeometry.ticks(from: viewport.yMin, to: viewport.yMax, step: yStep)

        var grid = Path()
        for x in xTicks {
            let px = viewport.point(x: x, y: 0, in: size).x
            grid.move(to: CGPoint(x: px, y: 0)); grid.addLine(to: CGPoint(x: px, y: size.height))
        }
        for y in yTicks {
            let py = viewport.point(x: 0, y: y, in: size).y
            grid.move(to: CGPoint(x: 0, y: py)); grid.addLine(to: CGPoint(x: size.width, y: py))
        }
        context.stroke(grid, with: .color(Color(white: 0.16)), lineWidth: 0.6)

        // Achsen; liegen sie außerhalb, stehen die Zahlen am Rand.
        let origin = viewport.point(x: 0, y: 0, in: size)
        var axes = Path()
        if origin.x >= 0 && origin.x <= size.width {
            axes.move(to: CGPoint(x: origin.x, y: 0)); axes.addLine(to: CGPoint(x: origin.x, y: size.height))
        }
        if origin.y >= 0 && origin.y <= size.height {
            axes.move(to: CGPoint(x: 0, y: origin.y)); axes.addLine(to: CGPoint(x: size.width, y: origin.y))
        }
        context.stroke(axes, with: .color(Color(white: 0.6)), lineWidth: 1)

        let labelY = min(max(origin.y + 4, 4), size.height - 18)
        for x in xTicks where x != 0 {
            let px = viewport.point(x: x, y: 0, in: size).x
            let text = Text(PlotGeometry.label(x, digits: 4)).font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Color(white: 0.55))
            context.draw(text, at: CGPoint(x: px, y: labelY), anchor: .top)
        }
        let labelX = min(max(origin.x - 4, 30), size.width - 4)
        for y in yTicks where y != 0 {
            let py = viewport.point(x: 0, y: y, in: size).y
            let text = Text(PlotGeometry.label(y, digits: 4)).font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Color(white: 0.55))
            context.draw(text, at: CGPoint(x: labelX, y: py), anchor: .trailing)
        }
    }

    private func drawArea(_ area: PlotArea, in context: GraphicsContext, size: CGSize, viewport: Viewport) {
        let lower = max(min(area.a, area.b), viewport.xMin - viewport.width)
        let upper = min(max(area.a, area.b), viewport.xMax + viewport.width)
        guard upper > lower else { return }
        let steps = 300
        var path = Path()
        path.move(to: viewport.point(x: lower, y: 0, in: size))
        for i in 0...steps {
            let x = lower + (upper - lower) * Double(i) / Double(steps)
            let y = area.f(x)
            let clamped = y.isFinite ? min(max(y, viewport.yMin - viewport.height), viewport.yMax + viewport.height) : 0
            path.addLine(to: viewport.point(x: x, y: clamped, in: size))
        }
        path.addLine(to: viewport.point(x: upper, y: 0, in: size))
        path.closeSubpath()
        context.fill(path, with: .color(area.color.opacity(0.3)))
    }
}
