import SwiftUI
import SwiftData

/// Main screen for editing a book with page navigation
struct BookEditorScreen: View {
    @StateObject private var viewModel: BookEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingPageList = false
    @State private var isEditingTitle = false
    @State private var editedTitle: String = ""
    
    init(book: LocalBook, modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: BookEditorViewModel(book: book, modelContext: modelContext))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Page navigation header
                PageNavigationHeader(
                    viewModel: viewModel,
                    onShowPageList: { showingPageList = true }
                )
                
                // Canvas editor
                CanvasEditorView(viewModel: viewModel)
            }
            .navigationTitle(viewModel.book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            editedTitle = viewModel.book.title
                            isEditingTitle = true
                        }) {
                            Label("Rename Book", systemImage: "pencil")
                        }
                        
                        Button(action: {
                            viewModel.isEditingCover.toggle()
                        }) {
                            Label(
                                viewModel.isEditingCover ? "Edit Pages" : "Edit Cover",
                                systemImage: viewModel.isEditingCover ? "doc.text" : "book.closed"
                            )
                        }
                        
                        Divider()
                        
                        Button(action: {
                            viewModel.addNewPage()
                        }) {
                            Label("Add New Page", systemImage: "plus.rectangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingPageList) {
                PageListView(viewModel: viewModel)
            }
            .alert("Rename Book", isPresented: $isEditingTitle) {
                TextField("Book Title", text: $editedTitle)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    viewModel.updateBookTitle(editedTitle)
                }
            }
        }
    }
}

/// Header showing page navigation controls
struct PageNavigationHeader: View {
    @ObservedObject var viewModel: BookEditorViewModel
    let onShowPageList: () -> Void
    
    var body: some View {
        HStack {
            // Previous page button
            Button(action: viewModel.goToPreviousPage) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(viewModel.canGoToPreviousPage ? .primary : .gray)
            }
            .disabled(!viewModel.canGoToPreviousPage)
            
            Spacer()
            
            // Current page indicator
            Button(action: onShowPageList) {
                VStack(spacing: 2) {
                    if viewModel.isEditingCover {
                        Text("Cover")
                            .font(.subheadline.weight(.medium))
                    } else {
                        Text("Page \(viewModel.currentPageIndex + 1) of \(viewModel.pageCount)")
                            .font(.subheadline.weight(.medium))
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Next page button
            Button(action: viewModel.goToNextPage) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(viewModel.canGoToNextPage ? .primary : .gray)
            }
            .disabled(!viewModel.canGoToNextPage)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

/// Sheet view showing list of all pages
struct PageListView: View {
    @ObservedObject var viewModel: BookEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Cover section
                Section("Cover") {
                    Button(action: {
                        viewModel.isEditingCover = true
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(.blue)
                            Text("Book Cover")
                            Spacer()
                            if viewModel.isEditingCover {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }

                // Pages section
                Section("Pages") {
                    ForEach(Array(viewModel.book.sortedPages.enumerated()), id: \.element.id) { index, page in
                        Button(action: {
                            viewModel.isEditingCover = false
                            viewModel.goToPage(at: index)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.gray)
                                Text("Page \(index + 1)")
                                Spacer()
                                if !viewModel.isEditingCover && viewModel.currentPageIndex == index {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deletePage(at: index)
                        }
                    }

                    Button(action: {
                        viewModel.addNewPage()
                    }) {
                        Label("Add New Page", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

