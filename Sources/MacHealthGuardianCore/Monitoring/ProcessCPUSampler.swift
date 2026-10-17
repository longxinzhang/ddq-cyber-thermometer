import Darwin
import Foundation

struct ProcessCPUReading: Sendable {
    let name: String
    let startedAt: UInt64
    let userTicks: UInt64
    let systemTicks: UInt64
}

public struct ProcessCPUSample: Sendable {
    let uptimeTicks: UInt64
    let processes: [Int32: ProcessCPUReading]

    public func topProcesses(since previous: ProcessCPUSample, limit: Int = 3) -> [ProcessCPUUsage] {
        guard limit > 0, uptimeTicks > previous.uptimeTicks else { return [] }
        let elapsed = Double(uptimeTicks - previous.uptimeTicks)

        return processes.compactMap { pid, current -> ProcessCPUUsage? in
            guard let earlier = previous.processes[pid],
                  current.startedAt == earlier.startedAt,
                  current.userTicks >= earlier.userTicks,
                  current.systemTicks >= earlier.systemTicks
            else {
                return nil
            }

            let cpuTime = Double(current.userTicks - earlier.userTicks)
                + Double(current.systemTicks - earlier.systemTicks)
            // Match Activity Monitor: a fully occupied logical core is 100%.
            return ProcessCPUUsage(pid: pid, name: current.name, cpuUsage: cpuTime / elapsed * 100)
        }
        .sorted { first, second in
            if first.cpuUsage == second.cpuUsage { return first.pid < second.pid }
            return first.cpuUsage > second.cpuUsage
        }
        .prefix(limit)
        .map { $0 }
    }
}

public struct ProcessCPUSampler: Sendable {
    public init() {}

    public func sample() throws -> ProcessCPUSample {
        let estimatedCount = proc_listallpids(nil, 0)
        guard estimatedCount > 0 else { throw ProcessCPUReadError.unavailable }

        var pids = [pid_t](repeating: -1, count: Int(estimatedCount) + 128)
        let count = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard count > 0 else { throw ProcessCPUReadError.unavailable }

        var processes: [Int32: ProcessCPUReading] = [:]
        for pid in pids.prefix(min(Int(count), pids.count)) where pid >= 0 {
            var usage = rusage_info_v2()
            let result = withUnsafeMutablePointer(to: &usage) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
                }
            }
            guard result == 0, usage.ri_proc_exit_abstime == 0 else { continue }

            processes[pid] = ProcessCPUReading(
                name: processName(for: pid),
                startedAt: usage.ri_proc_start_abstime,
                userTicks: usage.ri_user_time,
                systemTicks: usage.ri_system_time
            )
        }
        guard !processes.isEmpty else { throw ProcessCPUReadError.unavailable }

        // rusage CPU counters and mach_absolute_time share the same platform timebase.
        return ProcessCPUSample(
            uptimeTicks: mach_absolute_time(),
            processes: processes
        )
    }

    private func processName(for pid: pid_t) -> String {
        // PROC_PIDPATHINFO_MAXSIZE is a C expression that Swift does not import.
        var pathBuffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let pathLength = pathBuffer.withUnsafeMutableBytes { buffer in
            proc_pidpath(pid, buffer.baseAddress, UInt32(buffer.count))
        }
        if pathLength > 0 {
            let path = decodedString(pathBuffer)
            let name = URL(fileURLWithPath: path).lastPathComponent
            if !name.isEmpty { return name }
        }

        var nameBuffer = [CChar](repeating: 0, count: 256)
        let nameLength = nameBuffer.withUnsafeMutableBytes { buffer in
            proc_name(pid, buffer.baseAddress, UInt32(buffer.count))
        }
        if nameLength > 0 {
            let name = decodedString(nameBuffer)
            if !name.isEmpty { return name }
        }
        return "PID \(pid)"
    }

    private func decodedString(_ buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

private enum ProcessCPUReadError: Error {
    case unavailable
}
