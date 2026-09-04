import SwiftUI

@main
struct HummingbirdApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hb.appearance") private var appearance: AppAppearance = .system

    init() {
        #if DEBUG
        TestSupport.applyLaunchArgumentsIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Theme.accent)
                .preferredColorScheme(appearance.colorScheme)
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskIdentifier)) {
            await BackgroundRefresh.perform()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                BackgroundRefresh.schedule()
            }
        }
    }
}
