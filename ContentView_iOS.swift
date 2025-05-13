import SwiftUI

struct ContentView_iOS: View {
    @EnvironmentObject private var viewModel: SharedPhotoProcessorViewModel
    @State private var isShowingImagePicker = false
    
    var body: some View {
        NavigationView {
            if viewModel.selectedImage != nil {
                PhotoEditorView_iOS(viewModel: viewModel)
            } else {
                WelcomeView_iOS(viewModel: viewModel)
                    .navigationTitle("ID Photo Helper")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: $viewModel.selectedImage)
        }
    }
}

struct ContentView_iOS_Previews: PreviewProvider {
    static var previews: some View {
        ContentView_iOS()
            .environmentObject(SharedPhotoProcessorViewModel())
    }
} 