import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

class PhotoProcessorViewModel: ObservableObject {
    // Selected image properties
    @Published var selectedImage: NSImage?
    @Published var croppedImage: NSImage?
    
    // Format selection
    @Published var selectedPhotoFormat: PhotoFormat = .passport
    
    // Background color selection
    @Published var selectedBackgroundColor: Color = .white
    
    // Editing parameters
    @Published var zoomScale: CGFloat = 1.0
    @Published var rotationAngle: Double = 0.0
    @Published var offset: CGSize = .zero
    
    // Frame properties
    @Published var frameSize: CGSize = .zero
    
    // Image processor
    private let imageProcessor = ImageProcessor()
    
    // Constant for the editor's display area dimension used for initial scaledToFit
    private let editorDisplayDimension: CGFloat = 400.0
    
    // Default initializer
    init() {}
    
    // Initialize with an image
    init(image: NSImage) {
        self.selectedImage = image
    }
    
    // Select an image from file
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
                    self.processImage()
                }
            }
        }
    }
    
    // Reset editing parameters
    func resetEditing() {
        zoomScale = 1.0
        rotationAngle = 0.0
        offset = .zero
    }
    
    // Process the selected image with current parameters
    func processImage() {
        guard let selectedImage = selectedImage else { return }
        
        // Calculate s_fit: the initial scaling factor to fit the image in the editor's display area
        let originalSize = selectedImage.size
        var s_fit: CGFloat = 1.0
        if originalSize.width > 0 && originalSize.height > 0 { // Avoid division by zero
            s_fit = min(editorDisplayDimension / originalSize.width, editorDisplayDimension / originalSize.height)
        }
        // effectiveZoomScale combines s_fit with the user-controlled zoomScale
        let effectiveZoomScale = s_fit * self.zoomScale
        
        // Get dimensions from the selected photo format
        let dimensions = selectedPhotoFormat.dimensions
        let aspectRatio = dimensions.width / dimensions.height
        
        // For display in the editor, we use a 200px height frame with appropriate width based on aspect ratio
        // This is crucial to maintain exact proportions between what's shown and what's saved
        let frameHeight: CGFloat = 200 // Must match value used in FixedFormatFrame
        let frameWidth = frameHeight * aspectRatio
        let processingFrameSize = CGSize(width: frameWidth, height: frameHeight)
        
        print("Processing with frame size: \(processingFrameSize), aspect ratio: \(aspectRatio)")
        
        // Calculate final output dimensions in pixels (for print quality)
        // Standard print quality is 300 DPI
        let dpi: CGFloat = 300.0
        let mmToPixel: CGFloat = dpi / 25.4 // Convert mm to pixels at 300 DPI
        let finalWidth = dimensions.width * mmToPixel
        let finalHeight = dimensions.height * mmToPixel
        
        print("Final output dimensions: \(finalWidth)x\(finalHeight) pixels at \(dpi) DPI")
        
        // Convert SwiftUI Color to NSColor with proper colorspace
        let uiColor = NSColor(selectedBackgroundColor)
        let rgbColor = uiColor.usingColorSpace(.sRGB) ?? NSColor.white

        print("Processing image with background color: \(rgbColor)")
        
        // Invert the y-offset to match the preview behavior
        let processOffset = CGSize(
            width: offset.width,
            height: -offset.height // Invert the Y direction
        )
        
        // Process the image - using frameSize that matches the blue frame exactly
        self.croppedImage = imageProcessor.processImage(
            originalImage: selectedImage,
            format: selectedPhotoFormat,
            zoomScale: effectiveZoomScale,
            rotationAngle: rotationAngle,
            offset: processOffset,
            frameSize: processingFrameSize,
            backgroundColor: rgbColor
        )
        
        if self.croppedImage != nil {
            print("Image processed successfully")
        } else {
            print("Image processing failed")
        }
    }
    
    // Save the processed image
    func saveProcessedImage() {
        guard let image = croppedImage else { return }
        
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
    
    // Adjust zoom level
    func adjustZoom(by delta: CGFloat) {
        // Calculate new zoom value with 2 decimal precision for finer control
        let newZoomRaw = zoomScale + delta
        let newZoom = (newZoomRaw * 100).rounded() / 100 // Round to 2 decimal places
        
        // Limit zoom range to 10% - 300%
        zoomScale = max(0.1, min(newZoom, 3.0))
        
        // Process the image immediately after zoom changes
        processImage()
    }
}

// Photo format specifications
enum PhotoFormat: String, CaseIterable, Identifiable {
    case oneInch = "One Inch"
    case largeOneInch = "Large One Inch"
    case twoInch = "Two Inch"
    case smallTwoInch = "Small Two Inch" 
    case largeTwoInch = "Large Two Inch"
    case idCard = "ID Card"
    case passport = "Passport"
    case usVisa = "US Visa"
    case japanVisa = "Japan Visa"
    case schengenVisa = "Schengen Visa"
    case chinaVisa = "China Visa"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var dimensions: CGSize {
        switch self {
        case .oneInch:
            return CGSize(width: 25, height: 35) // 一寸: 25×35mm
        case .largeOneInch:
            return CGSize(width: 33, height: 48) // 大一寸: 33×48mm
        case .twoInch:
            return CGSize(width: 35, height: 49) // 二寸: 35×49mm
        case .smallTwoInch:
            return CGSize(width: 35, height: 45) // 小二寸: 35×45mm
        case .largeTwoInch:
            return CGSize(width: 35, height: 53) // 大二寸: 35×53mm
        case .idCard:
            return CGSize(width: 26, height: 32) // 身份证: 26×32mm
        case .passport:
            return CGSize(width: 33, height: 48) // 护照/港澳通行证: 33×48mm
        case .usVisa:
            return CGSize(width: 51, height: 51) // 美国签证: 51×51mm
        case .japanVisa:
            return CGSize(width: 45, height: 45) // 日本签证: 45×45mm
        case .schengenVisa:
            return CGSize(width: 35, height: 45) // 申根签证: 35×45mm
        case .chinaVisa:
            return CGSize(width: 33, height: 48) // 中国签证: 33×48mm (same as passport)
        case .custom:
            return CGSize(width: 35, height: 45) // Default for custom
        }
    }
    
    var description: String {
        switch self {
        case .oneInch:
            return "Standard one inch format (25×35mm, 295×413px)"
        case .largeOneInch:
            return "Large one inch format (33×48mm, 390×567px)"
        case .twoInch:
            return "Standard two inch format (35×49mm, 413×579px)"
        case .smallTwoInch:
            return "Small two inch format (35×45mm, 413×531px)"
        case .largeTwoInch:
            return "Large two inch format (35×53mm, 413×626px)"
        case .idCard:
            return "ID card photo (26×32mm, 358×441px)"
        case .passport:
            return "Passport/travel permit (33×48mm, 390×567px)"
        case .usVisa:
            return "US visa photo (51×51mm, 600×600px)"
        case .japanVisa:
            return "Japan visa photo (45×45mm, 531×531px)"
        case .schengenVisa:
            return "Schengen visa photo (35×45mm, 413×531px)"
        case .chinaVisa:
            return "China visa photo (33×48mm, 390×567px)"
        case .custom:
            return "Custom size - specify your dimensions"
        }
    }
    
    var fileExtension: String {
        "jpg" // Default to jpg for most ID photos
    }
} 
