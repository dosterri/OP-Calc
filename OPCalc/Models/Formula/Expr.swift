import Foundation

/// Der Mathe-AST: das, was tatsächlich gerechnet wird.
/// Entsteht durch den FormulaParser aus dem Editor-Baum (MathRow).
indirect enum Expr: Equatable {
    case number(Rational)
    case constant(MathConstant)
    case variable(String)
    case ans
    case negate(Expr)
    case add(Expr, Expr)
    case subtract(Expr, Expr)
    case multiply(Expr, Expr)
    case divide(Expr, Expr)
    case power(Expr, Expr)
    case root(degree: Expr, radicand: Expr)
    case function(MathFunction, Expr)
    case absolute(Expr)
    case factorial(Expr)
}
