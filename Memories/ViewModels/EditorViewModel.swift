import Foundation
import UIKit
import PencilKit

class EditorViewModel {
    
    var onDataLoaded: (() -> Void)?
    private(set) var pageData: PageData
    
    init() {
        self.pageData = PageData(id: UUID(), drawingData: Data(), items: [])
    }
    
    func addImage(_ image: UIImage, center: CGPoint) {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else { return }
        let size = CGSize(width: 250, height: 250 * (image.size.height / image.size.width))
        let frame = CGRect(origin: CGPoint(x: center.x - size.width/2, y: center.y - size.height/2), size: size)
        
        let newItem = CanvasItem(id: UUID(), frame: frame, rotation: 0, type: .image, imageData: jpegData, textContent: nil)
        pageData.items.append(newItem)
        onDataLoaded?()
    }
    
    func addText(_ text: String, center: CGPoint) {
        let size = CGSize(width: 300, height: 100)
        let frame = CGRect(origin: CGPoint(x: center.x - size.width/2, y: center.y - size.height/2), size: size)
        
        let newItem = CanvasItem(id: UUID(), frame: frame, rotation: 0, type: .text, imageData: nil, textContent: text)
        pageData.items.append(newItem)
        onDataLoaded?()
    }
    
    func updateItem(id: UUID, frame: CGRect, rotation: CGFloat) {
        if let index = pageData.items.firstIndex(where: { $0.id == id }) {
            pageData.items[index].frame = frame
            pageData.items[index].rotation = rotation
        }
    }
    
    func updateTextContent(id: UUID, newText: String) {
        if let index = pageData.items.firstIndex(where: { $0.id == id }) {
            pageData.items[index].textContent = newText
        }
    }
    
    func saveDrawing(_ drawing: PKDrawing) {
        pageData.drawingData = drawing.dataRepresentation()
        // Qui ci andrà il salvataggio su Supabase in futuro
        print("Salvataggio locale completato. Items: \(pageData.items.count)")
    }
    
    func restoreDrawing() -> PKDrawing? {
        try? PKDrawing(data: pageData.drawingData)
    }
}
