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
            rotationTransform.rotate(byDegrees: CGFloat(rotationAngle))
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
        backgroundColor: NSColor
    ) -> NSImage? {
        print("DEBUG - Processing image with params:")
        print("  - zoomScale: \(zoomScale)")
        print("  - rotationAngle: \(rotationAngle)")
        print("  - offset: \(offset)")
        print("  - frameSize: \(frameSize)")
        
        // Step 1: Create a perfectly cropped image using the same rendering logic as the preview
        let resultImage = renderImageInFrame(
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
        let formatDimensions = format.dimensions
        let finalWidth = formatDimensions.width * mmToPixel
        let finalHeight = formatDimensions.height * mmToPixel
        
        // Step 3: Create final image at the correct dimensions
        let finalImage = NSImage(size: NSSize(width: finalWidth, height: finalHeight))
        
        finalImage.lockFocus()
        
        // Use high quality interpolation for the final export
        NSGraphicsContext.current?.imageInterpolation = .high
        
        // Simply scale the resultImage, preserving exactly what was shown in the preview
        resultImage.draw(in: NSRect(origin: .zero, size: finalImage.size),
                       from: .zero,
                       operation: .copy,
                       fraction: 1.0)
        
        finalImage.unlockFocus()
        
        print("Final image created with size: \(finalImage.size)")
        return finalImage
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
        // Option 1: Color-based background removal (prioritized for ID photos)
        if let colorBasedImage = replaceBackgroundByColor(image: croppedImage, newColor: backgroundColor) {
            finalImage = colorBasedImage
            print("Using color-based background removal")
        }
        // Option 2: Person segmentation (fallback for complex cases)
        else if let segmentedImage = segmentPerson(in: croppedImage, backgroundColor: backgroundColor) {
            finalImage = segmentedImage
            print("Using person segmentation for background replacement")
        }
        // Option 3: Fallback - just use cropped image
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
                    let invertedMask = invertFilter?.outputImage ?? scaledMask
                    
                    // Apply the mask - background (color) as input image, person (original) as background 
                    if let blendFilter = CIFilter(name: "CIBlendWithMask") {
                        blendFilter.setValue(colorImage, forKey: kCIInputImageKey) 
                        blendFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
                        blendFilter.setValue(invertedMask, forKey: kCIInputMaskImageKey)
                        
                        segmentationResult = blendFilter.outputImage
                        
                        if segmentationResult != nil {
                            print("Person segmentation successful")
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
            completion(nil)
            return
        }
        
        // Create a face detection request
        let faceDetectionRequest = VNDetectFaceRectanglesRequest { request, error in
            if let error = error {
                print("Face detection error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            // Get the first detected face
            guard let observations = request.results as? [VNFaceObservation],
                  let firstFace = observations.first else {
                print("No faces detected")
                completion(nil)
                return
            }
            
            // Convert normalized coordinates to image coordinates
            let faceBounds = firstFace.boundingBox
            let imageWidth = CGFloat(cgImage.width)
            let imageHeight = CGFloat(cgImage.height)
            
            // VNBoundingBox is in normalized coordinates (0-1) with origin at bottom left
            // Convert to CGRect with origin at top left
            let rect = CGRect(
                x: faceBounds.minX * imageWidth,
                y: (1 - faceBounds.maxY) * imageHeight,
                width: faceBounds.width * imageWidth,
                height: faceBounds.height * imageHeight
            )
            
            completion(rect)
        }
        
        // Perform the request
        do {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try requestHandler.perform([faceDetectionRequest])
        } catch {
            print("Failed to perform face detection: \(error.localizedDescription)")
            completion(nil)
        }
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
        let rotationInRadians = CGFloat(rotationAngle) * .pi / 180.0
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
    
    // Apply final image enhancements for a more professional look
    private func applyFinalEnhancements(to image: CIImage) -> CIImage {
        var result = image
        
        // Apply subtle sharpening if enhancement strength > 0.5
        if enhancementStrength > 0.5, let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(result, forKey: kCIInputImageKey)
            sharpenFilter.setValue(enhancementStrength * 0.5, forKey: kCIInputSharpnessKey)
            
            if let sharpened = sharpenFilter.outputImage {
                result = sharpened
            }
        }
        
        // Apply subtle noise reduction
        if let noiseReductionFilter = CIFilter(name: "CINoiseReduction") {
            noiseReductionFilter.setValue(result, forKey: kCIInputImageKey)
            noiseReductionFilter.setValue(enhancementStrength * 0.02, forKey: "inputNoiseLevel")
            noiseReductionFilter.setValue(enhancementStrength * 0.4, forKey: "inputSharpness")
            
            if let noiseReduced = noiseReductionFilter.outputImage {
                result = noiseReduced
            }
        }
        
        return result
    }
    
    // Completely revised background replacement method
    private func replaceBackground(image: CIImage, backgroundColor: Color) -> CIImage {
        // Convert SwiftUI Color to NSColor to CIColor
        let nsColor = NSColor(backgroundColor)
        guard let ciBackgroundColor = CIColor(color: nsColor) else {
            return image
        }
        
        // Create solid color background
        let backgroundImage = CIImage(color: ciBackgroundColor).cropped(to: image.extent)
        
        // Try to use advanced portrait segmentation if available (iOS 12+/macOS 10.14+)
        if useAdvancedProcessing, let advancedMask = createAdvancedPersonSegmentationMask(for: image) {
            return applyMaskToImage(image: image, mask: advancedMask, background: backgroundImage)
        }
        
        // Fall back to face-based approach if advanced segmentation fails
        if let faceBasedMask = createFaceBasedMask(for: image) {
            return applyMaskToImage(image: image, mask: faceBasedMask, background: backgroundImage)
        }
        
        // Fall back to general approach if face detection fails
        let generalMask = createGeneralBackgroundMask(for: image, backgroundColor: backgroundColor)
        return applyMaskToImage(image: image, mask: generalMask, background: backgroundImage)
    }
    
    // Create a mask specifically designed for portrait/ID photos focused on the face
    private func createFaceBasedMask(for image: CIImage) -> CIImage? {
        // Use Vision framework to detect faces
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return nil
        }
        
        var faceMask: CIImage?
        let semaphore = DispatchSemaphore(value: 0)
        
        // Create a request to detect faces
        let request = VNDetectFaceRectanglesRequest { (request, error) in
            guard error == nil,
                  let results = request.results as? [VNFaceObservation],
                  !results.isEmpty else {
                semaphore.signal()
                return
            }
            
            // Create a blank (black) image to draw the mask
            let maskImage = CIImage(color: CIColor(red: 0, green: 0, blue: 0))
                .cropped(to: image.extent)
            
            // For each detected face, create a white ellipse slightly larger than the face
            var compositeMask = maskImage
            
            for faceObservation in results {
                // Convert normalized coordinates to pixel coordinates
                let faceRect = VNImageRectForNormalizedRect(
                    faceObservation.boundingBox,
                    Int(image.extent.width),
                    Int(image.extent.height)
                )
                
                // Create an enlarged ellipse around the face for better coverage
                // Use a larger enlargement factor for ID photos
                let enlargementFactor: CGFloat = 2.0 // Increased for better head/hair coverage
                let centerX = faceRect.midX
                let centerY = faceRect.midY
                let ellipseWidth = faceRect.width * enlargementFactor
                let ellipseHeight = faceRect.height * 2.0 * enlargementFactor // Much taller to include hair/shoulders
                
                // Create a white ellipse filter
                guard let radialGradient = CIFilter(name: "CIRadialGradient") else {
                    continue
                }
                
                // Define the gradient from white center to black edge
                let white = CIColor(red: 1, green: 1, blue: 1)
                let black = CIColor(red: 0, green: 0, blue: 0)
                
                // Set center as a CIVector instead of separate x and y components
                radialGradient.setValue(CIVector(x: centerX, y: centerY), forKey: "inputCenter")
                radialGradient.setValue(min(ellipseWidth, ellipseHeight) / 2.0, forKey: "inputRadius0")
                radialGradient.setValue(max(ellipseWidth, ellipseHeight) / 1.8, forKey: "inputRadius1")
                radialGradient.setValue(white, forKey: "inputColor0")
                radialGradient.setValue(black, forKey: "inputColor1")
                
                if let ellipseMask = radialGradient.outputImage?.cropped(to: image.extent) {
                    // Combine with existing mask (take maximum of the two masks)
                    guard let blendFilter = CIFilter(name: "CIMaximumCompositing") else {
                        continue
                    }
                    
                    blendFilter.setValue(compositeMask, forKey: kCIInputImageKey)
                    blendFilter.setValue(ellipseMask, forKey: kCIInputBackgroundImageKey)
                    
                    if let blendedMask = blendFilter.outputImage {
                        compositeMask = blendedMask
                    }
                }
            }
            
            // Apply some smoothing to the mask with more intensive blur for smoother edges
            guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
                semaphore.signal()
                return
            }
            
            blurFilter.setValue(compositeMask, forKey: kCIInputImageKey)
            blurFilter.setValue(8.0, forKey: kCIInputRadiusKey) // Increased blur for smoother transitions
            
            if let smoothedMask = blurFilter.outputImage {
                faceMask = smoothedMask
            }
            
            semaphore.signal()
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Face detection failed: \(error.localizedDescription)")
            semaphore.signal()
        }
        
        // Wait for the processing to complete
        _ = semaphore.wait(timeout: .now() + 5)
        return faceMask
    }
    
    // Apply a mask to an image using blend filter
    private func applyMaskToImage(image: CIImage, mask: CIImage, background: CIImage) -> CIImage {
        // Use CIBlendWithMask filter with better parameters
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            return image
        }
        
        // Set up filter with key-value coding
        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(background, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(mask, forKey: kCIInputMaskImageKey)
        
        // Get output image or return original if filter fails
        guard let outputImage = blendFilter.outputImage else {
            return image
        }
        
        return outputImage
    }
    
    // Helper method removed as it's no longer needed with the improved algorithm
    private func createAdaptiveThreshold(for image: CIImage) -> CIImage? {
        // Enhanced in applyBackgroundReplacement method
        return nil
    }
    
    // New advanced person segmentation for better background removal
    private func createAdvancedPersonSegmentationMask(for image: CIImage) -> CIImage? {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return nil
        }
        
        var personMask: CIImage?
        let semaphore = DispatchSemaphore(value: 0)
        
        // Use Vision's person segmentation request if available (iOS 15+/macOS 12+)
        if #available(macOS 12.0, *) {
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .accurate
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
                
                if let maskPixelBuffer = request.results?.first?.pixelBuffer {
                    // Convert the mask to a CIImage
                    let maskCIImage = CIImage(cvPixelBuffer: maskPixelBuffer)
                    
                    // Apply a slight blur for smoother edges
                    if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                        blurFilter.setValue(maskCIImage, forKey: kCIInputImageKey)
                        blurFilter.setValue(3.0, forKey: kCIInputRadiusKey)
                        
                        if let blurredMask = blurFilter.outputImage {
                            // Scale the mask to match the original image size
                            let scaleX = image.extent.width / maskCIImage.extent.width
                            let scaleY = image.extent.height / maskCIImage.extent.height
                            
                            let scaleTransform = CGAffineTransform(scaleX: scaleX, y: scaleY)
                            personMask = blurredMask.transformed(by: scaleTransform)
                        }
                    }
                }
            } catch {
                print("Person segmentation failed: \(error.localizedDescription)")
            }
        }
        
        semaphore.signal()
        _ = semaphore.wait(timeout: .now() + 2)
        
        return personMask
    }
    
    // Create a general background mask as a last resort
    private func createGeneralBackgroundMask(for image: CIImage, backgroundColor: Color) -> CIImage {
        // Extract luminance as before
        guard let luminanceFilter = CIFilter(name: "CIColorMatrix") else {
            return CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: image.extent)
        }
        
        luminanceFilter.setValue(image, forKey: kCIInputImageKey)
        // RGB to luminance conversion using standard coefficients
        luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputRVector")
        luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputGVector")
        luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputBVector")
        
        guard let luminanceImage = luminanceFilter.outputImage else {
            return CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: image.extent)
        }
        
        // Determine if background is light or dark
        let backgroundColor = NSColor(backgroundColor)
        let isLightBackground = backgroundColor.brightnessComponent > 0.5
        
        // Use more sophisticated edge detection
        guard let edgeFilter = CIFilter(name: "CIEdges") else {
            return luminanceImage
        }
        
        edgeFilter.setValue(luminanceImage, forKey: kCIInputImageKey)
        edgeFilter.setValue(2.0, forKey: "inputIntensity")
        
        guard let edgeImage = edgeFilter.outputImage else {
            return luminanceImage
        }
        
        // Invert the edge image for light backgrounds
        var maskImage = edgeImage
        if isLightBackground {
            guard let colorInvert = CIFilter(name: "CIColorInvert") else {
                return edgeImage
            }
            
            colorInvert.setValue(edgeImage, forKey: kCIInputImageKey)
            
            if let inverted = colorInvert.outputImage {
                maskImage = inverted
            }
        }
        
        // Apply a threshold operation
        guard let thresholdFilter = CIFilter(name: "CIColorThreshold") else {
            return maskImage
        }
        
        thresholdFilter.setValue(maskImage, forKey: kCIInputImageKey)
        thresholdFilter.setValue(isLightBackground ? 0.4 : 0.6, forKey: "inputThreshold")
        
        guard let thresholdImage = thresholdFilter.outputImage else {
            return maskImage
        }
        
        // Apply a blur for smoother edges
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            return thresholdImage
        }
        
        blurFilter.setValue(thresholdImage, forKey: kCIInputImageKey)
        blurFilter.setValue(5.0, forKey: kCIInputRadiusKey)
        
        if let blurredMask = blurFilter.outputImage {
            return blurredMask
        }
        
        return thresholdImage
    }
    
    // Color-based background removal method
    private func replaceBackgroundByColor(image: CIImage, newColor: NSColor) -> CIImage? {
        // Convert the background color to CIColor
        let rgbColor = newColor.usingColorSpace(.sRGB) ?? NSColor.white
        let ciBackgroundColor = CIColor(red: rgbColor.redComponent,
                                       green: rgbColor.greenComponent,
                                       blue: rgbColor.blueComponent,
                                       alpha: rgbColor.alphaComponent)
        
        // Create solid color background
        let backgroundImage = CIImage(color: ciBackgroundColor).cropped(to: image.extent)
        
        // Step 1: Detect dominant background colors
        var backgroundColors = detectBackgroundColors(in: image)
        
        // Always add white as a potential background color for ID photos
        // This is crucial for standard white-background ID photos
        backgroundColors.append(CIColor(red: 1.0, green: 1.0, blue: 1.0))
        
        print("Detected \(backgroundColors.count) background colors (including forced white)")
        
        // Step 2: Create a mask based on color similarity (white for background, black for foreground)
        // Use a much higher tolerance for white backgrounds (common in ID photos)
        let mask = createColorSimilarityMask(for: image, 
                                            targetColors: backgroundColors, 
                                            tolerance: 0.25) // Increased from 0.15 to 0.25
        
        // Step 3: Apply the mask to blend original image with new background
        if let mask = mask {
            print("Created background mask with extent: \(mask.extent)")
            
            // Use CIBlendWithMask filter
            // This filter uses the mask to determine how to blend the two images
            // White areas in the mask show the input image (background color)
            // Black areas in the mask show the background image (original person)
            if let blendFilter = CIFilter(name: "CIBlendWithMask") {
                blendFilter.setValue(backgroundImage, forKey: kCIInputImageKey)
                blendFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
                blendFilter.setValue(mask, forKey: kCIInputMaskImageKey)
                
                if let result = blendFilter.outputImage {
                    print("Successfully created background replacement with dimensions: \(result.extent)")
                    return result
                }
            }
        }
        
        print("Failed to create background replacement using color detection")
        return nil
    }
    
    // Detect the likely background colors by sampling the edges of the image
    private func detectBackgroundColors(in image: CIImage) -> [CIColor] {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return []
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        // Sample points from the edges of the image
        var samplePoints: [(x: Int, y: Int)] = []
        
        // Top edge
        for x in stride(from: 0, to: width, by: width/10) {
            samplePoints.append((x: x, y: 5))
        }
        
        // Bottom edge
        for x in stride(from: 0, to: width, by: width/10) {
            samplePoints.append((x: x, y: height - 5))
        }
        
        // Left edge
        for y in stride(from: 0, to: height, by: height/10) {
            samplePoints.append((x: 5, y: y))
        }
        
        // Right edge
        for y in stride(from: 0, to: height, by: height/10) {
            samplePoints.append((x: width - 5, y: y))
        }
        
        // Create a bitmap context to read pixel data
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let data = calloc(height, bytesPerRow) else {
            return []
        }
        
        guard let context = CGContext(data: data,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: bytesPerRow,
                                     space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            free(data)
            return []
        }
        
        // Draw the image into the context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Read color samples
        var colors: [CIColor] = []
        for point in samplePoints {
            let offset = point.y * bytesPerRow + point.x * bytesPerPixel
            let pixelData = data.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
            
            let r = CGFloat(pixelData[0]) / 255.0
            let g = CGFloat(pixelData[1]) / 255.0
            let b = CGFloat(pixelData[2]) / 255.0
            let a = CGFloat(pixelData[3]) / 255.0
            
            colors.append(CIColor(red: r, green: g, blue: b, alpha: a))
        }
        
        free(data)
        
        // Group similar colors and return the most common
        return findDominantColors(from: colors, maxColors: 3)
    }
    
    // Find dominant colors from a set of samples
    private func findDominantColors(from colors: [CIColor], maxColors: Int) -> [CIColor] {
        var colorGroups: [[CIColor]] = []
        
        // Group similar colors
        for color in colors {
            var addedToGroup = false
            
            for i in 0..<colorGroups.count {
                let groupColor = colorGroups[i].first!
                
                // Check if colors are similar
                if colorDistance(color1: color, color2: groupColor) < 0.1 {
                    colorGroups[i].append(color)
                    addedToGroup = true
                    break
                }
            }
            
            if !addedToGroup {
                colorGroups.append([color])
            }
        }
        
        // Sort by group size (most frequent colors first)
        colorGroups.sort { $0.count > $1.count }
        
        // Return the average color from each of the largest groups
        var dominantColors: [CIColor] = []
        for i in 0..<min(maxColors, colorGroups.count) {
            let group = colorGroups[i]
            let avgR = group.reduce(0.0) { $0 + $1.red } / CGFloat(group.count)
            let avgG = group.reduce(0.0) { $0 + $1.green } / CGFloat(group.count)
            let avgB = group.reduce(0.0) { $0 + $1.blue } / CGFloat(group.count)
            let avgA = group.reduce(0.0) { $0 + $1.alpha } / CGFloat(group.count)
            
            dominantColors.append(CIColor(red: avgR, green: avgG, blue: avgB, alpha: avgA))
        }
        
        return dominantColors
    }
    
    // Calculate distance between colors in RGB space
    private func colorDistance(color1: CIColor, color2: CIColor) -> CGFloat {
        let rDiff = color1.red - color2.red
        let gDiff = color1.green - color2.green
        let bDiff = color1.blue - color2.blue
        
        return sqrt(rDiff*rDiff + gDiff*gDiff + bDiff*bDiff)
    }
    
    // Create a mask where white pixels represent background (colors to replace)
    private func createColorSimilarityMask(for image: CIImage, targetColors: [CIColor], tolerance: CGFloat) -> CIImage? {
        // Use the Core Image color distance filter
        guard let distanceFilter = CIFilter(name: "CIColorMonochrome") else {
            return nil
        }
        
        let luminance = convertToLuminance(image: image)
        
        var totalMask: CIImage?
        
        for targetColor in targetColors {
            // Determine if this is a white/light color 
            let isWhiteColor = targetColor.red > 0.9 && targetColor.green > 0.9 && targetColor.blue > 0.9
            
            // Use a higher tolerance for white
            let effectiveTolerance = isWhiteColor ? tolerance * 1.5 : tolerance
            
            // Create a color cube filter for this target color
            guard let colorCube = CIFilter(name: "CIColorCube") else {
                continue
            }
            
            // Create a color cube that replaces target color with white, others with black
            let size = 64 // Cube dimension
            let cubeSize = size * size * size * 4 // 4 bytes per color (RGBA)
            let cubeData = UnsafeMutablePointer<Float>.allocate(capacity: cubeSize)
            defer { cubeData.deallocate() }
            
            // For each color in our cube
            for z in 0..<size {
                let blue = CGFloat(z) / CGFloat(size-1)
                for y in 0..<size {
                    let green = CGFloat(y) / CGFloat(size-1)
                    for x in 0..<size {
                        let red = CGFloat(x) / CGFloat(size-1)
                        
                        let offset = z * size * size + y * size + x
                        
                        // Calculate color distance
                        let pixelColor = CIColor(red: red, green: green, blue: blue)
                        var distance = colorDistance(color1: pixelColor, color2: targetColor)
                        
                        // For white/light colors, use a more forgiving distance calculation
                        // that puts more emphasis on lightness than color
                        if isWhiteColor {
                            let pixelLightness = (red + green + blue) / 3.0
                            let targetLightness = (targetColor.red + targetColor.green + targetColor.blue) / 3.0
                            
                            // Adjust distance to favor lightness similarity for white backgrounds
                            let lightnessDistance = abs(pixelLightness - targetLightness) * 2.0
                            distance = min(distance, lightnessDistance)
                        }
                        
                        // If color is close to target, make it white in mask (1.0)
                        // otherwise black (0.0)
                        let isBackground = distance < effectiveTolerance
                        
                        // Set RGB components (white for background, black for foreground)
                        cubeData[offset * 4] = isBackground ? 1.0 : 0.0     // R
                        cubeData[offset * 4 + 1] = isBackground ? 1.0 : 0.0 // G
                        cubeData[offset * 4 + 2] = isBackground ? 1.0 : 0.0 // B
                        cubeData[offset * 4 + 3] = 1.0                      // A (always opaque)
                    }
                }
            }
            
            // Create the color cube
            let data = Data(bytes: cubeData, count: cubeSize * MemoryLayout<Float>.size)
            colorCube.setValue(size, forKey: "inputCubeDimension")
            colorCube.setValue(data, forKey: "inputCubeData")
            colorCube.setValue(image, forKey: kCIInputImageKey)
            
            guard let colorMask = colorCube.outputImage else {
                continue
            }
            
            // Combine with existing mask
            if let existingMask = totalMask {
                guard let maxFilter = CIFilter(name: "CIMaximumCompositing") else {
                    continue
                }
                
                maxFilter.setValue(existingMask, forKey: kCIInputImageKey)
                maxFilter.setValue(colorMask, forKey: kCIInputBackgroundImageKey)
                
                totalMask = maxFilter.outputImage
            } else {
                totalMask = colorMask
            }
        }
        
        guard let finalMask = totalMask else {
            return nil
        }
        
        // Apply a blur to smooth the mask
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            return finalMask
        }
        
        blurFilter.setValue(finalMask, forKey: kCIInputImageKey)
        blurFilter.setValue(2.0, forKey: kCIInputRadiusKey)
        
        return blurFilter.outputImage
    }
    
    // Convert image to luminance (grayscale)
    private func convertToLuminance(image: CIImage) -> CIImage? {
        guard let filter = CIFilter(name: "CIColorMatrix") else {
            return nil
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputRVector")
        filter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputGVector")
        filter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputBVector")
        
        return filter.outputImage
    }
    
    // Apply color mask to original image
    private func applyColorMask(originalImage: CIImage, backgroundImage: CIImage, mask: CIImage) -> CIImage? {
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            return nil
        }
        
        blendFilter.setValue(backgroundImage, forKey: kCIInputImageKey)
        blendFilter.setValue(originalImage, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(mask, forKey: kCIInputMaskImageKey)
        
        return blendFilter.outputImage
    }
}

