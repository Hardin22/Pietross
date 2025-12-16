import PencilKit
import SwiftUI

/// Corner positions for resize handles
enum ResizeCorner {
    case topLeft, topRight, bottomLeft, bottomRight
}

/// Wrapper view for canvas elements with gesture handling and Freeform-style resize handles
struct CanvasElementWrapperView: View {
    let element: PageElement
    let isSelected: Bool
    let isEditing: Bool  // Whether this text element is in edit mode
    let scale: CGFloat
    let onSelect: () -> Void
    let onUpdate: (PageElement) -> Void
    let onDelete: () -> Void
    let onStartEditing: () -> Void
    let onStopEditing: () -> Void

    // Gesture state for element dragging
    @State private var dragOffset: CGSize = .zero
    @State private var currentRotation: Angle = .zero
    @State private var lastRotation: Angle = .zero

    // Resize state
    @State private var isResizing: Bool = false
    @State private var resizeStartSize: CGSize = .zero
    @State private var resizeStartPosition: CGPoint = .zero

    // Focus state for text editing
    @FocusState private var isTextFieldFocused: Bool

    private let handleSize: CGFloat = 24
    private let handleVisualSize: CGFloat = 12

    var body: some View {
        elementContent
            .frame(width: element.size.width * scale, height: element.size.height * scale)
            .contentShape(Rectangle())
            .rotationEffect(Angle(radians: element.rotation) + currentRotation)
            .overlay(selectionOverlay)
            .position(
                x: element.position.x * scale + dragOffset.width,
                y: element.position.y * scale + dragOffset.height
            )
            .gesture(isResizing || isEditing ? nil : combinedGesture)
            .onTapGesture {
                if case .text = element, isSelected {
                    onStartEditing()
                } else {
                    onSelect()
                }
            }
            .onChange(of: isEditing) { _, newValue in
                if newValue {
                    // Auto-focus the text field when entering edit mode
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextFieldFocused = true
                    }
                }
            }
    }

    @ViewBuilder
    private var elementContent: some View {
        switch element {
        case .text(let textElement):
            if isEditing {
                EditableTextElementView(
                    element: textElement,
                    isFocused: $isTextFieldFocused,
                    onUpdate: { updatedText in
                        var updated = textElement
                        updated.content = updatedText
                        onUpdate(.text(updated))
                    },
                    onCommit: {
                        onStopEditing()
                    }
                )
            } else {
                TextElementView(element: textElement)
            }
        case .image(let imageElement):
            ImageElementView(element: imageElement)
        case .drawing(let drawingElement):
            DrawingElementView(element: drawingElement)
        }
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected {
            let width = element.size.width * scale
            let height = element.size.height * scale

            ZStack {
                // Selection border
                Rectangle()
                    .strokeBorder(Color.blue, lineWidth: 2)
                    .frame(width: width, height: height)

                // Delete button (top-left, outside the element)
                deleteButton
                    .position(x: 0, y: 0)

                // Resize handles at all four corners
                resizeHandleView(corner: .topLeft)
                    .position(x: 0, y: 0)

                resizeHandleView(corner: .topRight)
                    .position(x: width, y: 0)

                resizeHandleView(corner: .bottomLeft)
                    .position(x: 0, y: height)

                resizeHandleView(corner: .bottomRight)
                    .position(x: width, y: height)
            }
            .frame(width: width, height: height)
        }
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Color.red)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
        .offset(x: -16, y: -16)
    }

    @ViewBuilder
    private func resizeHandleView(corner: ResizeCorner) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleVisualSize, height: handleVisualSize)
            .overlay(
                Circle()
                    .strokeBorder(Color.blue, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .frame(width: handleSize, height: handleSize)  // Larger hit area
            .contentShape(Circle().scale(2))  // Even larger touch target
            .gesture(resizeGesture(for: corner))
    }

    private func resizeGesture(for corner: ResizeCorner) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !isResizing {
                    isResizing = true
                    resizeStartSize = element.size
                    resizeStartPosition = element.position
                }

                let translation = value.translation

                // Calculate new size based on corner being dragged
                var newWidth = resizeStartSize.width
                var newHeight = resizeStartSize.height
                var newPosition = resizeStartPosition

                // Convert translation from screen to virtual coordinates
                let deltaX = translation.width / scale
                let deltaY = translation.height / scale

                switch corner {
                case .bottomRight:
                    newWidth = max(CanvasConstants.minElementSize, resizeStartSize.width + deltaX)
                    newHeight = max(CanvasConstants.minElementSize, resizeStartSize.height + deltaY)

                case .bottomLeft:
                    let widthChange = deltaX
                    newWidth = max(
                        CanvasConstants.minElementSize, resizeStartSize.width - widthChange)
                    newHeight = max(CanvasConstants.minElementSize, resizeStartSize.height + deltaY)
                    // Adjust position to keep right edge fixed
                    if newWidth > CanvasConstants.minElementSize {
                        newPosition.x = resizeStartPosition.x + widthChange / 2
                    }

                case .topRight:
                    newWidth = max(CanvasConstants.minElementSize, resizeStartSize.width + deltaX)
                    let heightChange = deltaY
                    newHeight = max(
                        CanvasConstants.minElementSize, resizeStartSize.height - heightChange)
                    // Adjust position to keep bottom edge fixed
                    if newHeight > CanvasConstants.minElementSize {
                        newPosition.y = resizeStartPosition.y + heightChange / 2
                    }

                case .topLeft:
                    let widthChange = deltaX
                    let heightChange = deltaY
                    newWidth = max(
                        CanvasConstants.minElementSize, resizeStartSize.width - widthChange)
                    newHeight = max(
                        CanvasConstants.minElementSize, resizeStartSize.height - heightChange)
                    // Adjust position to keep bottom-right edge fixed
                    if newWidth > CanvasConstants.minElementSize {
                        newPosition.x = resizeStartPosition.x + widthChange / 2
                    }
                    if newHeight > CanvasConstants.minElementSize {
                        newPosition.y = resizeStartPosition.y + heightChange / 2
                    }
                }

                // Maintain aspect ratio for images
                if case .image(let imageElement) = element {
                    let aspectRatio = imageElement.aspectRatio
                    // Use the larger dimension change to maintain aspect ratio
                    let widthRatio = newWidth / resizeStartSize.width
                    let heightRatio = newHeight / resizeStartSize.height

                    if abs(widthRatio - 1) > abs(heightRatio - 1) {
                        newHeight = newWidth / aspectRatio
                    } else {
                        newWidth = newHeight * aspectRatio
                    }

                    // Re-clamp after aspect ratio adjustment
                    newWidth = max(CanvasConstants.minElementSize, newWidth)
                    newHeight = max(CanvasConstants.minElementSize, newHeight)
                }

                var updated = element
                updated.size = CGSize(width: newWidth, height: newHeight)
                updated.position = newPosition
                onUpdate(updated)
            }
            .onEnded { _ in
                isResizing = false
            }
    }

    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            dragGesture,
            rotationGesture
        )
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isSelected {
                    onSelect()
                }
                dragOffset = value.translation
            }
            .onEnded { value in
                var updated = element
                updated.position = CGPoint(
                    x: element.position.x + value.translation.width / scale,
                    y: element.position.y + value.translation.height / scale
                )
                onUpdate(updated)
                dragOffset = .zero
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                if !isSelected {
                    onSelect()
                }
                currentRotation = value - lastRotation
            }
            .onEnded { value in
                var updated = element
                updated.rotation = element.rotation + currentRotation.radians
                onUpdate(updated)

                lastRotation = value
                currentRotation = .zero
            }
    }
}

