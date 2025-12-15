import Foundation
import SwiftUI
import SwiftData
import Combine

/// ViewModel for managing book editing operations
@MainActor
final class BookEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var book: LocalBook
    @Published var currentPageIndex: Int = 0
    @Published var selectedElementId: UUID?
    @Published var isEditingCover: Bool = false
    
    // Cover elements (when editing cover)
    @Published var coverElements: [PageElement] = []
    
    // Current page elements
    @Published var pageElements: [PageElement] = []
    
    private var modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var currentPage: LocalPage? {
        let sorted = book.sortedPages
        guard currentPageIndex >= 0 && currentPageIndex < sorted.count else { return nil }
        return sorted[currentPageIndex]
    }
    
    var pageCount: Int {
        book.pages.count
    }
    
    var canGoToPreviousPage: Bool {
        currentPageIndex > 0
    }
    
    var canGoToNextPage: Bool {
        currentPageIndex < pageCount - 1
    }
    
    var currentElements: [PageElement] {
        isEditingCover ? coverElements : pageElements
    }
    
    // MARK: - Initialization
    
    init(book: LocalBook, modelContext: ModelContext) {
        self.book = book
        self.modelContext = modelContext
        self.coverElements = book.coverElements
        loadCurrentPageElements()
    }
    
    // MARK: - Page Navigation
    
    func goToPreviousPage() {
        guard canGoToPreviousPage else { return }
        saveCurrentPageElements()
        currentPageIndex -= 1
        loadCurrentPageElements()
        selectedElementId = nil
    }
    
    func goToNextPage() {
        guard canGoToNextPage else { return }
        saveCurrentPageElements()
        currentPageIndex += 1
        loadCurrentPageElements()
        selectedElementId = nil
    }
    
    func goToPage(at index: Int) {
        guard index >= 0 && index < pageCount else { return }
        saveCurrentPageElements()
        currentPageIndex = index
        loadCurrentPageElements()
        selectedElementId = nil
    }
    
    // MARK: - Page Management
    
    func addNewPage() {
        let newPage = LocalPage(orderIndex: pageCount)
        newPage.book = book
        book.pages.append(newPage)
        save()
    }
    
    func deletePage(at index: Int) {
        let sorted = book.sortedPages
        guard index >= 0 && index < sorted.count else { return }
        
        let pageToDelete = sorted[index]
        modelContext.delete(pageToDelete)
        
        // Reorder remaining pages
        for (newIndex, page) in book.sortedPages.enumerated() {
            page.orderIndex = newIndex
        }
        
        // Adjust current page index
        if currentPageIndex >= pageCount {
            currentPageIndex = max(0, pageCount - 1)
        }
        
        loadCurrentPageElements()
        save()
    }
    
    // MARK: - Element Management
    
    func addTextElement(at position: CGPoint) {
        var element = TextElement(position: position)
        element.zIndex = currentElements.count
        
        if isEditingCover {
            coverElements.append(.text(element))
        } else {
            pageElements.append(.text(element))
        }
        
        selectedElementId = element.id
        saveCurrentPageElements()
    }
    
    func addImageElement(imageData: Data, originalSize: CGSize, at position: CGPoint) {
        var element = ImageElement(
            position: position,
            imageData: imageData,
            originalSize: originalSize
        )
        element.zIndex = currentElements.count
        
        if isEditingCover {
            coverElements.append(.image(element))
        } else {
            pageElements.append(.image(element))
        }
        
        selectedElementId = element.id
        saveCurrentPageElements()
    }
    
    func updateElement(_ element: PageElement) {
        if isEditingCover {
            if let index = coverElements.firstIndex(where: { $0.id == element.id }) {
                coverElements[index] = element
            }
        } else {
            if let index = pageElements.firstIndex(where: { $0.id == element.id }) {
                pageElements[index] = element
            }
        }
        saveCurrentPageElements()
    }
    
    func deleteElement(id: UUID) {
        if isEditingCover {
            coverElements.removeAll { $0.id == id }
        } else {
            pageElements.removeAll { $0.id == id }
        }

        if selectedElementId == id {
            selectedElementId = nil
        }
        saveCurrentPageElements()
    }

    func selectElement(id: UUID?) {
        selectedElementId = id
    }

    func deselectAll() {
        selectedElementId = nil
    }

    // MARK: - Text Element Updates

    func updateTextContent(_ id: UUID, content: String) {
        updateTextElement(id) { $0.content = content }
    }

    func updateTextFont(_ id: UUID, fontFamily: String, fontSize: CGFloat) {
        updateTextElement(id) {
            $0.fontFamily = fontFamily
            $0.fontSize = fontSize
        }
    }

    func updateTextColor(_ id: UUID, hexColor: String) {
        updateTextElement(id) { $0.textColor = hexColor }
    }

    func updateTextStyle(_ id: UUID, isBold: Bool? = nil, isItalic: Bool? = nil, isUnderlined: Bool? = nil) {
        updateTextElement(id) {
            if let bold = isBold { $0.isBold = bold }
            if let italic = isItalic { $0.isItalic = italic }
            if let underline = isUnderlined { $0.isUnderlined = underline }
        }
    }

    func updateTextAlignment(_ id: UUID, alignment: TextAlignmentType) {
        updateTextElement(id) { $0.textAlignment = alignment }
    }

    private func updateTextElement(_ id: UUID, update: (inout TextElement) -> Void) {
        let elements = isEditingCover ? coverElements : pageElements
        guard let index = elements.firstIndex(where: { $0.id == id }),
              case .text(var textElement) = elements[index] else { return }

        update(&textElement)

        if isEditingCover {
            coverElements[index] = .text(textElement)
        } else {
            pageElements[index] = .text(textElement)
        }
        saveCurrentPageElements()
    }

    // MARK: - Element Transform Updates

    func updateElementPosition(_ id: UUID, position: CGPoint) {
        updateElementTransform(id) { $0.position = position }
    }

    func updateElementSize(_ id: UUID, size: CGSize) {
        updateElementTransform(id) { $0.size = size }
    }

    func updateElementRotation(_ id: UUID, rotation: Double) {
        updateElementTransform(id) { $0.rotation = rotation }
    }

    private func updateElementTransform(_ id: UUID, update: (inout PageElement) -> Void) {
        if isEditingCover {
            if let index = coverElements.firstIndex(where: { $0.id == id }) {
                update(&coverElements[index])
            }
        } else {
            if let index = pageElements.firstIndex(where: { $0.id == id }) {
                update(&pageElements[index])
            }
        }
        saveCurrentPageElements()
    }

    // MARK: - Book Metadata

    func updateBookTitle(_ title: String) {
        book.title = title
        save()
    }

    // MARK: - Persistence Helpers

    private func loadCurrentPageElements() {
        guard let page = currentPage else {
            pageElements = []
            return
        }
        pageElements = page.elements
    }

    private func saveCurrentPageElements() {
        if isEditingCover {
            book.coverElements = coverElements
        } else if let page = currentPage {
            page.elements = pageElements
        }
        save()
    }

    private func save() {
        book.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            print("Error saving book: \(error)")
        }
    }
}

