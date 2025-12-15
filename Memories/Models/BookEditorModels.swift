import Foundation
import SwiftUI
import SwiftData

// MARK: - SwiftData Models for Local Book Persistence

/// Represents a user-created book with multiple pages
@Model
final class LocalBook {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    
    /// Cover page data stored as JSON
    var coverData: Data?
    
    /// Ordered pages in the book
    @Relationship(deleteRule: .cascade, inverse: \LocalPage.book)
    var pages: [LocalPage] = []
    
    init(id: UUID = UUID(), title: String = "Untitled Book") {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var sortedPages: [LocalPage] {
        pages.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    var coverElements: [PageElement] {
        get {
            guard let data = coverData else { return [] }
            return (try? JSONDecoder().decode([PageElement].self, from: data)) ?? []
        }
        set {
            coverData = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
}

/// Represents a single page within a book
@Model
final class LocalPage {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var createdAt: Date
    var updatedAt: Date
    
    /// Page elements stored as JSON
    var elementsData: Data?
    
    /// Background color stored as hex string
    var backgroundColorHex: String?
    
    /// Background image data (if using custom image)
    var backgroundImageData: Data?
    
    var book: LocalBook?
    
    init(id: UUID = UUID(), orderIndex: Int = 0) {
        self.id = id
        self.orderIndex = orderIndex
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var elements: [PageElement] {
        get {
            guard let data = elementsData else { return [] }
            return (try? JSONDecoder().decode([PageElement].self, from: data)) ?? []
        }
        set {
            elementsData = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
}

// MARK: - Page Element Types (Codable for JSON storage)

/// Protocol for all canvas elements
protocol CanvasElement: Codable, Identifiable {
    var id: UUID { get }
    var position: CGPoint { get set }
    var size: CGSize { get set }
    var rotation: Double { get set }
    var zIndex: Int { get set }
}

/// Represents a text block on the canvas
struct TextElement: CanvasElement, Codable, Identifiable {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: Double
    var zIndex: Int
    
    // Text-specific properties
    var content: String
    var fontFamily: String
    var fontSize: CGFloat
    var fontWeight: FontWeightType
    var textColor: String // Hex color
    var isBold: Bool
    var isItalic: Bool
    var isUnderlined: Bool
    var textAlignment: TextAlignmentType
    
    init(
        id: UUID = UUID(),
        position: CGPoint = .zero,
        size: CGSize = CGSize(width: 200, height: 50),
        content: String = "New Text"
    ) {
        self.id = id
        self.position = position
        self.size = size
        self.rotation = 0
        self.zIndex = 0
        self.content = content
        self.fontFamily = "System"
        self.fontSize = 18
        self.fontWeight = .regular
        self.textColor = "#000000"
        self.isBold = false
        self.isItalic = false
        self.isUnderlined = false
        self.textAlignment = .left
    }
}

/// Represents an image on the canvas
struct ImageElement: CanvasElement, Codable, Identifiable {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: Double
    var zIndex: Int

    // Image-specific properties
    var imageData: Data
    var aspectRatio: CGFloat

    init(
        id: UUID = UUID(),
        position: CGPoint = .zero,
        imageData: Data,
        originalSize: CGSize
    ) {
        self.id = id
        self.position = position
        self.imageData = imageData
        self.aspectRatio = originalSize.width / originalSize.height
        self.size = CGSize(width: 200, height: 200 / aspectRatio)
        self.rotation = 0
        self.zIndex = 0
    }
}

// MARK: - Supporting Types

enum FontWeightType: String, Codable, CaseIterable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

    var fontWeight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

enum TextAlignmentType: String, Codable, CaseIterable {
    case left, center, right

    var alignment: TextAlignment {
        switch self {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}

/// Unified page element wrapper for polymorphic storage
enum PageElement: Codable, Identifiable {
    case text(TextElement)
    case image(ImageElement)

    var id: UUID {
        switch self {
        case .text(let element): return element.id
        case .image(let element): return element.id
        }
    }

    var position: CGPoint {
        get {
            switch self {
            case .text(let e): return e.position
            case .image(let e): return e.position
            }
        }
        set {
            switch self {
            case .text(var e):
                e.position = newValue
                self = .text(e)
            case .image(var e):
                e.position = newValue
                self = .image(e)
            }
        }
    }

    var size: CGSize {
        get {
            switch self {
            case .text(let e): return e.size
            case .image(let e): return e.size
            }
        }
        set {
            switch self {
            case .text(var e):
                e.size = newValue
                self = .text(e)
            case .image(var e):
                e.size = newValue
                self = .image(e)
            }
        }
    }

    var rotation: Double {
        get {
            switch self {
            case .text(let e): return e.rotation
            case .image(let e): return e.rotation
            }
        }
        set {
            switch self {
            case .text(var e):
                e.rotation = newValue
                self = .text(e)
            case .image(var e):
                e.rotation = newValue
                self = .image(e)
            }
        }
    }

    var zIndex: Int {
        get {
            switch self {
            case .text(let e): return e.zIndex
            case .image(let e): return e.zIndex
            }
        }
        set {
            switch self {
            case .text(var e):
                e.zIndex = newValue
                self = .text(e)
            case .image(var e):
                e.zIndex = newValue
                self = .image(e)
            }
        }
    }
}

// MARK: - Canvas Constants

enum CanvasConstants {
    /// Virtual canvas size for consistent rendering across devices
    static let virtualSize = CGSize(width: 1000, height: 1400)

    /// Minimum element size
    static let minElementSize: CGFloat = 30

    /// Default text element size
    static let defaultTextSize = CGSize(width: 200, height: 50)

    /// Default image element width
    static let defaultImageWidth: CGFloat = 250
}

