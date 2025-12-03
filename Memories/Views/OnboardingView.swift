import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var selectedItem: PhotosPickerItem?
    var onFinished: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to Memories")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Choose a unique username and a photo.")
                .foregroundColor(.secondary)
            
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
                        .overlay(Image(systemName: "camera.fill").foregroundColor(.gray))
                }
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Text("Select Photo")
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
            
            VStack(alignment: .leading) {
                Text("Full Name (Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("John Doe", text: $viewModel.fullName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: {
                Task {
                    await viewModel.saveProfile(onSuccess: onFinished)
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
                    Text("Create Profile")
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
            
            Spacer()
        }
        .padding(.top, 60)
    }
}
