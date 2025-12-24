import SwiftUI
import UIKit

enum ImageCompressor {
    /// Compresses an image to fit within maxSize (in bytes) while maintaining aspect ratio
    /// Default max size is 200KB for receipt storage
    static func compress(
        _ image: UIImage,
        maxSize: Int = 200 * 1024,
        maxDimension: CGFloat = 800
    ) -> Data? {
        // First resize if needed
        let resizedImage = resize(image, maxDimension: maxDimension)

        // Start with high quality and reduce until size is acceptable
        var compressionQuality: CGFloat = 0.8
        var imageData = resizedImage.jpegData(compressionQuality: compressionQuality)

        while let data = imageData, data.count > maxSize, compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = resizedImage.jpegData(compressionQuality: compressionQuality)
        }

        return imageData
    }

    /// Resizes image to fit within maxDimension while maintaining aspect ratio
    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        let ratio = size.width / size.height
        let newSize: CGSize

        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / ratio)
        } else {
            newSize = CGSize(width: maxDimension * ratio, height: maxDimension)
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - UIImage Extension
extension UIImage {
    var compressedData: Data? {
        ImageCompressor.compress(self)
    }
}
