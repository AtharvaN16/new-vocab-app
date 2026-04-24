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

                // Floating Controls (Only on Home/Today and not expanded)
                if appEnvironment.selectedTab == 0, navState.homeViewModel?.isExpanded == false {
                    VStack {
                        HStack {
                            // Collections Button (Top Left)
                            IconButton(icon: "square.grid.2x2") {
                                withAnimation(Theme.Animation.spring) {
                                    appEnvironment.selectedTab = 1
                                }
                            }
                            
                            Spacer()
                            
                            // Account Button (Top Right)
                            IconButton(icon: "person.crop.circle") {
                                withAnimation(Theme.Animation.spring) {
                                    appEnvironment.selectedTab = 3
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        
                        Spacer()
                    }
                    .transition(.opacity)
                }
                
                // Floating Close Button for other tabs (Consistent frame and position)
                if appEnvironment.selectedTab != 0 {
                    VStack {
                        HStack {
                            Spacer()
                            IconButton(icon: "xmark") {
                                withAnimation(Theme.Animation.spring) {
                                    appEnvironment.selectedTab = 0
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16) // Exact same top padding as home buttons
                        
                        Spacer()
                    }
                    .transition(.opacity)
                    .zIndex(100) // Ensure it's above everything
                }
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

// Fallback for non-iOS 26 (though project target is iOS 26+)
extension View {
    @ViewBuilder
    func glassEffect(_ glass: GlassVariant = .regular, in shape: some Shape = Circle()) -> some View {
        if #available(iOS 26, *) {
            self.modifier(LiquidGlassModifier(variant: glass, shape: shape))
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

enum GlassVariant {
    case regular, clear
    func interactive() -> GlassVariant { self }
}

struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let variant: GlassVariant
    let shape: S
    
    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // Subtle inner glow/border for definition
                        shape.stroke(.white.opacity(0.5), lineWidth: 1.0)
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            }
    }
}

#Preview {
    ContentView()
}
