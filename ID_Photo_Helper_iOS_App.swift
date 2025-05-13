import SwiftUI

@main
struct ID_Photo_Helper_iOS_App: App {
    @StateObject private var viewModel = SharedPhotoProcessorViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView_iOS()
                .environmentObject(viewModel)
        }
    }
} 