import SwiftUI

struct BookGridView: View {
    let pages: [Page]
    let bookTitle: String
    let vibeColor: String
    let onPageSelected: (UUID) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(pages) { page in
                        PageThumbnailView(page: page)
                            .onTapGesture {
                                onPageSelected(page.id)
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(
                Color(hex: vibeColor)
                    .ignoresSafeArea()
            )
            .navigationTitle(bookTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Page Thumbnail View

struct PageThumbnailView: View {
    let page: Page
    
    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail Image Container
            ZStack(alignment: .topTrailing) {
                // Main Image
                GeometryReader { geometry in
                    if let url = URL(string: page.photoUrl) {
                        CachedImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        } placeholder: {
                            ZStack {
                                Color.white
                                
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                    .scaleEffect(0.8)
                            }
                        }
                    } else {
                        ZStack {
                            Color.white
                            
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.3))
                        }
                    }
                }
                .aspectRatio(0.75, contentMode: .fit)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
            }
            
            // Date label with better spacing
            if let date = page.photoDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(1)
                    .padding(.top, 6)
            }
        }
    }
}
