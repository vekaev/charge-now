import Foundation

enum Stage: String {
    case none
    /// Dimmed screen with a message. One click or Esc dismisses it.
    case warning
    /// Dimmed screen that stays until the charger is connected.
    /// Holding Esc (or the mouse) snoozes it until the battery drops another percent.
    case block
}

struct Reading: Equatable {
    var percent: Int
    var onBattery: Bool
    /// Minutes until empty, when macOS has an estimate.
    var minutesLeft: Int?
}

/// Decides which stage to show for a battery reading. No UI and no battery access, so Tests/main.swift can
/// walk it through a whole discharge.
struct Policy {
    var warnAt = 10
    var blockAt = 5

    private(set) var warningDismissed = false
    /// The block stays hidden while the battery is at or above this percent.
    private(set) var snoozedAt: Int?

    mutating func stage(for reading: Reading) -> Stage {
        guard reading.onBattery else {
            warningDismissed = false
            snoozedAt = nil
            return .none
        }
        if reading.percent <= blockAt {
            if let snoozedAt, reading.percent >= snoozedAt { return .none }
            return .block
        }
        snoozedAt = nil
        if reading.percent <= warnAt {
            return warningDismissed ? .none : .warning
        }
        warningDismissed = false
        return .none
    }

    mutating func dismiss(_ stage: Stage, at percent: Int) {
        switch stage {
        case .warning: warningDismissed = true
        case .block: snoozedAt = percent
        case .none: break
        }
    }
}
