import Darwin
import Foundation

struct CPUTicks {
    let user: UInt64
    let nice: UInt64
    let system: UInt64
    let idle: UInt64

    static func current() -> CPUTicks? {
        var cpuInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        return CPUTicks(
            user: UInt64(cpuInfo.cpu_ticks.0),
            nice: UInt64(cpuInfo.cpu_ticks.3),
            system: UInt64(cpuInfo.cpu_ticks.1),
            idle: UInt64(cpuInfo.cpu_ticks.2)
        )
    }
}
