import SwiftUI

struct SelectFriendsView: View {
    @ObservedObject var viewModel: SocialViewModel
    @Binding var selectedFriends: Set<UUID>
    var onNext: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""

    var filteredFriends: [Profile] {
        if searchText.isEmpty {
            return viewModel.friends
        } else {
            return viewModel.friends.filter { friend in
                let usernameMatch =
                    friend.username?.localizedCaseInsensitiveContains(searchText) ?? false
                let fullNameMatch =
                    friend.fullName?.localizedCaseInsensitiveContains(searchText) ?? false
                return usernameMatch || fullNameMatch
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                        .foregroundColor(.primary)
                }
                Spacer()
                Text("Add Friends")
                    .font(.headline)
                Spacer()
                // Balance
                Image(systemName: "xmark").opacity(0).padding(10)
            }
            .padding(.horizontal)
            .padding(.top)

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search friends", text: $searchText)
                    .autocapitalization(.none)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredFriends) { friend in
                        Button(action: {
                            if selectedFriends.contains(friend.id) {
                                selectedFriends.remove(friend.id)
                            } else {
                                selectedFriends.insert(friend.id)
                            }
                        }) {
                            HStack {
                                AvatarView(
                                    avatarUrl: friend.avatarUrl, username: friend.username, size: 50
                                )

                                VStack(alignment: .leading) {
                                    Text(friend.username ?? "Unknown")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    if let fullName = friend.fullName, !fullName.isEmpty {
                                        Text(fullName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Image(
                                    systemName: selectedFriends.contains(friend.id)
                                        ? "checkmark.circle.fill" : "circle"
                                )
                                .font(.title2)
                                .foregroundColor(
                                    selectedFriends.contains(friend.id) ? .blue : .gray.opacity(0.5)
                                )
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .padding()
            }

            // Next Button
            Button(action: onNext) {
                Text("Next")
                    .fontWeight(.bold)
                    .foregroundColor(Color(UIColor.systemBackground))  // Adapts to be opposite of primary
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primary)  // Adaptive Black(Light)/White(Dark)
                    .cornerRadius(12)
            }
            .padding()
            .disabled(selectedFriends.isEmpty)
            .opacity(selectedFriends.isEmpty ? 0.5 : 1.0)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}
