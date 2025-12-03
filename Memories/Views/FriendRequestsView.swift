import SwiftUI

struct FriendRequestsView: View {
    @ObservedObject var viewModel: SocialViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.pendingRequests.isEmpty {
                    Text("No pending requests")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(viewModel.pendingRequests) { request in
                        RequestRow(request: request, onAccept: {
                            Task { await viewModel.accept(request: request) }
                        }, onDecline: {
                            Task { await viewModel.decline(request: request) }
                        })
                    }
                }
            }
            .navigationTitle("Friend Requests")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
