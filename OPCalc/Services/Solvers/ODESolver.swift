import Foundation

/// Löser für Anfangswertprobleme u′ = F(t, u) mit u ∈ ℝⁿ (AK-05).
/// Dormand-Prince 5(4) mit Schrittweitensteuerung; DGL 2. Ordnung werden als System
/// (y, y′) gelöst.
enum ODESolver {
    struct Sample: Equatable {
        var t: Double
        var u: [Double]
    }

    struct Trajectory: Equatable {
        var samples: [Sample]
        /// Gesetzt, wenn die Lösung vor dem Ziel abbricht (Polstelle, Überlauf)
        var stoppedAt: Double?
        /// true, wenn nur die Höchstzahl der Schritte erreicht wurde (kein Pol)
        var ranOutOfSteps = false
    }

    /// Toleranz pro Schritt (relativ und absolut).
    static let tolerance = 1e-10
    /// Werte darüber gelten als „wächst über alle Grenzen“.
    static let blowUpLimit = 1e12
    /// Höchstzahl der Schritte, damit steife Gleichungen die App nicht blockieren.
    static let maxSteps = 200_000

    /// Löst von t₀ bis t₁ (auch rückwärts, wenn t₁ < t₀). `maxStep` begrenzt die Schrittweite,
    /// damit gezeichnete Kurven glatt werden.
    static func solve(_ f: ([Double], Double) -> [Double], u0: [Double], from t0: Double, to t1: Double,
                      maxStep: Double? = nil) -> Trajectory {
        var samples = [Sample(t: t0, u: u0)]
        guard t0 != t1, u0.allSatisfy(\.isFinite) else { return Trajectory(samples: samples, stoppedAt: nil) }
        let direction: Double = t1 > t0 ? 1 : -1
        let span = Swift.abs(t1 - t0)
        let hMax = maxStep ?? span / 50
        var h = min(hMax, span / 100) * direction
        var t = t0
        var u = u0

        for _ in 0..<maxSteps {
            if (t1 - t) * direction <= 0 { return Trajectory(samples: samples, stoppedAt: nil) }
            if Swift.abs(h) > Swift.abs(t1 - t) { h = t1 - t }
            guard let step = dormandPrince(f, t, u, h) else {
                return Trajectory(samples: samples, stoppedAt: t)
            }
            let scale = zip(u, step.u).map { tolerance + tolerance * max(Swift.abs($0), Swift.abs($1)) }
            let error = sqrt(zip(step.error, scale).map { ($0 / $1) * ($0 / $1) }.reduce(0, +) / Double(u.count))
            if error <= 1 {
                t += h
                u = step.u
                if u.contains(where: { !$0.isFinite || Swift.abs($0) > blowUpLimit }) {
                    return Trajectory(samples: samples, stoppedAt: t)
                }
                samples.append(Sample(t: t, u: u))
                // Ziel erreicht (auch mit Rundungsrest) – nicht als Abbruch melden
                if (t1 - t) * direction <= 1e-12 * max(1, Swift.abs(t1)) {
                    return Trajectory(samples: samples, stoppedAt: nil)
                }
            }
            // Schrittweite anpassen (Sicherheitsfaktor 0,9, Änderung höchstens Faktor 5)
            let factor = error == 0 ? 5 : min(5, max(0.2, 0.9 * pow(error, -0.2)))
            h = direction * min(hMax, Swift.abs(h) * factor)
            if Swift.abs(h) < 1e-14 * max(1, Swift.abs(t)) {
                return Trajectory(samples: samples, stoppedAt: t)
            }
        }
        return Trajectory(samples: samples, stoppedAt: t, ranOutOfSteps: true)
    }

    /// Ein Schritt Dormand-Prince: Lösung 5. Ordnung und Fehlerschätzung (Differenz zur 4. Ordnung).
    private static func dormandPrince(_ f: ([Double], Double) -> [Double], _ t: Double, _ u: [Double], _ h: Double)
        -> (u: [Double], error: [Double])? {
        func combine(_ weights: [Double], _ ks: [[Double]]) -> [Double] {
            var result = u
            for (w, k) in zip(weights, ks) where w != 0 {
                for i in result.indices { result[i] += h * w * k[i] }
            }
            return result
        }
        let k1 = f(u, t)
        let k2 = f(combine(Self.a2, [k1]), t + h / 5)
        let k3 = f(combine(Self.a3, [k1, k2]), t + 3 * h / 10)
        let k4 = f(combine(Self.a4, [k1, k2, k3]), t + 4 * h / 5)
        let k5 = f(combine(Self.a5, [k1, k2, k3, k4]), t + 8 * h / 9)
        let k6 = f(combine(Self.a6, [k1, k2, k3, k4, k5]), t + h)
        let fifth = combine(Self.b5, [k1, k2, k3, k4, k5, k6])
        let k7 = f(fifth, t + h)
        let errorWeights = Self.errorWeights
        let ks = [k1, k2, k3, k4, k5, k6, k7]
        guard ks.allSatisfy({ $0.allSatisfy(\.isFinite) }), fifth.allSatisfy(\.isFinite) else { return nil }
        var error = [Double](repeating: 0, count: u.count)
        for (w, k) in zip(errorWeights, ks) where w != 0 {
            for i in error.indices { error[i] += h * w * k[i] }
        }
        return (fifth, error)
    }

    // Butcher-Tabelle Dormand-Prince 5(4) (Standardwerte). Als typisierte Konstanten,
    // sonst braucht der Compiler zu lange für die Typprüfung der Brüche.
    private static let a2: [Double] = [0.2]
    private static let a3: [Double] = [3.0 / 40.0, 9.0 / 40.0]
    private static let a4: [Double] = [44.0 / 45.0, -56.0 / 15.0, 32.0 / 9.0]
    private static let a5: [Double] = [19372.0 / 6561.0, -25360.0 / 2187.0, 64448.0 / 6561.0, -212.0 / 729.0]
    private static let a6: [Double] = [9017.0 / 3168.0, -355.0 / 33.0, 46732.0 / 5247.0, 49.0 / 176.0, -5103.0 / 18656.0]
    private static let b5: [Double] = [35.0 / 384.0, 0, 500.0 / 1113.0, 125.0 / 192.0, -2187.0 / 6784.0, 11.0 / 84.0]
    private static let errorWeights: [Double] = [71.0 / 57600.0, 0, -71.0 / 16695.0, 71.0 / 1920.0,
                                                 -17253.0 / 339200.0, 22.0 / 525.0, -1.0 / 40.0]

    /// Wert der Lösung an der Stelle t durch lineare Interpolation der Stützstellen.
    static func value(of trajectory: Trajectory, at t: Double, component: Int = 0) -> Double? {
        let s = trajectory.samples
        guard let first = s.first, let last = s.last else { return nil }
        let (lo, hi) = (min(first.t, last.t), max(first.t, last.t))
        guard t >= lo, t <= hi else { return nil }
        for i in 0..<(s.count - 1) {
            let (a, b) = (s[i], s[i + 1])
            if (t - a.t) * (t - b.t) <= 0 {
                let w = b.t == a.t ? 0 : (t - a.t) / (b.t - a.t)
                return a.u[component] + w * (b.u[component] - a.u[component])
            }
        }
        return s.count == 1 ? first.u[component] : nil
    }
}
