import SwiftUI

struct RequestRow: View {
    let request: Friendship
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack {
            if let sender = request.sender {
                AvatarView(avatarUrl: sender.avatarUrl, username: sender.username, size: 50)
                
                VStack(alignment: .leading) {
                    Text(sender.username ?? "Unknown")
                        .font(.headline)
                    Text("Sent a friend request")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Unknown User")
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onDecline) {
                    Image(systemName: "xmark")
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
}
