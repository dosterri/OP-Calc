import SwiftUI
import SwiftData

/// Verlauf aller mit „=“ oder „≈“ berechneten Ausdrücke. Antippen lädt die Formel wieder in den Editor.
struct HistoryView: View {
    let onSelect: (CalculationRecord) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CalculationRecord.createdAt, order: .reverse) private var records: [CalculationRecord]
    @State private var confirmsClear = false

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView("Noch keine Rechnungen",
                                           systemImage: "clock",
                                           description: Text("Mit „=“ berechnete Ausdrücke erscheinen hier."))
                } else {
                    List {
                        ForEach(records) { record in
                            Button {
                                onSelect(record)
                                dismiss()
                            } label: {
                                HistoryRow(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Verlauf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Leeren", role: .destructive) { confirmsClear = true }
                        .disabled(records.isEmpty)
                }
            }
            .confirmationDialog("Gesamten Verlauf löschen?", isPresented: $confirmsClear, titleVisibility: .visible) {
                Button("Verlauf löschen", role: .destructive) {
                    for record in records { modelContext.delete(record) }
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }
}

private struct HistoryRow: View {
    let record: CalculationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MathRowView(row: record.input, path: [], context: .display)
                .environment(\.mathFontSize, 20)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()

            HStack(spacing: 6) {
                Text(record.isExact ? "=" : "≈")
                    .foregroundStyle(.secondary)
                MathRowView(row: record.result, path: [], context: .display)
                    .environment(\.mathFontSize, 22)
                    .fixedSize()
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()

            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(record.input.linearText) \(record.isExact ? "gleich" : "ungefähr") \(record.resultText)")
    }
}
