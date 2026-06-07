import Foundation

private typealias HIDClient = CFTypeRef
private typealias HIDService = CFTypeRef

@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(_ client: HIDClient, _ matching: CFDictionary?)

@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: HIDClient) -> Unmanaged<CFArray>?

@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyProperty(_ service: HIDService, _ key: CFString) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(_ service: HIDService, _ type: Int64, _ options: Int32, _ timeout: Int64) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: CFTypeRef, _ field: Int32) -> Double

final class AppleSiliconTemperatureReader: @unchecked Sendable {
    private let temperatureEventType: Int64 = 15
    private let temperatureEventField: Int32 = 15 << 16
    private let client: HIDClient?

    init() {
        client = IOHIDEventSystemClientCreate(kCFAllocatorDefault)?.takeRetainedValue()

        if let client {
            let matching: CFDictionary = [
                "PrimaryUsagePage" as CFString: 0xFF00 as CFNumber,
                "PrimaryUsage" as CFString: 5 as CFNumber
            ] as CFDictionary
            IOHIDEventSystemClientSetMatching(client, matching)
        }
    }

    func readCoreTemperature() -> Double? {
        guard let client,
              let services = IOHIDEventSystemClientCopyServices(client)?.takeRetainedValue()
        else {
            return nil
        }

        var temperatures: [Double] = []

        for index in 0..<CFArrayGetCount(services) {
            let service = unsafeBitCast(CFArrayGetValueAtIndex(services, index), to: HIDService.self)
            let product = IOHIDServiceClientCopyProperty(service, "Product" as CFString)?
                .takeRetainedValue() as? String ?? ""

            guard product.localizedCaseInsensitiveContains("tdie"),
                  let event = IOHIDServiceClientCopyEvent(service, temperatureEventType, 0, 0)?.takeRetainedValue()
            else {
                continue
            }

            let value = IOHIDEventGetFloatValue(event, temperatureEventField)
            if value >= 10, value <= 130 {
                temperatures.append(value)
            }
        }

        return temperatures.max()
    }
}
