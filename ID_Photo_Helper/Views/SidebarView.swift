import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: PhotoProcessorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Photo Format")
                .font(.headline)
            
            FormatSelector(selectedFormat: $viewModel.selectedPhotoFormat, formats: PhotoFormat.allCases.map { $0 })
            
            Text("Background Color")
                .font(.headline)
            
            ColorSelector(selectedColor: $viewModel.selectedBackgroundColor)
            
            Divider()
            
            if viewModel.selectedImage != nil {
                EditingControls(viewModel: viewModel)
            }
            
            Spacer()
            
            HStack {
                Button(action: viewModel.selectImage) {
                    Label("Upload Image", systemImage: "photo")
                }
                .buttonStyle(.borderedProminent)
                
                if viewModel.selectedImage != nil {
                    Button(action: viewModel.processImage) {
                        Label("Process", systemImage: "wand.and.rays")
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if viewModel.croppedImage != nil {
                Button(action: viewModel.saveProcessedImage) {
                    Label("Save Image", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 250)
        .background(Color(.controlBackgroundColor))
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
        .padding(.vertical, 5)
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
            
            VStack(alignment: .leading) {
                Text("Zoom: \(Int(viewModel.zoomScale * 100))%")
                Slider(value: $viewModel.zoomScale, in: 0.5...2.0, step: 0.1)
                    .labelsHidden()
                    .onChange(of: viewModel.zoomScale) { _ in
                        viewModel.processImage()
                    }
                
                Text("Rotation: \(Int(viewModel.rotationAngle))°")
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
                .padding(.top, 5)
            }
        }
    }
} 