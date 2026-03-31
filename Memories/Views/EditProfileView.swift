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
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    ScrollView {
                        VStack(spacing: 32) {
                            // Photo Picker
                            Button(action: { selectedItem = nil }) {
                                ZStack {
                                    if let image = viewModel.selectedImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 160, height: 160)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 160, height: 160)
                                            .overlay(
                                                Image(systemName: "camera.fill")
                                                    .font(.largeTitle)
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                }
                            }
                            .onTapGesture {
                                // Open photo picker
                                selectedItem = nil
                            }
                            .padding(.top)
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
                            // Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter your name", text: $viewModel.fullName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .padding(.horizontal)
                        }
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
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Save")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .disabled(viewModel.isLoading)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
        }
    }
}

