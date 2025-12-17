import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @StateObject private var viewModel: EditProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    
    let onProfileUpdated: () -> Void
    
    init(profile: Profile, onProfileUpdated: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: EditProfileViewModel(profile: profile))
        self.onProfileUpdated = onProfileUpdated
    }
    
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
                Text("Edit Profile")
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 24)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar Picker
                        VStack {
                            if let image = viewModel.selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .foregroundColor(.gray)
                                    )
                            }
                            
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Text("Change Photo")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .onChange(of: selectedItem) { newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        viewModel.selectedImage = uiImage
                                    }
                                }
                            }
                        }
                        .padding(.top, 20)
                        
                        // Username Field
                        VStack(alignment: .leading) {
                            Text("Username")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("username", text: $viewModel.username)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                if viewModel.isCheckingUsername {
                                    ProgressView()
                                } else if !viewModel.username.isEmpty {
                                    Image(systemName: viewModel.isUsernameValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(viewModel.isUsernameValid ? .green : .red)
                                }
                            }
                            
                            if !viewModel.username.isEmpty && !viewModel.isUsernameValid && !viewModel.isCheckingUsername {
                                Text("Username taken or too short (min 3 chars)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Full Name Field
                        VStack(alignment: .leading) {
                            Text("Full Name (Optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("John Doe", text: $viewModel.fullName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        // Error Message
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                        
                        // Save Button
                        Button(action: {
                            Task {
                                await viewModel.saveProfile {
                                    onProfileUpdated()
                                    dismiss()
                                }
                            }
                        }) {
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    if viewModel.isUploadingImage {
                                        Text("Uploading...")
                                    }
                                }
                            } else {
                                Text("Save Changes")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isUsernameValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .disabled(!viewModel.isUsernameValid || viewModel.isLoading)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

