import SwiftUI

/// First-run screen. Downloads Stremio's streaming engine, which the app needs
/// before it can play torrents.
struct OnboardingView: View {
    let onDone: () -> Void

    @State private var busy = false
    @State private var busyText = ""
    @State private var error: String?

    private let purple = Color(red: 123 / 255, green: 91 / 255, blue: 245 / 255)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.07, blue: 0.16), .black],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                logo.padding(.top, 24)

                Text("Stremio for iPhone")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)

                Text("Torrents play on this device through Stremio\u{2019}s streaming engine. The app downloads it once (about 7 MB).")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red.opacity(0.9))
                }

                Button(action: finish) {
                    Text(busy ? busyText : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(purple, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .disabled(busy)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
    }

    private func finish() {
        error = nil
        busy = true
        ServerScript.ensure(progress: { busyText = $0 }) { ok in
            busy = false
            if ok {
                onDone()
            } else {
                error = "Couldn\u{2019}t download the streaming engine. Check your connection and try again."
            }
        }
    }

    private var logo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(purple).frame(width: 72, height: 72)
            Image(systemName: "play.fill").font(.system(size: 32, weight: .bold)).foregroundStyle(.white).offset(x: 3)
        }
    }
}
