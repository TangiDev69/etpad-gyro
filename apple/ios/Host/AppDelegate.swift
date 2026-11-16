// Native scene structure adapted from UTP AppDelegate.swift and SceneDelegate.swift.
// UTP a9313911efcf044fd66f9a679af53e55e255a8b4. GPL-3.0-or-later.
import UIKit
@main final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "ETPad", sessionRole: session.role)
    }
}
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = GameViewController()
        self.window = window
        window.makeKeyAndVisible()
        landscape(scene)
    }
    func sceneDidBecomeActive(_ scene: UIScene) {
        if let scene = scene as? UIWindowScene { landscape(scene) }
        (window?.rootViewController as? GameViewController)?.restoreHost()
    }
    private func landscape(_ scene: UIWindowScene) {
        window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { NSLog("ETPad rotation: %@", $0.localizedDescription) }
    }
}
