import SwiftUI

struct PhotoEditorView: View {
    @ObservedObject var viewModel: PhotoProcessorViewModel
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @State private var frameSize: CGSize = .zero
    @State private var showPaperLayoutView = false
    
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
        }
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
            
            if viewModel.croppedImage != nil {
                Button("Save") {
                    viewModel.saveProcessedImage()
                }
                .buttonStyle(.bordered)
                
                Button("Add to Collection") {
                    viewModel.saveToCollection()
                }
                .buttonStyle(.bordered)
                .help("Add this photo to a collection for arranging on photo paper")
                
                Button("Arrange on Paper") {
                    showPaperLayoutView = true
                }
                .buttonStyle(.bordered)
                .help("Arrange saved photos on a 6-inch photo paper")
                .disabled(viewModel.savedPhotos.isEmpty)
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
            
            Spacer()
            
            // Use extracted action buttons view
            actionButtonsView()
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .animation(.interactiveSpring(), value: isDragging)
        .sheet(isPresented: $showPaperLayoutView) {
            PhotoPaperLayoutView(viewModel: viewModel)
        }
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
    let onTap: () -> Void
    let onDelete: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void
    
    var body: some View {
        let photoWidth = photo.pixelDimensions.width * displayScale * photo.scale
        let photoHeight = photo.pixelDimensions.height * displayScale * photo.scale
        
        // Convert normalized position to pixels
        let xPos = photo.position.x * (6 * 300 * displayScale)
        let yPos = photo.position.y * (4 * 300 * displayScale)
        
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
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    // 6-inch photo paper at 300dpi is 1800x1200 pixels (landscape orientation)
    private let paperWidth: CGFloat = 6 * 300 // 1800 pixels
    private let paperHeight: CGFloat = 4 * 300 // 1200 pixels
    
    // Display scale for the UI (scaled down to fit screen)
    private let displayScale: CGFloat = 0.25
    
    var body: some View {
        VStack {
            Text("Photo Paper Layout (6×4 inch)")
                .font(.headline)
                .padding(.top)
            
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
                
                Button("Save Layout") {
                    saveLayout()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            // Photo paper canvas
            ZStack {
                // Photo paper background
                Rectangle()
                    .fill(Color.white)
                    .border(Color.gray)
                    .frame(
                        width: paperWidth * displayScale,
                        height: paperHeight * displayScale
                    )
                
                // Photo grid lines
                GridLines(columns: 3, rows: 2)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                    .frame(
                        width: paperWidth * displayScale,
                        height: paperHeight * displayScale
                    )
                
                // Placed photos
                ForEach(Array(viewModel.savedPhotos.enumerated()), id: \.element.id) { index, photo in
                    PhotoItemView(
                        photo: photo,
                        isSelected: selectedPhotoIndex == index,
                        displayScale: displayScale,
                        onTap: {
                            selectedPhotoIndex = index
                        },
                        onDelete: {
                            viewModel.removeFromCollection(at: index)
                            if selectedPhotoIndex == index {
                                selectedPhotoIndex = nil
                            }
                        },
                        onDragChanged: { value in
                            isDragging = true
                            
                            // Calculate new position in normalized coordinates
                            let translation = value.translation
                            let scaledTranslation = CGSize(
                                width: translation.width / (paperWidth * displayScale),
                                height: translation.height / (paperHeight * displayScale)
                            )
                            
                            // Update the position
                            var newPosition = photo.position
                            newPosition.x += scaledTranslation.width
                            newPosition.y += scaledTranslation.height
                            
                            // Constrain to paper bounds
                            newPosition.x = max(0, min(1, newPosition.x))
                            newPosition.y = max(0, min(1, newPosition.y))
                            
                            // Update the model
                            viewModel.savedPhotos[index].position = newPosition
                            
                            // Reset for next drag
                            dragOffset = .zero
                        },
                        onDragEnded: { _ in
                            isDragging = false
                        }
                    )
                }
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
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
                
                // Create a grid-based position based on index
                let cols = 3
                let col = index % cols
                let row = index / cols
                
                // Normalize to 0-1 range
                let x = (CGFloat(col) / CGFloat(cols)) + 0.1
                let y = (CGFloat(row) / 2.0) + 0.1
                
                updatedPhoto.position = CGPoint(x: x, y: y)
                viewModel.savedPhotos[index] = updatedPhoto
            }
        }
    }
    
    // Auto arrange photos in a grid pattern
    private func autoArrangePhotos() {
        let cols = 3
        let rows = 2
        
        for (index, _) in viewModel.savedPhotos.enumerated() {
            if index < cols * rows { // Only arrange up to grid capacity
                let col = index % cols
                let row = index / cols
                
                // Distribute evenly with margins
                let margin: CGFloat = 0.05
                let cellWidth = (1.0 - (margin * 2)) / CGFloat(cols)
                let cellHeight = (1.0 - (margin * 2)) / CGFloat(rows)
                
                // Center in cell
                let x = margin + (cellWidth * CGFloat(col)) + (cellWidth / 2.0)
                let y = margin + (cellHeight * CGFloat(row)) + (cellHeight / 2.0)
                
                // Update the model
                viewModel.savedPhotos[index].position = CGPoint(x: x, y: y)
                viewModel.savedPhotos[index].rotation = 0
                viewModel.savedPhotos[index].scale = 1.0
            }
        }
    }
    
    // Save the layout as a single image
    private func saveLayout() {
        // Create a new image at 6x4 inches, 300 dpi
        let finalImage = NSImage(size: NSSize(width: paperWidth, height: paperHeight))
        
        finalImage.lockFocus()
        
        // Fill white background
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: paperWidth, height: paperHeight).fill()
        
        // Draw each photo at its position
        for photo in viewModel.savedPhotos {
            // Convert normalized position to absolute position on paper
            let x = photo.position.x * paperWidth
            let y = photo.position.y * paperHeight
            
            // Get photo dimensions
            let photoSize = photo.pixelDimensions
            
            // Calculate drawing rectangle, centered on position
            let rect = NSRect(
                x: x - (photoSize.width * photo.scale / 2),
                y: y - (photoSize.height * photo.scale / 2),
                width: photoSize.width * photo.scale,
                height: photoSize.height * photo.scale
            )
            
            // Apply rotation
            NSGraphicsContext.current?.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: x, yBy: y)
            transform.rotate(byDegrees: CGFloat(photo.rotation))
            transform.translateX(by: -x, yBy: -y)
            transform.concat()
            
            // Draw the image
            photo.image.draw(in: rect, from: .zero, operation: .copy, fraction: 1.0)
            
            NSGraphicsContext.current?.restoreGraphicsState()
        }
        
        finalImage.unlockFocus()
        
        // Save the image
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save Photo Paper Layout"
        savePanel.nameFieldLabel = "File Name:"
        savePanel.nameFieldStringValue = "photo_layout_\(Date().timeIntervalSince1970).jpg"
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url,
               let tiffData = finalImage.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                
                do {
                    try jpegData.write(to: url)
                } catch {
                    print("Error saving layout: \(error.localizedDescription)")
                }
            }
        }
    }
} 
