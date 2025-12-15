import SwiftUI
import PhotosUI

/// Main canvas editor view for editing book pages
struct CanvasEditorView: View {
    @ObservedObject var viewModel: BookEditorViewModel
    @State private var showingImagePicker = false
    @State private var showingTextToolbar = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    // Swipe gesture state
    @State private var swipeOffset: CGFloat = 0
    @State private var isSwipeActive = false

    // Page turn animation state
    @State private var isAnimatingPageTurn = false
    @State private var pageTurnProgress: Double = 0
    @State private var pageTurnDirection: PageTurnDirection = .forward

    private let swipeThreshold: CGFloat = 100

    /// Whether we're on the last page and can create a new one
    private var isOnLastPage: Bool {
        !viewModel.isEditingCover && viewModel.currentPageIndex == viewModel.pageCount - 1
    }

    /// Whether we can create a new page (on last page or cover with no pages)
    private var canCreateNewPage: Bool {
        isOnLastPage || (viewModel.isEditingCover && viewModel.pageCount == 0)
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = calculateScale(for: geometry.size)
            let canvasWidth = CanvasConstants.virtualSize.width * scale
            let canvasHeight = CanvasConstants.virtualSize.height * scale

            ZStack {
                // Background
                Color(.systemGray6)
                    .ignoresSafeArea()

                // Canvas container with page turn effect
                pageTurnContainer(scale: scale, canvasWidth: canvasWidth, canvasHeight: canvasHeight)

                // New page indicator on right edge
                if canCreateNewPage {
                    NewPageIndicator(swipeOffset: swipeOffset, isSwipeActive: isSwipeActive)
                }

                // Floating toolbar overlay
                VStack {
                    Spacer()

                    if let selectedId = viewModel.selectedElementId,
                       case .text(let textElement) = viewModel.currentElements.first(where: { $0.id == selectedId }) {
                        TextEditingToolbar(
                            textElement: textElement,
                            onUpdate: { updated in
                                viewModel.updateElement(.text(updated))
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    EditorBottomToolbar(
                        onAddText: {
                            let center = CGPoint(
                                x: CanvasConstants.virtualSize.width / 2,
                                y: CanvasConstants.virtualSize.height / 2
                            )
                            viewModel.addTextElement(at: center)
                        },
                        onAddImage: {
                            showingImagePicker = true
                        }
                    )
                }
            }
            .gesture(pageSwipeGesture(in: geometry, canvasWidth: canvasWidth))
        }
        .photosPicker(
            isPresented: $showingImagePicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadImage(from: newItem)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedElementId)
    }

    // MARK: - Page Turn Container

    @ViewBuilder
    private func pageTurnContainer(scale: CGFloat, canvasWidth: CGFloat, canvasHeight: CGFloat) -> some View {
        ZStack {
            // Main canvas with 3D page turn effect
            CanvasContainerView(
                viewModel: viewModel,
                scale: scale
            )
            .frame(width: canvasWidth, height: canvasHeight)
            .background(Color.white)
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            .modifier(PageTurnModifier(
                offset: swipeOffset,
                maxOffset: canvasWidth,
                isAnimating: isAnimatingPageTurn,
                progress: pageTurnProgress,
                direction: pageTurnDirection
            ))
        }
    }

    /// Horizontal swipe gesture for page navigation with page turn effect
    private func pageSwipeGesture(in geometry: GeometryProxy, canvasWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onChanged { value in
                // Only respond to horizontal swipes (not element drags)
                let horizontalAmount = abs(value.translation.width)
                let verticalAmount = abs(value.translation.height)

                // Must be primarily horizontal and no element selected
                if horizontalAmount > verticalAmount && viewModel.selectedElementId == nil && !isAnimatingPageTurn {
                    isSwipeActive = true

                    // Limit swipe offset with resistance at edges
                    let translation = value.translation.width

                    // Prevent swiping right on cover (no previous page)
                    if translation > 0 && !viewModel.canSwipeToPrevious {
                        swipeOffset = translation * 0.3 // Resistance effect
                    } else {
                        // Cap offset at canvas width for realistic page turn
                        swipeOffset = max(-canvasWidth, min(canvasWidth, translation))
                    }
                }
            }
            .onEnded { value in
                guard isSwipeActive else { return }
                isSwipeActive = false

                let translation = value.translation.width

                if translation < -swipeThreshold {
                    // Swiped left (right-to-left) → next page with animation
                    animatePageTurn(direction: .forward) {
                        viewModel.swipeToNextPage()
                    }
                } else if translation > swipeThreshold && viewModel.canSwipeToPrevious {
                    // Swiped right (left-to-right) → previous page with animation
                    animatePageTurn(direction: .backward) {
                        viewModel.swipeToPreviousPage()
                    }
                } else {
                    // Snap back with spring animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        swipeOffset = 0
                    }
                }
            }
    }

    // MARK: - Page Turn Animation

    private func animatePageTurn(direction: PageTurnDirection, completion: @escaping () -> Void) {
        pageTurnDirection = direction
        isAnimatingPageTurn = true

        // Animate page flip
        withAnimation(.easeInOut(duration: 0.35)) {
            pageTurnProgress = 1.0
            swipeOffset = direction == .forward ? -200 : 200
        }

        // Complete the transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            completion()

            // Reset animation state
            withAnimation(.easeOut(duration: 0.15)) {
                pageTurnProgress = 0
                swipeOffset = 0
                isAnimatingPageTurn = false
            }
        }
    }
    
