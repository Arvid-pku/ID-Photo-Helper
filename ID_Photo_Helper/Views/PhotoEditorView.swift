import SwiftUI

struct PhotoEditorView: View {
    @ObservedObject var viewModel: PhotoProcessorViewModel
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @State private var frameSize: CGSize = .zero
    
    // Computed properties for preview dimensions
    private var previewDimensions: (width: CGFloat, height: CGFloat, aspectRatio: CGFloat) {
        let dimensions = viewModel.selectedPhotoFormat.dimensions
        let aspectRatio = dimensions.width / dimensions.height
        let previewHeight: CGFloat = 200
        let previewWidth = previewHeight * aspectRatio
        return (previewWidth, previewHeight, aspectRatio)
    }
    
    // Extract preview view to separate method to avoid variable declarations in the view builder
    @ViewBuilder
    private func previewContent() -> some View {
        let previewWidth = previewDimensions.width
        let previewHeight = previewDimensions.height
        let aspectRatio = previewDimensions.aspectRatio
        
        // Always return a VStack with either the preview or placeholder
        VStack {
            if let image = viewModel.selectedImage {
                // Define local variables
                let frameHeight: CGFloat = 200 // Must match the height in FixedFormatFrame
                let frameWidth = frameHeight * aspectRatio
                let editorDisplayDimension: CGFloat = 400.0
                let originalSize = image.size
                let s_fit: CGFloat = originalSize.width > 0 && originalSize.height > 0 
                    ? min(editorDisplayDimension / originalSize.width, editorDisplayDimension / originalSize.height)
                    : 1.0
                let effectiveZoomScale = s_fit * viewModel.zoomScale
                
                // Invert the y-offset for the preview to make movements consistent
                let previewOffset = CGSize(
                    width: viewModel.offset.width,
                    height: -viewModel.offset.height // Invert the Y direction
                )
                
                // The actual view
                LivePreviewView(
                    sourceImage: viewModel.selectedImage,
                    zoomScale: effectiveZoomScale,
                    rotationAngle: viewModel.rotationAngle,
                    offset: previewOffset, // Use the inverted offset
                    frameSize: CGSize(width: frameWidth, height: frameHeight),
                    backgroundColor: viewModel.selectedBackgroundColor
                )
                .frame(width: previewWidth, height: previewHeight)
            } else {
                Rectangle()
                    .fill(viewModel.selectedBackgroundColor)
                    .frame(width: previewWidth, height: previewHeight)
                    .border(Color.gray)
                    .overlay(
                        Text("Select an image")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .padding(10)
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(4)
    }
    
    // Extract the draggable image section to avoid variable declarations in the view builder
    @ViewBuilder
    private func draggableImageView() -> some View {
        // Use the @ViewBuilder attribute to help with conditional content
        if let image = viewModel.selectedImage {
            DraggableImage(
                image: image,
                zoomScale: $viewModel.zoomScale,
                rotationAngle: $viewModel.rotationAngle,
                offset: $viewModel.offset,
                onDrag: { newOffset in
                    viewModel.offset = newOffset
                    viewModel.processImage()
                }
            )
        } else {
            // Return an empty view when there's no image
            EmptyView()
        }
    }
    
    // Extract the frame overlay with its modifiers
    @ViewBuilder
    private func formatFrameView() -> some View {
        FixedFormatFrame(format: viewModel.selectedPhotoFormat)
            .onAppear {
                updateFrameSize()
                viewModel.frameSize = frameSize
                print("Frame size set to: \(frameSize)")
                DispatchQueue.main.async {
                    viewModel.processImage()
                }
            }
            .onChange(of: viewModel.selectedPhotoFormat) { newFormat in
                updateFrameSize()
                viewModel.frameSize = frameSize
                print("Format changed to: \(newFormat.rawValue), new frame size: \(frameSize)")
                DispatchQueue.main.async {
                    viewModel.processImage()
                }
            }
    }
    
    // Extract zoom controls
    @ViewBuilder
    private func zoomControlsView() -> some View {
        HStack {
            Button(action: {
                viewModel.adjustZoom(by: -0.15)
                DispatchQueue.main.async {
                    viewModel.processImage()
                }
            }) {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.bordered)
            
            Text("Zoom: \(Int(viewModel.zoomScale * 100))%")
                .frame(width: 80)
            
            Button(action: {
                viewModel.adjustZoom(by: 0.15)
                DispatchQueue.main.async {
                    viewModel.processImage()
                }
            }) {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.bordered)
        }
    }
    
    // Extract rotation controls
    @ViewBuilder
    private func rotationControlsView() -> some View {
        HStack {
            Button(action: {
                viewModel.rotationAngle -= 5
                DispatchQueue.main.async {
                    viewModel.processImage()
                }
            }) {
                Image(systemName: "rotate.left")
            }
            .buttonStyle(.bordered)
            
            Text("Rotation: \(Int(viewModel.rotationAngle))°")
                .frame(width: 80)
            
            Button(action: {
                viewModel.rotationAngle += 5
                DispatchQueue.main.async {
                    viewModel.processImage()
                }
            }) {
                Image(systemName: "rotate.right")
            }
            .buttonStyle(.bordered)
        }
    }
    
    // Extract face detection button
    @ViewBuilder
    private func faceDetectionButtonView() -> some View {
        Button(action: {
            viewModel.autoPositionFrame()
        }) {
            Label("Auto-Detect Face", systemImage: "face.dashed")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(.top, 8)
    }
    
    // Extract the action buttons
    @ViewBuilder
    private func actionButtonsView() -> some View {
        HStack(spacing: 20) {
            Button("Reset All") {
                viewModel.resetEditing()
                DispatchQueue.main.async {
                    viewModel.processImage()
                }
            }
            .buttonStyle(.bordered)
            
            Button("Center Photo") {
                viewModel.offset = .zero
                DispatchQueue.main.async {
                    viewModel.processImage()
                }
            }
            .buttonStyle(.bordered)
            
            Button("Process Photo") {
                viewModel.processImage()
            }
            .buttonStyle(.borderedProminent)
            
            // Use a conditional approach with EmptyView for the save button
            if viewModel.croppedImage != nil {
                Button("Save") {
                    viewModel.saveProcessedImage()
                }
                .buttonStyle(.bordered)
            } else {
                EmptyView()
            }
        }
        .padding()
    }
    
    var body: some View {
        VStack {
            Text("ID Photo Editor")
                .font(.headline)
                .padding(.top)
            
            Text("Drag the photo to position it within the frame")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack {
                // Left side - editing area
                VStack {
                    Text("Position the photo")
                        .font(.subheadline)
                        .padding(.bottom, 5)
                    
                    ZStack {
                        // Background
                        Rectangle()
                            .fill(Color(.windowBackgroundColor).opacity(0.5))
                            .frame(width: 400, height: 400)
                            .border(Color.gray)
                        
                        // Use the extracted draggable image view
                        draggableImageView()
                        
                        // Use the extracted frame overlay view
                        formatFrameView()
                    }
                    .frame(width: 400, height: 400)
                    .clipped()
                    
                    // Zoom and rotation controls
                    HStack(spacing: 20) {
                        // Use extracted zoom controls
                        zoomControlsView()
                        
                        Divider()
                            .frame(height: 20)
                        
                        // Use extracted rotation controls
                        rotationControlsView()
                    }
                    .padding(.top, 8)
                    
                    // Use extracted face detection button
                    faceDetectionButtonView()
                }
                .padding()
                
                // Right side - preview
                VStack(alignment: .center) {
                    Text("Preview")
                        .font(.subheadline)
                        .padding(.bottom, 5)
                    
                    // Call the extracted method instead of declaring variables here
                    previewContent()
                    
                    PhotoDimensionsInfo(format: viewModel.selectedPhotoFormat)
                }
                .padding()
            }
            
            Spacer()
            
            // Use extracted action buttons view
            actionButtonsView()
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .animation(.interactiveSpring(), value: isDragging)
        .onAppear {
            // Ensure initial processing happens
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if viewModel.selectedImage != nil && viewModel.croppedImage == nil {
                    viewModel.processImage()
                }
            }
        }
    }
    
    // Update frame size based on selected format
    private func updateFrameSize() {
        // Get dimensions from selected format in mm
        let dimensions = viewModel.selectedPhotoFormat.dimensions
        
        // Calculate aspect ratio
        let aspectRatio = dimensions.width / dimensions.height
        
        // Use a fixed height for the frame in the UI
        let frameHeight: CGFloat = 200 // Fixed height in pixels - must match FixedFormatFrame
        let frameWidth = frameHeight * aspectRatio
        
        // Update the local frame size
        frameSize = CGSize(width: frameWidth, height: frameHeight)
        
        // Debug print
        print("Updated frame size: \(frameSize) for format: \(viewModel.selectedPhotoFormat.rawValue), aspect ratio: \(aspectRatio)")
    }
}

// Fixed frame that shows the cropping area
struct FixedFormatFrame: View {
    let format: PhotoFormat
    
    var body: some View {
        // Calculate the aspect ratio based on the format dimensions
        let dimensions = format.dimensions
        let aspectRatio = dimensions.width / dimensions.height
        
        // Use a fixed height and calculate width based on aspect ratio
        let frameHeight: CGFloat = 200
        let frameWidth = frameHeight * aspectRatio
        
        return ZStack {
            // Frame border
            Rectangle()
                .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5]))
                .frame(width: frameWidth, height: frameHeight)
                .overlay(
                    Grid()
                        .stroke(Color.blue.opacity(0.5), lineWidth: 0.5)
                        .frame(width: frameWidth, height: frameHeight)
                )
            
            // Handles at corners for visual feedback
            VStack {
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    Spacer()
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
                Spacer()
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    Spacer()
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: frameWidth - 4, height: frameHeight - 4)
        }
        // Position in the exact center of the 400x400 container
        .position(x: 200, y: 200)
        .onAppear {
            print("Frame dimensions: \(frameWidth) x \(frameHeight) for format \(format.rawValue)")
        }
    }
}

struct Grid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Vertical lines
        let columnWidth = rect.width / 3
        for i in 1..<3 {
            let x = rect.minX + columnWidth * CGFloat(i)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        
        // Horizontal lines
        let rowHeight = rect.height / 3
        for i in 1..<3 {
            let y = rect.minY + rowHeight * CGFloat(i)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        
        return path
    }
}

struct PhotoDimensionsInfo: View {
    let format: PhotoFormat
    
