import Foundation

public struct NetworkSnapshot: Sendable {
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double
    public let activeInterfaceNames: [String]

    public static let empty = NetworkSnapshot(
        downloadBytesPerSecond: 0,
        uploadBytesPerSecond: 0,
        activeInterfaceNames: []
    )

    public init(
        downloadBytesPerSecond: Double,
        uploadBytesPerSecond: Double,
        activeInterfaceNames: [String]
    ) {
        self.downloadBytesPerSecond = max(0, downloadBytesPerSecond)
        self.uploadBytesPerSecond = max(0, uploadBytesPerSecond)
        self.activeInterfaceNames = activeInterfaceNames
    }

    public var displayText: String {
        "下载 \(downloadBytesPerSecond.bytesPerSecondText)  上传 \(uploadBytesPerSecond.bytesPerSecondText)"
    }

    public var shortText: String {
        "↓\(downloadBytesPerSecond.compactBytesPerSecondText) ↑\(uploadBytesPerSecond.compactBytesPerSecondText)"
    }

    public var downloadShortText: String {
        "↓\(downloadBytesPerSecond.compactBytesPerSecondText)"
    }

    public var uploadShortText: String {
        "↑\(uploadBytesPerSecond.compactBytesPerSecondText)"
    }

    public var interfaceText: String {
        guard !activeInterfaceNames.isEmpty else { return "暂无实时流量" }
        return activeInterfaceNames.joined(separator: ", ")
    }
}
