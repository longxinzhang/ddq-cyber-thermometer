import Foundation

public enum UpdateError: LocalizedError {
    case invalidReleaseURL
    case invalidReleaseFeed
    case httpStatus(Int)
    case invalidChecksumFile
    case checksumMismatch(expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case .invalidReleaseURL:
            return "更新地址无效。"
        case .invalidReleaseFeed:
            return "没有从 GitHub Release 页面解析到最新版本。"
        case .httpStatus(let statusCode):
            return "GitHub 返回了 HTTP \(statusCode)。请稍后再试。"
        case .invalidChecksumFile:
            return "Release 里的 SHA256 校验文件格式无效，已停止安装。"
        case .checksumMismatch(let expected, let actual):
            return "下载的安装包校验失败。\n期望：\(expected)\n实际：\(actual)"
        }
    }
}
