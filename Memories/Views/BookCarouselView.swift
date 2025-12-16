import SwiftUI

struct BookCarouselView: View {
    @ObservedObject var viewModel: BookDetailViewModel
    @Environment(\.dismiss) var dismiss

    @State private var currentPageId: UUID?
    @State private var showGridView = false

    // Drag Mode State (activated by long press)
    @State private var isDragModeActive = false
    @State private var isDragging = false
    @State private var draggedPageId: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var isHoveringEdit = false
    @State private var isHoveringDelete = false
    @State private var showDeleteConfirmation = false
    @State private var pageToDelete: Page?

    // Long press visual feedback
    @State private var isLongPressing = false
    @State private var longPressPageId: UUID?

    // Button frame tracking for hit testing
    @State private var editButtonFrame: CGRect = .zero
    @State private var deleteButtonFrame: CGRect = .zero

    // Haptic feedback generator
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

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
                    // Carousel with long-press-to-drag support
                    ZStack {
                        ScrollViewReader { scrollProxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 0) {
                                    ForEach(viewModel.pages) { page in
                                        let isBeingDragged = draggedPageId == page.id && isDragging
                                        let isBeingLongPressed = longPressPageId == page.id && isLongPressing

                                        VStack {
                                            FlipCardView(page: page)
                                                .frame(
                                                    width: geometry.size.width * 0.75,
                                                    height: geometry.size.height * 0.6
                                                )
                                                .scaleEffect(cardScaleEffect(isBeingDragged: isBeingDragged, isBeingLongPressed: isBeingLongPressed))
                                                .opacity(isBeingDragged ? 0.3 : 1.0)
                                                .scrollTransition { content, phase in
                                                    content
                                                        .opacity(phase.isIdentity ? 1.0 : 0.8)
                                                        .scaleEffect(phase.isIdentity ? 1.0 : 0.9)
                                                        .rotationEffect(.degrees(phase.value * 5))
                                                }
                                                .gesture(
                                                    longPressAndDragGesture(for: page, in: geometry)
                                                )
                                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isBeingLongPressed)
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
                            .scrollDisabled(isDragModeActive)
                            .onAppear {
                                // Initialize to last page if not set
                                if currentPageId == nil {
                                    currentPageId = viewModel.pages.last?.id
                                }
                            }
                        }

                        // Dragged card overlay (follows finger)
                        if isDragging, let pageId = draggedPageId,
                           let page = viewModel.pages.first(where: { $0.id == pageId }) {
                            FlipCardView(page: page)
                                .frame(
                                    width: geometry.size.width * 0.75 * cardDragScale,
                                    height: geometry.size.height * 0.6 * cardDragScale
                                )
                                .opacity(0.9)
                                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                                .offset(dragOffset)
                                .allowsHitTesting(false)
                        }
                    }

                    // CRUD options - only visible when drag mode is active
                    if isDragModeActive {
                        HStack(spacing: 24) {
                            // Edit Button
                            Button {
                                if let pageId = currentPageId {
                                    handleEditPage(pageId: pageId)
                                }
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: isHoveringEdit ? 20 : 17))
                                    .foregroundColor(isHoveringEdit ? .white : .black)
                                    .frame(width: isHoveringEdit ? 56 : 44, height: isHoveringEdit ? 56 : 44)
                                    .background(isHoveringEdit ? Color.blue : Color(.systemGray5))
                                    .clipShape(Circle())
                                    .shadow(color: isHoveringEdit ? .blue.opacity(0.5) : .clear, radius: 8)
                            }
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            editButtonFrame = geo.frame(in: .global)
                                        }
                                        .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                            editButtonFrame = newFrame
                                        }
                                }
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringEdit)

                            // Delete Button
                            Button {
                                if let pageId = currentPageId,
                                   let page = viewModel.pages.first(where: { $0.id == pageId }) {
                                    pageToDelete = page
                                    showDeleteConfirmation = true
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: isHoveringDelete ? 20 : 17))
                                    .foregroundColor(isHoveringDelete ? .white : .black)
                                    .frame(width: isHoveringDelete ? 56 : 44, height: isHoveringDelete ? 56 : 44)
                                    .background(isHoveringDelete ? Color.red : Color(.systemGray5))
                                    .clipShape(Circle())
                                    .shadow(color: isHoveringDelete ? .red.opacity(0.5) : .clear, radius: 8)
                            }
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            deleteButtonFrame = geo.frame(in: .global)
                                        }
                                        .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                            deleteButtonFrame = newFrame
                                        }
                                }
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringDelete)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .transition(.opacity.combined(with: .scale))
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
        .alert("Delete Memory", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                pageToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let page = pageToDelete {
                    Task {
                        await viewModel.deletePage(page)
                    }
                }
                pageToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this memory? This action cannot be undone.")
        }
    }

    // MARK: - Computed Properties

    private var isOnFirstPage: Bool {
        guard let currentId = currentPageId,
              let firstPage = viewModel.pages.first else {
            return false
        }
        return currentId == firstPage.id
    }

    private var isOnLastPage: Bool {
        guard let currentId = currentPageId,
              let lastPage = viewModel.pages.last else {
            return false
        }
        return currentId == lastPage.id
    }

    /// Scale factor for the card while being dragged
    private var cardDragScale: CGFloat {
        let baseDragScale: CGFloat = 0.7
        let hoverScale: CGFloat = 0.5

        if isHoveringEdit || isHoveringDelete {
            return hoverScale
        }
        return baseDragScale
    }

    /// Calculate scale effect for card based on drag/long-press state
    private func cardScaleEffect(isBeingDragged: Bool, isBeingLongPressed: Bool) -> CGFloat {
        if isBeingDragged {
            return cardDragScale
        } else if isBeingLongPressed {
            return 1.05 // Slight scale up during long press
        }
        return 1.0
    }

    // MARK: - Long Press + Drag Gesture

    private func longPressAndDragGesture(for page: Page, in geometry: GeometryProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onChanged { isPressing in
                // Visual feedback during long press
                withAnimation(.easeInOut(duration: 0.1)) {
                    isLongPressing = isPressing
                    longPressPageId = page.id
                }
            }
            .onEnded { _ in
                // Long press completed - activate drag mode
                hapticFeedback.impactOccurred()

                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isDragModeActive = true
                    isLongPressing = false
                    longPressPageId = nil
                    draggedPageId = page.id
                }
            }
            .sequenced(before: DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    guard isDragModeActive else { return }

                    if !isDragging {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isDragging = true
                        }
                    }

                    dragOffset = value.translation

                    // Check if hovering over buttons
                    let dragPoint = value.location

                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHoveringEdit = editButtonFrame.insetBy(dx: -20, dy: -20).contains(dragPoint)
                        isHoveringDelete = deleteButtonFrame.insetBy(dx: -20, dy: -20).contains(dragPoint)
                    }
                }
                .onEnded { value in
                    let dropPoint = value.location

                    // Check if dropped on edit button
                    if editButtonFrame.insetBy(dx: -20, dy: -20).contains(dropPoint) {
                        handleEditPage(pageId: page.id)
                    }

                    // Check if dropped on delete button
                    if deleteButtonFrame.insetBy(dx: -20, dy: -20).contains(dropPoint) {
                        pageToDelete = page
                        showDeleteConfirmation = true
                    }

                    // Reset all drag state
                    resetDragState()
                }
            )
    }

    /// Reset all drag-related state
    private func resetDragState() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isDragModeActive = false
            isDragging = false
            draggedPageId = nil
            dragOffset = .zero
            isHoveringEdit = false
            isHoveringDelete = false
            isLongPressing = false
            longPressPageId = nil
        }
    }

    // MARK: - Actions

    private func handleEditPage(pageId: UUID) {
        // Find the page and set up edit mode
        guard let page = viewModel.pages.first(where: { $0.id == pageId }) else { return }

        // Set the page to edit in the view model
        viewModel.startEditingPage(page)

        // Reset drag state before showing sheet
        resetDragState()

        // Show the add memory sheet in edit mode
        viewModel.showAddMemorySheet = true
    }
}
