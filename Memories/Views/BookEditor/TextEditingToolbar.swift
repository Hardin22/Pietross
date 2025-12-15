import SwiftUI

/// Contextual toolbar for editing text element properties
struct TextEditingToolbar: View {
    let textElement: TextElement
    let onUpdate: (TextElement) -> Void
    
    @State private var showingFontPicker = false
    @State private var showingColorPicker = false
    @State private var editedText: String = ""
    @State private var isEditingText = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Text content editor
            if isEditingText {
                HStack {
                    TextField("Enter text", text: $editedText)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit {
                            var updated = textElement
                            updated.content = editedText
                            onUpdate(updated)
                            isEditingText = false
                        }
                    
                    Button("Done") {
                        var updated = textElement
                        updated.content = editedText
                        onUpdate(updated)
                        isEditingText = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            // Formatting toolbar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Edit text button
                    Button(action: {
                        editedText = textElement.content
                        isEditingText.toggle()
                    }) {
                        Image(systemName: "pencil")
                            .toolbarButtonStyle(isActive: isEditingText)
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    // Font size controls
                    HStack(spacing: 8) {
                        Button(action: {
                            var updated = textElement
                            updated.fontSize = max(8, textElement.fontSize - 2)
                            onUpdate(updated)
                        }) {
                            Image(systemName: "textformat.size.smaller")
                                .toolbarButtonStyle()
                        }
                        
                        Text("\(Int(textElement.fontSize))")
                            .font(.caption)
                            .frame(width: 30)
                        
                        Button(action: {
                            var updated = textElement
                            updated.fontSize = min(72, textElement.fontSize + 2)
                            onUpdate(updated)
                        }) {
                            Image(systemName: "textformat.size.larger")
                                .toolbarButtonStyle()
                        }
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    // Text style buttons
                    Button(action: {
                        var updated = textElement
                        updated.isBold.toggle()
                        onUpdate(updated)
                    }) {
                        Image(systemName: "bold")
                            .toolbarButtonStyle(isActive: textElement.isBold)
                    }
                    
                    Button(action: {
                        var updated = textElement
                        updated.isItalic.toggle()
                        onUpdate(updated)
                    }) {
                        Image(systemName: "italic")
                            .toolbarButtonStyle(isActive: textElement.isItalic)
                    }
                    
                    Button(action: {
                        var updated = textElement
                        updated.isUnderlined.toggle()
                        onUpdate(updated)
                    }) {
                        Image(systemName: "underline")
                            .toolbarButtonStyle(isActive: textElement.isUnderlined)
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    // Alignment buttons
                    ForEach(TextAlignmentType.allCases, id: \.self) { alignment in
                        Button(action: {
                            var updated = textElement
                            updated.textAlignment = alignment
                            onUpdate(updated)
                        }) {
                            Image(systemName: alignmentIcon(for: alignment))
                                .toolbarButtonStyle(isActive: textElement.textAlignment == alignment)
                        }
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    // Color picker
                    ColorPicker("", selection: colorBinding)
                        .labelsHidden()
                        .frame(width: 30, height: 30)
                }
                .padding(.horizontal)
            }
            .frame(height: 50)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 5, y: -2)
    }
    
    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: textElement.textColor) },
            set: { newColor in
                var updated = textElement
                updated.textColor = newColor.toHex()
                onUpdate(updated)
            }
        )
    }
    
    private func alignmentIcon(for alignment: TextAlignmentType) -> String {
        switch alignment {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        }
    }
}

// MARK: - Toolbar Button Style

extension View {
    func toolbarButtonStyle(isActive: Bool = false) -> some View {
        self
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(isActive ? .blue : .primary)
            .frame(width: 36, height: 36)
            .background(isActive ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Bottom Toolbar

/// Bottom toolbar with add drawing/text/image buttons (Freeform-style)
struct EditorBottomToolbar: View {
    let onAddDrawing: () -> Void
    let onAddText: () -> Void
    let onAddImage: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            // Drawing button (Apple Pencil support)
            Button(action: onAddDrawing) {
                VStack(spacing: 4) {
                    Image(systemName: "pencil.tip.crop.circle")
                        .font(.system(size: 22))
                    Text("Draw")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
            }

            // Text button
            Button(action: onAddText) {
                VStack(spacing: 4) {
                    Image(systemName: "textformat")
                        .font(.system(size: 22))
                    Text("Text")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
            }

            // Image button
            Button(action: onAddImage) {
                VStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                    Text("Image")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        .padding(.bottom, 8)
    }
}

