import Foundation

final class TemperatureReader: @unchecked Sendable {
    private let shell: Shell
    private let appleSiliconReader: AppleSiliconTemperatureReader
    private let command: TemperatureCommand?

    init(shell: Shell) {
        self.shell = shell
        self.appleSiliconReader = AppleSiliconTemperatureReader()
        self.command = TemperatureCommand.detect(shell: shell)
    }

    func read() -> Double? {
        if let temperature = appleSiliconReader.readCoreTemperature() {
            return temperature
        }

        guard let command else { return nil }

        switch command {
        case .osxCPUTemp(let path):
            return Self.lastReasonableNumber(in: shell.run(path, []))
        case .istats(let path):
            return Self.lastReasonableNumber(in: shell.run(path, ["cpu", "temp"]))
        case .smc(let path):
            return Self.lastReasonableNumber(in: shell.run(path, ["-k", "TC0P", "-r"]))
        }
    }

    private static func lastReasonableNumber(in text: String) -> Double? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(text.startIndex..., in: text)
        let values = regex
            .matches(in: text, range: range)
            .compactMap { match -> Double? in
                guard let valueRange = Range(match.range(at: 1), in: text) else { return nil }
                return Double(text[valueRange])
            }

        return values.reversed().first { $0 >= 10 && $0 <= 130 }
    }
}
