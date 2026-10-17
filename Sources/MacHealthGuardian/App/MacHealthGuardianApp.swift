import Darwin
import Foundation
import SwiftUI
import MacHealthGuardianCore

@main
struct MacHealthGuardianApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let arguments = CommandLine.arguments

        if arguments.contains("--help") {
            print("""
            DDQ's Cyber Thermometer / 动动枪赛博体温计

            Usage:
              MacHealthGuardian             Launch menu bar thermometer
              MacHealthGuardian --sample    Print one compact metrics sample
              MacHealthGuardian --top-cpu   Print the three busiest CPU processes
            """)
            Darwin.exit(0)
        }

        if arguments.contains("--top-cpu") {
            do {
                let sampler = ProcessCPUSampler()
                let previous = try sampler.sample()
                Thread.sleep(forTimeInterval: 1)
                let processes = try sampler.sample().topProcesses(since: previous)
                print("CPU 占用前三（100% = 1 个逻辑核心）")
                for (index, process) in processes.enumerated() {
                    let usage = String(format: "%.1f%%", process.cpuUsage)
                    print("\(index + 1). \(process.name) (PID \(process.pid))  \(usage)")
                }
                Darwin.exit(0)
            } catch {
                print("暂时无法读取进程 CPU 占用")
                Darwin.exit(1)
            }
        }

        if arguments.contains("--sample") || arguments.contains("--doctor") {
            let sampler = SystemSampler()
            _ = sampler.sample()
            Thread.sleep(forTimeInterval: 1)
            print(sampler.sample().summaryText)
            Darwin.exit(0)
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
