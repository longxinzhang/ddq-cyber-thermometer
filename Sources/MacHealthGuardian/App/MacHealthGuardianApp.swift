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
            """)
            Darwin.exit(0)
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
