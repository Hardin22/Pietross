import SwiftUI

struct NotificationBanner: View {
    let author: Profile
    let bookTitle: String
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Author Avatar
                AvatarView(
                    avatarUrl: author.avatarUrl,
                    username: author.username,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(author.username ?? "Someone")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("added a photo in \(bookTitle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                onDismiss()
            }
        }
    }
}
