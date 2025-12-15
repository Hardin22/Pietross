import SwiftUI
import PhotosUI

/// Main canvas editor view for editing book pages
struct CanvasEditorView: View {
    @ObservedObject var viewModel: BookEditorViewModel
    @State private var showingImagePicker = false
    @State private var showingTextToolbar = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        GeometryReader { geometry in
            let scale = calculateScale(for: geometry.size)
            
            ZStack {
                // Background
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                // Canvas container with scaling
                CanvasContainerView(
                    viewModel: viewModel,
                    scale: scale
                )
                .frame(
                    width: CanvasConstants.virtualSize.width * scale,
                    height: CanvasConstants.virtualSize.height * scale
                )
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                
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

