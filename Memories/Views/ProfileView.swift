import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showEditProfile = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(uiColor: .secondarySystemFill))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Title
                Text("Profile")
                    .font(.title.bold())
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 24)
                
                Spacer()
                
                // Content
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let profile = viewModel.currentProfile {
                    VStack(spacing: 40) {
                        // Flip Card
                        ProfileFlipCardView(profile: profile) {
                            showEditProfile = true
                        }
                        
                        // Sign Out Button
                        Button(action: {
                            Task {
                                await viewModel.signOut()
                            }
                        }) {
                            Text("Sign Out")
                                .font(.headline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 40)
                    }
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        
                        Text("Error Loading Profile")
                            .font(.headline)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Retry") {
                            Task {
                                await viewModel.loadProfile()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadProfile()
        }
        .fullScreenCover(isPresented: $showEditProfile) {
            if let profile = viewModel.currentProfile {
                EditProfileView(profile: profile, onProfileUpdated: {
                    Task {
                        await viewModel.loadProfile()
                    }
                })
            }
        }
    }
}

#Preview {
    ProfileView()
}

