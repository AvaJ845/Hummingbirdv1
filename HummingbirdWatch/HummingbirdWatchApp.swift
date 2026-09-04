import SwiftUI

@main
struct HummingbirdWatchApp: App {
    init() {
        #if DEBUG
        WatchTestSupport.applyLaunchArgumentsIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}