/// View for displaying text elements with text wrapping support
struct TextElementView: View {
    let element: TextElement

    var body: some View {
        Text(element.content.isEmpty ? "Tap to edit" : element.content)
            .font(computedFont)
            .foregroundColor(
                element.content.isEmpty ? Color.gray.opacity(0.5) : Color(hex: element.textColor)
            )
            .underline(element.isUnderlined)
            .multilineTextAlignment(element.textAlignment.alignment)
            .lineSpacing((element.lineHeight - 1.0) * element.fontSize)
            .lineLimit(nil) // Allow unlimited lines for text wrapping
            .fixedSize(horizontal: false, vertical: false) // Allow text to wrap and expand
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignmentFromTextAlignment)
    }

    private var computedFont: Font {
        var font: Font
        if element.fontFamily == "System" {
            font = .system(size: element.fontSize)
        } else {
            font = Font.custom(element.fontFamily, size: element.fontSize)
        }
        if element.isBold {
            font = font.bold()
        }
        if element.isItalic {
            font = font.italic()
        }
        return font
    }

    private var alignmentFromTextAlignment: Alignment {
        switch element.textAlignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        case .justify: return .leading
        }
    }
}

/// Editable text field view for editing text elements
struct EditableTextElementView: View {
    let element: TextElement
    var isFocused: FocusState<Bool>.Binding
    let onUpdate: (String) -> Void
    let onCommit: () -> Void

    @State private var editingText: String = ""

    var body: some View {
        TextField("Enter text...", text: $editingText, axis: .vertical)
            .font(computedFont)
            .foregroundColor(Color(hex: element.textColor))
            .underline(element.isUnderlined)
            .multilineTextAlignment(element.textAlignment.alignment)
            .lineSpacing((element.lineHeight - 1.0) * element.fontSize)
            .lineLimit(nil)
            .focused(isFocused)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignmentFromTextAlignment)
            .padding(4)
            .background(Color.white.opacity(0.9))
            .onAppear {
                editingText = element.content
            }
            .onChange(of: editingText) { _, newValue in
                onUpdate(newValue)
            }
            .onSubmit {
                onCommit()
            }
    }

    private var computedFont: Font {
        var font: Font
        if element.fontFamily == "System" {
            font = .system(size: element.fontSize)
        } else {
            font = Font.custom(element.fontFamily, size: element.fontSize)
        }
        if element.isBold {
            font = font.bold()
        }
        if element.isItalic {
            font = font.italic()
        }
        return font
    }

    private var alignmentFromTextAlignment: Alignment {
        switch element.textAlignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        case .justify: return .leading
        }
    }
}

/// View for displaying image elements
struct ImageElementView: View {
    let element: ImageElement

    var body: some View {
        if let uiImage = UIImage(data: element.imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay {
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                }
        }
    }
}

/// View for displaying drawing elements (renders PKDrawing as an image)
struct DrawingElementView: View {
    let element: DrawingElement

    var body: some View {
        if let drawing = try? PKDrawing(data: element.drawingData) {
            // Render the drawing as an image
            let image = drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Empty drawing placeholder
            Rectangle()
                .fill(Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundColor(.gray.opacity(0.5))
                }
        }
    }
}
