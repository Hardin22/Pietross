import UIKit

struct ImageCompressor {
    /// Compresses and resizes the image to an optimal size for web/mobile usage.
    /// - Parameters:
    ///   - image: The source UIImage.
    ///   - maxDimension: The maximum width or height allowed (default 2048 for high quality).
    ///   - compressionQuality: The JPEG compression quality (0.0 - 1.0, default 0.8).
    /// - Returns: Compressed Data?
    static func compress(
        image: UIImage, maxDimension: CGFloat = 2048, compressionQuality: CGFloat = 0.8
    ) -> Data? {
        // 1. Calculate new size
        let originalSize = image.size
        let aspectRatio = originalSize.width / originalSize.height

        var newSize = originalSize
        if originalSize.width > maxDimension || originalSize.height > maxDimension {
            if originalSize.width > originalSize.height {
                newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            }
        }

        // 2. Resize Image
        // IMPORTANT: Use scale 1.0 to avoid inflating the image on Retina displays (e.g. 3x)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        // 3. Compress to JPEG
        let compressedData = resizedImage.jpegData(compressionQuality: compressionQuality)

        // Debug Logging
        if let data = compressedData {
            let originalSizeMB =
                Double(image.jpegData(compressionQuality: 1.0)?.count ?? 0) / 1024 / 1024
            let compressedSizeMB = Double(data.count) / 1024 / 1024
            print("🖼️ Image Compression: \(image.size) -> \(newSize)")
            print(String(format: "📉 Size: %.2f MB -> %.2f MB", originalSizeMB, compressedSizeMB))
        }

        return compressedData
    }
}
