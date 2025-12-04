import Foundation
import UIKit
import Combine
import PencilKit

class EditorViewModel {
    
    var onDataLoaded: (() -> Void)?
    @Published var pageData: PageData
    @Published var recipient: Profile? // If set, we are in "Letter Mode"
    @Published var isSending: Bool = false
    
    init(pageData: PageData, recipient: Profile? = nil) {
        self.pageData = pageData
        self.recipient = recipient
    }
    
    func sendLetter(imageData: Data) async throws {
        guard let recipient = recipient else { return }
        
        await MainActor.run { self.isSending = true }
        defer { Task { await MainActor.run { self.isSending = false } } }
        
        try await SocialService.shared.sendLetter(recipientId: recipient.id, imageData: imageData)
    }
    
    func updateBodyText(_ text: String) {
        pageData.bodyText = text
    }
    
    func updateAttributedBodyText(_ attributedString: NSAttributedString) {
        do {
            let data = try attributedString.data(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            pageData.attributedBodyText = data
        } catch {
            print("Error saving attributed text: \(error)")
        }
    }
    
    func updateBackgroundColor(_ color: UIColor) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
            pageData.backgroundColorData = data
        } catch {
            print("Error saving background color: \(error)")
        }
    }
    
    func getAttributedBodyText() -> NSAttributedString? {
        guard let data = pageData.attributedBodyText else { return nil }
        do {
            return try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        } catch {
            print("Error loading attributed text: \(error)")
            return nil
        }
    }
    
    func getBackgroundColor() -> UIColor {
        guard let data = pageData.backgroundColorData else { return .white }
        do {
            if let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) {
                return color
            }
        } catch {
            print("Error loading background color: \(error)")
        }
        return .white
    }
    
    func updateBackgroundImageName(_ name: String?) {
        pageData.backgroundImageName = name
    }
    
    func getBackgroundImageName() -> String? {
        return pageData.backgroundImageName
    }
    
    func addImage(imageData: Data, imageSize: CGSize, center: CGPoint) {
        let size = CGSize(width: 250, height: 250 * (imageSize.height / imageSize.width))
        let frame = CGRect(origin: CGPoint(x: center.x - size.width/2, y: center.y - size.height/2), size: size)
        
        let newItem = CanvasItem(id: UUID(), frame: frame, rotation: 0, type: .image, imageData: imageData, textContent: nil)
        pageData.items.append(newItem)
        onDataLoaded?()
    }
    
    // addText removed as we are using bodyText now
    
    func updateItem(id: UUID, frame: CGRect, rotation: CGFloat) {
        if let index = pageData.items.firstIndex(where: { $0.id == id }) {
            pageData.items[index].frame = frame
            pageData.items[index].rotation = rotation
        }
    }
    
    func removeItem(id: UUID) {
        pageData.items.removeAll(where: { $0.id == id })
        onDataLoaded?()
    }
    
    // saveDrawing removed as per user request
    
    func restoreDrawing() -> PKDrawing? {
        try? PKDrawing(data: pageData.drawingData)
    }
}
