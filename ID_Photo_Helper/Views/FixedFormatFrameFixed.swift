import SwiftUI

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