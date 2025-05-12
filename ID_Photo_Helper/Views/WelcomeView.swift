import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: PhotoProcessorViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("Welcome to ID Photo Helper")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Create professional ID photos that meet international standards")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 15) {
                FeatureItem(icon: "ruler", text: "Precise sizing for passports, visas, and IDs")
                FeatureItem(icon: "photo.fill.on.rectangle.fill", text: "Background replacement with various colors")
                FeatureItem(icon: "person.crop.rectangle", text: "Automatic face detection and positioning")
                FeatureItem(icon: "arrow.down.doc", text: "Export high-quality images ready for printing")
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(10)
            
            Button(action: viewModel.selectImage) {
                Label("Select an Image to Begin", systemImage: "photo")
                    .font(.headline)
                    .padding()
                    .frame(minWidth: 250)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

struct FeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 30)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.body)
        }
    }
} 