    var body: some View {
        // Calculate dimensions up front
        let dimensions = format.dimensions
        
        VStack(alignment: .leading, spacing: 5) {
            Text("\(format.rawValue) Photo")
                .font(.headline)
            
            Text("Dimensions: \(Int(dimensions.width))mm × \(Int(dimensions.height))mm")
                .font(.caption)
            
            // Format description
            Text(format.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// Custom preview component that directly shows what's in the frame
struct LivePreviewView: View {
    var sourceImage: NSImage?
    var zoomScale: CGFloat
    var rotationAngle: Double
    var offset: CGSize
    var frameSize: CGSize
    var backgroundColor: Color
    
    // Access to the image processor for consistent rendering
    private let imageProcessor = ImageProcessor()
    
    var body: some View {
        // Return the snapshot that shows exactly what's in the blue frame
        if let originalImage = sourceImage {
            // Convert SwiftUI Color to NSColor
            let nsBackgroundColor = NSColor(backgroundColor)
            
            // Use the same rendering method as the final image processing
            let previewImage = imageProcessor.renderImageInFrame(
                originalImage: originalImage,
                zoomScale: zoomScale,
                rotationAngle: rotationAngle,
                offset: offset,
                frameSize: frameSize,
                backgroundColor: nsBackgroundColor
            )
            
            Image(nsImage: previewImage)
                .resizable()
                .scaledToFit()
                .frame(width: frameSize.width, height: frameSize.height)
                .border(Color.red, width: 1) // Red border for the preview to visually distinguish it
        } else {
            // Fallback if no source image is available
            Rectangle()
                .fill(backgroundColor)
                .frame(width: frameSize.width, height: frameSize.height)
                .border(Color.gray, width: 1)
        }
    }
}

// Custom view for draggable image to completely isolate gesture handling
struct DraggableImage: View {
    let image: NSImage
    @Binding var zoomScale: CGFloat
    @Binding var rotationAngle: Double
    @Binding var offset: CGSize
    let onDrag: (CGSize) -> Void
    
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 400, height: 400)
            .scaleEffect(zoomScale)
            .rotationEffect(Angle(degrees: rotationAngle))
            .offset(offset)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { gesture in
                        isDragging = true
                        let newOffset = CGSize(
                            width: offset.width + gesture.translation.width - dragOffset.width,
                            height: offset.height + gesture.translation.height - dragOffset.height
                        )
                        onDrag(newOffset)
                        dragOffset = gesture.translation
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragOffset = .zero
                    }
            )
    }
} 