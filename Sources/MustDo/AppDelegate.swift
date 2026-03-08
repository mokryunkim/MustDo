import AppKit
import Combine
import SwiftUI
import MustDoCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let keepAliveWindowIdentifier = NSUserInterfaceItemIdentifier("MustDo.KeepAliveWindow")
    private var ownedStore: NotesStore?
    private weak var store: NotesStore?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var notesCancellable: AnyCancellable?
    private var levelCancellable: AnyCancellable?
    private var saveObserver: NSObjectProtocol?
    private let windowManager = StickerWindowManager()
    private var statusItem: NSStatusItem?
    private weak var alwaysOnTopMenuItem: NSMenuItem?
    private var keepAliveWindow: NSWindow?

    func configure(with store: NotesStore) {
        self.store = store
        NSApp.setActivationPolicy(.regular)
        configureKeepAliveWindow()
        windowManager.store = store
        registerGlobalHotKeyIfNeeded()
        configureStatusItem()
        bindStore(store)
        syncStickerWindows()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ownedStore == nil {
            let newStore = NotesStore()
            ownedStore = newStore
            configure(with: newStore)
        }
        configureStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotKey()
    }

    func applicationDidResignActive(_ notification: Notification) {
        windowManager.deactivateWindowsForOtherApps()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if let store {
            windowManager.applyAlwaysOnTop(store.isAlwaysOnTop)
        }
    }

    func bringMainWindowToFront() {
        NSApp.activate(ignoringOtherApps: true)
        windowManager.focusAnyWindow()
    }

    func applyAlwaysOnTop(_ enabled: Bool) {
        windowManager.applyAlwaysOnTop(enabled)
    }

    func importStickerFromFile() {
        guard let store else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.notesDirectoryURL
        let mustDoType = UTType(filenameExtension: "mustdo")
        let legacyType = UTType(filenameExtension: "stickynote")
        panel.allowedContentTypes = [mustDoType, legacyType, .json].compactMap { $0 }

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try store.importNoteFile(at: url)
                bringMainWindowToFront()
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    func openStickersFolder() {
        guard let store else { return }
        NSWorkspace.shared.open(store.notesDirectoryURL)
    }

    private func bindStore(_ store: NotesStore) {
        notesCancellable = store.$notes.sink { [weak self] _ in
            self?.syncStickerWindows()
        }

        levelCancellable = store.$isAlwaysOnTop.sink { [weak self] enabled in
            self?.windowManager.applyAlwaysOnTop(enabled)
            self?.alwaysOnTopMenuItem?.state = enabled ? .on : .off
        }

        saveObserver = NotificationCenter.default.addObserver(
            forName: NotesStore.didSaveNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncStickerWindows()
            }
        }
    }

    private func syncStickerWindows() {
        guard let store else { return }
        windowManager.syncWindows(notes: store.visibleNotes, alwaysOnTop: store.isAlwaysOnTop)
    }

    private func registerGlobalHotKeyIfNeeded() {
        if globalKeyMonitor != nil || localKeyMonitor != nil { return }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            self.handleKeyEvent(event)
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.handleKeyEvent(event) {
                return nil
            }
            return event
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let hotkeyModifiers: NSEvent.ModifierFlags = [.command, .option]
        let isHotkey = event.keyCode == 45 && event.modifierFlags.intersection([.command, .option]) == hotkeyModifiers
        guard isHotkey else { return false }

        store?.createNote()
        bringMainWindowToFront()
        return true
    }

    private func unregisterHotKey() {
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }

        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }

        if let saveObserver {
            NotificationCenter.default.removeObserver(saveObserver)
            self.saveObserver = nil
        }
    }

    private func configureStatusItem() {
        if statusItem != nil { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "MustDo")
            image?.isTemplate = true
            button.image = image
            if image == nil {
                button.title = "S"
            }
            button.imagePosition = .imageOnly
            button.toolTip = "MustDo"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "새 스티커 만들기", action: #selector(onNewSticker), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "파일에서 스티커 열기", action: #selector(onImportSticker), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "스티커 파일 폴더 열기", action: #selector(onOpenFolder), keyEquivalent: ""))
        menu.addItem(.separator())

        let always = NSMenuItem(title: "항상 위에 고정", action: #selector(onToggleAlwaysOnTop), keyEquivalent: "")
        always.state = store?.isAlwaysOnTop == true ? .on : .off
        menu.addItem(always)
        alwaysOnTopMenuItem = always

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "스티커 보기", action: #selector(onShowAnySticker), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "종료", action: #selector(onQuit), keyEquivalent: ""))

        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func configureKeepAliveWindow() {
        if keepAliveWindow != nil { return }

        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.identifier = Self.keepAliveWindowIdentifier
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.alphaValue = 0
        window.level = .normal
        window.orderOut(nil)
        keepAliveWindow = window
    }

    @objc private func onNewSticker() {
        store?.createNote()
        bringMainWindowToFront()
    }

    @objc private func onImportSticker() {
        importStickerFromFile()
    }

    @objc private func onOpenFolder() {
        openStickersFolder()
    }

    @objc private func onToggleAlwaysOnTop() {
        guard let store else { return }
        store.isAlwaysOnTop.toggle()
        applyAlwaysOnTop(store.isAlwaysOnTop)
    }

    @objc private func onShowAnySticker() {
        bringMainWindowToFront()
    }

    @objc private func onQuit() {
        NSApp.terminate(nil)
    }
}

@MainActor
final class StickerWindowManager: NSObject, NSWindowDelegate {
    weak var store: NotesStore?
    private var windowsByID: [UUID: NSWindow] = [:]

    func syncWindows(notes: [Note], alwaysOnTop: Bool) {
        let currentIDs = Set(notes.map(\.id))

        let idsToRemove = windowsByID.keys.filter { !currentIDs.contains($0) }
        for id in idsToRemove {
            if let window = windowsByID[id] {
                window.delegate = nil
                window.orderOut(nil)
            }
            windowsByID.removeValue(forKey: id)
        }

        for note in notes {
            if let window = windowsByID[note.id] {
                apply(note: note, to: window)
            } else {
                let window = makeWindow(for: note)
                windowsByID[note.id] = window
                window.makeKeyAndOrderFront(nil)
            }
        }

        applyAlwaysOnTop(alwaysOnTop)
    }

    func applyAlwaysOnTop(_ enabled: Bool) {
        let level: NSWindow.Level = enabled ? .floating : .normal
        windowsByID.values.forEach { $0.level = level }
    }

    func focusAnyWindow() {
        windowsByID.values.first?.makeKeyAndOrderFront(nil)
    }

    func sendAllWindowsToBack() {
        windowsByID.values.forEach { $0.orderBack(nil) }
    }

    func deactivateWindowsForOtherApps() {
        windowsByID.values.forEach { window in
            window.level = .normal
            window.orderBack(nil)
        }
    }

    private func makeWindow(for note: Note) -> NSWindow {
        let frame = NSRect(x: note.x, y: note.y, width: note.width, height: note.height)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.identifier = NSUserInterfaceItemIdentifier(note.id.uuidString)
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.delegate = self

        if let store {
            window.contentView = NSHostingView(
                rootView: NoteCardView(noteID: note.id)
                    .environmentObject(store)
            )
        }

        return window
    }

    private func apply(note: Note, to window: NSWindow) {
        let current = window.frame
        let target = NSRect(x: note.x, y: note.y, width: note.width, height: note.height)
        let delta = abs(current.origin.x - target.origin.x)
            + abs(current.origin.y - target.origin.y)
            + abs(current.width - target.width)
            + abs(current.height - target.height)

        if delta > 1.5 {
            window.setFrame(target, display: true)
        }
    }

    func windowDidMove(_ notification: Notification) {
        persistWindowFrame(notification)
    }

    func windowDidResize(_ notification: Notification) {
        persistWindowFrame(notification)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard
            let store,
            let rawID = sender.identifier?.rawValue,
            let id = UUID(uuidString: rawID)
        else { return false }

        store.close(id)
        // Managed by store/sync cycle. Prevent direct close path from terminating app.
        return false
    }

    private func persistWindowFrame(_ notification: Notification) {
        guard
            let store,
            let window = notification.object as? NSWindow,
            let rawID = window.identifier?.rawValue,
            let id = UUID(uuidString: rawID)
        else { return }

        let frame = window.frame
        store.updateNote(id) { note in
            note.x = frame.origin.x
            note.y = frame.origin.y
            note.width = frame.width
            note.height = frame.height
        }
    }
}
