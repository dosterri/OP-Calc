import CoreGraphics
import Foundation

/// Fläche z = f(x, y) als Gitter für die eigene 3D-Darstellung (AK-06).
/// Eigene Projektion statt SceneKit/RealityKit: SceneKit wird nicht weiterentwickelt,
/// RealityView braucht iOS 18 (Mindestversion ist 17).
struct SurfaceMesh {
    /// Gitterpunkte je Achse – 40 sieht glatt aus und bleibt beim Drehen flüssig.
    static let defaultResolution = 40

    let resolution: Int
    let xRange: ClosedRange<Double>
    let yRange: ClosedRange<Double>
    /// z-Werte, Zeile für Zeile (y außen, x innen); nan = nicht definiert
    let z: [Double]
    /// Einmal beim Erzeugen berechnet – beim Drehen wird das Gitter nicht neu sortiert.
    let zRange: ClosedRange<Double>

    init(_ f: (Double, Double) -> Double, x: ClosedRange<Double>, y: ClosedRange<Double>,
         resolution: Int = defaultResolution) {
        self.resolution = resolution
        self.xRange = x
        self.yRange = y
        var values: [Double] = []
        values.reserveCapacity((resolution + 1) * (resolution + 1))
        for j in 0...resolution {
            let yv = y.lowerBound + (y.upperBound - y.lowerBound) * Double(j) / Double(resolution)
            for i in 0...resolution {
                let xv = x.lowerBound + (x.upperBound - x.lowerBound) * Double(i) / Double(resolution)
                let value = f(xv, yv)
                values.append(value.isFinite ? value : .nan)
            }
        }
        z = values
        zRange = Self.displayRange(values)
    }

    func x(_ i: Int) -> Double { xRange.lowerBound + (xRange.upperBound - xRange.lowerBound) * Double(i) / Double(resolution) }
    func y(_ j: Int) -> Double { yRange.lowerBound + (yRange.upperBound - yRange.lowerBound) * Double(j) / Double(resolution) }
    func z(_ i: Int, _ j: Int) -> Double { z[j * (resolution + 1) + i] }

    /// z-Bereich für die Darstellung: kleinster und größter endlicher Wert.
    /// Nur bei Ausreißern an Polstellen (1/(x²+y²)) wird auf das 2.–98. Perzentil begrenzt,
    /// sonst würde die Fläche zu einem flachen Brett.
    private static func displayRange(_ z: [Double]) -> ClosedRange<Double> {
        let finite = z.filter(\.isFinite).sorted()
        guard let first = finite.first, let last = finite.last else { return -1...1 }
        let lower = finite[Int(Double(finite.count - 1) * 0.02)]
        let upper = finite[Int(Double(finite.count - 1) * 0.98)]
        let hasOutliers = upper - lower > 0 && (last - first) > 10 * (upper - lower)
        var (lo, hi) = hasOutliers ? (lower, upper) : (first, last)
        if hi - lo < 1e-12 { lo -= 1; hi += 1 }
        return lo...hi
    }
}

/// Blickrichtung und Projektion der 3D-Ansicht.
struct Camera3D: Equatable {
    /// Drehung um die senkrechte Achse (Bogenmaß)
    var yaw = -0.6
    /// Neigung; 0 = von der Seite, π/2 = von oben
    var pitch = 0.5
    var zoom = 1.0

    /// Ein Punkt im Einheitswürfel [−1, 1]³ → Bildschirm (Ursprung Mitte) und Tiefe (größer = weiter hinten).
    func project(_ x: Double, _ y: Double, _ z: Double, size: CGSize) -> (point: CGPoint, depth: Double) {
        // Drehung um z (yaw), dann Neigung um die x-Achse (pitch)
        let cy = cos(yaw), sy = sin(yaw)
        let xr = x * cy - y * sy
        let yr = x * sy + y * cy
        let cp = cos(pitch), sp = sin(pitch)
        // Betrachter vorn (−y) und oben (+z): oben auf dem Bildschirm = (0, sin p, cos p)
        let screenY = z * cp + yr * sp
        let depth = yr * cp - z * sp
        // Schwache Perspektive: weiter hinten etwas kleiner
        let perspective = 1 / (1 + 0.12 * depth)
        let scale = Double(min(size.width, size.height)) * 0.33 * zoom * perspective
        return (CGPoint(x: Double(size.width) / 2 + xr * scale, y: Double(size.height) / 2 - screenY * scale), depth)
    }
}

/// Ein zu zeichnendes Viereck der Fläche.
struct SurfaceQuad {
    var corners: [CGPoint]
    var depth: Double
    /// mittlere Höhe 0…1 für die Farbe
    var height: Double
    /// Helligkeit aus Flächennormale und Licht, 0…1
    var shade: Double
    var surface: Int
}

enum SurfaceRenderer {
    /// Vierecke aller Flächen, von hinten nach vorn sortiert (Maler-Algorithmus).
    /// `zRange` gemeinsam für alle Flächen, damit sie zueinander passen.
    static func quads(_ meshes: [SurfaceMesh], zRange: ClosedRange<Double>, camera: Camera3D, size: CGSize) -> [SurfaceQuad] {
        var result: [SurfaceQuad] = []
        let zSpan = zRange.upperBound - zRange.lowerBound
        // Licht schräg von oben vorn
        let light = normalized((0.3, -0.4, 0.85))
        for (index, mesh) in meshes.enumerated() {
            let n = mesh.resolution
            func unit(_ i: Int, _ j: Int) -> (Double, Double, Double)? {
                let zv = mesh.z(i, j)
                guard zv.isFinite else { return nil }
                let clamped = min(max(zv, zRange.lowerBound), zRange.upperBound)
                return (Double(i) / Double(n) * 2 - 1, Double(j) / Double(n) * 2 - 1, (clamped - zRange.lowerBound) / zSpan * 2 - 1)
            }
            for j in 0..<n {
                for i in 0..<n {
                    guard let p00 = unit(i, j), let p10 = unit(i + 1, j), let p11 = unit(i + 1, j + 1),
                          let p01 = unit(i, j + 1) else { continue }
                    let points = [p00, p10, p11, p01]
                    let projected = points.map { camera.project($0.0, $0.1, $0.2, size: size) }
                    let depth: Double = projected.map(\.depth).reduce(0, +) / 4
                    let meanZ: Double = (p00.2 + p10.2 + p11.2 + p01.2) / 4
                    let height = (meanZ + 1) / 2
                    // Normale aus den Diagonalen
                    let d1 = (p11.0 - p00.0, p11.1 - p00.1, p11.2 - p00.2)
                    let d2 = (p01.0 - p10.0, p01.1 - p10.1, p01.2 - p10.2)
                    let nx: Double = d1.1 * d2.2 - d1.2 * d2.1
                    let ny: Double = d1.2 * d2.0 - d1.0 * d2.2
                    let nz: Double = d1.0 * d2.1 - d1.1 * d2.0
                    let normal = normalized((nx, ny, nz))
                    let shade = 0.35 + 0.65 * Swift.abs(normal.0 * light.0 + normal.1 * light.1 + normal.2 * light.2)
                    result.append(SurfaceQuad(corners: projected.map(\.point), depth: depth, height: height,
                                              shade: shade, surface: index))
                }
            }
        }
        return result.sorted { $0.depth > $1.depth }
    }

    private static func normalized(_ v: (Double, Double, Double)) -> (Double, Double, Double) {
        let length = (v.0 * v.0 + v.1 * v.1 + v.2 * v.2).squareRoot()
        guard length > 0 else { return (0, 0, 1) }
        return (v.0 / length, v.1 / length, v.2 / length)
    }
}
