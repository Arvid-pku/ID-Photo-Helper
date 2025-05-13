import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: PhotoProcessorViewModel
    @State private var forceRedraw = UUID()
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppBecameActive"),
            object: nil,
            queue: .main
        ) { _ in
            self.forceRedraw = UUID()
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("Photo Format")
                    .font(.headline)
                
                FormatSelector(selectedFormat: $viewModel.selectedPhotoFormat, formats: PhotoFormat.allCases.map { $0 })
                
                if viewModel.selectedPhotoFormat == .custom {
                    CustomDimensionsInput(
                        width: $viewModel.customWidth,
                        height: $viewModel.customHeight,
                        onDimensionChange: {
                            DispatchQueue.main.async {
                                viewModel.processImage()
                            }
                        }
                    )
                }
                
                Text("Background Color")
                    .font(.headline)
                
                ColorSelector(selectedColor: $viewModel.selectedBackgroundColor)
                
                Divider()
                
                if viewModel.selectedImage != nil {
                    EditingControls(viewModel: viewModel)
                }
                
                Spacer(minLength: 20)
                
                HStack {
                    Button(action: viewModel.selectImage) {
                        Label("Upload", systemImage: "photo")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(2)
                    .background(Color(.controlBackgroundColor).opacity(0.01))
                    
                    if viewModel.selectedImage != nil {
                        Button(action: viewModel.processImage) {
                            Label("Process", systemImage: "wand.and.rays")
                        }
                        .buttonStyle(.bordered)
                        .padding(2)
                        .background(Color(.controlBackgroundColor).opacity(0.01))
                    }
                }
                
                if viewModel.croppedImage != nil {
                    Button(action: viewModel.saveProcessedImage) {
                        Label("Save Image", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(2)
                    .background(Color(.controlBackgroundColor).opacity(0.01))
                }
            }
            .padding()
        }
        .frame(width: 250)
        .background(Color(.controlBackgroundColor))
        .id(forceRedraw)
        .onAppear {
            setupNotifications()
        }
    }
}

struct FormatSelector: View {
    @Binding var selectedFormat: PhotoFormat
    let formats: [PhotoFormat]
    
    var body: some View {
        Picker("", selection: $selectedFormat) {
            ForEach(formats) { format in
                Text(format.rawValue).tag(format)
            }
        }
        .pickerStyle(RadioGroupPickerStyle())
        .labelsHidden()
        .padding(.vertical, 2)
    }
}

struct ColorSelector: View {
    @Binding var selectedColor: Color
    
    private let predefinedColors: [(Color, String)] = [
        (.white, "White"),
        (.blue, "Blue"),
        (.red, "Red"),
        (.gray, "Gray")
    ]
    
    var body: some View {
        HStack {
            ForEach(predefinedColors, id: \.1) { color, name in
                ColorButton(color: color, name: name, isSelected: selectedColor == color) {
                    selectedColor = color
                }
            }
            
            ColorPicker("", selection: $selectedColor)
                .labelsHidden()
                .frame(width: 28, height: 28)
                .padding(3)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.gray, lineWidth: 1)
                )
        }
    }
}

struct ColorButton: View {
    let color: Color
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color.gray, lineWidth: 1)
                    )
                
                if isSelected {
                    Circle()
                        .stroke(Color.blue, lineWidth: 3)
                        .frame(width: 34, height: 34)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help(name)
    }
}

struct EditingControls: View {
    @ObservedObject var viewModel: PhotoProcessorViewModel
    
    var body: some View {
        Group {
            Text("Image Adjustments")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Zoom: \(Int(viewModel.zoomScale * 100))%")
                    .font(.caption)
                Slider(value: $viewModel.zoomScale, in: 0.5...2.0, step: 0.1)
                    .labelsHidden()
                    .onChange(of: viewModel.zoomScale) { _ in
                        viewModel.processImage()
                    }
                
                Text("Rotation: \(Int(viewModel.rotationAngle))°")
                    .font(.caption)
                Slider(value: $viewModel.rotationAngle, in: -180...180, step: 1)
                    .labelsHidden()
                    .onChange(of: viewModel.rotationAngle) { _ in
                        viewModel.processImage()
                    }
                
                Button("Reset Adjustments") {
                    viewModel.resetEditing()
                    viewModel.processImage()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .padding(.top, 3)
            }
        }
    }
}

struct CustomDimensionsInput: View {
    @Binding var width: CGFloat
    @Binding var height: CGFloat
    var onDimensionChange: () -> Void
    
    // Add string buffers for text input
    @State private var widthText: String
    @State private var heightText: String
    @FocusState private var isWidthFocused: Bool
    @FocusState private var isHeightFocused: Bool
    
