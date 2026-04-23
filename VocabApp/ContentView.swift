import SwiftUI

struct ContentView: View {
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var selectedTab = 2 // Default to Discover for now

    var body: some View {
        if let appEnvironment = appEnvironment {
            TabView(selection: $selectedTab) {
                // Home Tab
                HomeView(viewModel: HomeViewModel(
                    wordRepository: appEnvironment.wordRepository,
                    collectionRepository: appEnvironment.collectionRepository
                ))
                .tabItem {
                    Label("Today", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

                // Library Tab
                LibraryView(viewModel: LibraryViewModel(
                    collectionRepository: appEnvironment.collectionRepository
                ))
                .tabItem {
                    Label("Library", systemImage: selectedTab == 1 ? "books.vertical.fill" : "books.vertical")
                }
                .tag(1)

                // Discover Tab
                DiscoverView(dictionaryRepository: appEnvironment.dictionaryRepository)
                    .tabItem {
                        Label("Discover", systemImage: "magnifyingglass")
                    }
                    .tag(2)

                // Profile Tab
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: selectedTab == 3 ? "person.crop.circle.fill" : "person.crop.circle")
                    }
                    .tag(3)
            }
            .tint(Theme.Colors.amiePink)
        } else {
            ProgressView()
                .tint(Theme.Colors.amieBlue)
        }
    }
}

#Preview {
    ContentView()
}
