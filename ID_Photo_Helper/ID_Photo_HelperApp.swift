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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onChange(of: scenePhase) { phase in
                    // Force redraw when window becomes active again
                    if phase == .active {
                        // This will trigger a view update when the app becomes active again
                        NotificationCenter.default.post(name: NSNotification.Name("AppBecameActive"), object: nil)
                        
                        // Set shared view model in app delegate when the app becomes active
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.sharedViewModel = viewModel
                        }
                    }
                }
                .onAppear {
                    // Set shared view model in app delegate when the view appears
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.sharedViewModel = viewModel
                    }
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentMinSize)
    }
} 