import SwiftUI

#if os(iOS)
import UIKit
public typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#endif

extension PlatformImage {
    #if os(iOS)
    var cgImage: CGImage? {
        return self.cgImage
    }
    #endif
    
    #if os(macOS)
    var ciImage: CIImage? {
        guard let data = self.tiffRepresentation else { return nil }
        return CIImage(data: data)
    }
    #endif
    
    func toSwiftUIImage() -> Image {
        #if os(iOS)
        return Image(uiImage: self)
        #elseif os(macOS)
        return Image(nsImage: self)
        #endif
    }
    
    static func fromCGImage(_ cgImage: CGImage, size: CGSize) -> PlatformImage {
        #if os(iOS)
        return UIImage(cgImage: cgImage)
        #elseif os(macOS)
        return NSImage(cgImage: cgImage, size: size)
        #endif
    }
} 