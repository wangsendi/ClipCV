import SwiftData
import SwiftUI

@main
struct ClipCVApp: App {
    @State private var runtime = AppRuntime()

    var body: some Scene {
        WindowGroup {
            AppRootView().environment(runtime).modelContainer(runtime.container)
        }
    }
}

private struct AppRootView: View {
    @Environment(AppRuntime.self) private var runtime
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            if runtime.settings.hasStarted { HistoryView() }
            else { WelcomeView() }
        }
        .tint(ClipStyle.green)
        .fontDesign(.rounded)
        .environment(\.locale, runtime.settings.locale)
        .preferredColorScheme(runtime.settings.appearance == "system" ? nil : runtime.settings.appearance == "dark" ? .dark : .light)
        .onAppear { runtime.setActive(scenePhase == .active) }
        .onChange(of: scenePhase) { _, phase in runtime.setActive(phase == .active) }
        .onChange(of: runtime.settings.paused) { runtime.updateRecording() }
        .onChange(of: runtime.settings.hasStarted) { runtime.updateRecording() }
    }
}
