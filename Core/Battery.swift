import Foundation
import IOKit.ps

/// Reports the internal battery's state. macOS pushes changes, so this costs nothing while idle.
@MainActor
final class BatteryMonitor {
    var onChange: ((Reading?) -> Void)?
    private var timer: Timer?

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.refresh() }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        // Safety net in case a notification is missed, for example across sleep.
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
    }

    func refresh() {
        onChange?(Self.read())
    }

    /// Returns nil on a Mac without a battery.
    static func read() -> Reading? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = info[kIOPSCurrentCapacityKey] as? Int,
                  let capacity = info[kIOPSMaxCapacityKey] as? Int, capacity > 0
            else { continue }

            let onBattery = info[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue
            let minutes = info[kIOPSTimeToEmptyKey] as? Int
            return Reading(
                percent: Int((Double(current) / Double(capacity) * 100).rounded()),
                onBattery: onBattery,
                minutesLeft: (minutes ?? -1) > 0 ? minutes : nil
            )
        }
        return nil
    }
}
