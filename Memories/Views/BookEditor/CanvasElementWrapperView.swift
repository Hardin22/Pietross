import SwiftUI

/// Wrapper view for canvas elements with gesture handling
struct CanvasElementWrapperView: View {
    let element: PageElement
    let isSelected: Bool
    let scale: CGFloat
    let onSelect: () -> Void
    let onUpdate: (PageElement) -> Void
    let onDelete: () -> Void
    
    // Gesture state
    @State private var dragOffset: CGSize = .zero
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var currentRotation: Angle = .zero
    @State private var lastRotation: Angle = .zero
    
    var body: some View {
        elementContent
            .frame(width: element.size.width, height: element.size.height)
            .rotationEffect(Angle(radians: element.rotation) + currentRotation)
            .scaleEffect(currentScale)
            .position(
                x: element.position.x + dragOffset.width / scale,
                y: element.position.y + dragOffset.height / scale
            )
            .overlay(selectionOverlay)
            .gesture(combinedGesture)
            .onTapGesture {
                onSelect()
            }
    }
    
    @ViewBuilder
    private var elementContent: some View {
        switch element {
        case .text(let textElement):
            TextElementView(element: textElement)
        case .image(let imageElement):
            ImageElementView(element: imageElement)
        }
    }
    
    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected {
            Rectangle()
                .strokeBorder(Color.blue, lineWidth: 2 / scale)
                .frame(width: element.size.width * currentScale, height: element.size.height * currentScale)
                .overlay(alignment: .topLeading) {
                    deleteButton
                }
                .overlay(alignment: .bottomTrailing) {
                    resizeHandle
                }
        }
    }
    
    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.red)
                .clipShape(Circle())
        }
        .offset(x: -14, y: -14)
    }
    
    private var resizeHandle: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 20, height: 20)
            .offset(x: 10, y: 10)
    }
    
    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            dragGesture,
            SimultaneousGesture(magnificationGesture, rotationGesture)
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
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if !isSelected {
                    onSelect()
                }
                currentScale = lastScale * value
            }
            .onEnded { value in
                lastScale = currentScale
                let newWidth = max(CanvasConstants.minElementSize, element.size.width * currentScale)
                let newHeight = max(CanvasConstants.minElementSize, element.size.height * currentScale)
                
                var updated = element
                updated.size = CGSize(width: newWidth, height: newHeight)
                onUpdate(updated)
                
                currentScale = 1.0
                lastScale = 1.0
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

/// View for displaying text elements
struct TextElementView: View {
    let element: TextElement
    
    var body: some View {
        Text(element.content)
            .font(computedFont)
            .foregroundColor(Color(hex: element.textColor))
            .underline(element.isUnderlined)
            .multilineTextAlignment(element.textAlignment.alignment)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignmentFromTextAlignment)
    }
    
    private var computedFont: Font {
        var font = Font.custom(element.fontFamily, size: element.fontSize)
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

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }

        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

