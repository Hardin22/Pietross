import UIKit
import CryptoKit

class ImageCacheService {
    static let shared = ImageCacheService()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let diskCacheDirectory: URL
    
    private init() {
        // Setup disk cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        diskCacheDirectory = paths[0].appendingPathComponent("ImageCache")
        
        do {
            try fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
            print("ImageCache: Directory ready at \(diskCacheDirectory.path)")
        } catch {
            print("ImageCache: Failed to create directory: \(error)")
        }
    }
    
    func image(for url: URL) -> UIImage? {
        let key = url.absoluteString as NSString
        
        // 1. Check Memory Cache
        if let image = memoryCache.object(forKey: key) {
            print("ImageCache: Memory Hit for \(url.lastPathComponent)")
            return image
        }
        
        // 2. Check Disk Cache
        let fileURL = diskCachePath(for: url)
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            // Restore to memory cache
            memoryCache.setObject(image, forKey: key)
            print("ImageCache: Disk Hit for \(url.lastPathComponent)")
            return image
        }
        
        print("ImageCache: Miss for \(url.lastPathComponent)")
        return nil
    }
    
    func insert(_ image: UIImage, for url: URL) {
        let key = url.absoluteString as NSString
        
        // 1. Save to Memory
        memoryCache.setObject(image, forKey: key)
        
        // 2. Save to Disk (background)
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.diskCachePath(for: url)
            if let data = image.jpegData(compressionQuality: 0.8) {
                do {
                    try data.write(to: fileURL)
                    print("ImageCache: Saved to disk \(fileURL.lastPathComponent)")
                } catch {
                    print("ImageCache: Failed to write to disk: \(error)")
                }
            }
        }
    }
    
    private func diskCachePath(for url: URL) -> URL {
        // Use SHA256 to generate a safe, fixed-length filename
        let key = url.absoluteString
        let inputData = Data(key.utf8)
        let hashed = SHA256.hash(data: inputData)
        let hashString = hashed.compactMap { String(format: "%02x", $0) }.joined()
        
        return diskCacheDirectory.appendingPathComponent(hashString + ".jpg")
    }
}
