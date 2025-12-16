import SwiftUI
import Combine

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    
    private let url: URL
    private var cancellable: AnyCancellable?
    private let cache = ImageCacheService.shared
    
    init(url: URL) {
        self.url = url
    }
    
    func load() {
        // 1. Check Cache
        if let cachedImage = cache.image(for: url) {
            self.image = cachedImage
            return
        }
        
        // 2. Download
        isLoading = true
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] downloadedImage in
                guard let self = self else { return }
                self.isLoading = false
                
                if let image = downloadedImage {
                    self.image = image
                    self.cache.insert(image, for: self.url)
                }
            }
    }
    
    func cancel() {
        cancellable?.cancel()
    }
}
