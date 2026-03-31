import SwiftUI

struct BookCarouselView: View {
    @ObservedObject var viewModel: BookDetailViewModel
    @Environment(\.dismiss) var dismiss

    @State private var currentPageId: UUID?
    @State private var showGridView = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .padding(12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .foregroundColor(.black)
                    }

                    Spacer()

                    Text(viewModel.book.title ?? "Memories")
                        .font(.system(size: 24, weight: .bold, design: .serif))  // Serif font like design
                        .foregroundColor(.black)  // Or adaptive based on vibe

                    Spacer()

                    Button(action: {
                        viewModel.showAddMemorySheet = true
                    }) {
                        Image(systemName: "plus")  // Or arrow.right if strictly following design, but user asked for +
                            .font(.title2)
                            .padding(12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 60)  // Adjust for safe area
                .padding(.bottom, 20)

                if viewModel.pages.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Spacer()

                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.black.opacity(0.5))

                        Text(
                            "Create your first memory with \(viewModel.partnerName ?? "your partner")"
                        )
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .foregroundColor(.black.opacity(0.7))

                        Button(action: {
                            viewModel.showAddMemorySheet = true
                        }) {
                            Text("Add Memory")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(Color.black)
                                .cornerRadius(30)
                        }

                        Spacer()
                    }
                } else {
                    // Carousel
                    ScrollViewReader { scrollProxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 0) {
                                ForEach(viewModel.pages) { page in
                                    VStack {
                                        FlipCardView(page: page)
                                            .frame(
                                                width: geometry.size.width * 0.75,
                                                height: geometry.size.height * 0.6
                                            )
                                            .scrollTransition { content, phase in
                                                content
                                                    .opacity(phase.isIdentity ? 1.0 : 0.8)
                                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.9)
                                                    .rotationEffect(.degrees(phase.value * 5))
                                            }
                                    }
                                    .frame(width: geometry.size.width)
                                    .containerRelativeFrame(.horizontal)
                                    .id(page.id)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .scrollPosition(id: $currentPageId)
                        .defaultScrollAnchor(.trailing)
                        .onAppear {
                            // Initialize to last page if not set
                            if currentPageId == nil {
                                currentPageId = viewModel.pages.last?.id
                            }
                        }

                        // Navigation Controls
                        HStack {
                            // First button - hidden when on first page
                            if !isOnFirstPage {
                                Button(action: {
                                    withAnimation {
                                        if let firstPage = viewModel.pages.first {
                                            currentPageId = firstPage.id
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.backward")
                                        Text("first")
                                            .fontWeight(.bold)
                                    }
                                    .foregroundColor(.black)
                                }
                            } else {
                                // Invisible placeholder to maintain layout
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.backward")
                                    Text("first")
                                        .fontWeight(.bold)
                                }
                                .opacity(0)
                            }

                            Spacer()

                            // Grid View Button
                            Button(action: {
                                showGridView = true
                            }) {
                                Image(systemName: "rectangle.grid.3x2")
                                    .font(.system(size: 24))
                                    .foregroundColor(.black)
                            }

                            Spacer()

                            // Last button - hidden when on last page
                            if !isOnLastPage {
                                Button(action: {
                                    withAnimation {
                                        if let lastPage = viewModel.pages.last {
                                            currentPageId = lastPage.id
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Text("last")
                                            .fontWeight(.bold)
                                        Image(systemName: "chevron.forward")
                                    }
                                    .foregroundColor(.black)
                                }
                            } else {
                                // Invisible placeholder to maintain layout
                                HStack(spacing: 4) {
                                    Text("last")
                                        .fontWeight(.bold)
                                    Image(systemName: "chevron.forward")
                                }
                                .opacity(0)
                            }
                        }
                        .padding()
                    }
                }

                // Bottom Avatar (User)
                HStack {
                    Spacer()
                    // Placeholder for current user avatar or similar
                    // In the design there is a small avatar at bottom right
                    if let user = SocialService.shared.currentUser {  // We need to expose currentUser or fetch it
                        // AvatarView(url: user.avatarUrl, size: 40)
                        // For now just a placeholder or nothing
                    }
                }
                .padding()
            }
        }
        .background(
            Color(hex: viewModel.book.vibe ?? "#FFB7B2")  // Default to pinkish if no vibe
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showGridView) {
            BookGridView(
                pages: viewModel.pages,
                bookTitle: viewModel.book.title ?? "Memories",
                vibeColor: viewModel.book.vibe ?? "#FFB7B2",
                onPageSelected: { pageId in
                    currentPageId = pageId
                    showGridView = false
                }
            )
        }
    }

    // MARK: - Computed Properties

    private var isOnFirstPage: Bool {
        guard let currentId = currentPageId,
            let firstPage = viewModel.pages.first
        else {
            return false
        }
        return currentId == firstPage.id
    }

    private var isOnLastPage: Bool {
        guard let currentId = currentPageId,
            let lastPage = viewModel.pages.last
        else {
            return false
        }
        return currentId == lastPage.id
    }
}
