import AppKit
import SwiftUI
import Combine

class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()
    private let session: SessionManager

    init(session: SessionManager) {
        self.session = session
        super.init()
        setupStatusItem()
        setupPopover()
        observeSession()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 150)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: DistractionPopoverView(session: session)
        )
    }

    private func observeSession() {
        Publishers.CombineLatest(session.$isDistracted, session.$state)
            .receive(on: RunLoop.main)
            .sink { [weak self] distracted, _ in
                self?.updateIcon()
                if distracted {
                    self?.showPopover()
                } else {
                    self?.popover.close()
                }
            }
            .store(in: &cancellables)
    }

    private func updateIcon() {
        let symbolName: String
        let isTemplate: Bool

        switch (session.state, session.isDistracted) {
        case (.running, true):
            symbolName = "exclamationmark.circle.fill"
            isTemplate = false
        case (.running, false):
            symbolName = "eye.fill"
            isTemplate = true
        default:
            symbolName = "eye"
            isTemplate = true
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "FocusGuard") {
            image.isTemplate = isTemplate
            statusItem.button?.image = image
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.close()
        } else {
            showPopover()
        }
    }
}
