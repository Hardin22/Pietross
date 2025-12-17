import SwiftUI
import UIKit

struct StickerInputView: UIViewRepresentable {
    @Binding var isFirstResponder: Bool
    var onStickerSelected: (UIImage) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.allowsEditingTextAttributes = true  // Enable rich content (stickers)
        textView.isEditable = true
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.returnKeyType = .done

        // Hide the text view but keep it functional
        textView.tintColor = .clear
        textView.textColor = .clear

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if isFirstResponder {
            uiView.becomeFirstResponder()
        } else {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: StickerInputView

        init(_ parent: StickerInputView) {
            self.parent = parent
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            DispatchQueue.main.async {
                self.parent.isFirstResponder = false
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            // Check for attachments in the attributed text
            textView.attributedText.enumerateAttribute(
                .attachment, in: NSRange(location: 0, length: textView.attributedText.length),
                options: []
            ) { (value, range, stop) in
                if let attachment = value as? NSTextAttachment {
                    if let image = attachment.image {
                        // Found an image attachment (sticker)
                        parent.onStickerSelected(image)
                        parent.isFirstResponder = false  // Dismiss keyboard
                        textView.text = ""  // Clear text
                        stop.pointee = true
                    } else if let fileWrapper = attachment.fileWrapper,
                        let data = fileWrapper.regularFileContents,
                        let image = UIImage(data: data)
                    {
                        // Found a file wrapper attachment (some stickers)
                        parent.onStickerSelected(image)
                        parent.isFirstResponder = false
                        textView.text = ""
                        stop.pointee = true
                    }
                }
            }
        }

        func textView(
            _ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String
        ) -> Bool {
            if text == "\n" {
                parent.isFirstResponder = false
                return false
            }
            return true
        }
    }
}
