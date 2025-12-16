import SwiftUI

struct BookCarouselView: View {
    @ObservedObject var viewModel: BookDetailViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .padding(12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .foregroundColor(.black)
                    }

                    Spacer()

                    Text(viewModel.book.title ?? "Memories")
                        .font(.system(size: 24, weight: .bold, design: .serif))  // Serif font like design
                        .foregroundColor(.black)  // Or adaptive based on vibe

                    Spacer()

                    Button(action: {
                        viewModel.showAddMemorySheet = true
                    }) {
                        Image(systemName: "plus")  // Or arrow.right if strictly following design, but user asked for +
                            .font(.title2)
                            .padding(12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 60)  // Adjust for safe area
                .padding(.bottom, 20)

                if viewModel.pages.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Spacer()

                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.black.opacity(0.5))

                        Text(
                            "Create your first memory with \(viewModel.partnerName ?? "your partner")"
                        )
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .foregroundColor(.black.opacity(0.7))

                        Button(action: {
                            viewModel.showAddMemorySheet = true
                        }) {
                            Text("Add Memory")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(Color.black)
                                .cornerRadius(30)
                        }

                        Spacer()
                    }
                } else {
                    // Carousel
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(viewModel.pages) { page in
                                VStack {
                                    Spacer()

                                    FlipCardView(page: page)
                                        .frame(
                                            width: geometry.size.width * 0.75,
                                            height: geometry.size.height * 0.6
                                        )
                                        .scrollTransition { content, phase in
                                            content
                                                .opacity(phase.isIdentity ? 1.0 : 0.8)
                                                .scaleEffect(phase.isIdentity ? 1.0 : 0.9)
                                                .rotationEffect(.degrees(phase.value * 5))
                                        }

                                    Spacer()
                                }
                                .frame(width: geometry.size.width)
                                .containerRelativeFrame(.horizontal)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .defaultScrollAnchor(.trailing)
                }

                // Bottom Avatar (User)
                HStack {
                    Spacer()
                    // Placeholder for current user avatar or similar
                    // In the design there is a small avatar at bottom right
                    if let user = SocialService.shared.currentUser {  // We need to expose currentUser or fetch it
                        // AvatarView(url: user.avatarUrl, size: 40)
                        // For now just a placeholder or nothing
                    }
                }
                .padding()
            }
        }
        .background(
            Color(hex: viewModel.book.vibe ?? "#FFB7B2")  // Default to pinkish if no vibe
                .ignoresSafeArea()
        )
    }
}
