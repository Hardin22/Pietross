import Foundation
import UIKit

// MARK: - Data Models

struct PageData: Codable {
    let id: UUID
    var drawingData: Data
    var items: [CanvasItem]
    var bodyText: String = ""
    var attributedBodyText: Data? // RTF Data for rich text
    var backgroundColorData: Data? // Encoded UIColor
    var backgroundImageName: String? // Name of the asset for background template
    
    // Dimensioni virtuali fisse per garantire consistenza tra dispositivi
    static let virtualSize = CGSize(width: 1000, height: 1400)
}

struct CanvasItem: Codable, Identifiable {
    let id: UUID
    var frame: CGRect // Coordinate nello spazio virtuale
    var rotation: CGFloat
    let type: ItemType
    
    // Contenuto (Immagine o Testo)
    let imageData: Data?
    var textContent: String?
    
    enum ItemType: String, Codable {
        case image
        case text
    }
}
