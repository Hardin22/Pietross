import SwiftUI

struct FriendshipsView: View {
    @StateObject private var viewModel = SocialViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSearchSheet = false
    @State private var showFriendRequests = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header with back button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(uiColor: .secondarySystemFill))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)

                // Title
                Text("Your Friends")
                    .font(.title.bold())
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.top, 24)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Friends List
                        friendsList

                        // Add Friend Button
                        addFriendButton
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadData()
        }
        .sheet(isPresented: $showSearchSheet) {
            SearchUsersSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showFriendRequests) {
            FriendRequestsListView(viewModel: viewModel)
        }
    }

    // MARK: - Friend Requests Preview

    private var friendRequestsPreview: some View {
        Button(action: {
            showFriendRequests = true
        }) {
            HStack(spacing: 12) {
                // Avatar of first requester
                if let firstRequest = viewModel.pendingRequests.first {
                    AvatarView(
                        avatarUrl: firstRequest.sender?.avatarUrl,
                        username: firstRequest.sender?.username,
                        size: 50
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Friend requests")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)

                    let count = viewModel.pendingRequests.count
                    let names = viewModel.pendingRequests.prefix(2).compactMap {
                        $0.sender?.username
                    }.joined(separator: ", ")
                    let moreCount = count > 2 ? " + \(count - 2) more" : ""

                    Text("@\(names)\(moreCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Friends List

    private var friendsList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.friends) { friend in
                FriendRowWithActions(
                    friend: friend,
                    onMomosAction: {
                        print("Momos tapped for \(friend.username ?? "friend")")
                    },
                    onDelete: {
                        Task {
                            await viewModel.deleteFriend(friendId: friend.id)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Add Friend Button

    private var addFriendButton: some View {
        Button(action: {
            showSearchSheet = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.headline)
                Text("Add Friend")
                    .font(.headline.weight(.semibold))
            }
            .foregroundColor(.primary)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(
                Capsule()
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color(uiColor: .separator), lineWidth: 0.5)
            )
        }
        .padding(.horizontal)
    }
}

// MARK: - Friend Row with Actions

struct FriendRowWithActions: View {
    let friend: Profile
    let onMomosAction: () -> Void
    let onDelete: () -> Void

    @State private var isDeleting = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                avatarUrl: friend.avatarUrl,
                username: friend.username,
                size: 50
            )

            Spacer()

            if isDeleting {
                ProgressView()
                    .tint(.primary)
            } else {
                HStack(spacing: 12) {
                    // Delete button
                    Button(action: {
                        isDeleting = true
                        onDelete()
                    }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                            .background(Color(uiColor: .secondarySystemFill))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Friend Requests List View

struct FriendRequestsListView: View {
    @ObservedObject var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header with back button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(uiColor: .secondarySystemFill))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)

                // Title
                Text("Friend Requests")
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.top, 24)

                ScrollView {
                    VStack(spacing: 12) {
                        if viewModel.pendingRequests.isEmpty {
                            emptyRequestsView
                        } else {
                            ForEach(viewModel.pendingRequests) { request in
                                FriendRequestRow(
                                    request: request,
                                    onAccept: {
                                        Task {
                                            await viewModel.accept(request: request)
                                        }
                                    },
                                    onDecline: {
                                        Task {
                                            await viewModel.decline(request: request)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
    }

    private var emptyRequestsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Friend Requests")
                .font(.headline)
                .foregroundColor(.primary)

            Text("You don't have any pending friend requests")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Friend Request Row

struct FriendRequestRow: View {
    let request: Friendship
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var isProcessing = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                avatarUrl: request.sender?.avatarUrl,
                username: request.sender?.username,
                size: 50
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(request.sender?.username ?? "Unknown")
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)

                Text("@\(request.sender?.username ?? "")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isProcessing {
                ProgressView()
                    .tint(.primary)
            } else {
                HStack(spacing: 12) {
                    // Accept button
                    Button(action: {
                        isProcessing = true
                        onAccept()
                    }) {
                        Text("confirm")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .cornerRadius(20)
                    }

                    // Decline button
                    Button(action: {
                        isProcessing = true
                        onDecline()
                    }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                            .background(Color(uiColor: .secondarySystemFill))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    FriendshipsView()
}
