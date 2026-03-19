import SwiftUI

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    let orientationManager = OrientationManager()

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        orientationManager.supportedOrientations
    }
}

@main
struct OllieCamApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var serverStore = ServerStore()
    @State private var settingsViewModel = SettingsViewModel()
    @State private var appState: AppState = .splash

    enum AppState {
        case splash
        case onboarding
        case main
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch appState {
                case .splash:
                    SplashView()

                case .onboarding:
                    OnboardingView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            appState = .main
                        }
                    }
                    .environment(serverStore)
                    .environment(settingsViewModel)
                    .transition(.opacity)

                case .main:
                    ContentView()
                        .environment(serverStore)
                        .environment(settingsViewModel)
                        .environment(appDelegate.orientationManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: appState)
            .task {
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation {
                    appState = serverStore.isConfigured ? .main : .onboarding
                }
            }
        }
    }
}

extension OllieCamApp.AppState: Equatable {}
