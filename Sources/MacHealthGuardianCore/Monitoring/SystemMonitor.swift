import Foundation

@MainActor
public final class SystemMonitor {
    public var onSnapshot: ((SystemSnapshot) -> Void)?

    private let sampler = SystemSampler()
    private var timer: Timer?
    private var isRefreshing = false

    public init() {}

    public func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    public func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        DispatchQueue.global(qos: .utility).async { [sampler] in
            let snapshot = sampler.sample()
            DispatchQueue.main.async { [weak self] in
                self?.onSnapshot?(snapshot)
                self?.isRefreshing = false
            }
        }
    }
}
