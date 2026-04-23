import SwiftUI

struct ProfileView: View {
    @State var viewModel = ProfileViewModel()
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var showingLogin = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("AI Assistant")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenRouter API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Enter sk-or-v1-...", text: $viewModel.openRouterApiKey)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("Your key is stored securely in the iOS Keychain.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Button(action: { 
                        viewModel.saveKeys() 
                        if let appEnv = appEnvironment {
                            appEnv.updateAIKey(viewModel.openRouterApiKey)
                        }
                    }) {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save AI Settings")
                        }
                    }
                }
                
                if let message = viewModel.message {
                    Section {
                        Text(message)
                            .foregroundColor(message.contains("Error") ? .red : .green)
                            .font(.caption)
                    }
                }

                Section(header: Text("Account")) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            if let user = appEnvironment?.authRepository.currentUser {
                                Text(user.email ?? "User")
                                    .font(.headline)
                                Text("Premium Member")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Guest User")
                                    .font(.headline)
                                Text("Sign in to sync your library")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                    
                    Button("Reset Cache", role: .destructive) {
                        // TODO: Implement cache reset
                    }
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingLogin) {
                if let appEnv = appEnvironment {
                    LoginView(viewModel: LoginViewModel(authRepository: appEnv.authRepository))
                }
            }
        }
    }
}
