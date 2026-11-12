import AppKit
import SwiftUI

@main
enum ChargeNow {
    @MainActor
    static func main() {
        let arguments = CommandLine.arguments

        // `--render <folder>` writes both stages as PNGs without touching the screen (README pictures, design checks).
        if let index = arguments.firstIndex(of: "--render"), index + 1 < arguments.count {
            exit(render(to: arguments[index + 1]) ? 0 : 1)
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu-bar only: no Dock icon, no main window.
        app.setActivationPolicy(.accessory)
        app.run()
    }

    @MainActor
    private static func render(to folder: String) -> Bool {
        var ok = true
        for (stage, percent, minutes) in [(Stage.warning, 9, 14), (Stage.block, 4, 6)] {
            let model = OverlayModel()
            model.stage = stage
            model.percent = percent
            model.minutesLeft = minutes
            // A stand-in desktop behind the shade: the real overlay blurs whatever is on screen.
            let view = OverlayView(model: model)
                .frame(width: 1280, height: 800)
                .background(LinearGradient(colors: [Theme.quiet, Theme.faint], startPoint: .top, endPoint: .bottom))
                .background(Theme.shade)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]),
                  (try? data.write(to: URL(fileURLWithPath: "\(folder)/\(stage.rawValue).png"))) != nil
            else {
                ok = false
                continue
            }
        }
        return ok
    }
}
