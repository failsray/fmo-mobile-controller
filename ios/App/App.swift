import SwiftUI
import AVFoundation

@main
struct FMOXApp: App {
    init() {
        // Keep the radio audio playing when the silent switch is on
        // and when the app goes to the background.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
