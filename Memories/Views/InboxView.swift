import SwiftUI

struct InboxView: View {
    @ObservedObject var viewModel: SocialViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab = 0
    @State private var selectedLetter: Letter?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Segmented Control
                HStack {
                    Button(action: { selectedTab = 0 }) {
                        VStack {
                            Text("Letters")
                                .fontWeight(selectedTab == 0 ? .bold : .regular)
                                .foregroundColor(selectedTab == 0 ? .primary : .secondary)
                            
                            if selectedTab == 0 {
                                Capsule()
                                    .fill(Color.blue)
                                    .frame(height: 3)
                                    .matchedGeometryEffect(id: "tab", in: Namespace().wrappedValue)
                            } else {
                                Capsule().fill(Color.clear).frame(height: 3)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button(action: { selectedTab = 1 }) {
                        VStack {
                            HStack {
                                Text("Requests")
                                    .fontWeight(selectedTab == 1 ? .bold : .regular)
                                    .foregroundColor(selectedTab == 1 ? .primary : .secondary)
                                
                                if !viewModel.pendingRequests.isEmpty {
                                    Text("\(viewModel.pendingRequests.count)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                }
                            }
                            
                            if selectedTab == 1 {
                                Capsule()
                                    .fill(Color.blue)
                                    .frame(height: 3)
                                    .matchedGeometryEffect(id: "tab", in: Namespace().wrappedValue)
                            } else {
                                Capsule().fill(Color.clear).frame(height: 3)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                
                TabView(selection: $selectedTab) {
                    // Letters List
                    List {
                        if viewModel.receivedLetters.isEmpty {
                            Text("No letters yet.")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(viewModel.receivedLetters) { letter in
                                Button(action: {
                                    viewModel.markLetterAsRead(letter)
                                    selectedLetter = letter
                                }) {
                                    HStack {
                                        // Sender Avatar
                                        if let sender = letter.sender {
                                            AvatarView(avatarUrl: sender.avatarUrl, username: sender.username, size: 50)
                                        } else {
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .frame(width: 50, height: 50)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(letter.sender?.username ?? "Unknown")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            Text(letter.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if !letter.isRead {
                                            Circle()
                                                .fill(Color.blue)
                                                .frame(width: 10, height: 10)
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .tag(0)
                    
                    // Requests List
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
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .fullScreenCover(item: $selectedLetter) { letter in
                LetterView(letter: letter)
            }
        }
    }
}


