import SwiftUI

struct RequestRow: View {
    let request: Friendship
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "person.fill.questionmark")
                .padding(10)
                .background(Color.orange.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text("New Friend Request")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Tap to accept")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: onDecline) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                
                Button(action: onAccept) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
