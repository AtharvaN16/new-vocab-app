import SwiftUI

@Observable
final class NavigationState {
    var homeViewModel: HomeViewModel?
    var libraryViewModel: LibraryViewModel?
}

struct ContentView: View {
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var navState = NavigationState()

    var body: some View {
        if let appEnvironment = appEnvironment {
            ZStack {
                // Main Content
                ZStack {
                    switch appEnvironment.selectedTab {
                    case 0:
                        homeTab(appEnvironment)
                            .transition(.opacity)
                    case 1:
                        libraryTab(appEnvironment)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case 2:
                        discoverTab(appEnvironment)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    case 3:
                        ProfileView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(Theme.Animation.spring, value: appEnvironment.selectedTab)

            }
            .ignoresSafeArea(.keyboard)
        } else {
            ProgressView()
                .tint(Theme.Colors.amieBlue)
        }
    }

    @ViewBuilder
    private func homeTab(_ appEnvironment: AppEnvironment) -> some View {
        if let vm = navState.homeViewModel {
            HomeView(viewModel: vm)
        } else {
            Color.clear.onAppear {
                navState.homeViewModel = HomeViewModel(
                    wordRepository: appEnvironment.wordRepository,
                    collectionRepository: appEnvironment.collectionRepository
                )
            }
        }
    }

    @ViewBuilder
    private func libraryTab(_ appEnvironment: AppEnvironment) -> some View {
        if let vm = navState.libraryViewModel {
            LibraryView(viewModel: vm)
        } else {
            Color.clear.onAppear {
                navState.libraryViewModel = LibraryViewModel(
                    collectionRepository: appEnvironment.collectionRepository
                )
            }
        }
    }

    @ViewBuilder
    private func discoverTab(_ appEnvironment: AppEnvironment) -> some View {
        DiscoverView(
            dictionaryRepository: appEnvironment.dictionaryRepository,
            wordRepository: appEnvironment.wordRepository,
            collectionRepository: appEnvironment.collectionRepository
        )
    }
}

#Preview {
    ContentView()
}
