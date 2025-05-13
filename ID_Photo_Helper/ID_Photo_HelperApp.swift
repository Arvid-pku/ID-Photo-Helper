import SwiftUI

@main
struct ID_Photo_HelperApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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