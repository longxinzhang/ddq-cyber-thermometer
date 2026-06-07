import Foundation

final class MenuBarDisplaySettings {
    private let defaults: UserDefaults
    private let key = "menuBarDisplayMetrics"
    private let defaultMetrics: [MenuBarDisplayMetric] = [
        .memoryPressure,
        .memoryUsage,
        .cpuUsage
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var metrics: [MenuBarDisplayMetric] {
        get {
            guard let stored = defaults.stringArray(forKey: key) else {
                return defaultMetrics
            }

            let selected = Set(stored.compactMap(MenuBarDisplayMetric.init(rawValue:)))
            guard !selected.isEmpty else {
                return defaultMetrics
            }

            return MenuBarDisplayMetric.allCases.filter { selected.contains($0) }
        }
        set {
            let selected = Set(newValue)
            let normalized = MenuBarDisplayMetric.allCases.filter { selected.contains($0) }
            let safeMetrics = normalized.isEmpty ? defaultMetrics : normalized
            defaults.set(safeMetrics.map(\.rawValue), forKey: key)
        }
    }

    func isEnabled(_ metric: MenuBarDisplayMetric) -> Bool {
        metrics.contains(metric)
    }

    func canDisable(_ metric: MenuBarDisplayMetric) -> Bool {
        !(isEnabled(metric) && metrics.count == 1)
    }

    func toggle(_ metric: MenuBarDisplayMetric) {
        setEnabled(!isEnabled(metric), for: metric)
    }

    func setEnabled(_ isEnabled: Bool, for metric: MenuBarDisplayMetric) {
        var selected = Set(metrics)

        if isEnabled {
            selected.insert(metric)
        } else if selected.count > 1 {
            selected.remove(metric)
        }

        metrics = MenuBarDisplayMetric.allCases.filter { selected.contains($0) }
    }
}
