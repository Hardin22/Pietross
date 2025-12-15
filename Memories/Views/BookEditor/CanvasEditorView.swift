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

    private let swipeThreshold: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            let scale = calculateScale(for: geometry.size)

            ZStack {
                // Background
                Color(.systemGray6)
                    .ignoresSafeArea()

                // Canvas container with scaling and swipe offset
                CanvasContainerView(
                    viewModel: viewModel,
                    scale: scale
                )
                .frame(
                    width: CanvasConstants.virtualSize.width * scale,
                    height: CanvasConstants.virtualSize.height * scale
                )
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                .offset(x: swipeOffset)

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
            .gesture(pageSwipeGesture(in: geometry))
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swipeOffset)
    }

    /// Horizontal swipe gesture for page navigation
    private func pageSwipeGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onChanged { value in
                // Only respond to horizontal swipes (not element drags)
                let horizontalAmount = abs(value.translation.width)
                let verticalAmount = abs(value.translation.height)

                // Must be primarily horizontal and no element selected
                if horizontalAmount > verticalAmount && viewModel.selectedElementId == nil {
                    isSwipeActive = true

                    // Limit swipe offset with resistance at edges
                    let translation = value.translation.width

                    // Prevent swiping right on cover (no previous page)
                    if translation > 0 && !viewModel.canSwipeToPrevious {
                        swipeOffset = translation * 0.3 // Resistance effect
                    } else {
                        swipeOffset = translation
                    }
                }
            }
            .onEnded { value in
                guard isSwipeActive else { return }
                isSwipeActive = false

                let translation = value.translation.width

                if translation < -swipeThreshold {
                    // Swiped left (right-to-left) → next page
                    viewModel.swipeToNextPage()
                } else if translation > swipeThreshold && viewModel.canSwipeToPrevious {
                    // Swiped right (left-to-right) → previous page
                    viewModel.swipeToPreviousPage()
                }

                // Reset offset with animation
                swipeOffset = 0
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

