import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var onClear: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search username...", text: $text)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.search)
            
            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
