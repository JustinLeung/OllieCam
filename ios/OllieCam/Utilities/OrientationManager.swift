import UIKit
import Observation

@MainActor
@Observable
final class OrientationManager {
    var allowsLandscape = false

    var supportedOrientations: UIInterfaceOrientationMask {
        allowsLandscape ? .allButUpsideDown : .portrait
    }

    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    func setLandscapeAllowed(_ allowed: Bool) {
        allowsLandscape = allowed
        refreshOrientationLock()
    }

    func requestLandscape() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
    }

    func requestPortrait() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
    }

    private func refreshOrientationLock() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else { return }
        rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
