import SwiftUI

struct AvatarView: View {
    let avatarUrl: String?
    let username: String?
    let size: CGFloat
    
    var body: some View {
        if let avatarUrl = avatarUrl, let url = URL(string: avatarUrl) {
            CachedImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: size, height: size)
                .overlay(Text(username?.prefix(1).uppercased() ?? "?"))
        }
    }
}
