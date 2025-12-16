import PhotosUI
import SwiftUI

struct BookDetailView: View {
    @StateObject private var viewModel: BookDetailViewModel
    @Environment(\.dismiss) var dismiss

    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(book: book))
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.pages.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
            } else {
                if viewModel.book.title == nil || viewModel.book.vibe == nil {
                    BookSetupView(viewModel: viewModel)
                } else {
                    BookCarouselView(viewModel: viewModel)
                }
            }
        }
        .task {
            await viewModel.loadPages()
            await viewModel.fetchPartnerProfile()
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.showAddMemorySheet) {
            AddMemoryView(viewModel: viewModel)
        }
        .alert(item: $viewModel.alertItem) { item in
            Alert(
                title: Text("Error"), message: Text(item.message),
                dismissButton: .default(Text("OK")))
        }
    }
}

struct AlertItem: Identifiable {
    var id = UUID()
    var message: String
}

// MARK: - Book Setup View
// MARK: - Book Setup View
struct BookSetupView: View {
    @ObservedObject var viewModel: BookDetailViewModel
    @State private var step = 0  // 0: Title/Cover, 1: Vibe

    var body: some View {
        VStack {
            if step == 0 {
                BookSetupTitleView(
                    viewModel: viewModel,
                    onNext: {
                        withAnimation { step = 1 }
                    })
            } else {
                BookSetupVibeView(
                    viewModel: viewModel,
                    onBack: {
                        withAnimation { step = 0 }
                    })
            }
        }
    }
}

struct BookSetupTitleView: View {
    @ObservedObject var viewModel: BookDetailViewModel
    var onNext: () -> Void
    @State private var showImagePicker = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                        .foregroundColor(.primary)
                }
                Spacer()
                Text("Setup Book")
                    .font(.headline)
                Spacer()
                // Balance
                Image(systemName: "xmark").opacity(0).padding(10)
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
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 160, height: 220)
                                    .cornerRadius(12)
                                    .clipped()
                            } else if let coverUrl = viewModel.book.coverUrl,
                                let url = URL(string: coverUrl)
                            {
                                CachedImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
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

struct BookSetupVibeView: View {
    @ObservedObject var viewModel: BookDetailViewModel
    var onBack: () -> Void
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
                // Invisible spacer for balance
                Image(systemName: "chevron.left").opacity(0)
                    .padding(10)
            }
            .padding()

            // Category Selector
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
                                Task {
                                    _ = await viewModel.saveBookDetails()
                                }
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
        }
        .background(Color(UIColor.systemGroupedBackground))  // Light gray background for contrast
    }
}

// MARK: - Add Memory View
struct AddMemoryView: View {
    @ObservedObject var viewModel: BookDetailViewModel
    @State private var showImagePicker = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Photo Picker
                        Button(action: { showImagePicker = true }) {
                            ZStack {
                                if let image = viewModel.newMemoryImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 350)
                                        .cornerRadius(16)
                                        .clipped()
                                } else {
                                    ZStack {
                                        Color.gray.opacity(0.1)
                                        VStack(spacing: 12) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text("Tap to add photo")
                                                .font(.headline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .frame(height: 350)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                Color.gray.opacity(0.3),
                                                style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)

                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CAPTION")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)

                            TextField(
                                "Write a memory...", text: $viewModel.newMemoryText, axis: .vertical
                            )
                            .lineLimit(1...4)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        // Date
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DATE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)

                            DatePicker(
                                "", selection: $viewModel.newMemoryDate, displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                    }
                }

                // Save Button
                Button(action: {
                    Task {
                        if await viewModel.addMemory() {
                            dismiss()
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Save Memory")
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
                .disabled(
                    viewModel.newMemoryImage == nil || viewModel.newMemoryText.isEmpty
                        || viewModel.isLoading
                )
                .opacity(
                    (viewModel.newMemoryImage == nil || viewModel.newMemoryText.isEmpty) ? 0.5 : 1.0
                )
            }
            .navigationTitle("New Memory")
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
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $viewModel.newMemoryImage)
        }
    }
}

// MARK: - Pages View
struct PagesView: View {
    @ObservedObject var viewModel: BookDetailViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding(10)
                        .background(Color.white.opacity(0.5))
                        .clipShape(Circle())
                        .foregroundColor(.black)
                }

                Spacer()

                Text(viewModel.book.title ?? "Memories")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Spacer()

                Button(action: {
                    // Scroll to last logic or add new memory
                }) {
                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .padding(10)
                        .background(Color.white.opacity(0.5))
                        .clipShape(Circle())
                        .foregroundColor(.black)
                }
            }
            .padding()

            TabView(selection: $viewModel.selectedPageId) {
                ForEach(viewModel.pages) { page in
                    GeometryReader { proxy in
                        VStack(spacing: 0) {
                            // Date Header
                            HStack {
                                Text(
                                    page.photoDate?.formatted(date: .abbreviated, time: .omitted)
                                        ?? ""
                                )
                                .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)

                            // Photo Card
                            ZStack {
                                CachedImage(url: URL(string: page.photoUrl)!) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(
                                    width: proxy.size.width - 40,
                                    height: proxy.size.height * 0.7
                                )
                                .clipped()
                                .cornerRadius(2)  // Photo frame style
                                .padding(10)  // White border
                                .background(Color.white)
                                .cornerRadius(4)
                                .shadow(radius: 5)

                                // Caption Overlay
                                if let caption = page.memoryText {
                                    Text(caption)
                                        .font(.custom("Courier", size: 24))  // Handwriting style placeholder
                                        .foregroundColor(.white)
                                        .shadow(color: .black, radius: 2)
                                        .padding()
                                        .background(Color.black.opacity(0.3))
                                        .cornerRadius(8)
                                        .padding()
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .tag(Optional(page.id))  // Tag must match selection type
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Add Button
            Button(action: {
                // Logic to add new memory from here
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.black)
                    .shadow(radius: 2)
            }
            .padding(.bottom)
        }
    }
}
