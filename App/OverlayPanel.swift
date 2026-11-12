import AppKit
import SwiftUI

/// A non-activating panel takes keyboard focus without having to pull the whole app to the front,
/// which macOS no longer lets a background app do reliably.
final class OverlayWindow: NSPanel {
    var onPressBegan: (() -> Void)?
    var onPressEnded: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        let escape: UInt16 = 53
        switch event.type {
        case .leftMouseDown:
            onPressBegan?()
        case .leftMouseUp:
            onPressEnded?()
        case .keyDown:
            if event.keyCode == escape, !event.isARepeat { onPressBegan?() }
        case .keyUp:
            if event.keyCode == escape { onPressEnded?() }
        default:
            super.sendEvent(event)
        }
    }
}

/// Covers every display with the dimmed overlay and turns clicks and Esc into a dismiss request.
@MainActor
final class OverlayController {
    let model = OverlayModel()
    var onDismiss: (() -> Void)?

    private var windows: [OverlayWindow] = []
    private var visible = false
    private var shownAt = Date.distantPast
    private var holdWork: DispatchWorkItem?

    var isVisible: Bool { visible }

    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildIfVisible() }
        }
    }

    func show(stage: Stage, percent: Int, minutesLeft: Int?) {
        if model.stage != stage { cancelHold() }
        model.stage = stage
        model.percent = percent
        model.minutesLeft = minutesLeft
        guard !visible else { return }

        visible = true
        shownAt = Date()

        buildWindows()
        for window in windows {
            window.alphaValue = 0
            window.orderFrontRegardless()
        }
        windows.first?.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            windows.forEach { $0.animator().alphaValue = 1 }
        }
    }

    func hide() {
        guard visible else { return }
        visible = false
        cancelHold()

        let closing = windows
        windows = []
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        })
    }

    private func buildWindows() {
        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(
                contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false)
            window.isFloatingPanel = true
            window.hidesOnDeactivate = false
            window.becomesKeyOnlyIfNeeded = false
            window.setFrame(screen.frame, display: false)
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.animationBehavior = .none
            window.onPressBegan = { [weak self] in self?.pressBegan() }
            window.onPressEnded = { [weak self] in self?.pressEnded() }

            let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: screen.frame.size))
            blur.material = .fullScreenUI
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.appearance = NSAppearance(named: .darkAqua)

            let host = NSHostingView(rootView: OverlayView(model: model))
            host.sizingOptions = []
            host.frame = blur.bounds
            host.autoresizingMask = [.width, .height]
            blur.addSubview(host)
            window.contentView = blur
            return window
        }
    }

    private func rebuildIfVisible() {
        guard visible else { return }
        windows.forEach { $0.orderOut(nil) }
        buildWindows()
        windows.forEach { $0.orderFrontRegardless() }
        windows.first?.makeKey()
    }

    private func pressBegan() {
        // Ignore the click or keystroke that was already under way when the overlay appeared.
        guard visible, Date().timeIntervalSince(shownAt) > 0.8 else { return }
        guard model.stage == .block else {
            onDismiss?()
            return
        }
        guard holdWork == nil else { return }
        model.holding = true
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.holdWork = nil
            self.model.holding = false
            self.onDismiss?()
        }
        holdWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + model.holdSeconds, execute: work)
    }

    private func pressEnded() {
        cancelHold()
    }

    private func cancelHold() {
        holdWork?.cancel()
        holdWork = nil
        model.holding = false
    }
}
