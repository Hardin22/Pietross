import SwiftUI
import PhotosUI
import PencilKit

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

    // Drawing mode state
    @State private var isDrawingMode = false
    @State private var currentDrawing = PKDrawing()

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
                    // Drawing mode toolbar at TOP (above PKToolPicker which appears at bottom)
                    if isDrawingMode {
                        DrawingModeToolbar(
                            onDone: {
                                // Save the drawing as an element
                                if !currentDrawing.bounds.isEmpty {
                                    let drawingData = currentDrawing.dataRepresentation()
                                    let center = CGPoint(
                                        x: CanvasConstants.virtualSize.width / 2,
                                        y: CanvasConstants.virtualSize.height / 2
                                    )
                                    let bounds = currentDrawing.bounds
                                    viewModel.addDrawingElement(
                                        at: center,
                                        size: CGSize(width: bounds.width, height: bounds.height)
                                    )
                                    // Update the drawing data
                                    if let lastElement = viewModel.currentElements.last,
                                       case .drawing = lastElement {
                                        viewModel.updateDrawingData(lastElement.id, drawingData: drawingData)
                                    }
                                }
                                currentDrawing = PKDrawing()
                                isDrawingMode = false
                            },
                            onCancel: {
                                currentDrawing = PKDrawing()
                                isDrawingMode = false
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100) // Ensure toolbar is above drawing canvas
                    }

                    Spacer()

                    if !isDrawingMode {
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
                            onAddDrawing: {
                                isDrawingMode = true
                                viewModel.deselectAll()
                            },
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
                scale: scale,
                isDrawingMode: isDrawingMode,
                drawing: $currentDrawing
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
    let isDrawingMode: Bool
    @Binding var drawing: PKDrawing

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
                    isEditing: viewModel.editingTextElementId == element.id,
                    scale: scale,
                    onSelect: {
                        viewModel.selectElement(id: element.id)
                    },
                    onUpdate: { updated in
                        viewModel.updateElement(updated)
                    },
                    onDelete: {
                        viewModel.deleteElement(id: element.id)
                    },
                    onStartEditing: {
                        viewModel.editingTextElementId = element.id
                    },
                    onStopEditing: {
                        viewModel.stopEditingText()
                    }
                )
            }

            // Drawing overlay (when in drawing mode)
            if isDrawingMode {
                DrawingCanvasView(drawing: $drawing)
                    .allowsHitTesting(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDrawingMode {
                viewModel.stopEditingText()
                viewModel.deselectAll()
            }
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

// MARK: - Drawing Canvas View (PencilKit)

/// UIViewRepresentable wrapper for PKCanvasView
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawing = drawing
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .anyInput // Allows finger and Apple Pencil

        // Set up the tool picker
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        // Store tool picker in coordinator to keep it alive
        context.coordinator.toolPicker = toolPicker

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Only update if the drawing is different (to avoid loops)
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvasView
        var toolPicker: PKToolPicker?

        init(_ parent: DrawingCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

// MARK: - Drawing Mode Toolbar

/// Toolbar shown when in drawing mode (positioned at top of screen)
struct DrawingModeToolbar: View {
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack {
            Button(action: onCancel) {
                Text("Cancel")
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            Spacer()

            Text("Drawing")
                .font(.headline)

            Spacer()

            Button(action: onDone) {
                Text("Done")
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            Color(.systemBackground)
                .opacity(0.95)
        )
        .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .padding(.horizontal, 16)
    }
}

