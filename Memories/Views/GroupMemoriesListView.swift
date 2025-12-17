import SwiftUI

struct GroupMemoriesListView: View {
    @ObservedObject var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Description
                        Text("A private space for the moments that matter most. Create shared postcards between you and one close friend, capturing memories, details, and experiences that tell a story only the two of you share.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top)
                        
                        // Empty State (no group memories yet)
                        EmptyStateView(
                            iconName: "person.3",
                            title: "No Group Memories Yet",
                            message: "Group memories will appear here when you create them."
                        )
                        .padding(.top, 50)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Group Memories")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

