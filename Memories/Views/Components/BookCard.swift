import SwiftUI

struct BookCard: View {
    let book: Book
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(0.75, contentMode: .fit)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "book.closed")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
                
                Text(book.title ?? "Untitled")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(10)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}
