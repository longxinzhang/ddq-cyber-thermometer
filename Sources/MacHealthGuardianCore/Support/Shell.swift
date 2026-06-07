import Foundation

final class Shell: @unchecked Sendable {
    func run(_ executable: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        if data.isEmpty {
            return String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func which(_ command: String) -> String? {
        let output = run("/usr/bin/which", [command])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? nil : output
    }
}
