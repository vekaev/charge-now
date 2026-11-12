import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let monitor = BatteryMonitor()
    private let overlay = OverlayController()
    private var policy = Policy()
    private var reading: Reading?
    private var preview: Stage?

    private var statusItem: NSStatusItem?
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return
        }

        let defaults = UserDefaults.standard
        defaults.register(defaults: ["warnAt": 10, "blockAt": 5, "holdSeconds": 2.0])
        policy.blockAt = min(max(defaults.integer(forKey: "blockAt"), 1), 50)
        policy.warnAt = max(defaults.integer(forKey: "warnAt"), policy.blockAt)
        overlay.model.holdSeconds = max(defaults.double(forKey: "holdSeconds"), 0.5)

        overlay.onDismiss = { [weak self] in self?.userDismissed() }
        buildMenu()

        monitor.onChange = { [weak self] reading in
            self?.reading = reading
            self?.evaluate()
        }
        monitor.start()

        enableLoginItemOnFirstLaunch()
        runPreviewFromArguments()
    }

    // MARK: - Deciding what to show

    private func evaluate() {
        if let preview {
            overlay.show(stage: preview, percent: preview == .block ? 4 : 9, minutesLeft: nil)
            return
        }
        guard let reading else {
            overlay.hide()
            return
        }
        let stage = policy.stage(for: reading)
        if stage == .none {
            overlay.hide()
        } else {
            overlay.show(stage: stage, percent: reading.percent, minutesLeft: reading.minutesLeft)
        }
    }

    private func userDismissed() {
        if preview != nil {
            preview = nil
        } else if let reading {
            policy.dismiss(overlay.model.stage, at: reading.percent)
        }
        evaluate()
    }

    // MARK: - Menu bar

    private func buildMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Charge Now")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.delegate = self
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Preview Warning", action: #selector(previewWarning), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Preview Block", action: #selector(previewBlock), keyEquivalent: "").target = self
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Charge Now", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        if let reading {
            statusLine.title = "\(reading.percent)% · \(reading.onBattery ? "on battery" : "charger connected")"
                + " · warns at \(policy.warnAt)%, blocks at \(policy.blockAt)%"
        } else {
            statusLine.title = "No battery found"
        }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        loginItem.isHidden = Bundle.main.bundleIdentifier == nil
    }

    @objc private func previewWarning() { startPreview(.warning) }
    @objc private func previewBlock() { startPreview(.block) }

    private func startPreview(_ stage: Stage) {
        overlay.hide()
        preview = stage
        evaluate()
    }

    // MARK: - Launch at login

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("ChargeNow: could not change the login item: \(error.localizedDescription)")
        }
    }

    private func enableLoginItemOnFirstLaunch() {
        let key = "didSetUpLoginItem"
        guard Bundle.main.bundleIdentifier != nil, !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        do {
            try SMAppService.mainApp.register()
        } catch {
            NSLog("ChargeNow: could not add the login item: \(error.localizedDescription)")
        }
    }

    // MARK: - Command line preview

    /// `--preview warning|block [--seconds N]` shows the overlay once, for checking the design.
    private func runPreviewFromArguments() {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--preview"), index + 1 < args.count,
              let stage = Stage(rawValue: args[index + 1]), stage != .none
        else { return }
        startPreview(stage)
        if let index = args.firstIndex(of: "--seconds"), index + 1 < args.count,
           let seconds = Double(args[index + 1]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { NSApp.terminate(nil) }
        }
    }
}
