import Foundation

enum TemperatureCommand {
    case osxCPUTemp(String)
    case istats(String)
    case smc(String)

    static func detect(shell: Shell) -> TemperatureCommand? {
        if let path = shell.which("osx-cpu-temp") {
            return .osxCPUTemp(path)
        }
        if let path = shell.which("istats") {
            return .istats(path)
        }
        if let path = shell.which("smc") {
            return .smc(path)
        }
        return nil
    }
}
