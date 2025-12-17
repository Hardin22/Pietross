import SwiftUI

struct ProfileFlipCardView: View {
    let profile: Profile
    let onEditTapped: () -> Void
    
    @State private var isFlipped = false
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            // Back of the card (User Info & Edit Button)
            ProfileCardBack(profile: profile, onEditTapped: onEditTapped)
                .rotation3DEffect(
                    .degrees(180),
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )
                .opacity(isFlipped ? 1 : 0)
                .accessibility(hidden: !isFlipped)

            // Front of the card (Profile Photo)
            ProfileCardFront(profile: profile)
                .opacity(isFlipped ? 0 : 1)
                .accessibility(hidden: isFlipped)
        }
        .frame(width: 300, height: 450)
        .rotation3DEffect(
            .degrees(rotationAngle),
            axis: (x: 0.0, y: 1.0, z: 0.0),
            perspective: 0.8
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isFlipped.toggle()
                rotationAngle += 180
            }
        }
    }
}

// MARK: - Profile Card Front

struct ProfileCardFront: View {
    let profile: Profile

    var body: some View {
        ZStack {
            Color.white

            if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
                CachedImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.1)
                        ProgressView()
                    }
                }
                .clipped()
            } else {
                // Fallback: Show initials
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Text(profile.username?.prefix(1).uppercased() ?? "?")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundColor(.gray)
                    )
                    .padding(40)
            }
        }
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        // White border effect
        .padding(8)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Profile Card Back

struct ProfileCardBack: View {
    let profile: Profile
    let onEditTapped: () -> Void

    var body: some View {
        ZStack {
            // Cream/Paper background
            Color(hex: "#FDFBF7")

            VStack(alignment: .center, spacing: 24) {
                Spacer()

                // Username
                if let username = profile.username {
                    Text("@\(username)")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                }

                // Full Name
                if let fullName = profile.fullName, !fullName.isEmpty {
                    Text(fullName)
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .foregroundColor(.black.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Edit Button
                Button(action: onEditTapped) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Edit Profile")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .cornerRadius(25)
                }
                .padding(.bottom, 20)
            }
            .padding(32)
        }
        .cornerRadius(16)
        // Border similar to the reference image
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black, lineWidth: 4)
        )
        .padding(8)  // To match front padding sizing
        .background(Color.clear)
    }
}

