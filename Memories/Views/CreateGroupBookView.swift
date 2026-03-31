import SwiftUI

struct CreateGroupBookView: View {
    @StateObject private var viewModel = CreateGroupBookViewModel()
    @ObservedObject var socialViewModel: SocialViewModel
    @Environment(\.dismiss) var dismiss
    @State private var step = 0  // 0: Friends, 1: Title/Cover, 2: Vibe

    var body: some View {
        VStack {
            if step == 0 {
                SelectFriendsView(
                    viewModel: socialViewModel,
                    selectedFriends: $viewModel.selectedFriends,
                    onNext: { withAnimation { step = 1 } }
                )
            } else if step == 1 {
                // Reusing BookSetupTitleView logic but adapted for CreateGroupBookViewModel
                // Since BookSetupTitleView is tied to BookDetailViewModel, we might need to duplicate the view or refactor.
                // To avoid duplication, let's create a generic SetupTitleView or just implement it here since it's simple.
                GroupBookSetupTitleView(
                    viewModel: viewModel,
                    onNext: { withAnimation { step = 2 } },
                    onBack: { withAnimation { step = 0 } }
                )
            } else {
                GroupBookSetupVibeView(
                    viewModel: viewModel,
                    onBack: { withAnimation { step = 1 } },
                    onFinish: {
                        Task {
                            if await viewModel.createBook() {
                                await socialViewModel.loadData()
                                dismiss()
                            }
                        }
                    }
                )
            }
        }
    }
}

struct GroupBookSetupTitleView: View {
    @ObservedObject var viewModel: CreateGroupBookViewModel
    var onNext: () -> Void
    var onBack: () -> Void
    @State private var showImagePicker = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                        .foregroundColor(.primary)
                }
                Spacer()
                Text("Setup Group Book")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.left").opacity(0).padding(10)
            }
            .padding()

            ScrollView {
                VStack(spacing: 32) {
                    // Cover Image
                    Button(action: { showImagePicker = true }) {
                        ZStack {
                            if let image = viewModel.coverImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 160, height: 220)
                                    .cornerRadius(12)
                                    .clipped()
                            } else {
                                ZStack {
                                    Color.gray.opacity(0.1)
                                    Image(systemName: "camera.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 160, height: 220)
                                .cornerRadius(12)
                            }

                            // Edit badge
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                                .overlay(Image(systemName: "pencil").font(.caption))
                                .shadow(radius: 2)
                                .offset(x: 70, y: 100)
                        }
                    }

                    // Title
                    VStack(alignment: .leading) {
                        Text("Book Title")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter title", text: $viewModel.title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button(action: onNext) {
                        Text("Next")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(viewModel.title.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $viewModel.coverImage)
        }
    }
}

struct GroupBookSetupVibeView: View {
    @ObservedObject var viewModel: CreateGroupBookViewModel
    var onBack: () -> Void
    var onFinish: () -> Void
    @State private var selectedCategory: String = "Winter"

    let categories = ["Winter", "Spring", "Autumn", "Summer"]
    let vibes: [String: [String]] = [
        "Winter": ["#A1C6EA", "#E3E4E6", "#2C3E50", "#E85D75", "#B0C4DE", "#F0F8FF"],
        "Spring": ["#A8E6CF", "#FFD3B6", "#FFAAA5", "#B39CD0", "#FFB7B2", "#E2F0CB"],
        "Autumn": ["#D2691E", "#8B4513", "#DAA520", "#556B2F", "#CD853F", "#800000"],
        "Summer": ["#FFD700", "#FF8C00", "#00BFFF", "#FF69B4", "#40E0D0", "#FF4500"],
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                        .foregroundColor(.primary)
                }
                Spacer()
                Text("Choose a Vibe")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.left").opacity(0).padding(10)
            }
            .padding()

            // Category Selector (Same as before)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            withAnimation {
                                selectedCategory = category
                            }
                        }) {
                            Text(category)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
                                .background(
                                    selectedCategory == category
                                        ? Color.white : Color.gray.opacity(0.1)
                                )
                                .foregroundColor(selectedCategory == category ? .black : .primary)
                                .cornerRadius(20)
                                .shadow(
                                    color: selectedCategory == category
                                        ? Color.black.opacity(0.1) : .clear, radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Color Grid
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16
                ) {
                    if let colors = vibes[selectedCategory] {
                        ForEach(colors, id: \.self) { colorHex in
                            Button(action: {
                                viewModel.selectedVibe = colorHex
                            }) {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(hex: colorHex))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(
                                        ZStack {
                                            if viewModel.selectedVibe == colorHex {
                                                Image(systemName: "checkmark")
                                                    .font(.title)
                                                    .foregroundColor(.white)
                                                    .shadow(radius: 2)
                                            }
                                        }
                                    )
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }

            // Create Button
            Button(action: onFinish) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Create Group")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(viewModel.isLoading)
        }
    }
}
