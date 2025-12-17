//
//  FriendsView.swift
//  Memories
//
//  Created by Emiliano Luna George on 15/12/25.
//

import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = SocialViewModel()
    @State private var showSearchSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else {
                    mainContent
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSearchSheet = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showSearchSheet) {
                SearchUsersSheet(viewModel: viewModel)
            }
            .refreshable {
                await viewModel.loadData()
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Pending Requests Section
                if !viewModel.pendingRequests.isEmpty {
                    pendingRequestsSection
                }

                // Friends List Section
                friendsListSection
            }
            .padding(.vertical)
        }
    }

    // MARK: - Pending Requests Section

    private var pendingRequestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friend Requests")
                    .font(.headline)

                Text("\(viewModel.pendingRequests.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)

            ForEach(viewModel.pendingRequests) { request in
                PendingRequestRow(
                    request: request,
                    onAccept: {
                        Task { await viewModel.accept(request: request) }
                    },
                    onDecline: {
                        Task { await viewModel.decline(request: request) }
                    }
                )
            }
        }
    }

    // MARK: - Friends List Section

    private var friendsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Friends")
                .font(.headline)
                .padding(.horizontal)

            if viewModel.friends.isEmpty {
                friendsEmptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.friends) { friend in
                        FriendRow(friend: friend)

                        if friend.id != viewModel.friends.last?.id {
                            Divider()
                                .padding(.leading, 76)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var friendsEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Friends Yet")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Tap the + button to search and add friends")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { showSearchSheet = true }) {
                Label("Find Friends", systemImage: "magnifyingglass")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friend: Profile

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(avatarUrl: friend.avatarUrl, username: friend.username, size: 50)
            
            Text(friend.username ?? "Unknown")
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Pending Request Row

struct PendingRequestRow: View {
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
                    .foregroundStyle(.primary)

                Text("wants to be your friend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isProcessing {
                ProgressView()
                    .tint(.primary)
            } else {
                HStack(spacing: 8) {
                    Button(action: {
                        isProcessing = true
                        onDecline()
                    }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(Circle())
                    }

                    Button(action: {
                        isProcessing = true
                        onAccept()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Search Users Sheet

struct SearchUsersSheet: View {
    @ObservedObject var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var sentRequests: Set<UUID> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search results
                if viewModel.searchText.isEmpty {
                    searchPrompt
                } else if viewModel.searchResults.isEmpty {
                    noResultsView
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("Find Friends")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search by username"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.searchText = ""
                        viewModel.searchResults = []
                        dismiss()
                    }
                }
            }
        }
    }

    private var searchPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Search for Friends")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Enter a username to find people")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Users Found")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchResultsList: some View {
        List(viewModel.searchResults) { user in
            SearchResultRow(
                user: user,
                isFriend: viewModel.friends.contains(where: { $0.id == user.id }),
                hasPendingRequest: hasPendingRequest(for: user),
                requestSent: sentRequests.contains(user.id),
                onSendRequest: {
                    Task {
                        await viewModel.sendRequest(to: user)
                        sentRequests.insert(user.id)
                    }
                }
            )
        }
        .listStyle(.plain)
    }

    private func hasPendingRequest(for user: Profile) -> Bool {
        viewModel.pendingRequests.contains(where: { $0.userA == user.id })
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let user: Profile
    let isFriend: Bool
    let hasPendingRequest: Bool
    let requestSent: Bool
    let onSendRequest: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(avatarUrl: user.avatarUrl, username: user.username, size: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.username ?? "Unknown")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                if let fullName = user.fullName, !fullName.isEmpty {
                    Text(fullName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            actionButton
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButton: some View {
        if isFriend {
            Text("Friends")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(uiColor: .tertiarySystemFill))
                .cornerRadius(12)
        } else if hasPendingRequest {
            Text("Pending")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(uiColor: .tertiarySystemFill))
                .cornerRadius(12)
        } else if requestSent {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                Text("Sent")
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(uiColor: .tertiarySystemFill))
            .cornerRadius(12)
        } else {
            Button(action: onSendRequest) {
                Text("Add")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
        }
    }
}

#Preview {
    FriendsView()
}