    // Add initializer to set up the text fields with current values
    init(width: Binding<CGFloat>, height: Binding<CGFloat>, onDimensionChange: @escaping () -> Void) {
        self._width = width
        self._height = height
        self.onDimensionChange = onDimensionChange
        
        // Initialize text fields with current values
        self._widthText = State(initialValue: String(format: "%.0f", width.wrappedValue))
        self._heightText = State(initialValue: String(format: "%.0f", height.wrappedValue))
    }
    
    // Function to validate and commit width changes
    private func commitWidth() {
        // Remove any non-numeric characters first
        let filteredText = widthText.filter { "0123456789".contains($0) }
        
        if let newWidth = Double(filteredText), newWidth > 0 {
            // Apply min/max constraints only when committing
            let constrainedWidth = max(10, min(CGFloat(newWidth), 100))
            
            // Only trigger update if value actually changed
            if width != constrainedWidth {
                width = constrainedWidth
                widthText = String(format: "%.0f", constrainedWidth)
                onDimensionChange()
            } else if String(format: "%.0f", width) != filteredText {
                // Update text to reflect constraints if needed
                widthText = String(format: "%.0f", width)
            }
        } else {
            // Reset to current value if invalid input
            widthText = String(format: "%.0f", width)
        }
    }
    
    // Function to validate and commit height changes
    private func commitHeight() {
        // Remove any non-numeric characters first
        let filteredText = heightText.filter { "0123456789".contains($0) }
        
        if let newHeight = Double(filteredText), newHeight > 0 {
            // Apply min/max constraints only when committing
            let constrainedHeight = max(10, min(CGFloat(newHeight), 100))
            
            // Only trigger update if value actually changed
            if height != constrainedHeight {
                height = constrainedHeight
                heightText = String(format: "%.0f", constrainedHeight)
                onDimensionChange()
            } else if String(format: "%.0f", height) != filteredText {
                // Update text to reflect constraints if needed
                heightText = String(format: "%.0f", height)
            }
        } else {
            // Reset to current value if invalid input
            heightText = String(format: "%.0f", height)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Dimensions (mm)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Width")
                        .font(.caption)
                    
                    HStack {
                        TextField("Width", text: $widthText)
                            .focused($isWidthFocused)
                            .frame(width: 50)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: widthText) { newValue in
                                // Filter non-numeric characters in real-time
                                let filtered = newValue.filter { "0123456789".contains($0) }
                                if filtered != newValue {
                                    widthText = filtered
                                }
                            }
                            .onSubmit {
                                commitWidth()
                            }
                            .onChange(of: isWidthFocused) { focused in
                                if !focused {
                                    commitWidth()
                                }
                            }
                        
                        Text("mm")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Height")
                        .font(.caption)
                    
                    HStack {
                        TextField("Height", text: $heightText)
                            .focused($isHeightFocused)
                            .frame(width: 50)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: heightText) { newValue in
                                // Filter non-numeric characters in real-time
                                let filtered = newValue.filter { "0123456789".contains($0) }
                                if filtered != newValue {
                                    heightText = filtered
                                }
                            }
                            .onSubmit {
                                commitHeight()
                            }
                            .onChange(of: isHeightFocused) { focused in
                                if !focused {
                                    commitHeight()
                                }
                            }
                        
                        Text("mm")
                            .font(.caption)
                    }
                }
            }
            
            Text("Min: 10mm, Max: 100mm")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 5) {
                Button("1:1") {
                    let aspectRatio: CGFloat = 1.0
                    if width > height {
                        height = width / aspectRatio
                    } else {
                        width = height * aspectRatio
                    }
                    // Update text fields to match the new values
                    widthText = String(format: "%.0f", width)
                    heightText = String(format: "%.0f", height)
                    onDimensionChange()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                
                Button("3:4") {
                    let aspectRatio: CGFloat = 0.75
                    if width > height {
                        height = width / aspectRatio
                    } else {
                        width = height * aspectRatio
                    }
                    // Update text fields to match the new values
                    widthText = String(format: "%.0f", width)
                    heightText = String(format: "%.0f", height)
                    onDimensionChange()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                
                Button("2:3") {
                    let aspectRatio: CGFloat = 0.67
                    if width > height {
                        height = width / aspectRatio
                    } else {
                        width = height * aspectRatio
                    }
                    // Update text fields to match the new values
                    widthText = String(format: "%.0f", width)
                    heightText = String(format: "%.0f", height)
                    onDimensionChange()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding(8)
        .background(Color(.textBackgroundColor))
        .cornerRadius(5)
    }
} 