import SwiftUI

/// Wurzelzeichen, das mit dem Inhalt in die Höhe wächst.
struct RadicalSignShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.6))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

enum DelimiterStyle {
    case parenthesis
    case bar
}

/// Mitwachsende Klammer bzw. Betragsstrich.
struct DelimiterShape: Shape {
    var style: DelimiterStyle
    var isLeft: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch style {
        case .bar:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        case .parenthesis:
            let inner = isLeft ? rect.maxX - rect.width * 0.2 : rect.minX + rect.width * 0.2
            let outer = isLeft ? rect.minX + rect.width * 0.05 : rect.maxX - rect.width * 0.05
            path.move(to: CGPoint(x: inner, y: rect.minY))
            path.addCurve(to: CGPoint(x: inner, y: rect.maxY),
                          control1: CGPoint(x: outer, y: rect.minY + rect.height * 0.22),
                          control2: CGPoint(x: outer, y: rect.maxY - rect.height * 0.22))
        }
        return path
    }
}
