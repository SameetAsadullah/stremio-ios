import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if session.role == .windowExternalDisplayNonInteractive {
            let c = UISceneConfiguration(name: "External", sessionRole: session.role)
            c.delegateClass = ExternalDisplaySceneDelegate.self
            return c
        }
        return UISceneConfiguration(name: nil, sessionRole: session.role)
    }
}
