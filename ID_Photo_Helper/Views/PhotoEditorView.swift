import SwiftUI

struct PhotoEditorView: View {
    @ObservedObject var viewModel: PhotoProcessorViewModel
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @State private var frameSize: CGSize = .zero
    @State private var showPaperLayoutView = false
    @State private var forceRedraw = UUID() // Add a state to force view redraw
    
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
                    backgroundColor: viewModel.selectedBackgroundColor,
                    format: viewModel.selectedPhotoFormat
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
        VStack(spacing: 8) {
            HStack {
                Button(action: {
                    viewModel.adjustZoom(by: -0.05) // Reduced from 0.15 to 0.05 for finer control
                    DispatchQueue.main.async {
                        viewModel.processImage()
                    }
                }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .padding(2) // Add padding to increase hitbox size
                .background(Color(.controlBackgroundColor).opacity(0.01)) // Add near-invisible background to force redraw
                
                Text("Zoom: \(Int(viewModel.zoomScale * 100))%")
                    .frame(width: 80)
                
                Button(action: {
                    viewModel.adjustZoom(by: 0.05) // Reduced from 0.15 to 0.05 for finer control
                    DispatchQueue.main.async {
                        viewModel.processImage()
                    }
                }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .padding(2) // Add padding to increase hitbox size
                .background(Color(.controlBackgroundColor).opacity(0.01)) // Add near-invisible background to force redraw
            }
            
            // Add a slider for precise zoom control
            HStack {
                Text("10%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(
                    value: Binding(
                        get: { viewModel.zoomScale },
                        set: { newValue in
                            viewModel.zoomScale = newValue
                            DispatchQueue.main.async {
                                viewModel.processImage()
                            }
                        }
                    ),
                    in: 0.1...3.0,
                    step: 0.01
                )
                .frame(width: 200)
                
                Text("300%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // Extract rotation controls
    @ViewBuilder
    private func rotationControlsView() -> some View {
        HStack {
            Button(action: {
                viewModel.rotationAngle -= 5  // Back to the original logic
                DispatchQueue.main.async {
                    viewModel.processImage()
                }
            }) {
                Image(systemName: "rotate.left")
            }
            .buttonStyle(.bordered)
            .padding(2) // Add padding to increase hitbox size
            .background(Color(.controlBackgroundColor).opacity(0.01)) // Add near-invisible background to force redraw
            
            Text("Rotation: \(Int(viewModel.rotationAngle))°")
                .frame(width: 80)
            
            Button(action: {
                viewModel.rotationAngle += 5  // Back to the original logic
                DispatchQueue.main.async {
                    viewModel.processImage()
                }
            }) {
                Image(systemName: "rotate.right")
            }
            .buttonStyle(.bordered)
            .padding(2) // Add padding to increase hitbox size
            .background(Color(.controlBackgroundColor).opacity(0.01)) // Add near-invisible background to force redraw
        }
    }
    
    // Extract the action buttons
    @ViewBuilder
    private func actionButtonsView() -> some View {
        VStack {
            HStack(spacing: 15) { // Reduced spacing and added wrapping with VStack
                Button("Reset All") {
                    viewModel.resetEditing()
                    DispatchQueue.main.async {
                        viewModel.processImage()
                    }
                }
                .buttonStyle(.bordered)
                .padding(4)
                .background(Color(.controlBackgroundColor).opacity(0.01))
                
                Button("Center Photo") {
                    viewModel.offset = .zero
                    DispatchQueue.main.async {
                        viewModel.processImage()
                    }
                }
                .buttonStyle(.bordered)
                .padding(4)
                .background(Color(.controlBackgroundColor).opacity(0.01))
                
                Button("Process Photo") {
                    viewModel.processImage()
                }
                .buttonStyle(.borderedProminent)
                .padding(4)
                .background(Color(.controlBackgroundColor).opacity(0.01))
            }
            
            if viewModel.croppedImage != nil {
                HStack(spacing: 15) {
                    Button("Save") {
                        viewModel.saveProcessedImage()
                    }
                    .buttonStyle(.bordered)
                    .padding(4)
                    .background(Color(.controlBackgroundColor).opacity(0.01))
                    
                    Button("Add to Collection") {
                        viewModel.saveToCollection()
                    }
                    .buttonStyle(.bordered)
                    .padding(4)
                    .background(Color(.controlBackgroundColor).opacity(0.01))
                    .help("Add this photo to a collection for arranging on photo paper")
                    
                    Button("Arrange on Paper") {
                        showPaperLayoutView = true
                    }
                    .buttonStyle(.bordered)
                    .padding(4)
                    .background(Color(.controlBackgroundColor).opacity(0.01))
                    .help("Arrange saved photos on a 6-inch photo paper")
                    .disabled(viewModel.savedPhotos.isEmpty)
                }
            }
        }
        .padding()
    }
    
    // Add a method to handle app becoming active
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppBecameActive"),
            object: nil,
            queue: .main
        ) { _ in
            // Force the view to redraw by updating the UUID
            self.forceRedraw = UUID()
        }
    }
    
    var body: some View {
        ScrollView {
            VStack {
                Text("ID Photo Editor")
                    .font(.headline)
                    .padding(.top)
                
                Text("Drag the photo to position it within the frame")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer(minLength: 10)
                
                VStack {
                    // Main content area - can use GeometryReader to respect available space
                    GeometryReader { geometry in
                        let availableWidth = geometry.size.width
                        
                        // If we have enough width for side-by-side layout
                        if availableWidth > 700 {
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
                                }
                                .padding()
                                
                                // Right side - preview
                                VStack(alignment: .center) {
                                    Text("Preview")
                                        .font(.subheadline)
                                        .padding(.bottom, 5)
                                    
                                    // Call the extracted method instead of declaring variables here
                                    previewContent()
                                    
                                    // Add StandardColorPickerView
                                    StandardColorPickerView(selectedColor: $viewModel.selectedBackgroundColor)
                                        .padding(.vertical, 5)
                                    
                                    PhotoDimensionsInfo(format: viewModel.selectedPhotoFormat)
                                }
                                .padding()
                            }
                        } else {
                            // Vertical layout for narrow windows
                            VStack {
                                // Editing area
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
                                    VStack(spacing: 10) {
                                        // Use extracted zoom controls
                                        zoomControlsView()
                                        
                                        Divider()
                                            .frame(width: 100)
                                        
                                        // Use extracted rotation controls
                                        rotationControlsView()
                                    }
                                    .padding(.top, 8)
                                }
                                .padding()
                                
                                // Preview
                                VStack(alignment: .center) {
                                    Text("Preview")
                                        .font(.subheadline)
                                        .padding(.bottom, 5)
                                    
                                    // Call the extracted method instead of declaring variables here
                                    previewContent()
                                    
                                    // Add StandardColorPickerView
                                    StandardColorPickerView(selectedColor: $viewModel.selectedBackgroundColor)
                                        .padding(.vertical, 5)
                                    
                                    PhotoDimensionsInfo(format: viewModel.selectedPhotoFormat)
                                }
                                .padding()
                            }
                        }
                    }
                    .frame(minHeight: 700) // Minimum height for the content area
                }
                
                Spacer(minLength: 10)
                
                // Use extracted action buttons view
                actionButtonsView()
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
        .animation(.interactiveSpring(), value: isDragging)
        .sheet(isPresented: $showPaperLayoutView) {
            PhotoPaperLayoutView(viewModel: viewModel)
        }
        .id(forceRedraw) // Force redraw with ID change
        .onAppear {
            // Setup notifications
            setupNotifications()
            
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
        
        // Calculate pixel dimensions at 300 DPI
        let dpi: CGFloat = 300.0
        let mmToPixel: CGFloat = dpi / 25.4 // Convert mm to pixels at 300 DPI
        let pixelWidth = Int(dimensions.width * mmToPixel)
        let pixelHeight = Int(dimensions.height * mmToPixel)
        
        VStack(alignment: .leading, spacing: 5) {
            Text("\(format.rawValue)")
                .font(.headline)
            
            Text("Dimensions: \(Int(dimensions.width))×\(Int(dimensions.height))mm")
                .font(.caption)
            
            Text("Pixels: \(pixelWidth)×\(pixelHeight)px at 300dpi")
                .font(.caption)
                .foregroundColor(.blue)
            
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
    var format: PhotoFormat
    
    // Access to the image processor for consistent rendering
    private let imageProcessor = ImageProcessor()
    
    var body: some View {
        // Return the snapshot that shows exactly what's in the blue frame
        if let originalImage = sourceImage {
            // Convert SwiftUI Color to NSColor
            let nsBackgroundColor = NSColor(backgroundColor)
            
            // Use the same rendering method as the final image processing
            let previewImage = imageProcessor.processImage(
                originalImage: originalImage,
                format: format,
                zoomScale: zoomScale,
                rotationAngle: rotationAngle,
                offset: offset,
                frameSize: frameSize,
                backgroundColor: nsBackgroundColor
            )
            
            if let previewImage = previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: frameSize.width, height: frameSize.height)
                    .border(Color.red, width: 1) // Red border for the preview to visually distinguish it
            } else {
                // Fallback if processing fails
                Rectangle()
                    .fill(backgroundColor)
                    .frame(width: frameSize.width, height: frameSize.height)
                    .border(Color.red, width: 1)
                    .overlay(
                        Text("Processing failed")
                            .foregroundColor(.white)
                    )
            }
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

// Add this new struct for standard colors after the PhotoDimensionsInfo struct

struct StandardColorPickerView: View {
    @Binding var selectedColor: Color
    
    // Standard background colors for ID photos
    private let standardColors: [(name: String, color: Color, description: String, rgb: String)] = [
        ("White", Color(red: 1.0, green: 1.0, blue: 1.0), "For ID cards, passports, visas, driver's licenses", "R:255 G:255 B:255"),
        ("Blue", Color(red: 67.0/255.0, green: 142.0/255.0, blue: 219.0/255.0), "For education certificates, employment records, resumes", "R:67 G:142 B:219"),
        ("Red", Color(red: 1.0, green: 0.0, blue: 0.0), "For marriage certificates, party member IDs, title certificates", "R:255 G:0 B:0")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Standard Background Colors")
                .font(.headline)
            
            HStack(spacing: 15) {
                ForEach(0..<standardColors.count, id: \.self) { index in
                    Button(action: {
                        selectedColor = standardColors[index].color
                    }) {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(standardColors[index].color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue, lineWidth: selectedColor == standardColors[index].color ? 2 : 0)
                                )
                            Text(standardColors[index].name)
                                .font(.caption)
                            Text(standardColors[index].rgb)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(standardColors[index].description)
                }
                
                ColorPicker("Custom Color", selection: $selectedColor)
                    .labelsHidden()
                    .frame(width: 100)
            }
            
            Text("Color Usage Guidelines:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
            
            ForEach(0..<standardColors.count, id: \.self) { index in
                Text("• \(standardColors[index].name): \(standardColors[index].description)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// Individual photo item on the layout canvas
struct PhotoItemView: View {
    let photo: SavedPhoto
    let isSelected: Bool
    let displayScale: CGFloat
    let paperWidth: CGFloat
    let paperHeight: CGFloat
    let onTap: () -> Void
    let onDelete: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void
    
    var body: some View {
        let photoWidth = photo.pixelDimensions.width * displayScale * photo.scale
        let photoHeight = photo.pixelDimensions.height * displayScale * photo.scale
        
        // Convert normalized position (0-1) to absolute pixels in the display
        let xPos = photo.position.x * paperWidth * displayScale
        let yPos = photo.position.y * paperHeight * displayScale
        
        Image(nsImage: photo.image)
            .resizable()
            .scaledToFit()
            .frame(width: photoWidth, height: photoHeight)
            .rotationEffect(Angle(degrees: photo.rotation))
            .position(x: xPos, y: yPos)
            .border(isSelected ? Color.blue : Color.clear, width: 2)
            .overlay(
                Group {
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: onDelete) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Circle().fill(Color.white))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(4)
                            }
                            Spacer()
                        }
                        .frame(width: photoWidth, height: photoHeight)
                    }
                }
            )
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged(onDragChanged)
                    .onEnded(onDragEnded)
            )
            .onTapGesture(perform: onTap)
    }
}

// Grid lines for the photo paper
struct GridLines: Shape {
    let columns: Int
    let rows: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Vertical lines
        let columnWidth = rect.width / CGFloat(columns)
        for i in 1..<columns {
            let x = rect.minX + columnWidth * CGFloat(i)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        
        // Horizontal lines
        let rowHeight = rect.height / CGFloat(rows)
        for i in 1..<rows {
            let y = rect.minY + rowHeight * CGFloat(i)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        
        return path
    }
}

struct PhotoPaperLayoutView: View {
    @ObservedObject var viewModel: PhotoProcessorViewModel
    @State private var selectedPhotoIndex: Int? = nil
    @State private var dragStartPosition: CGPoint = .zero
    @State private var isDragging = false
    
    // Photo paper dimensions: 10.2cm x 15.2cm (4×6 inches) with 1200x1800 pixels
    private let paperWidth: CGFloat = 1800 // pixels (15.2cm)
    private let paperHeight: CGFloat = 1200 // pixels (10.2cm)
    
    // Display scale for the UI (scaled down to fit screen)
    private let displayScale: CGFloat = 0.25
    
    // Default grid divisions
    private let defaultColumns = 4
    private let defaultRows = 3
    
    var body: some View {
        VStack {
            Text("Photo Paper Layout (10.2cm × 15.2cm)")
                .font(.headline)
                .padding(.top)
            
            // Layout information
            Text("Paper dimensions: 1800×1200 pixels")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Layout controls
            HStack {
                Button("Auto Arrange") {
                    autoArrangePhotos()
                }
                .buttonStyle(.bordered)
                
                Button("Clear All") {
                    viewModel.clearCollection()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                // Photo manipulation controls - only enabled when a photo is selected
                HStack(spacing: 12) {
                    Button(action: {
                        if let index = selectedPhotoIndex {
                            duplicatePhoto(at: index)
                        }
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedPhotoIndex == nil)
                    .help("Duplicate the selected photo")
                    
                    Button(action: {
                        if let index = selectedPhotoIndex {
                            viewModel.removeFromCollection(at: index)
                            selectedPhotoIndex = nil
                        }
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedPhotoIndex == nil)
                    .help("Delete the selected photo")
                    
                    Button(action: {
                        if let index = selectedPhotoIndex {
                            rotatePhoto(at: index)
                        }
                    }) {
                        Label("Rotate 90°", systemImage: "rotate.right")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedPhotoIndex == nil)
                    .help("Rotate the selected photo 90 degrees")
                }
                
                Spacer()
                
                Button("Save Layout") {
                    saveLayout()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            // Photo paper canvas area - this is critical for alignment
            GeometryReader { geometry in
                let paperFrameWidth = paperWidth * displayScale
                let paperFrameHeight = paperHeight * displayScale
                
                // Center the paper in the available area
                let paperOriginX = (geometry.size.width - paperFrameWidth) / 2
                let paperOriginY = (geometry.size.height - paperFrameHeight) / 2
                
                ZStack {
                    // Semi-transparent background for the whole area
                    Color(.windowBackgroundColor).opacity(0.5)
                    
                    // Photo paper background - exactly positioned
                    Rectangle()
                        .fill(Color.white)
                        .border(Color.gray)
                        .frame(width: paperFrameWidth, height: paperFrameHeight)
                        .position(x: geometry.size.width/2, y: geometry.size.height/2)
                    
                    // Photo grid lines - exactly matching paper dimensions
                    GridLines(columns: defaultColumns, rows: defaultRows)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        .frame(width: paperFrameWidth, height: paperFrameHeight)
                        .position(x: geometry.size.width/2, y: geometry.size.height/2)
                    
                    // Placed photos
                    ForEach(Array(viewModel.savedPhotos.enumerated()), id: \.element.id) { index, photo in
                        let photoWidth = photo.pixelDimensions.width * displayScale * photo.scale
                        let photoHeight = photo.pixelDimensions.height * displayScale * photo.scale
                        
                        // Calculate absolute position on screen by combining:
                        // 1. Paper's center position
                        // 2. Photo's normalized position (0-1) scaled to paper dimensions
                        // 3. Offset from center of paper to the photo's position
                        let photoAbsX = geometry.size.width/2 + (photo.position.x - 0.5) * paperFrameWidth
                        let photoAbsY = geometry.size.height/2 + (photo.position.y - 0.5) * paperFrameHeight
                        
                        Image(nsImage: photo.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: photoWidth, height: photoHeight)
                            .rotationEffect(Angle(degrees: photo.rotation))
                            .position(x: photoAbsX, y: photoAbsY)
                            .border(selectedPhotoIndex == index ? Color.blue : Color.clear, width: 2)
                            .overlay(
                                Group {
                                    if selectedPhotoIndex == index {
                                        VStack {
                                            HStack {
                                                Spacer()
                                                HStack(spacing: 4) {
                                                    // Quick duplicate button
                                                    Button(action: {
                                                        duplicatePhoto(at: index)
                                                    }) {
                                                        Image(systemName: "doc.on.doc.fill")
                                                            .foregroundColor(.blue)
                                                            .background(Circle().fill(Color.white))
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                    .help("Duplicate this photo")
                                                    
                                                    // Quick rotate button
                                                    Button(action: {
                                                        rotatePhoto(at: index)
                                                    }) {
                                                        Image(systemName: "rotate.right.fill")
                                                            .foregroundColor(.green)
                                                            .background(Circle().fill(Color.white))
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                    .help("Rotate 90°")
                                                    
                                                    // Delete button
                                                    Button(action: {
                                                        viewModel.removeFromCollection(at: index)
                                                        if selectedPhotoIndex == index {
                                                            selectedPhotoIndex = nil
                                                        }
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.red)
                                                            .background(Circle().fill(Color.white))
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                    .help("Delete this photo")
                                                }
                                                .padding(4)
                                            }
                                            Spacer()
                                        }
                                        .frame(width: photoWidth, height: photoHeight)
                                    }
                                }
                            )
                            .gesture(
                                DragGesture(minimumDistance: 2)
                                    .onChanged { value in
                                        isDragging = true
                                        selectedPhotoIndex = index
                                        
                                        // Calculate paper frame in absolute coordinates
                                        let paperFrame = CGRect(
                                            x: paperOriginX,
                                            y: paperOriginY,
                                            width: paperFrameWidth,
                                            height: paperFrameHeight
                                        )
                                        
                                        // Convert screen coordinates to normalized (0-1) paper coordinates
                                        // First ensure coordinates are within paper bounds
                                        let boundedX = min(max(value.location.x, paperFrame.minX), paperFrame.maxX)
                                        let boundedY = min(max(value.location.y, paperFrame.minY), paperFrame.maxY)
                                        
                                        // Convert to normalized 0-1 coordinate space for the paper
                                        let normalizedX = (boundedX - paperFrame.minX) / paperFrame.width
                                        let normalizedY = (boundedY - paperFrame.minY) / paperFrame.height
                                        
                                        // Update the model with new position
                                        viewModel.savedPhotos[index].position = CGPoint(x: normalizedX, y: normalizedY)
                                    }
                                    .onEnded { _ in
                                        isDragging = false
                                    }
                            )
                            .onTapGesture {
                                selectedPhotoIndex = index
                            }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(height: 400)
            .padding()
            
            // Thumbnail list of available photos
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Array(viewModel.savedPhotos.enumerated()), id: \.element.id) { index, photo in
                        VStack {
                            Image(nsImage: photo.image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                                .border(Color.gray)
                                .shadow(color: selectedPhotoIndex == index ? Color.blue : Color.clear, radius: 3)
                                .onTapGesture {
                                    selectedPhotoIndex = index
                                }
                            
                            Text("\(photo.format.rawValue)")
                                .font(.caption)
                        }
                    }
                }
                .padding()
            }
            .frame(height: 120)
            .background(Color(.controlBackgroundColor))
        }
        .frame(width: 800, height: 600)
        .onAppear {
            initializeLayout()
        }
    }
    
    // Initialize default positions for newly added photos
    private func initializeLayout() {
        // Only position photos that aren't positioned yet (position is at 0,0)
        for (index, photo) in viewModel.savedPhotos.enumerated() {
            if photo.position == .zero {
                var updatedPhoto = photo
                
                // Calculate grid position based on index
                let col = index % defaultColumns
                let row = index / defaultColumns
                
                if row < defaultRows { // Only place if there's room in the grid
                    // Position photos at cell centers in the grid
                    let cellWidth = 1.0 / CGFloat(defaultColumns)
                    let cellHeight = 1.0 / CGFloat(defaultRows)
                    
                    // Center in the grid cell
                    let x = (CGFloat(col) * cellWidth) + (cellWidth * 0.5)
                    let y = (CGFloat(row) * cellHeight) + (cellHeight * 0.5)
                    
                    updatedPhoto.position = CGPoint(x: x, y: y)
                    viewModel.savedPhotos[index] = updatedPhoto
                }
            }
        }
    }
    
    // Auto arrange photos using a Maximal Rectangles bin packing algorithm for optimal layout
    private func autoArrangePhotos() {
        guard !viewModel.savedPhotos.isEmpty else { return }
        
        // Paper dimensions in pixels
        let paperWidth: CGFloat = 1800
        let paperHeight: CGFloat = 1200
        
        // Spacing between photos
        let spacing: CGFloat = 4
        
        // Create working copies of the photos that we can modify
        var arrangedPhotos = viewModel.savedPhotos
        
        // Reset existing transformations
        for i in 0..<arrangedPhotos.count {
            arrangedPhotos[i].rotation = 0
            arrangedPhotos[i].scale = 1.0
        }
        
        // Sort photos by height (typically better for bin packing)
        arrangedPhotos.sort { 
            $0.pixelDimensions.height > $1.pixelDimensions.height
        }
        
        // Initialize the maximal rectangles bin packer
        // Start with a single free rectangle representing the entire paper (minus margins)
        var freeRectangles = [CGRect(x: spacing, y: spacing, 
                                   width: paperWidth - spacing * 2, 
                                   height: paperHeight - spacing * 2)]
        
        // Keep track of placed photos and their positions
        var placedPhotoInfo: [(index: Int, rect: CGRect, rotated: Bool)] = []
        
        // Process each photo
        for (currentIndex, photo) in arrangedPhotos.enumerated() {
            let photoWidth = photo.pixelDimensions.width
            let photoHeight = photo.pixelDimensions.height
            
            // Try to place the photo (in both orientations)
            if let placement = findBestPlacement(
                width: photoWidth, 
                height: photoHeight,
                freeRectangles: freeRectangles,
                spacing: spacing
            ) {
                // Photo has been placed, update free rectangles
                freeRectangles = splitFreeRectangles(
                    freeRectangles: freeRectangles,
                    usedRect: placement.rect,
                    spacing: spacing
                )
                
                // Save the placement information
                placedPhotoInfo.append((currentIndex, placement.rect, placement.rotated))
            }
        }
        
        // Now apply the placements to the actual photos
        for placement in placedPhotoInfo {
            let rect = placement.rect
            let index = placement.index
            let rotated = placement.rotated
            
            // Calculate the center of the photo
            let centerX = rect.midX / paperWidth
            let centerY = rect.midY / paperHeight
            
            // Update the photo position
            arrangedPhotos[index].position = CGPoint(x: centerX, y: centerY)
            
            // Set rotation if needed
            arrangedPhotos[index].rotation = rotated ? 90 : 0
        }
        
        // Apply the arranged layout to the view model
        viewModel.savedPhotos = arrangedPhotos
    }
    
    // Helper structure to store placement result
    private struct PlacementResult {
        let rect: CGRect
        let rotated: Bool
        let score: CGFloat
    }
    
    // Find the best placement for a photo using various heuristics
    private func findBestPlacement(
        width: CGFloat, 
        height: CGFloat,
        freeRectangles: [CGRect],
        spacing: CGFloat
    ) -> PlacementResult? {
        var bestPlacement: PlacementResult? = nil
        var bestScore: CGFloat = CGFloat.greatestFiniteMagnitude
        
        // Try each free rectangle as a potential placement
        for rect in freeRectangles {
            // Try normal orientation
            if width <= rect.width && height <= rect.height {
                let score = scorePlacement(containerRect: rect, width: width, height: height)
                if score < bestScore {
                    bestScore = score
                    bestPlacement = PlacementResult(
                        rect: CGRect(x: rect.minX, y: rect.minY, width: width, height: height),
                        rotated: false,
                        score: score
                    )
                }
            }
            
            // Try rotated orientation
            if height <= rect.width && width <= rect.height {
                let score = scorePlacement(containerRect: rect, width: height, height: width)
                if score < bestScore {
                    bestScore = score
                    bestPlacement = PlacementResult(
                        rect: CGRect(x: rect.minX, y: rect.minY, width: height, height: width),
                        rotated: true,
                        score: score
                    )
                }
            }
        }
        
        return bestPlacement
    }
    
    // Score a potential placement (lower is better)
    private func scorePlacement(containerRect: CGRect, width: CGFloat, height: CGFloat) -> CGFloat {
        // Best Fit: Minimize wasted area
        let areaFit = containerRect.width * containerRect.height - width * height
        
        // Best Short Side Fit: Minimize the shorter leftover side
        let leftoverWidth = containerRect.width - width
        let leftoverHeight = containerRect.height - height
        let shortSideFit = min(leftoverWidth, leftoverHeight)
        
        // Best Long Side Fit: Minimize the longer leftover side
        let longSideFit = max(leftoverWidth, leftoverHeight)
        
        // Combined score (weighted) - lower is better
        return areaFit * 0.5 + shortSideFit * 0.3 + longSideFit * 0.2
    }
    
    // Split free rectangles after placing a photo
    private func splitFreeRectangles(
        freeRectangles: [CGRect],
        usedRect: CGRect,
        spacing: CGFloat
    ) -> [CGRect] {
        // Add a spacing buffer around the used rectangle to ensure photos don't touch
        let bufferedRect = CGRect(
            x: usedRect.minX - spacing,
            y: usedRect.minY - spacing, 
            width: usedRect.width + spacing * 2,
            height: usedRect.height + spacing * 2
        )
        
        var newFreeRectangles: [CGRect] = []
        
        // Process each existing free rectangle
        for freeRect in freeRectangles {
            // Skip if this free rectangle doesn't intersect with our used one
            if !freeRect.intersects(bufferedRect) {
                newFreeRectangles.append(freeRect)
                continue
            }
            
            // Split the free rectangle in up to 4 directions
            
            // Right of the placed photo
            if freeRect.maxX > bufferedRect.maxX {
                let rightRect = CGRect(
                    x: bufferedRect.maxX,
                    y: freeRect.minY,
                    width: freeRect.maxX - bufferedRect.maxX,
                    height: freeRect.height
                )
                if rightRect.width > spacing && rightRect.height > spacing {
                    newFreeRectangles.append(rightRect)
                }
            }
            
            // Left of the placed photo
            if bufferedRect.minX > freeRect.minX {
                let leftRect = CGRect(
                    x: freeRect.minX,
                    y: freeRect.minY,
                    width: bufferedRect.minX - freeRect.minX,
                    height: freeRect.height
                )
                if leftRect.width > spacing && leftRect.height > spacing {
                    newFreeRectangles.append(leftRect)
                }
            }
            
            // Above the placed photo
            if freeRect.maxY > bufferedRect.maxY {
                let topRect = CGRect(
                    x: freeRect.minX,
                    y: bufferedRect.maxY,
                    width: freeRect.width,
                    height: freeRect.maxY - bufferedRect.maxY
                )
                if topRect.width > spacing && topRect.height > spacing {
                    newFreeRectangles.append(topRect)
                }
            }
            
            // Below the placed photo
            if bufferedRect.minY > freeRect.minY {
                let bottomRect = CGRect(
                    x: freeRect.minX,
                    y: freeRect.minY,
                    width: freeRect.width,
                    height: bufferedRect.minY - freeRect.minY
                )
                if bottomRect.width > spacing && bottomRect.height > spacing {
                    newFreeRectangles.append(bottomRect)
                }
            }
        }
        
        // Remove redundant rectangles (ones fully contained within others)
        newFreeRectangles = removeDuplicateRectangles(newFreeRectangles)
        
        return newFreeRectangles
    }
    
    // Remove any contained or duplicate rectangles
    private func removeDuplicateRectangles(_ rects: [CGRect]) -> [CGRect] {
        var result = rects
        
        for i in (0..<result.count).reversed() {
            let rect1 = result[i]
            
            // Remove tiny rectangles
            if rect1.width < 10 || rect1.height < 10 {
                result.remove(at: i)
                continue
            }
            
            for j in 0..<result.count {
                if i == j { continue }
                
                let rect2 = result[j]
                
                // Check if rect1 is contained within rect2
                if rect2.contains(rect1) {
                    result.remove(at: i)
                    break
                }
            }
        }
        
        return result
    }
    
    // Save the layout as a single image
    private func saveLayout() {
        // Force exact dimensions with no scaling: 1800 × 1200 pixels
        let exactWidth: CGFloat = 1800
        let exactHeight: CGFloat = 1200
        
        // Create bitmap context with exact pixel dimensions
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(exactWidth),
            pixelsHigh: Int(exactHeight),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        // Set scale factors to 1.0 to prevent any Retina/scaling effects
        bitmapRep?.size = NSSize(width: exactWidth, height: exactHeight)
        
        // Create new image with the bitmap rep
        let finalImage = NSImage(size: NSSize(width: exactWidth, height: exactHeight))
        finalImage.addRepresentation(bitmapRep!)
        
        // Set up graphics context
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep!)
        
        // Fill white background
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: exactWidth, height: exactHeight).fill()
        
        // Draw grid lines (just like in the UI)
        let cols = defaultColumns
        let rows = defaultRows
        
        NSColor.gray.withAlphaComponent(0.3).setStroke()
        let gridPath = NSBezierPath()
        
        // Draw vertical grid lines
        let colWidth = exactWidth / CGFloat(cols)
        for i in 1..<cols {
            let x = colWidth * CGFloat(i)
            gridPath.move(to: NSPoint(x: x, y: 0))
            gridPath.line(to: NSPoint(x: x, y: exactHeight))
        }
        
        // Draw horizontal grid lines
        let rowHeight = exactHeight / CGFloat(rows)
        for i in 1..<rows {
            let y = rowHeight * CGFloat(i)
            gridPath.move(to: NSPoint(x: 0, y: y))
            gridPath.line(to: NSPoint(x: exactWidth, y: y))
        }
        
        gridPath.lineWidth = 0.5
        gridPath.stroke()
        
        // Draw border around the entire paper
        let borderPath = NSBezierPath(rect: NSRect(x: 0, y: 0, width: exactWidth, height: exactHeight))
        NSColor.gray.setStroke()
        borderPath.lineWidth = 1.0
        borderPath.stroke()
        
        // Draw each photo at its position
        for photo in viewModel.savedPhotos {
            // Convert normalized position to absolute pixel coordinates
            let normalizedX = photo.position.x
            // Invert Y-coordinate to fix upside-down issue - in SwiftUI Y increases downward,
            // but in our exported image we want it to match the visible layout
            let normalizedY = 1.0 - photo.position.y
            
            // Calculate the absolute pixel coordinates
            let x = normalizedX * exactWidth
            let y = normalizedY * exactHeight
            
            // Get photo dimensions
            let photoSize = photo.pixelDimensions
            
            // Calculate drawing rectangle, centered on position
            let rect = NSRect(
                x: x - (photoSize.width / 2),
                y: y - (photoSize.height / 2),
                width: photoSize.width,
                height: photoSize.height
            )
            
            // Apply rotation
            let transform = NSAffineTransform()
            transform.translateX(by: x, yBy: y)
            // Negate the rotation angle to maintain consistent direction
            transform.rotate(byDegrees: -CGFloat(photo.rotation))
            transform.translateX(by: -x, yBy: -y)
            transform.concat()
            
            // Draw the image
            photo.image.draw(in: rect, from: .zero, operation: .copy, fraction: 1.0)
        }
        
        // Restore graphics state
        NSGraphicsContext.restoreGraphicsState()
        
        // Save the image
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save Photo Paper Layout"
        savePanel.nameFieldLabel = "File Name:"
        savePanel.nameFieldStringValue = "photo_layout_1800x1200_\(Date().timeIntervalSince1970).jpg"
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                // For printing, use exact size with no scaling
                if url.pathExtension.lowercased() == "png" {
                    if let pngData = bitmapRep?.representation(using: .png, properties: [:]) {
                        do {
                            try pngData.write(to: url)
                            print("Saved layout with dimensions: \(exactWidth) × \(exactHeight) pixels")
                        } catch {
                            print("Error saving layout: \(error.localizedDescription)")
                        }
                    }
                } else {
                    // Use high quality JPEG for smaller file size option
                    if let jpegData = bitmapRep?.representation(using: .jpeg, properties: [.compressionFactor: 0.95]) {
                        do {
                            try jpegData.write(to: url)
                            print("Saved layout with dimensions: \(exactWidth) × \(exactHeight) pixels")
                        } catch {
                            print("Error saving layout: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    // Function to duplicate a photo
    private func duplicatePhoto(at index: Int) {
        guard index < viewModel.savedPhotos.count else { return }
        
        let originalPhoto = viewModel.savedPhotos[index]
        var duplicatedPhoto = SavedPhoto(
            image: originalPhoto.image,
            format: originalPhoto.format,
            dateCreated: Date()
        )
        
        // Position the duplicate slightly offset from the original
        let offsetX: CGFloat = 0.02 // Small offset to make it visible
        let offsetY: CGFloat = 0.02
        
        // Apply the offset while keeping it within paper boundaries
        let newX = min(max(originalPhoto.position.x + offsetX, 0.0), 1.0)
        let newY = min(max(originalPhoto.position.y + offsetY, 0.0), 1.0)
        
        duplicatedPhoto.position = CGPoint(x: newX, y: newY)
        duplicatedPhoto.rotation = originalPhoto.rotation
        duplicatedPhoto.scale = originalPhoto.scale
        
        // Add the duplicate to the collection
        viewModel.savedPhotos.append(duplicatedPhoto)
        
        // Select the new photo
        selectedPhotoIndex = viewModel.savedPhotos.count - 1
    }
    
    // Function to rotate a photo by 90 degrees
    private func rotatePhoto(at index: Int) {
        guard index < viewModel.savedPhotos.count else { return }
        
        // Increment rotation by 90 degrees
        viewModel.savedPhotos[index].rotation += 90
        
        // Normalize the rotation angle to 0-360
        if viewModel.savedPhotos[index].rotation >= 360 {
            viewModel.savedPhotos[index].rotation -= 360
        }
    }
} 
