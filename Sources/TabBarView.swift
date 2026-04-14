import Cocoa

class TabBarView: NSView {
    static let barHeight: CGFloat = 31

    var onTabSelected: ((Int) -> Void)?
    var onAddTab: (() -> Void)?
    var onCloseTab: ((Int) -> Void)?
    var onTabRenamed: ((Int, String) -> Void)?

    private var pillViews: [TabPillView] = []
    private let addButton = NSView()
    private let addLabel = NSTextField(labelWithString: "+")
    private let separator = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.078, green: 0.078, blue: 0.086, alpha: 0.80).cgColor

        // Separator line at bottom
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        addSubview(separator)

        // Add button
        addButton.wantsLayer = true
        addButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        addButton.layer?.cornerRadius = 11
        addSubview(addButton)

        addLabel.font = NSFont.systemFont(ofSize: 14, weight: .light)
        addLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        addLabel.alignment = .center
        addLabel.isBezeled = false
        addLabel.drawsBackground = false
        addLabel.isEditable = false
        addButton.addSubview(addLabel)
    }

    func update(tabs: [TabInfo], activeIndex: Int) {
        // Remove old pills
        pillViews.forEach { $0.removeFromSuperview() }
        pillViews.removeAll()

        let version = TabManager.claudeVersion.isEmpty ? TabManager.appVersion : TabManager.claudeVersion

        for i in tabs.indices {
            let displayTitle = tabs[i].customTitle ?? version
            let pill = TabPillView(title: displayTitle, isActive: i == activeIndex, index: i)
            pill.onClick = { [weak self] idx in
                self?.onTabSelected?(idx)
            }
            pill.onRightClick = { [weak self] idx in
                self?.showCloseMenu(for: idx)
            }
            pill.onDoubleClick = { [weak self] idx in
                self?.pillViews[idx].startEditing()
            }
            pill.onEditFinished = { [weak self] idx, newTitle in
                self?.onTabRenamed?(idx, newTitle)
            }
            addSubview(pill)
            pillViews.append(pill)
        }

        // Hide add button if max tabs
        addButton.isHidden = tabs.count >= TabManager.maxTabs

        needsLayout = true
    }

    override func layout() {
        super.layout()

        let padding: CGFloat = 8
        let pillGap: CGFloat = 4
        let pillHeight: CGFloat = 22
        let pillY = (bounds.height - pillHeight) / 2

        var x = padding

        for pill in pillViews {
            let w = pill.idealWidth()
            pill.frame = NSRect(x: x, y: pillY, width: w, height: pillHeight)
            x += w + pillGap
        }

        // Add button
        let addW: CGFloat = 40
        addButton.frame = NSRect(x: x, y: pillY, width: addW, height: pillHeight)
        addLabel.frame = addButton.bounds

        // Separator at bottom — full width
        separator.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 1)
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        if addButton.frame.contains(pt) && !addButton.isHidden {
            onAddTab?()
            return
        }
        for pill in pillViews {
            if pill.frame.contains(pt) {
                pill.handleClick(event)
                return
            }
        }
    }

    private func showCloseMenu(for index: Int) {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Close Tab", action: #selector(closeTabAction(_:)), keyEquivalent: "")
        item.target = self
        item.tag = index
        menu.addItem(item)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func closeTabAction(_ sender: NSMenuItem) {
        onCloseTab?(sender.tag)
    }
}

// MARK: - Tab Pill View

private class TabPillView: NSView, NSTextFieldDelegate {
    var onClick: ((Int) -> Void)?
    var onRightClick: ((Int) -> Void)?
    var onDoubleClick: ((Int) -> Void)?
    var onEditFinished: ((Int, String) -> Void)?

    private let label: NSTextField
    private let editField: NSTextField
    private let index: Int
    private let isActive: Bool
    private var isEditing = false

    init(title: String, isActive: Bool, index: Int) {
        self.index = index
        self.isActive = isActive
        self.label = NSTextField(labelWithString: title)
        self.editField = NSTextField(string: title)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 11
        layer?.backgroundColor = isActive
            ? NSColor.white.withAlphaComponent(0.2).cgColor
            : NSColor.white.withAlphaComponent(0.1).cgColor

        label.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        label.textColor = isActive
            ? NSColor.white.withAlphaComponent(0.9)
            : NSColor.white.withAlphaComponent(0.7)
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        addSubview(label)

        // Edit field — hidden until double-click
        editField.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        editField.textColor = NSColor.white
        editField.backgroundColor = NSColor.white.withAlphaComponent(0.1)
        editField.isBezeled = false
        editField.focusRingType = .none
        editField.alignment = .center
        editField.isHidden = true
        editField.delegate = self
        editField.maximumNumberOfLines = 1
        editField.cell?.isScrollable = true
        editField.cell?.wraps = false
        addSubview(editField)
    }

    required init?(coder: NSCoder) { fatalError() }

    func idealWidth() -> CGFloat {
        let textW = label.attributedStringValue.size().width
        return max(60, textW + 24)
    }

    func startEditing() {
        isEditing = true
        editField.stringValue = label.stringValue
        editField.isHidden = false
        label.isHidden = true
        editField.frame = NSRect(x: 4, y: (bounds.height - 16) / 2, width: bounds.width - 8, height: 16)
        window?.makeFirstResponder(editField)
        editField.selectText(nil)
    }

    private func finishEditing() {
        guard isEditing else { return }
        isEditing = false
        let newTitle = String(editField.stringValue.prefix(20))
        editField.isHidden = true
        label.isHidden = false
        if !newTitle.isEmpty {
            label.stringValue = newTitle
        }
        onEditFinished?(index, newTitle.isEmpty ? label.stringValue : newTitle)
    }

    override func layout() {
        super.layout()
        label.sizeToFit()
        let labelH = label.frame.height
        let y = (bounds.height - labelH) / 2
        label.frame = NSRect(x: 0, y: y, width: bounds.width, height: labelH)
        if !editField.isHidden {
            editField.frame = NSRect(x: 4, y: (bounds.height - 16) / 2, width: bounds.width - 8, height: 16)
        }
    }

    func handleClick(_ event: NSEvent) {
        if event.clickCount >= 2 {
            onDoubleClick?(index)
        } else {
            onClick?(index)
        }
    }

    override func mouseDown(with event: NSEvent) {
        handleClick(event)
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(index)
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidEndEditing(_ obj: Notification) {
        finishEditing()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            finishEditing()
            return true
        }
        if commandSelector == #selector(cancelOperation(_:)) {
            isEditing = false
            editField.isHidden = true
            label.isHidden = false
            return true
        }
        return false
    }
}
