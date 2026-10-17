import AppKit
import MacHealthGuardianCore

final class CPUProcessesMenuView: NSView {
    private let statusLabel = NSTextField(labelWithString: "采样中…")
    private var nameLabels: [NSTextField] = []
    private var usageLabels: [NSTextField] = []

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 90))
        configureView()
        render(.sampling)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 260, height: 90)
    }

    func render(_ state: ProcessCPUState) {
        let processes: [ProcessCPUUsage]
        switch state {
        case .sampling:
            statusLabel.stringValue = "采样中…"
            processes = []
        case .ready(let result):
            statusLabel.stringValue = result.isEmpty ? "暂无数据" : "当前"
            processes = result
        case .unavailable:
            statusLabel.stringValue = "暂时无法读取"
            processes = []
        }

        for index in 0..<3 {
            guard index < processes.count else {
                nameLabels[index].stringValue = "--"
                usageLabels[index].stringValue = "--"
                nameLabels[index].toolTip = nil
                nameLabels[index].setAccessibilityLabel("第 \(index + 1) 名，等待进程数据")
                continue
            }

            let process = processes[index]
            let name = NSRunningApplication(processIdentifier: process.pid)?.localizedName ?? process.name
            let usage = String(format: "%.1f%%", process.cpuUsage)
            nameLabels[index].stringValue = name
            nameLabels[index].toolTip = "\(name)\n进程：\(process.name)\nPID：\(process.pid)\nCPU：\(usage)"
            nameLabels[index].setAccessibilityLabel("第 \(index + 1) 名，\(name)，CPU 占用 \(usage)，PID \(process.pid)")
            usageLabels[index].stringValue = usage
        }
    }

    private func configureView() {
        let titleLabel = NSTextField(labelWithString: "CPU 占用前三")
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 10)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .right
        toolTip = "按最近采样区间的 CPU 占用排序。100% 表示占满一个逻辑核心，多核进程可超过 100%。"

        let header = NSStackView(views: [titleLabel, NSView(), statusLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .fill

        let stack = NSStackView(views: [header])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            header.heightAnchor.constraint(equalToConstant: 17)
        ])

        for index in 0..<3 {
            let rankLabel = NSTextField(labelWithString: "\(index + 1)")
            rankLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            rankLabel.textColor = .tertiaryLabelColor

            let nameLabel = NSTextField(labelWithString: "--")
            nameLabel.font = .systemFont(ofSize: 12)
            nameLabel.lineBreakMode = .byTruncatingTail
            nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            nameLabels.append(nameLabel)

            let usageLabel = NSTextField(labelWithString: "--")
            usageLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            usageLabel.alignment = .right
            usageLabels.append(usageLabel)

            let row = NSStackView(views: [rankLabel, nameLabel, usageLabel])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.distribution = .fill
            row.spacing = 6
            stack.addArrangedSubview(row)

            NSLayoutConstraint.activate([
                rankLabel.widthAnchor.constraint(equalToConstant: 12),
                usageLabel.widthAnchor.constraint(equalToConstant: 60),
                row.widthAnchor.constraint(equalTo: stack.widthAnchor),
                row.heightAnchor.constraint(equalToConstant: 19)
            ])
        }
    }
}
