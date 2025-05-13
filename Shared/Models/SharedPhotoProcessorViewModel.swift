import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// Define SavedPhoto struct with cross-platform compatibility
struct SavedPhoto: Identifiable {
    let id = UUID()
    let image: PlatformImage
    let format: PhotoFormat
    let dateCreated: Date
    
    // Position on the layout canvas (normalized 0-1 coordinates)
    var position: CGPoint = .zero
    var scale: CGFloat = 1.0
    var rotation: Double = 0.0
    
    // Calculate pixel dimensions based on format and 300dpi
    var pixelDimensions: CGSize {
        let dpi: CGFloat = 300.0
        let mmToPixel: CGFloat = dpi / 25.4 // Convert mm to pixels at 300 DPI
        return CGSize(
            width: format.dimensions.width * mmToPixel,
            height: format.dimensions.height * mmToPixel
        )
    }
    
    // Date formatter for display
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Date string for display
    var dateString: String {
        return SavedPhoto.dateFormatter.string(from: dateCreated)
    }
}

// Define photo formats
enum PhotoFormat: String, CaseIterable, Identifiable {
    case passport = "Passport"
    case usVisa = "US Visa"
    case euId = "EU ID"
    case custom = "Custom"
    
    var id: String { self.rawValue }
    
    var dimensions: CGSize {
        switch self {
        case .passport:
            return CGSize(width: 35, height: 45) // mm (standard passport)
        case .usVisa:
            return CGSize(width: 50, height: 50) // mm (US visa square)
        case .euId:
            return CGSize(width: 35, height: 45) // mm (EU ID, same as passport)
        case .custom:
            return CGSize(width: 35, height: 45) // Default for custom, will be overridden
        }
    }
    
    var description: String {
        switch self {
        case .passport:
            return "35 x 45 mm - International Passport"
        case .usVisa:
            return "50 x 50 mm - US Visa (2x2 inch)"
        case .euId:
            return "35 x 45 mm - European ID Card"
        case .custom:
            return "Custom Size"
        }
    }
}

class SharedPhotoProcessorViewModel: ObservableObject {
    // Selected image properties
    @Published var selectedImage: PlatformImage?
    @Published var processedImage: PlatformImage?
    
    // Format selection
    @Published var selectedPhotoFormat: PhotoFormat = .passport
    
    // Custom dimensions (in mm) for the custom format
    @Published var customWidth: CGFloat = 35
    @Published var customHeight: CGFloat = 45
    
    // Background color selection
    @Published var selectedBackgroundColor: Color = .white
    
    // Editing parameters
    @Published var zoomScale: CGFloat = 1.0
    @Published var rotationAngle: Double = 0.0
    @Published var offset: CGSize = .zero
    
    // Frame properties
    @Published var frameSize: CGSize = .zero
    
    // Default initializer
    init() {}
    
    // Initialize with an image
    init(image: PlatformImage) {
        self.selectedImage = image
    }
    
    // Reset editing parameters
    func resetEditing() {
        zoomScale = 1.0
        rotationAngle = 0.0
        offset = .zero
    }
    
    // Platform-specific image selection
    #if os(iOS)
    // iOS image saving
    func saveImage() {
        guard let processedImage = self.processedImage else { return }
        UIImageWriteToSavedPhotosAlbum(processedImage, nil, nil, nil)
    }
    #elseif os(macOS)
    // macOS image selection
    func selectImage() {
        let openPanel = NSOpenPanel()
        openPanel.prompt = "Select Image"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.image]
        
        if openPanel.runModal() == .OK {
            if let selectedFileURL = openPanel.url {
                if let image = NSImage(contentsOf: selectedFileURL) {
                    self.selectedImage = image
                    self.resetEditing()
                }
            }
        }
    }
    
    // macOS image saving
    func saveImage() {
        guard let image = processedImage else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save ID Photo"
        savePanel.nameFieldLabel = "File Name:"
        
        // Set default filename
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let defaultName = "\(selectedPhotoFormat.rawValue)_\(formatter.string(from: Date())).png"
        savePanel.nameFieldStringValue = defaultName
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                // Convert NSImage to PNG data
                if let tiffData = image.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                    
                    do {
                        try pngData.write(to: url)
                    } catch {
                        print("Error saving image: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    #endif
    
    // Background removal function
    #if os(iOS)
    func removeBackground(from image: PlatformImage, replaceWithColor color: UIColor) {
        // Implementation will use Vision API for segmentation
        // This is a simplified version for demonstration
        guard let cgImage = image.cgImage else { return }
        
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            if let mask = request.results?.first?.pixelBuffer {
                let ciImage = CIImage(cvPixelBuffer: mask)
                let originalCIImage = CIImage(cgImage: cgImage)
                
                // Create a CIImage with the background color
                let colorCIImage = CIImage(color: CIColor(color: color))
                    .cropped(to: originalCIImage.extent)
                
                // Set up the blending
                let filter = CIFilter.blendWithMask()
                filter.inputImage = colorCIImage
                filter.backgroundImage = originalCIImage
                filter.maskImage = ciImage
                
                if let outputCIImage = filter.outputImage {
                    let context = CIContext()
                    if let outputCGImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) {
                        self.processedImage = UIImage(cgImage: outputCGImage)
                    }
                }
            }
        } catch {
            print("Error processing image: \(error)")
        }
    }
    #elseif os(macOS)
    func removeBackground(from image: NSImage, replaceWithColor color: NSColor) {
        // Implementation using Vision API
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            if let mask = request.results?.first?.pixelBuffer {
                let ciImage = CIImage(cvPixelBuffer: mask)
                let originalCIImage = CIImage(cgImage: cgImage)
                
                // Create a CIImage with the background color
                let colorCIImage = CIImage(color: CIColor(color: color))
                    .cropped(to: originalCIImage.extent)
                
                // Set up the blending
                let filter = CIFilter.blendWithMask()
                filter.inputImage = colorCIImage
                filter.backgroundImage = originalCIImage
                filter.maskImage = ciImage
                
                if let outputCIImage = filter.outputImage {
                    let context = CIContext()
                    if let outputCGImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) {
                        let outputSize = CGSize(width: cgImage.width, height: cgImage.height)
                        self.processedImage = NSImage(cgImage: outputCGImage, size: outputSize)
                    }
                }
            }
        } catch {
            print("Error processing image: \(error)")
        }
    }
    #endif
} 