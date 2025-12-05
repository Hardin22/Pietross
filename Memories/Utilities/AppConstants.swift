import Foundation

struct AppConstants {
    struct Table {
        static let profiles = "profiles"
        static let friendships = "friendships"
        static let books = "books"
        static let letters = "letters"
    }
    
    struct Storage {
        static let bucket = "memories-assets"
        static let avatarsPath = "avatars"
        static let lettersPath = "letters"
    }
    
    struct Realtime {
        static let friendshipsChannel = "public:friendships"
        static let lettersChannel = "public:letters"
    }
}
