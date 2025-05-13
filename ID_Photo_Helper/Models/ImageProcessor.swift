import Foundation
import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

class ImageProcessor {
    private let context = CIContext()
    // Properties to enable more advanced processing options
    var useAdvancedProcessing: Bool = true
    var enhancementStrength: CGFloat = 1.0
    
    // This helper method ensures consistent rendering between preview and final image
    func renderImageInFrame(
        originalImage: NSImage,
        zoomScale: CGFloat,
        rotationAngle: Double,
        offset: CGSize,
        frameSize: CGSize,
        backgroundColor: NSColor
    ) -> NSImage {
        // Create a new image with the correct dimensions
        let resultImage = NSImage(size: frameSize)
        
        resultImage.lockFocus()
        
        // Fill with background color
        backgroundColor.setFill()
        NSRect(origin: .zero, size: frameSize).fill()
        
        // Calculate scaled size and position
        let originalSize = originalImage.size
        let scaledSourceSize = CGSize(
            width: originalSize.width * zoomScale,
            height: originalSize.height * zoomScale
        )
        
        // Center offset (how much we need to position the image to center it)
        let centerOffsetX = (frameSize.width - scaledSourceSize.width) / 2
        let centerOffsetY = (frameSize.height - scaledSourceSize.height) / 2
        
        // Final position including user's offset
        let xPos = centerOffsetX + offset.width
        let yPos = centerOffsetY + offset.height
        
        let destRect = NSRect(
            x: xPos,
            y: yPos,
            width: scaledSourceSize.width, 
            height: scaledSourceSize.height
        )
        
        // Apply high quality interpolation
        NSGraphicsContext.current?.imageInterpolation = .high
        
        // Draw the image with rotation if needed
        if rotationAngle != 0 {
            // Save the graphics state
            NSGraphicsContext.current?.saveGraphicsState()
            
            // Rotate around the center of the frame
            let rotationTransform = NSAffineTransform()
            rotationTransform.translateX(by: frameSize.width / 2, yBy: frameSize.height / 2)
            rotationTransform.rotate(byDegrees: CGFloat(-rotationAngle))  // Use negative angle to reverse direction
            rotationTransform.translateX(by: -frameSize.width / 2, yBy: -frameSize.height / 2)
            rotationTransform.concat()
            
            // Draw the image
            originalImage.draw(in: destRect, from: .zero, operation: .copy, fraction: 1.0)
            
            // Restore the graphics state
            NSGraphicsContext.current?.restoreGraphicsState()
        } else {
            // Draw without rotation
            originalImage.draw(in: destRect, from: .zero, operation: .copy, fraction: 1.0)
        }
        
        resultImage.unlockFocus()
        
        return resultImage
    }
    
