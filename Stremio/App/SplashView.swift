import SwiftUI

/// Continues the launch screen until the web app has loaded. The logo sits where the launch
/// screen draws it, so the switch is not visible.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground")
            Image("LaunchLogo")
        }
        .ignoresSafeArea()
    }
}
