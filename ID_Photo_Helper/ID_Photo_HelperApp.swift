import SwiftUI

// Create an AppDelegate class to hold shared app data
class AppDelegate: NSObject, NSApplicationDelegate {
    // Shared view model instance that can be accessed from static contexts
    var sharedViewModel: PhotoProcessorViewModel?
}

@main
struct ID_Photo_HelperApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = PhotoProcessorViewModel()
    
    // Create an instance of AppDelegate and store it in NSApp.delegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Capture viewModel to avoid 'self' capture issues
        let viewModelRef = viewModel
        
        // We need to use DispatchQueue.main.async here because NSApp.delegate 
        // is not set until after init() completes
        DispatchQueue.main.async {
            // Store the shared view model in the app delegate
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.sharedViewModel = viewModelRef
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onChange(of: scenePhase) { phase in
                    // Force redraw when window becomes active again
                    if phase == .active {
                        // This will trigger a view update when the app becomes active again
                        NotificationCenter.default.post(name: NSNotification.Name("AppBecameActive"), object: nil)
                    }
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentMinSize)
    }
} 