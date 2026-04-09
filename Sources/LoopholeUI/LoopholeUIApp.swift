import SwiftUI

@main
struct LoopholeUIApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 1100, minHeight: 760)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
