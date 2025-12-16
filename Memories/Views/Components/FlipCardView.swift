import SwiftUI

struct FlipCardView: View {
    let page: Page
    @State private var isFlipped = false
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            // Back of the card (Text & Date)
            CardBack(page: page)
                .rotation3DEffect(
                    .degrees(180),
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )
                .opacity(isFlipped ? 1 : 0)
                .accessibility(hidden: !isFlipped)

            // Front of the card (Photo)
            CardFront(page: page)
                .opacity(isFlipped ? 0 : 1)
                .accessibility(hidden: isFlipped)
        }
        .frame(width: 300, height: 450)  // Fixed size or flexible? Will make flexible in usage
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

struct CardFront: View {
    let page: Page

    var body: some View {
        ZStack {
            Color.white

            if let url = URL(string: page.photoUrl) {
                CachedImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.1)
                    ProgressView()
                }
                .clipped()
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

struct CardBack: View {
    let page: Page

    var body: some View {
        ZStack {
            // Cream/Paper background
            Color(hex: "#FDFBF7")

            VStack(alignment: .center, spacing: 16) {
                Spacer()

                // Date as Title
                if let date = page.photoDate {
                    Text(date.formatted(date: .long, time: .omitted))
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                }

                // Memory Text
                if let text = page.memoryText, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundColor(.black.opacity(0.8))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                } else {
                    Text("No description")
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundColor(.gray)
                }

                Spacer()
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
