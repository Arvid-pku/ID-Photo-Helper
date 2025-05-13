import SwiftUI

struct WelcomeView_iOS: View {
    @ObservedObject var viewModel: SharedPhotoProcessorViewModel
    @State private var isShowingImagePicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("Welcome to ID Photo Helper")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Create perfect ID photos for passports, visas, and other documents")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                isShowingImagePicker = true
            }) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Select Photo")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 20)
        }
        .padding()
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: $viewModel.selectedImage)
        }
    }
}

struct WelcomeView_iOS_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView_iOS(viewModel: SharedPhotoProcessorViewModel())
    }
} 