import SwiftUI

@main
struct HummingbirdWatchApp: App {
    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            WatchContentView(store: store)
        }
    }
}
