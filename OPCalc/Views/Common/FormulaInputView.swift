import SwiftUI

/// Eingabe einer Formel mit Variablen (Graph, 3D, DGL, Gleichungen): Formel-Editor plus Rechnertastatur.
/// Variablen bekommen eigene Tasten, ✓ übernimmt die Formel, wenn sie vollständig ist.
struct FormulaInputView: View {
    let title: String
    /// Text vor der Formel, z. B. „f(x) =“
    let prefix: String
    let variables: [String]
    let initial: MathRow
    var allowsEmpty = false
    let onDone: (MathRow) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model = CalculatorModel()
    @State private var mode: AppMode = .calculator

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 8) {
                    Text(prefix)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    FormulaEditorView(editor: model.editor) { path in
                        model.setCursor(path)
                    }
                }
                .frame(height: 110)
                .padding(.horizontal, 12)

                if let message = model.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 16)
                }

                KeyboardView(layer: model.layer, angleMode: model.angleMode,
                             isSelecting: model.isSelecting, mode: $mode,
                             variables: variables) { key in
                    if key == .equals { confirm() } else { model.press(key, context: nil) }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { confirm() }
                }
            }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: model.feedbackTick)
            .sensoryFeedback(.error, trigger: model.errorTick)
        }
        .onAppear { model.startEditing(initial) }
    }

    private func confirm() {
        let row = model.editor.root
        if row.isEmpty && allowsEmpty {
            onDone(row)
            dismiss()
            return
        }
        switch FormulaCompiler.expression(row, allowed: Set(variables)) {
        case .success:
            onDone(row)
            dismiss()
        case .failure(let failure):
            model.showError(failure.message, at: failure.path)
        }
    }
}
