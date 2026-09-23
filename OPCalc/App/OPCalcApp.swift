import SwiftUI
import SwiftData

@main
struct OPCalcApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            CalculationRecord.self,
        ])
        // Rein lokale Speicherung – kein iCloud-Sync, keine Registrierung.
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
