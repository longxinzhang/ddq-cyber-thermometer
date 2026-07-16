import AppKit

final class MonthCalendarMenuView: NSView {
    private let calendar: Calendar
    private var displayedMonthStart: Date
    private let titleLabel = NSTextField(labelWithString: "")
    private let previousButton = NSButton(title: "‹", target: nil, action: nil)
    private let nextButton = NSButton(title: "›", target: nil, action: nil)
    private var dayViews: [MonthCalendarDayView] = []

    init(calendar: Calendar = .mondayFirstGregorian) {
        self.calendar = calendar
        displayedMonthStart = MonthCalendarGrid.monthStart(containing: Date(), calendar: calendar)
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 188))

        configureView()
        renderMonth()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 260, height: 188)
    }

    func resetToCurrentMonth() {
        displayedMonthStart = MonthCalendarGrid.monthStart(containing: Date(), calendar: calendar)
        renderMonth()
    }

    @objc private func showPreviousMonth() {
        displayedMonthStart = MonthCalendarGrid.month(offsetBy: -1, from: displayedMonthStart, calendar: calendar)
        renderMonth()
    }

    @objc private func showNextMonth() {
        displayedMonthStart = MonthCalendarGrid.month(offsetBy: 1, from: displayedMonthStart, calendar: calendar)
        renderMonth()
    }

    private func configureView() {
        wantsLayer = true

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .centerX
        rootStack.spacing = 4
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            rootStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        rootStack.addArrangedSubview(headerView())
        rootStack.addArrangedSubview(weekdayHeaderView())
        rootStack.addArrangedSubview(dayGridView())
    }

    private func headerView() -> NSView {
        previousButton.target = self
        previousButton.action = #selector(showPreviousMonth)
        previousButton.toolTip = "上个月"
        previousButton.setAccessibilityLabel("上个月")
        nextButton.target = self
        nextButton.action = #selector(showNextMonth)
        nextButton.toolTip = "下个月"
        nextButton.setAccessibilityLabel("下个月")

        [previousButton, nextButton].forEach { button in
            button.isBordered = false
            button.bezelStyle = .inline
            button.font = .systemFont(ofSize: 18, weight: .medium)
            button.contentTintColor = .secondaryLabelColor
            button.setButtonType(.momentaryChange)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 28),
                button.heightAnchor.constraint(equalToConstant: 24)
            ])
        }

        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .fill
        header.spacing = 4
        header.translatesAutoresizingMaskIntoConstraints = false
        header.addArrangedSubview(previousButton)
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(nextButton)

        NSLayoutConstraint.activate([
            header.widthAnchor.constraint(equalToConstant: 236),
            header.heightAnchor.constraint(equalToConstant: 24),
            titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 160)
        ])

        return header
    }

    private func weekdayHeaderView() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fillEqually
        row.spacing = 3
        row.translatesAutoresizingMaskIntoConstraints = false

        for title in MonthCalendarGrid.weekdayTitles {
            let label = NSTextField(labelWithString: title)
            label.alignment = .center
            label.font = .systemFont(ofSize: 10, weight: .medium)
            label.textColor = .tertiaryLabelColor
            row.addArrangedSubview(label)
        }

        NSLayoutConstraint.activate([
            row.widthAnchor.constraint(equalToConstant: 236),
            row.heightAnchor.constraint(equalToConstant: 16)
        ])

        return row
    }

    private func dayGridView() -> NSView {
        let grid = NSStackView()
        grid.orientation = .vertical
        grid.alignment = .centerX
        grid.spacing = 3
        grid.translatesAutoresizingMaskIntoConstraints = false

        for _ in 0..<6 {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.distribution = .fillEqually
            row.spacing = 3
            row.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                row.widthAnchor.constraint(equalToConstant: 236),
                row.heightAnchor.constraint(equalToConstant: 18)
            ])

            for _ in 0..<7 {
                let dayView = MonthCalendarDayView()
                dayViews.append(dayView)
                row.addArrangedSubview(dayView)
            }

            grid.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            grid.widthAnchor.constraint(equalToConstant: 236),
            grid.heightAnchor.constraint(equalToConstant: 123)
        ])

        return grid
    }

    private func renderMonth() {
        let grid = MonthCalendarGrid.grid(
            monthContaining: displayedMonthStart,
            today: Date(),
            calendar: calendar
        )

        titleLabel.stringValue = grid.title

        for (index, dayView) in dayViews.enumerated() {
            dayView.configure(day: grid.days[index])
        }
    }
}

private final class MonthCalendarDayView: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 31, height: 18)
    }

    func configure(day: MonthCalendarDay?) {
        guard let day else {
            label.stringValue = ""
            layer?.backgroundColor = NSColor.clear.cgColor
            return
        }

        label.stringValue = "\(day.day)"

        if day.isToday {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
            label.textColor = .controlAccentColor
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            label.textColor = .labelColor
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        }
    }

    private func configureView() {
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.masksToBounds = true

        label.alignment = .center
        label.lineBreakMode = .byClipping
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
