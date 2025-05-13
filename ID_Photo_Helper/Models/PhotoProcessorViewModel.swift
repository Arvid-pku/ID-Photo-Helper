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
        
        // Process the image - using frameSize that matches the blue frame exactly
        self.croppedImage = imageProcessor.processImage(
            originalImage: selectedImage,
            format: selectedPhotoFormat,
            zoomScale: effectiveZoomScale,
            rotationAngle: rotationAngle,
            offset: offset,
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
        // Limit zoom range to 10% - 300% as requested
        let newZoom = max(0.1, min(zoomScale + delta, 3.0))
        zoomScale = newZoom
        
        // Process the image immediately after zoom changes
        processImage()
    }
    
    // Auto-position the frame based on face detection
    func autoPositionFrame() {
        guard let image = selectedImage else { return }
        
        // Reset rotation first
        rotationAngle = 0.0
        
        // Perform face detection and center frame on face
        imageProcessor.detectFace(in: image) { [weak self] faceBounds in
            guard let strongSelf = self else { return }
            
            if faceBounds == nil {
                print("No face detected")
                // If no face detected, reset to center
                DispatchQueue.main.async {
                    strongSelf.offset = .zero
                    strongSelf.zoomScale = 1.0
                    strongSelf.processImage()
                }
                return 
            }
            
            let detectedBounds = faceBounds!
            
            DispatchQueue.main.async {
                // Get the frame dimensions
                let dimensions = strongSelf.selectedPhotoFormat.dimensions
                let aspectRatio = dimensions.width / dimensions.height
                let frameHeight: CGFloat = 200 // Must match the height in FixedFormatFrame
                let frameWidth = frameHeight * aspectRatio
                
                // Get image size
                let imageSize = image.size
                
                // Calculate the required zoom to make the face fill about 70-80% of the frame height
                let faceToFrameRatio: CGFloat = 0.7 // Face should take 70% of frame height
                let targetFaceHeight = frameHeight * faceToFrameRatio
                
                // Calculate required zoom
                let zoomToFitFace = targetFaceHeight / detectedBounds.height
                
                // Apply min/max bounds to zoom
                strongSelf.zoomScale = min(max(zoomToFitFace, 0.1), 3.0)
                
                // Calculate position to center the face in the frame
                // First, determine where the face center would be at current zoom
                let faceCenterX = detectedBounds.midX * strongSelf.zoomScale
                let faceCenterY = detectedBounds.midY * strongSelf.zoomScale
                
                // Then calculate the offset to center the face in the frame
                let frameCenter = CGPoint(x: frameWidth / 2, y: frameHeight / 2)
                let scaledImageCenter = CGPoint(
                    x: imageSize.width * strongSelf.zoomScale / 2,
                    y: imageSize.height * strongSelf.zoomScale / 2
                )
                
                // Calculate offset from the centered position
                let offsetX = frameCenter.x - faceCenterX
                let offsetY = frameCenter.y - faceCenterY
                
                // Apply the calculated offset
                strongSelf.offset = CGSize(width: offsetX, height: offsetY)
                
                print("Auto-positioned face:")
                print("  - Face bounds: \(detectedBounds)")
                print("  - Zoom: \(strongSelf.zoomScale)")
                print("  - Offset: \(strongSelf.offset)")
                
                // Process image with new position and zoom
                strongSelf.processImage()
            }
        }
    }
}

// Photo format specifications
enum PhotoFormat: String, CaseIterable, Identifiable {
    case passport = "Passport"
    case visa = "Visa"
    case driversLicense = "Driver's License"
    case idCard = "ID Card"
    case usVisa = "US Visa"
    case schengenVisa = "Schengen Visa" 
    case japanVisa = "Japan Visa"
    case chinaVisa = "China Visa"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var dimensions: CGSize {
        switch self {
        case .passport:
            return CGSize(width: 35, height: 45) // 35x45mm standard passport photo
        case .visa:
            return CGSize(width: 50, height: 50) // 50x50mm common for visa photos
        case .driversLicense:
            return CGSize(width: 35, height: 45) // Varies by country, using common size
        case .idCard:
            return CGSize(width: 35, height: 45) // Varies by country, using common size
        case .usVisa:
            return CGSize(width: 50, height: 50) // 2x2 inches (50.8x50.8mm)
        case .schengenVisa:
            return CGSize(width: 35, height: 45) // 35x45mm Schengen standard
        case .japanVisa:
            return CGSize(width: 45, height: 45) // 45x45mm for Japan
        case .chinaVisa:
            return CGSize(width: 33, height: 48) // 33x48mm for Chinese visa
        case .custom:
            return CGSize(width: 50, height: 50) // Default for custom, user can change
        }
    }
    
    var description: String {
        switch self {
        case .passport:
            return "Standard 35×45mm passport photo used by most countries"
        case .visa:
            return "Standard 50×50mm visa photo format"
        case .driversLicense:
            return "Standard size for most driver's licenses"
        case .idCard:
            return "Common ID card format (varies by country)"
        case .usVisa:
            return "US visa/passport photo (2×2 inches)"
        case .schengenVisa:
            return "Format for Schengen area visa applications"
        case .japanVisa:
            return "Square format for Japanese visa applications"
        case .chinaVisa:
            return "Chinese visa photo requirements"
        case .custom:
            return "Custom size - specify your dimensions"
        }
    }
    
    var fileExtension: String {
        "jpg" // Default to jpg for most ID photos
    }
} 
