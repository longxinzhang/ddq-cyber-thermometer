import Foundation

final class FanSpeedReader: @unchecked Sendable {
    private let shell: Shell
    private let smcReader: AppleSMCReader?

    init(shell: Shell) {
        self.shell = shell
        self.smcReader = AppleSMCReader()
    }

    func read() -> FanSpeedSnapshot {
        if let snapshot = readFromSMC() {
            return snapshot
        }
        if let snapshot = readFromIStats() {
            return snapshot
        }
        if let snapshot = readFromSMCCommand() {
            return snapshot
        }
        return .unknown
    }

    private func readFromSMC() -> FanSpeedSnapshot? {
        guard let smcReader else { return nil }

        if let fanCount = smcReader.readNumeric("FNum") {
            let count = Int(fanCount.rounded())
            if count == 0 {
                return .fanless
            }

            let speeds = (0..<min(count, 8)).compactMap { index in
                smcReader.readNumeric("F\(index)Ac")
            }
            if !speeds.isEmpty {
                return FanSpeedSnapshot(speedsRPM: speeds, isFanless: false, source: "SMC")
            }
        }

        let fallbackSpeeds = (0..<4).compactMap { index in
            smcReader.readNumeric("F\(index)Ac")
        }
        guard !fallbackSpeeds.isEmpty else { return nil }
        return FanSpeedSnapshot(speedsRPM: fallbackSpeeds, isFanless: false, source: "SMC")
    }

    private func readFromIStats() -> FanSpeedSnapshot? {
        guard let path = shell.which("istats") else { return nil }
        let output = shell.run(path, ["fan", "speed"])
        let speeds = Self.rpmValues(in: output)
        guard !speeds.isEmpty else { return nil }
        return FanSpeedSnapshot(speedsRPM: speeds, isFanless: false, source: "iStats")
    }

    private func readFromSMCCommand() -> FanSpeedSnapshot? {
        guard let path = shell.which("smc") else { return nil }

        if let fanCount = Self.firstReasonableNumber(in: shell.run(path, ["-k", "FNum", "-r"])) {
            let count = Int(fanCount.rounded())
            if count == 0 {
                return .fanless
            }

            let speeds = (0..<min(count, 8)).compactMap { index in
                Self.firstReasonableNumber(in: shell.run(path, ["-k", "F\(index)Ac", "-r"]))
            }
            if !speeds.isEmpty {
                return FanSpeedSnapshot(speedsRPM: speeds, isFanless: false, source: "smc")
            }
        }

        let fallbackSpeeds = (0..<4).compactMap { index in
            Self.firstReasonableNumber(in: shell.run(path, ["-k", "F\(index)Ac", "-r"]))
        }
        guard !fallbackSpeeds.isEmpty else { return nil }
        return FanSpeedSnapshot(speedsRPM: fallbackSpeeds, isFanless: false, source: "smc")
    }

    private static func rpmValues(in text: String) -> [Double] {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*(?:RPM|rpm)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match -> Double? in
            guard let valueRange = Range(match.range(at: 1), in: text),
                  let value = Double(text[valueRange]),
                  value >= 0,
                  value <= 20_000
            else {
                return nil
            }
            return value
        }
    }

    private static func firstReasonableNumber(in text: String) -> Double? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match -> Double? in
            guard let valueRange = Range(match.range(at: 1), in: text),
                  let value = Double(text[valueRange]),
                  value >= 0,
                  value <= 20_000
            else {
                return nil
            }
            return value
        }.last
    }
}