    // Process an image according to the selected format and user adjustments
    func processImage(
        originalImage: NSImage,
        format: PhotoFormat,
        zoomScale: CGFloat,
        rotationAngle: Double,
        offset: CGSize,
        frameSize: CGSize,
        backgroundColor: NSColor,
        customDimensions: CGSize? = nil
    ) -> NSImage? {
        print("DEBUG - Processing image with params:")
        print("  - zoomScale: \(zoomScale)")
        print("  - rotationAngle: \(rotationAngle)")
        print("  - offset: \(offset)")
        print("  - frameSize: \(frameSize)")
        if let customDimensions = customDimensions {
            print("  - custom dimensions: \(customDimensions)")
        }
        
        // Step 1: Create a cropped image using the same rendering logic as the preview
        let tempImage = renderImageInFrame(
            originalImage: originalImage,
            zoomScale: zoomScale,
            rotationAngle: rotationAngle,
            offset: offset,
            frameSize: frameSize,
            backgroundColor: backgroundColor
        )
        
        // Step 2: Calculate final output dimensions in pixels
        let dpi: CGFloat = 300.0 // Standard print quality
        let mmToPixel: CGFloat = dpi / 25.4 // 25.4mm = 1 inch
        
        // Use customDimensions if provided and format is .custom
        let formatDimensions: CGSize
        if let customDimensions = customDimensions, format == .custom {
            formatDimensions = customDimensions
        } else {
            formatDimensions = format.dimensions
        }
        
        let finalWidth = formatDimensions.width * mmToPixel
        let finalHeight = formatDimensions.height * mmToPixel
        
        // Step 3: Convert the temporary NSImage to CIImage for background replacement
        guard let ciImage = ciImage(from: tempImage) else {
            print("Failed to convert NSImage to CIImage")
            return tempImage // Fallback to using the temp image without background replacement
        }
        
        // Step 4: Apply advanced background replacement
        if let finalImageWithBackgroundReplaced = createFinalImage(
            from: ciImage,
            backgroundColor: backgroundColor,
            finalWidth: finalWidth,
            finalHeight: finalHeight
        ) {
            print("Successfully applied background replacement")
            return finalImageWithBackgroundReplaced
        } else {
            print("Background replacement failed, using regular rendering")
            
            // Fallback to original method if advanced background replacement fails
            let finalImage = NSImage(size: NSSize(width: finalWidth, height: finalHeight))
            
            finalImage.lockFocus()
            
            // Use high quality interpolation for the final export
            NSGraphicsContext.current?.imageInterpolation = .high
            
            // Simply scale the tempImage, preserving exactly what was shown in the preview
            tempImage.draw(in: NSRect(origin: .zero, size: finalImage.size),
                           from: .zero,
                           operation: .copy,
                           fraction: 1.0)
            
            finalImage.unlockFocus()
            
            print("Final image created with size: \(finalImage.size)")
            return finalImage
        }
    }
    
    // Create the final image with background replacement
    private func createFinalImage(
        from croppedImage: CIImage,
        backgroundColor: NSColor,
        finalWidth: CGFloat,
        finalHeight: CGFloat
    ) -> NSImage? {
        // Convert background color to CIColor
        let rgbColor = backgroundColor.usingColorSpace(.sRGB) ?? NSColor.white
        let ciColor = CIColor(red: rgbColor.redComponent,
                             green: rgbColor.greenComponent,
                             blue: rgbColor.blueComponent,
                             alpha: rgbColor.alphaComponent)
        
        // Create background matching exact crop dimensions
        let solidColorImage = CIImage(color: ciColor).cropped(to: croppedImage.extent)
        
        // Apply background replacement
        var finalImage: CIImage
        
        print("Processing background replacement")
        
        // For ID photos, prioritize color-based background removal as it works better with uniform backgrounds
        // Option 1: Person segmentation (fallback for complex cases)
        // Option 2: Color-based background removal (prioritized for ID photos)
        if let segmentedImage = segmentPerson(in: croppedImage, backgroundColor: backgroundColor) {
            finalImage = segmentedImage
            print("Using person segmentation for background replacement")
        }
        // Option 2: Fallback - just use cropped image
        else {
            print("Using original image without background replacement")
            // Create a composite image with the solid background and the original image
            if let compositeFilter = CIFilter(name: "CISourceOverCompositing") {
                compositeFilter.setValue(croppedImage, forKey: kCIInputImageKey)
                compositeFilter.setValue(solidColorImage, forKey: kCIInputBackgroundImageKey)
                if let composited = compositeFilter.outputImage {
                    finalImage = composited
                } else {
                    finalImage = croppedImage
                }
            } else {
                finalImage = croppedImage
            }
        }
        
        // Additional step to ensure the background is completely uniform with no border artifacts
        // Create a new solid color background with the exact dimensions of the final image
        let fullSolidColorImage = CIImage(color: ciColor).cropped(to: finalImage.extent)
        
        // Apply an improved blending to ensure the background is completely uniform
        if let improvedBlendFilter = CIFilter(name: "CIBlendWithMask") {
            // Extract alpha channel from the image to use as a mask
            let alphaFilter = CIFilter(name: "CIColorMatrix")
            alphaFilter?.setValue(finalImage, forKey: kCIInputImageKey)
            // Set color matrix to extract alpha (fourth row: 0,0,0,1,0)
            alphaFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
            alphaFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
            alphaFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
            alphaFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            
            if let alphaMask = alphaFilter?.outputImage {
                improvedBlendFilter.setValue(fullSolidColorImage, forKey: kCIInputImageKey)
                improvedBlendFilter.setValue(finalImage, forKey: kCIInputBackgroundImageKey)
                improvedBlendFilter.setValue(alphaMask, forKey: kCIInputMaskImageKey)
                
                if let improvedImage = improvedBlendFilter.outputImage {
                    finalImage = improvedImage
                    print("Applied additional background uniformity improvement")
                }
            }
        }
        
        print("Final image before scaling: \(finalImage.extent), target size: \(finalWidth)x\(finalHeight)")
        
        // Calculate the correct scaling transformation
        // CRITICAL: Maintain the exact aspect ratio from the target format dimensions
        let targetAspectRatio = finalWidth / finalHeight
        let currentAspectRatio = finalImage.extent.width / finalImage.extent.height
        
        // If aspect ratios don't match, we need to adjust the scaling
        var scaleTransform = CGAffineTransform.identity
        if abs(targetAspectRatio - currentAspectRatio) > 0.01 {
            print("Correcting aspect ratio from \(currentAspectRatio) to \(targetAspectRatio)")
            
            // Create a transform that will scale the image to match the target aspect ratio
            // We'll scale to match the target dimensions exactly
            scaleTransform = CGAffineTransform(scaleX: finalWidth / finalImage.extent.width,
                                             y: finalHeight / finalImage.extent.height)
        } else {
            // Aspect ratios match, so just scale uniformly
            let scale = finalWidth / finalImage.extent.width
            scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        }
        
        // Apply the scale transform
        let scaledImage = finalImage.transformed(by: scaleTransform)
        
        print("Scaled image: \(scaledImage.extent)")
        
        // Create the final NSImage at the exact target dimensions
        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            let finalNSImage = NSImage(cgImage: cgImage, size: CGSize(width: finalWidth, height: finalHeight))
            print("Final NSImage size: \(finalNSImage.size)")
            return finalNSImage
        }
        
