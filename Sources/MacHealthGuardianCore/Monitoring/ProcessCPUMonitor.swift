import Foundation

public enum ProcessCPUState: Sendable {
    case sampling
    case ready([ProcessCPUUsage])
    case unavailable
}

@MainActor
public final class ProcessCPUMonitor {
    public var onUpdate: ((ProcessCPUState) -> Void)?

    private var samplingTask: Task<Void, Never>?

    public init() {}

    public func start() {
        stop()
        onUpdate?(.sampling)

        samplingTask = Task { [weak self] in
            var previous: ProcessCPUSample?
            while !Task.isCancelled, self != nil {
                let delay: Duration
                do {
                    let current = try await Task.detached(priority: .utility) {
                        try ProcessCPUSampler().sample()
                    }.value
                    try Task.checkCancellation()

                    if let earlier = previous {
                        self?.onUpdate?(.ready(current.topProcesses(since: earlier)))
                        delay = .seconds(2)
                    } else {
                        delay = .seconds(1)
                    }
                    previous = current
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    self?.onUpdate?(.unavailable)
                    previous = nil
                    delay = .seconds(2)
                }

                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
            }
        }
    }

    public func stop() {
        samplingTask?.cancel()
        samplingTask = nil
    }
}
