import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: PhotoProcessorViewModel
    
    var body: some View {
        NavigationView {
            SidebarView(viewModel: viewModel)
            
            if viewModel.selectedImage != nil {
                PhotoEditorView(viewModel: viewModel)
            } else {
                WelcomeView(viewModel: viewModel)
            }
        }
        .navigationTitle("ID Photo Helper")
        .frame(minWidth: 1000, minHeight: 700)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PhotoProcessorViewModel())
    }
} 