        return nil
    }
    
    // Helper method to create the final output image with background replacement
    private func createOutputImage(from croppedImage: CIImage, 
                                 backgroundColor: NSColor,
                                 finalWidth: CGFloat, 
                                 finalHeight: CGFloat) -> NSImage? {
        // This method is deprecated - use createFinalImage instead
        return createFinalImage(
            from: croppedImage,
            backgroundColor: backgroundColor,
            finalWidth: finalWidth,
            finalHeight: finalHeight
        )
    }
    
    // Helper function to convert NSImage to CIImage
    private func ciImage(from nsImage: NSImage) -> CIImage? {
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        // Try to create a CGImage from the bitmap
        if let cgImage = bitmap.cgImage {
            return CIImage(cgImage: cgImage)
        }
        
        return nil
    }
    
    // Separate person from background and replace background color
    private func segmentPerson(in image: CIImage, backgroundColor: NSColor) -> CIImage? {
        // Convert CIImage to CGImage for Vision
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            print("Unable to create CGImage from input")
            return nil
        }
        
        // Convert the NSColor to a reliable RGB format
        let rgbColor = backgroundColor.usingColorSpace(.sRGB) ?? NSColor.white
        
        // Create a semaphore to wait for the asynchronous request
        let semaphore = DispatchSemaphore(value: 0)
        var segmentationResult: CIImage?
        
        // Use Vision for person segmentation if available
        if #available(macOS 12.0, *) {
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .accurate  // Use highest quality for ID photos
            
            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
                
                if let observation = request.results?.first {
                    // Create a CIImage from the mask
                    let maskImage = CIImage(cvPixelBuffer: observation.pixelBuffer)
                    
                    // Create the background color image (solid color)
                    let ciColor = CIColor(red: rgbColor.redComponent,
                                         green: rgbColor.greenComponent,
                                         blue: rgbColor.blueComponent,
                                         alpha: rgbColor.alphaComponent)
                    
                    // Create a solid color background matching the input image dimensions
                    let colorImage = CIImage(color: ciColor).cropped(to: image.extent)
                    
                    // Scale the mask to match the image dimensions
                    let scaleX = image.extent.width / maskImage.extent.width
                    let scaleY = image.extent.height / maskImage.extent.height
                    let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                    
                    // Important: In the VNGeneratePersonSegmentationRequest, black is for person 
                    // and white is for background, but CIBlendWithMask is the opposite
                    // We need to invert the mask
                    let invertFilter = CIFilter(name: "CIColorInvert")
                    invertFilter?.setValue(scaledMask, forKey: kCIInputImageKey)
                    guard let invertedMask = invertFilter?.outputImage else {
                        print("Failed to invert mask")
                        semaphore.signal()
                        return nil
                    }
                    
                    // Improve the mask to reduce edge artifacts
                    // 1. Apply a slight Gaussian blur to soften the mask edges
                    let blurFilter = CIFilter(name: "CIGaussianBlur")
                    blurFilter?.setValue(invertedMask, forKey: kCIInputImageKey)
                    blurFilter?.setValue(0.5, forKey: kCIInputRadiusKey) // Small radius to just soften edges
                    
                    // 2. Use a threshold filter to sharpen the mask after blurring to remove the halo
                    let thresholdFilter = CIFilter(name: "CIColorThreshold")
                    thresholdFilter?.setValue(blurFilter?.outputImage ?? invertedMask, forKey: kCIInputImageKey)
                    thresholdFilter?.setValue(0.05, forKey: "inputThreshold") // Lower threshold to capture more of the person
                    
                    // Get the refined mask
                    let refinedMask = thresholdFilter?.outputImage ?? invertedMask
                    
                    // 3. Apply a slight choke/erode to reduce edge artifacts
                    let chokeFilter = CIFilter(name: "CIMorphologyRectangleMinimum")
                    chokeFilter?.setValue(refinedMask, forKey: kCIInputImageKey)
                    chokeFilter?.setValue(2.0, forKey: "inputWidth") // Width of the morphological operation
                    chokeFilter?.setValue(2.0, forKey: "inputHeight") // Height of the morphological operation
                    
                    let finalMask = chokeFilter?.outputImage ?? refinedMask
                    
                    // Apply the refined mask - background (color) as input image, person (original) as background 
                    if let blendFilter = CIFilter(name: "CIBlendWithMask") {
                        blendFilter.setValue(colorImage, forKey: kCIInputImageKey) 
                        blendFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
                        blendFilter.setValue(finalMask, forKey: kCIInputMaskImageKey)
                        
                        segmentationResult = blendFilter.outputImage
                        
                        if segmentationResult != nil {
                            print("Person segmentation successful with enhanced mask")
                        } else {
                            print("Person segmentation blending failed")
                        }
                    }
                } else {
                    print("No person segmentation results")
                }
                
                // Signal after the processing is complete
                semaphore.signal()
            } catch {
                print("Error performing person segmentation: \(error)")
                semaphore.signal()
            }
        } else {
            // Fallback for older macOS versions
            print("Advanced person segmentation not available on this macOS version")
            segmentationResult = nil
            semaphore.signal()
        }
        
        // Wait for the processing to complete
        _ = semaphore.wait(timeout: .now() + 5.0)
        
        return segmentationResult
    }
    
    // Face detection for auto-positioning
    func detectFace(in image: NSImage, completion: @escaping (CGRect?) -> Void) {
        // Convert NSImage to CGImage for Vision
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else {
            print("Failed to convert image for face detection")
            completion(nil)
            return
        }
        
        // Create a face detection request with better configuration
        let faceDetectionRequest = VNDetectFaceLandmarksRequest { request, error in
            if let error = error {
                print("Face detection error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            // Get all detected faces
            guard let observations = request.results as? [VNFaceObservation], !observations.isEmpty else {
                print("No faces detected with landmarks. Trying basic face detection...")
                
                // Fallback to basic face detection
                let basicRequest = VNDetectFaceRectanglesRequest { request, error in
                    guard let faces = request.results as? [VNFaceObservation], !faces.isEmpty else {
                        print("No faces detected with basic detection either")
                        completion(nil)
                        return
                    }
                    
                    // Process the first face from basic detection
                    self.processFaceObservation(faces[0], imageSize: CGSize(width: cgImage.width, height: cgImage.height), completion: completion)
                }
                
                // Use a different configuration for basic detection
                basicRequest.revision = VNDetectFaceRectanglesRequestRevision1
                
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([basicRequest])
                } catch {
                    print("Basic face detection failed: \(error)")
                    completion(nil)
                }
                return
            }
            
            // If multiple faces are detected, prioritize:
            // 1. Largest face (likely closest to camera/main subject)
            // 2. Face closest to center of the image
            if observations.count > 1 {
                print("Multiple faces detected (\(observations.count)). Finding the most prominent one...")
                
                let imageCenter = CGPoint(x: 0.5, y: 0.5) // Normalized image center
                var bestFace: VNFaceObservation?
                var bestScore: CGFloat = -1
                
                for face in observations {
                    // Calculate face size (area)
                    let faceSize = face.boundingBox.width * face.boundingBox.height
                    
                    // Calculate distance from center (normalized coordinates)
                    let faceCenter = CGPoint(
                        x: face.boundingBox.midX,
                        y: face.boundingBox.midY
                    )
                    let distanceFromCenter = sqrt(
                        pow(faceCenter.x - imageCenter.x, 2) +
                        pow(faceCenter.y - imageCenter.y, 2)
                    )
                    
                    // Score combines size (75% weight) and proximity to center (25% weight)
                    // Higher is better
                    let score = (faceSize * 0.75) + ((1 - distanceFromCenter) * 0.25)
                    
                    if score > bestScore {
                        bestScore = score
                        bestFace = face
                    }
                }
                
                if let bestFace = bestFace {
                    print("Selected best face with score: \(bestScore)")
                    self.processFaceObservation(bestFace, imageSize: CGSize(width: cgImage.width, height: cgImage.height), completion: completion)
                } else {
                    // Fallback to first face if scoring fails
                    self.processFaceObservation(observations[0], imageSize: CGSize(width: cgImage.width, height: cgImage.height), completion: completion)
                }
            } else {
                // Just one face - process it
                self.processFaceObservation(observations[0], imageSize: CGSize(width: cgImage.width, height: cgImage.height), completion: completion)
            }
        }
        
        // Configure the request for better detection
        faceDetectionRequest.revision = VNDetectFaceLandmarksRequestRevision3
        
        // Perform the request
        do {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try requestHandler.perform([faceDetectionRequest])
        } catch {
            print("Failed to perform face detection: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    // Helper method to process face detection results
    private func processFaceObservation(_ face: VNFaceObservation, imageSize: CGSize, completion: @escaping (CGRect?) -> Void) {
        // Convert normalized coordinates to image coordinates
        let faceBounds = face.boundingBox
        let imageWidth = imageSize.width
        let imageHeight = imageSize.height
        
        // VNBoundingBox is in normalized coordinates (0-1) with origin at bottom left
        // Convert to CGRect with origin at top left
        let rect = CGRect(
            x: faceBounds.minX * imageWidth,
            y: (1 - faceBounds.maxY) * imageHeight,
            width: faceBounds.width * imageWidth,
            height: faceBounds.height * imageHeight
        )
        
        print("Face detected at: \(rect)")
        
        // If we have landmarks, we can make a more precise bounding box
        if let landmarks = face.landmarks {
            // Get all points from landmarks
            var allPoints: [CGPoint] = []
            
            // Add all facial feature points we have
            if let faceContour = landmarks.faceContour?.normalizedPoints {
                allPoints.append(contentsOf: faceContour)
            }
            if let leftEye = landmarks.leftEye?.normalizedPoints {
                allPoints.append(contentsOf: leftEye)
            }
            if let rightEye = landmarks.rightEye?.normalizedPoints {
                allPoints.append(contentsOf: rightEye)
            }
            if let nose = landmarks.nose?.normalizedPoints {
                allPoints.append(contentsOf: nose)
            }
            if let outerLips = landmarks.outerLips?.normalizedPoints {
                allPoints.append(contentsOf: outerLips)
            }
            
            // If we have enough points, calculate a more accurate bounding box
            if allPoints.count > 10 {
                // Convert normalized points to image coordinates
                let imagePoints = allPoints.map { point in
                    return CGPoint(
                        x: (faceBounds.origin.x + point.x * faceBounds.width) * imageWidth,
                        y: (1 - (faceBounds.origin.y + point.y * faceBounds.height)) * imageHeight
                    )
                }
                
                // Find min/max coordinates to create new bounding box
                let minX = imagePoints.min { $0.x < $1.x }?.x ?? rect.minX
                let minY = imagePoints.min { $0.y < $1.y }?.y ?? rect.minY
                let maxX = imagePoints.max { $0.x < $1.x }?.x ?? rect.maxX
                let maxY = imagePoints.max { $0.y < $1.y }?.y ?? rect.maxY
                
                // Create refined bounding box with some padding
                let padding: CGFloat = 20 // Add some padding around the face
                let refinedRect = CGRect(
                    x: max(0, minX - padding),
                    y: max(0, minY - padding),
                    width: min(imageWidth, maxX - minX + (padding * 2)),
                    height: min(imageHeight, maxY - minY + (padding * 2))
                )
                
                print("Refined face bounds using landmarks: \(refinedRect)")
                completion(refinedRect)
                return
            }
        }
        
        // If we don't have landmarks or not enough points, use the regular bounding box
        completion(rect)
    }
    
    // Convert NSImage to CIImage
    private func convertNSImageToCIImage(_ nsImage: NSImage) -> CIImage? {
        guard let data = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data),
              let cgImage = bitmap.cgImage else {
            return nil
        }
        
        return CIImage(cgImage: cgImage)
    }
    
    // Convert CIImage to NSImage
    private func convertCIImageToNSImage(_ ciImage: CIImage) -> NSImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let nsImage = NSImage(cgImage: cgImage, size: size)
        return nsImage
    }
    
    // Apply zoom, offset, and rotation transformations
    private func applyTransformations(
        to image: CIImage,
        zoomScale: CGFloat,
        offset: CGSize,
        rotationAngle: Double
    ) -> CIImage {
        // Get the center of the image
        let centerX = image.extent.midX
        let centerY = image.extent.midY
        
        // Create an affine transform that combines zoom, rotation, and translation
        var transform = CGAffineTransform.identity
        
        // Apply translation to center first
        transform = transform.translatedBy(x: -centerX, y: -centerY)
        
        // Scale
        transform = transform.scaledBy(x: zoomScale, y: zoomScale)
        
        // Rotate
        let rotationInRadians = CGFloat(-rotationAngle) * .pi / 180.0  // Use negative angle to reverse direction
        transform = transform.rotated(by: rotationInRadians)
        
        // Translate back and apply additional offset
        transform = transform.translatedBy(x: centerX + offset.width, y: centerY + offset.height)
        
        // Apply the combined transform
        return image.transformed(by: transform)
    }
    
    // Crop image based on the visible frame
    private func cropToFrame(image: CIImage, frameSize: CGSize, frameOffset: CGSize) -> CIImage {
        // If frameSize is zero (not yet initialized), return the original image
        if frameSize.width <= 0 || frameSize.height <= 0 {
            return image
        }
        
        // Get the center of the image
        let centerX = image.extent.midX
        let centerY = image.extent.midY
        
        // Calculate the scale factor for the final output (ensure high resolution)
        let dpi: CGFloat = 300
        let inchesPerMM: CGFloat = 1 / 25.4  // 1 mm = 1/25.4 inches
        
        // Calculate the pixel dimensions at the target DPI
        // For ID photos, we need millimeter accuracy, so use mm conversion
        let scaledWidth = frameSize.width * dpi * inchesPerMM
        let scaledHeight = frameSize.height * dpi * inchesPerMM
        
        // Apply the frameOffset to the crop position
        // Note: frameOffset is in UI points but needs to be scaled for the actual pixels
        let scaleFactor = image.extent.width / 400  // Assuming 400pt is the display width
        
        let cropRect = CGRect(
            x: centerX - (scaledWidth / 2) + (frameOffset.width * scaleFactor),
            y: centerY - (scaledHeight / 2) + (frameOffset.height * scaleFactor),
            width: scaledWidth,
            height: scaledHeight
        )
        
        // Apply crop
        return image.cropped(to: cropRect)
    }
    
  }

