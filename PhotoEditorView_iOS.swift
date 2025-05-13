import SwiftUI

struct PhotoEditorView_iOS: View {
    @ObservedObject var viewModel: SharedPhotoProcessorViewModel
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var selectedBgColor = Color.blue
    @State private var showingPhotoSettings = false
    
    var body: some View {
        VStack {
            if let image = viewModel.processedImage ?? viewModel.selectedImage {
                ZStack {
                    // Background color
                    selectedBgColor
                    
                    // Image with gestures
                    image.toSwiftUIImage()
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    offset = CGSize(
                                        width: lastOffset.width + gesture.translation.width,
                                        height: lastOffset.height + gesture.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                    
                    // Crop frame overlay
                    GeometryReader { geometry in
                        let frameSize = min(geometry.size.width * 0.8, geometry.size.height * 0.8)
                        Rectangle()
                            .strokeBorder(Color.white, lineWidth: 2)
                            .frame(width: frameSize, height: frameSize * 1.25) // Standard ID photo aspect ratio
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                }
                
                HStack(spacing: 20) {
                    Button(action: {
                        viewModel.selectedImage = nil
                        viewModel.processedImage = nil
                    }) {
                        VStack {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 24))
                            Text("Cancel")
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        showingPhotoSettings.toggle()
                    }) {
                        VStack {
                            Image(systemName: "sliders.horizontal")
                                .font(.system(size: 24))
                            Text("Settings")
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        // Process the image
                        if let originalImage = viewModel.selectedImage {
                            viewModel.removeBackground(from: originalImage, replaceWithColor: UIColor(selectedBgColor))
                        }
                    }) {
                        VStack {
                            Image(systemName: "person.crop.rectangle")
                                .font(.system(size: 24))
                            Text("Remove BG")
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        // Export the image
                        viewModel.saveImage()
                    }) {
                        VStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 24))
                            Text("Export")
                                .font(.caption)
                        }
                    }
                }
                .padding()
            } else {
                Text("No image selected")
            }
        }
        .navigationBarTitle("Edit Photo", displayMode: .inline)
        .sheet(isPresented: $showingPhotoSettings) {
            VStack {
                Text("Photo Settings")
                    .font(.headline)
                    .padding()
                
                Text("Background Color")
                    .font(.subheadline)
                
                ColorPicker("", selection: $selectedBgColor)
                    .padding()
                
                Button("Close") {
                    showingPhotoSettings = false
                }
                .padding()
            }
            .presentationDetents([.medium])
        }
    }
}

#if os(iOS)
extension Color {
    func uiColor() -> UIColor {
        UIColor(self)
    }
}
#endif

struct PhotoEditorView_iOS_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = SharedPhotoProcessorViewModel()
        return PhotoEditorView_iOS(viewModel: viewModel)
    }
} 