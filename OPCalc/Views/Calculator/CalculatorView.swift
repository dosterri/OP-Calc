import SwiftUI
import SwiftData

/// Hauptbildschirm: Anzeige oben, eigene Tastatur unten.
struct CalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var model = CalculatorModel()
    @State private var showsHistory = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DisplayView(model: model)
                    .frame(maxHeight: .infinity)

                KeyboardView(layer: model.layer,
                             angleMode: model.angleMode,
                             isSelecting: model.isSelecting) { key in
                    model.press(key, context: modelContext)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
            .background(Color(.systemBackground))
            .navigationTitle("OP Calc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("Verlauf")
                }
            }
            .sheet(isPresented: $showsHistory) {
                HistoryView { record in
                    model.load(record)
                }
            }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: model.feedbackTick)
            .sensoryFeedback(.error, trigger: model.errorTick)
        }
    }
}