    private func calculateScale(for size: CGSize) -> CGFloat {
        let padding: CGFloat = 40
        let availableWidth = size.width - padding
        let availableHeight = size.height - padding - 100 // Account for toolbar
        
        let scaleX = availableWidth / CanvasConstants.virtualSize.width
        let scaleY = availableHeight / CanvasConstants.virtualSize.height
        
        return min(scaleX, scaleY, 1.0)
    }
    
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        
        let center = CGPoint(
            x: CanvasConstants.virtualSize.width / 2,
            y: CanvasConstants.virtualSize.height / 2
        )
        
        await MainActor.run {
            viewModel.addImageElement(
                imageData: data,
                originalSize: uiImage.size,
                at: center
            )
            selectedPhotoItem = nil
        }
    }
}

/// Container view that holds the actual canvas with elements
struct CanvasContainerView: View {
    @ObservedObject var viewModel: BookEditorViewModel
    let scale: CGFloat
    
    var body: some View {
        ZStack {
            // Page background
            Rectangle()
                .fill(Color.white)
            
            // Canvas elements
            ForEach(viewModel.currentElements.sorted(by: { $0.zIndex < $1.zIndex })) { element in
                CanvasElementWrapperView(
                    element: element,
                    isSelected: viewModel.selectedElementId == element.id,
                    scale: scale,
                    onSelect: {
                        viewModel.selectElement(id: element.id)
                    },
                    onUpdate: { updated in
                        viewModel.updateElement(updated)
                    },
                    onDelete: {
                        viewModel.deleteElement(id: element.id)
                    }
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.deselectAll()
        }
    }
}

// MARK: - Page Turn Direction

enum PageTurnDirection {
    case forward  // Swiping left, going to next page
    case backward // Swiping right, going to previous page
}

// MARK: - Page Turn Modifier

/// A modifier that applies a 3D page-turn effect based on swipe offset
struct PageTurnModifier: ViewModifier {
    let offset: CGFloat
    let maxOffset: CGFloat
    let isAnimating: Bool
    let progress: Double
    let direction: PageTurnDirection

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                rotationAngle,
                axis: (x: 0, y: 1, z: 0),
                anchor: rotationAnchor,
                perspective: 0.5
            )
            .offset(x: translationOffset)
            .scaleEffect(scaleAmount, anchor: scaleAnchor)
            .shadow(color: shadowColor, radius: shadowRadius, x: shadowOffset, y: 0)
    }

    /// Calculate rotation angle based on swipe offset
    private var rotationAngle: Angle {
        let maxAngle: Double = 25 // Maximum rotation degrees
        let normalizedOffset = Double(offset / max(1, maxOffset))

        if isAnimating {
            // During animation, use progress-based rotation
            let targetAngle = direction == .forward ? -maxAngle : maxAngle
            return Angle(degrees: targetAngle * progress * 0.5)
        } else {
            // During drag, rotate proportionally
            return Angle(degrees: -normalizedOffset * maxAngle)
        }
    }

    /// Anchor point for rotation (left edge when going forward, right when going back)
    private var rotationAnchor: UnitPoint {
        if offset < 0 || (isAnimating && direction == .forward) {
            return .leading
        } else {
            return .trailing
        }
    }

    /// Translation offset during swipe
    private var translationOffset: CGFloat {
        if isAnimating {
            return 0
        }
        // Apply a curved translation for more realistic page flip
        return offset * 0.3
    }

    /// Scale effect for depth illusion
    private var scaleAmount: CGFloat {
        let normalizedOffset = abs(offset / max(1, maxOffset))
        let scale = 1.0 - (normalizedOffset * 0.03)
        return max(0.95, scale)
    }

    private var scaleAnchor: UnitPoint {
        offset < 0 ? .trailing : .leading
    }

    /// Shadow properties for depth
    private var shadowColor: Color {
        let normalizedOffset = abs(offset / max(1, maxOffset))
        return Color.black.opacity(0.1 + normalizedOffset * 0.15)
    }

    private var shadowRadius: CGFloat {
        let normalizedOffset = abs(offset / max(1, maxOffset))
        return 10 + normalizedOffset * 15
    }

    private var shadowOffset: CGFloat {
        offset < 0 ? -5 : 5
    }
}

// MARK: - New Page Indicator

/// Visual indicator shown on the right edge when user can create a new page
struct NewPageIndicator: View {
    let swipeOffset: CGFloat
    let isSwipeActive: Bool

    @State private var isPulsing = false

    /// How much the indicator is "activated" based on swipe progress
    private var activationProgress: CGFloat {
        guard swipeOffset < 0 else { return 0 }
        return min(1.0, abs(swipeOffset) / 100)
    }

    var body: some View {
        HStack {
            Spacer()

            VStack(spacing: 8) {
                // Plus icon
                ZStack {
                    // Glow effect when activated
                    Circle()
                        .fill(Color.blue.opacity(0.2 * activationProgress))
                        .frame(width: 60, height: 60)
                        .blur(radius: 10)

                    // Main indicator circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.7 + activationProgress * 0.3),
                                    Color.blue.opacity(0.5 + activationProgress * 0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .scaleEffect(isPulsing ? 1.1 : 1.0)
                        .scaleEffect(1.0 + activationProgress * 0.2)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)

                    // Plus icon
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .scaleEffect(1.0 + activationProgress * 0.1)
                }

                // "New Page" label
                Text("New Page")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
                    .opacity(0.6 + activationProgress * 0.4)
            }
            .offset(x: isSwipeActive ? -10 - activationProgress * 20 : 20)
            .opacity(isSwipeActive ? 0.9 + activationProgress * 0.1 : 0.6)
            .padding(.trailing, 8)
        }
        .onAppear {
            startPulseAnimation()
        }
    }

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            isPulsing = true
        }
    }
}

