import SwiftData
import SwiftUI

@main
struct VocabAppApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                WordSD.self,
                CollectionSD.self,
                SRSCardSD.self,
                ReviewLogSD.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appEnvironment, AppEnvironment(modelContext: container.mainContext))
        }
        .modelContainer(container)
    }
}
