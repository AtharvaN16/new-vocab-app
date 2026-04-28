import SwiftUI

struct ProfileView: View {
    @State var viewModel = ProfileViewModel()
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var showingLogin = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                
                Form {
                    Section(header: Text("AI")) {
                        if let env = appEnvironment {
                            NavigationLink {
                                ModelManagerView(
                                    viewModel: ModelManagerViewModel(repository: env.localModelRepository)
                                )
                            } label: {
                                HStack {
                                    Label("Intelligence", systemImage: "cpu")
                                    Spacer()
                                    Text(ModelManagerViewModel(repository: env.localModelRepository).activeModelLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    if let message = viewModel.message {
                        Section {
                            Text(message)
                                .foregroundStyle(message.contains("Error") ? .red : .green)
                                .font(.caption)
                        }
                    }

                    Section(header: Text("Account")) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(Theme.Colors.amieBlue)
                            
                            VStack(alignment: .leading) {
                                if let user = appEnvironment?.authRepository.currentUser {
                                    Text(user.email ?? "User")
                                        .font(.headline)
                                    Text("Premium Member")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Guest User")
                                        .font(.headline)
                                    Text("Sign in to sync your library")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        if let auth = appEnvironment?.authRepository, auth.isAuthenticated {
                            Button("Sign Out", role: .destructive) {
                                Task { try? await auth.signOut() }
                            }
                        } else {
                            Button("Sign In / Sign Up") {
                                showingLogin = true
                            }
                        }
                    }

                    Section(header: Text("Data Management")) {
                        Button("Manual Sync Now") {
                            Task {
                                try? await appEnvironment?.syncRepository.pushLocalChanges()
                            }
                        }
                    }

                    Section(header: Text("About")) {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .padding(.top, 16) // Consistent top margin
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(Theme.Animation.spring) {
                            appEnvironment?.selectedTab = 0
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingLogin) {
                if let appEnv = appEnvironment {
                    LoginView(viewModel: LoginViewModel(authRepository: appEnv.authRepository))
                }
            }
        }
    }
}
