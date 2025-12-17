import SwiftUI

struct NotificationsView: View {
    @ObservedObject var viewModel: SocialViewModel
    var onNavigateToBook: (Book) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.pendingRequests.isEmpty && viewModel.recentNotifications.isEmpty {
                    emptyState
                } else {
                    List {
                        if !viewModel.pendingRequests.isEmpty {
                            Section(header: Text("Friend Requests")) {
                                ForEach(viewModel.pendingRequests) { request in
                                    NotificationRow(
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

                        if !viewModel.recentNotifications.isEmpty {
                            Section(header: Text("Updates")) {
                                ForEach(viewModel.recentNotifications) { notification in
                                    PageNotificationRow(
                                        notification: notification,
                                        onTap: {
                                            viewModel.dismissNotification(id: notification.id)
                                            dismiss()
                                            onNavigateToBook(notification.book)
                                        },
                                        onDismiss: {
                                            viewModel.dismissNotification(id: notification.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Notifications")
                .font(.headline)
                .foregroundColor(.primary)
            Text("You're all caught up!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct NotificationRow: View {
    let request: Friendship
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var isProcessing = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                avatarUrl: request.sender?.avatarUrl,
                username: request.sender?.username,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(request.sender?.username ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("sent you a friend request")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isProcessing {
                ProgressView()
            } else {
                HStack(spacing: 8) {
                    Button(action: {
                        isProcessing = true
                        onAccept()
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        isProcessing = true
                        onDecline()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PageNotificationRow: View {
    let notification: SocialViewModel.InAppNotification
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AvatarView(
                    avatarUrl: notification.author.avatarUrl,
                    username: notification.author.username,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.author.username ?? "Someone")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("added a photo in \(notification.book.title ?? "Memory Book")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
    }
}
