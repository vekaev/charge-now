import SwiftUI

@MainActor
final class OverlayModel: ObservableObject {
    @Published var stage: Stage = .warning
    @Published var percent = 0
    @Published var minutesLeft: Int?
    @Published var holding = false
    var holdSeconds = 2.0

    /// What the number counts, in plain words, with the time left when macOS has an estimate.
    var detail: String {
        guard let minutesLeft else { return "\(percent)% battery left." }
        return "\(percent)% battery left, about \(minutesLeft) \(minutesLeft == 1 ? "minute" : "minutes")."
    }
}

/// The whole screen: why it is dimmed, what to do now, and the way back in.
struct OverlayView: View {
    @ObservedObject var model: OverlayModel

    private var blocked: Bool { model.stage == .block }

    var body: some View {
        ZStack {
            Theme.shade.opacity(blocked ? Theme.dimBlock : Theme.dimWarning)

            VStack(spacing: 0) {
                BatteryMark(fraction: Double(model.percent) / 100, charge: blocked ? Theme.danger : Theme.ink)
                    .padding(.bottom, Theme.Space.l)
                InkHeadline(text: "you need to charge as soon as possible.")
                Text(model.detail)
                    .font(.system(size: Theme.Size.detail))
                    .monospacedDigit()
                    .foregroundStyle(Theme.quiet)
                    .padding(.top, Theme.Space.xxs)
            }
            .padding(.horizontal, Theme.Space.xxl)

            VStack(spacing: Theme.Space.s) {
                Spacer(minLength: 0)
                if blocked {
                    Text("Plug in the charger to continue.")
                        .font(.system(size: Theme.Size.hint, weight: .medium))
                        .foregroundStyle(Theme.quiet)
                    HoldBar(holding: model.holding, seconds: model.holdSeconds)
                    Text("Or hold esc to keep working.")
                        .font(.system(size: Theme.Size.hint))
                        .foregroundStyle(Theme.faint)
                } else {
                    Text("Click anywhere or press esc to dismiss.")
                        .font(.system(size: Theme.Size.hint))
                        .foregroundStyle(Theme.faint)
                }
            }
            .padding(.bottom, Theme.Space.edge)
        }
        .animation(Theme.calm, value: model.stage)
        .animation(Theme.calm, value: model.percent)
        .ignoresSafeArea()
    }
}

/// An empty battery with the little charge that is left. The outline is ink; only the charge takes a color.
struct BatteryMark: View {
    var fraction: Double
    var charge: Color

    var body: some View {
        let room = Theme.Mark.width - Theme.Mark.inset * 2
        HStack(spacing: Theme.Mark.capGap) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Theme.Mark.radius, style: .continuous)
                    .strokeBorder(Theme.ink, lineWidth: Theme.Mark.stroke)
                RoundedRectangle(cornerRadius: Theme.Mark.chargeRadius, style: .continuous)
                    .fill(charge)
                    .frame(width: max(Theme.Mark.minCharge, room * min(max(fraction, 0), 1)))
                    .padding(Theme.Mark.inset)
            }
            .frame(width: Theme.Mark.width, height: Theme.Mark.height)

            Capsule()
                .fill(Theme.ink)
                .frame(width: Theme.Mark.capWidth, height: Theme.Mark.capHeight)
        }
        .accessibilityHidden(true)
    }
}

/// A thin line that fills while Esc or the mouse is held down.
struct HoldBar: View {
    var holding: Bool
    var seconds: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Theme.line)
            Capsule().fill(Theme.ink)
                .frame(width: holding ? Theme.Size.holdWidth : 0)
                .animation(holding ? .linear(duration: seconds) : Theme.calm, value: holding)
        }
        .frame(width: Theme.Size.holdWidth, height: Theme.Size.holdHeight)
    }
}
