import SwiftUI

struct SignOutButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Sign Out")
                .foregroundColor(.red)
                .font(.subheadline)
        }
    }
}
