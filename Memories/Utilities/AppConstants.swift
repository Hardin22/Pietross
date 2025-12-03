import Foundation

struct AppConstants {
    struct Table {
        static let profiles = "profiles"
        static let friendships = "friendships"
        static let books = "books"
    }
    
    struct Storage {
        static let bucket = "memories-assets"
        static let avatarsPath = "avatars"
    }
    
    struct Realtime {
        static let friendshipsChannel = "public:friendships"
    }
}
