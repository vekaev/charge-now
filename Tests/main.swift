// Walks Core/Policy.swift through a discharge. Run with scripts/test-core.sh.
import Foundation

var failures = 0

func expect(_ got: Stage, _ want: Stage, _ label: String) {
    if got != want {
        failures += 1
        print("FAIL \(label): got \(got.rawValue), want \(want.rawValue)")
    }
}

func battery(_ percent: Int) -> Reading { Reading(percent: percent, onBattery: true) }
func charger(_ percent: Int) -> Reading { Reading(percent: percent, onBattery: false) }

var policy = Policy()
expect(policy.stage(for: battery(50)), .none, "50% on battery")
expect(policy.stage(for: battery(11)), .none, "11% on battery")
expect(policy.stage(for: battery(10)), .warning, "10% on battery")
expect(policy.stage(for: charger(10)), .none, "10% on the charger")
expect(policy.stage(for: battery(9)), .warning, "9% after unplugging again")
policy.dismiss(.warning, at: 9)
expect(policy.stage(for: battery(9)), .none, "9% after dismissing the warning")
expect(policy.stage(for: battery(6)), .none, "6% stays dismissed")
expect(policy.stage(for: battery(5)), .block, "5% blocks even after the warning was dismissed")
policy.dismiss(.block, at: 5)
expect(policy.stage(for: battery(5)), .none, "5% after hold to dismiss")
expect(policy.stage(for: battery(4)), .block, "4% blocks again")
policy.dismiss(.block, at: 4)
expect(policy.stage(for: battery(4)), .none, "4% after hold to dismiss")
expect(policy.stage(for: battery(1)), .block, "1% blocks again")
expect(policy.stage(for: charger(1)), .none, "1% on the charger")
expect(policy.stage(for: battery(3)), .block, "3% after unplugging again")
expect(policy.stage(for: charger(40)), .none, "40% on the charger")
expect(policy.stage(for: battery(8)), .warning, "8% warns again after a charge")

var custom = Policy()
custom.warnAt = 20
custom.blockAt = 8
expect(custom.stage(for: battery(20)), .warning, "custom warning threshold")
expect(custom.stage(for: battery(8)), .block, "custom block threshold")

print(failures == 0 ? "Core tests passed" : "Core tests failed: \(failures)")
exit(failures == 0 ? 0 : 1)
