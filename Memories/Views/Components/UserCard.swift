import SwiftUI

struct UserCard: View {
    let user: Profile
    let onAdd: () -> Void
    
    var body: some View {
        VStack {
            AvatarView(avatarUrl: user.avatarUrl, username: user.username, size: 60)
            
            Text(user.username ?? "Unknown")
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onAdd) {
                Text("Add")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .frame(width: 100)
    }
}
