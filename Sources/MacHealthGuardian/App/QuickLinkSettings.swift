import Foundation

final class QuickLinkSettings {
    static let slotCount = 3

    private let defaults: UserDefaults
    private let key = "quickLinks"
    private let defaultLinks: [QuickLink?] = [
        QuickLink(title: "雪鸡号池用量", urlString: "https://ddq.stats.trytrythisai.com/"),
        nil,
        nil
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var links: [QuickLink?] {
        get {
            guard let data = defaults.data(forKey: key),
                  let stored = try? JSONDecoder().decode([QuickLink?].self, from: data)
            else {
                return defaultLinks
            }

            return normalizedSlots(stored)
        }
        set {
            let normalized = normalizedSlots(newValue)
            guard let data = try? JSONEncoder().encode(normalized) else { return }
            defaults.set(data, forKey: key)
        }
    }

    func link(at index: Int) -> QuickLink? {
        guard Self.slotRange.contains(index) else { return nil }
        return links[index]
    }

    func setLink(_ link: QuickLink?, at index: Int) {
        guard Self.slotRange.contains(index) else { return }

        var current = links
        current[index] = normalizedLink(link)
        links = current
    }

    private func normalizedSlots(_ slots: [QuickLink?]) -> [QuickLink?] {
        var result = Array(slots.prefix(Self.slotCount)).map(normalizedLink)

        while result.count < Self.slotCount {
            result.append(nil)
        }

        return result
    }

    private func normalizedLink(_ link: QuickLink?) -> QuickLink? {
        guard let link else { return nil }
        return QuickLink(title: link.title, rawURLString: link.urlString)
    }

    private static var slotRange: Range<Int> {
        0..<slotCount
    }
}
