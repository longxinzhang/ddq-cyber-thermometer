import Darwin
import Foundation

final class NetworkSampler: @unchecked Sendable {
    private var previousCounters: NetworkCounters?
    private var previousSampleDate: Date?

    func sample(at date: Date = Date()) -> NetworkSnapshot {
        guard let counters = Self.readCounters() else {
            return .empty
        }

        defer {
            previousCounters = counters
            previousSampleDate = date
        }

        guard let previousCounters,
              let previousSampleDate
        else {
            return NetworkSnapshot(
                downloadBytesPerSecond: 0,
                uploadBytesPerSecond: 0,
                activeInterfaceNames: counters.interfaceNames
            )
        }

        let elapsed = date.timeIntervalSince(previousSampleDate)
        guard elapsed > 0 else {
            return NetworkSnapshot(
                downloadBytesPerSecond: 0,
                uploadBytesPerSecond: 0,
                activeInterfaceNames: counters.interfaceNames
            )
        }

        let deltas = counters.deltas(from: previousCounters)

        return NetworkSnapshot(
            downloadBytesPerSecond: Double(deltas.receivedBytes) / elapsed,
            uploadBytesPerSecond: Double(deltas.sentBytes) / elapsed,
            activeInterfaceNames: deltas.interfaceNames
        )
    }

    private static func readCounters() -> NetworkCounters? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddress = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }

        var interfaces: [String: InterfaceCounters] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let interface = cursor?.pointee {
            defer { cursor = interface.ifa_next }

            guard let address = interface.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  let rawData = interface.ifa_data
            else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            guard shouldIncludeInterface(name: name, flags: interface.ifa_flags) else {
                continue
            }

            let data = rawData.assumingMemoryBound(to: if_data.self).pointee
            interfaces[name] = InterfaceCounters(
                receivedBytes: UInt64(data.ifi_ibytes),
                sentBytes: UInt64(data.ifi_obytes),
                kind: interfaceKind(name: name)
            )
        }

        return NetworkCounters(interfaces: interfaces)
    }

    private static func shouldIncludeInterface(name: String, flags: UInt32) -> Bool {
        guard (flags & UInt32(IFF_UP)) != 0,
              (flags & UInt32(IFF_RUNNING)) != 0,
              (flags & UInt32(IFF_LOOPBACK)) == 0
        else {
            return false
        }

        let includedPrefixes = [
            "en",
            "utun",
            "ipsec",
            "ppp",
            "tun",
            "tap",
            "wg",
            "gif",
            "stf",
            "pdp_ip"
        ]
        return includedPrefixes.contains { name.hasPrefix($0) }
    }

    private static func interfaceKind(name: String) -> InterfaceKind {
        let tunnelPrefixes = ["utun", "ipsec", "ppp", "tun", "tap", "wg", "gif", "stf"]
        return tunnelPrefixes.contains { name.hasPrefix($0) } ? .tunnel : .physical
    }
}

private struct NetworkCounters {
    let interfaces: [String: InterfaceCounters]

    var interfaceNames: [String] {
        interfaces.keys.sorted()
    }

    func deltas(from previous: NetworkCounters) -> NetworkCountersDelta {
        var physicalReceivedBytes: UInt64 = 0
        var physicalSentBytes: UInt64 = 0
        var tunnelReceivedBytes: UInt64 = 0
        var tunnelSentBytes: UInt64 = 0
        var activeInterfaceNames: [String] = []

        for name in interfaceNames {
            guard let current = interfaces[name],
                  let previous = previous.interfaces[name]
            else {
                continue
            }

            let receivedDelta = current.receivedBytes >= previous.receivedBytes
                ? current.receivedBytes - previous.receivedBytes
                : 0
            let sentDelta = current.sentBytes >= previous.sentBytes
                ? current.sentBytes - previous.sentBytes
                : 0

            switch current.kind {
            case .physical:
                physicalReceivedBytes += receivedDelta
                physicalSentBytes += sentDelta
            case .tunnel:
                tunnelReceivedBytes += receivedDelta
                tunnelSentBytes += sentDelta
            }

            if receivedDelta > 0 || sentDelta > 0 {
                activeInterfaceNames.append(name)
            }
        }

        return NetworkCountersDelta(
            receivedBytes: max(physicalReceivedBytes, tunnelReceivedBytes),
            sentBytes: max(physicalSentBytes, tunnelSentBytes),
            interfaceNames: activeInterfaceNames
        )
    }
}

private struct InterfaceCounters {
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let kind: InterfaceKind
}

private struct NetworkCountersDelta {
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let interfaceNames: [String]
}

private enum InterfaceKind {
    case physical
    case tunnel
}
