import CoreText
import SwiftData
import SwiftUI

@main
struct VocabAppApp: App {
    let container: ModelContainer
    @State private var appEnvironment: AppEnvironment

    init() {
        Self.registerFonts()
        do {
            let schema = Schema([
                WordSD.self,
                CollectionSD.self,
                SRSCardSD.self,
                ReviewLogSD.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            // TODO: before first TestFlight/App Store distribution, add a VersionedSchema +
            // SchemaMigrationPlan to handle the @Attribute(.unique) added to SRSCardSD.wordId.
            // Safe to skip while no users have the old schema on-device.
            let container = try ModelContainer(for: schema, configurations: [config])
            self.container = container
            
            // Initialize AppEnvironment on MainActor
            self._appEnvironment = State(initialValue: AppEnvironment(modelContext: container.mainContext))
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    private static func registerFonts() {
        guard let url = Bundle.main.url(forResource: "DynaPuff-Medium", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appEnvironment, appEnvironment)
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
