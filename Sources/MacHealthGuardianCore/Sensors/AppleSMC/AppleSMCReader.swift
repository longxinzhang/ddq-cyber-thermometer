import Foundation
import IOKit

struct SMCKeyDataVers {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

struct SMCKeyDataPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

struct SMCKeyDataKeyInfo {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCKeyDataVers()
    var pLimitData = SMCKeyDataPLimitData()
    var keyInfo = SMCKeyDataKeyInfo()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
}

struct SMCValue {
    let type: String
    let bytes: [UInt8]
}

final class AppleSMCReader: @unchecked Sendable {
    private let smcHandleYPCEvent: UInt32 = 2
    private let smcCmdReadBytes: UInt8 = 5
    private let smcCmdReadKeyInfo: UInt8 = 9
    private var connection: io_connect_t = 0

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else {
            return nil
        }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    func readNumeric(_ key: String) -> Double? {
        guard let value = read(key) else { return nil }
        return decodeNumeric(value)
    }

    private func read(_ key: String) -> SMCValue? {
        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = Self.fourCC(key)
        input.data8 = smcCmdReadKeyInfo

        guard call(input: &input, output: &output) == KERN_SUCCESS,
              output.result == 0
        else {
            return nil
        }

        input.keyInfo = output.keyInfo
        input.data8 = smcCmdReadBytes

        guard call(input: &input, output: &output) == KERN_SUCCESS,
              output.result == 0
        else {
            return nil
        }

        let size = min(Int(output.keyInfo.dataSize), 32)
        let bytes = withUnsafeBytes(of: output.bytes) { rawBuffer in
            Array(rawBuffer.prefix(size))
        }

        return SMCValue(
            type: Self.fourCCString(output.keyInfo.dataType),
            bytes: bytes
        )
    }

    private func call(input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride
        return IOConnectCallStructMethod(
            connection,
            smcHandleYPCEvent,
            &input,
            inputSize,
            &output,
            &outputSize
        )
    }

    private func decodeNumeric(_ value: SMCValue) -> Double? {
        let bytes = value.bytes

        switch value.type {
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(raw) / 4.0
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let raw = (UInt32(bytes[0]) << 24) |
                (UInt32(bytes[1]) << 16) |
                (UInt32(bytes[2]) << 8) |
                UInt32(bytes[3])
            return Double(Float(bitPattern: raw))
        case "ui8 ":
            return bytes.first.map(Double.init)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            return Double((UInt32(bytes[0]) << 24) |
                (UInt32(bytes[1]) << 16) |
                (UInt32(bytes[2]) << 8) |
                UInt32(bytes[3]))
        default:
            return nil
        }
    }

    private static func fourCC(_ string: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in string.utf8.prefix(4) {
            result = (result << 8) + UInt32(byte)
        }
        return result
    }

    private static func fourCCString(_ value: UInt32) -> String {
        let bytes = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ].filter { $0 != 0 }
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }
}
