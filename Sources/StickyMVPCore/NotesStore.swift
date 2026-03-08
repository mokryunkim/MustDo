import Foundation
import Combine

@MainActor
public final class NotesStore: ObservableObject {
    public static let didSaveNotification = Notification.Name("MustDoNotesStoreDidSave")
    @Published public private(set) var notes: [Note] = []
    @Published public var isAlwaysOnTop: Bool = false {
        didSet { save() }
    }

    public let notesDirectoryURL: URL

    private let storageURL: URL
    private var autosaveTimer: Timer?

    public init(fileManager: FileManager = .default) {
        let paths = Self.makeStoragePaths(fileManager: fileManager)
        self.storageURL = paths.stateURL
        self.notesDirectoryURL = paths.notesDirectoryURL
        load()
        normalizeFontSizeForExistingNotes()
        if visibleNotes.isEmpty {
            if let latestIndex = notes.indices.max(by: { notes[$0].updatedAt < notes[$1].updatedAt }) {
                notes[latestIndex].isClosed = false
                save()
            } else {
                createNote()
            }
        }
        startAutosaveTimer()
    }

    public var visibleNotes: [Note] {
        notes
            .filter { !$0.isClosed }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func createNote() {
        var note = Note()
        note.x = Double(30 + (visibleNotes.count % 8) * 26)
        note.y = Double(30 + (visibleNotes.count % 8) * 26)
        notes.append(note)
        save()
    }

    public func updateNote(_ id: UUID, _ mutation: (inout Note) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        mutation(&notes[index])
        notes[index].updatedAt = .now
        save()
    }

    public func setTitle(_ id: UUID, title: String) {
        updateNote(id) { $0.title = title }
    }

    public func setText(_ id: UUID, text: String) {
        updateNote(id) { $0.text = text }
    }

    public func setColor(_ id: UUID, colorHex: String) {
        updateNote(id) { $0.colorHex = colorHex }
    }

    public func setTextColor(_ id: UUID, colorHex: String) {
        updateNote(id) { $0.textColorHex = colorHex }
    }

    public func setFontSize(_ id: UUID, fontSize: Double) {
        updateNote(id) { $0.fontSize = min(42, max(12, fontSize)) }
    }

    public func close(_ id: UUID) {
        updateNote(id) { $0.isClosed = true }
    }

    @discardableResult
    public func addChecklistItem(_ id: UUID) -> UUID? {
        insertChecklistItem(noteID: id, after: nil)
    }

    @discardableResult
    public func insertChecklistItem(noteID: UUID, after itemID: UUID?) -> UUID? {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteID }) else { return nil }

        let newItem = ChecklistTask(text: "")
        if let itemID, let index = notes[noteIndex].checklist.firstIndex(where: { $0.id == itemID }) {
            notes[noteIndex].checklist.insert(newItem, at: index + 1)
        } else if let firstDoneIndex = notes[noteIndex].checklist.firstIndex(where: { $0.isDone }) {
            notes[noteIndex].checklist.insert(newItem, at: firstDoneIndex)
        } else {
            notes[noteIndex].checklist.append(newItem)
        }

        notes[noteIndex].updatedAt = .now
        save()
        return newItem.id
    }

    public func insertCheckboxIntoText(_ id: UUID) {
        updateNote(id) { note in
            if note.text.isEmpty {
                note.text = "- [ ] "
            } else if note.text.hasSuffix("\n") {
                note.text += "- [ ] "
            } else {
                note.text += "\n- [ ] "
            }
        }
    }

    public func toggleCheckboxLineInText(_ id: UUID, lineIndex: Int) {
        updateNote(id) { note in
            var lines = note.text.components(separatedBy: "\n")
            guard lines.indices.contains(lineIndex) else { return }

            if lines[lineIndex].hasPrefix("- [ ] ") {
                lines[lineIndex] = lines[lineIndex].replacingOccurrences(of: "- [ ] ", with: "- [x] ", options: [.anchored])
            } else if lines[lineIndex].hasPrefix("- [x] ") {
                lines[lineIndex] = lines[lineIndex].replacingOccurrences(of: "- [x] ", with: "- [ ] ", options: [.anchored])
            }

            note.text = lines.joined(separator: "\n")
        }
    }

    public func setTextLine(_ id: UUID, lineIndex: Int, newLine: String) {
        updateNote(id) { note in
            var lines = note.text.components(separatedBy: "\n")
            if lines.isEmpty { lines = [""] }
            guard lines.indices.contains(lineIndex) else { return }
            lines[lineIndex] = newLine
            note.text = lines.joined(separator: "\n")
        }
    }

    public func removeTextLine(_ id: UUID, lineIndex: Int) {
        updateNote(id) { note in
            var lines = note.text.components(separatedBy: "\n")
            guard lines.indices.contains(lineIndex) else { return }
            lines.remove(at: lineIndex)
            note.text = lines.isEmpty ? "" : lines.joined(separator: "\n")
        }
    }

    public func toggleChecklistItem(noteID: UUID, itemID: UUID) {
        updateNote(noteID) { note in
            guard let index = note.checklist.firstIndex(where: { $0.id == itemID }) else { return }
            note.checklist[index].isDone.toggle()
            let original = Array(note.checklist.enumerated())
            note.checklist = original
                .sorted { lhs, rhs in
                    if lhs.element.isDone != rhs.element.isDone {
                        return lhs.element.isDone == false
                    }
                    return lhs.offset < rhs.offset
                }
                .map(\.element)
        }
    }

    public func setChecklistItemText(noteID: UUID, itemID: UUID, text: String) {
        updateNote(noteID) { note in
            guard let index = note.checklist.firstIndex(where: { $0.id == itemID }) else { return }
            note.checklist[index].text = text
        }
    }

    public func removeChecklistItem(noteID: UUID, itemID: UUID) {
        updateNote(noteID) { note in
            note.checklist.removeAll { $0.id == itemID }
        }
    }

    public func importNoteFile(at url: URL) throws {
        let data = try Data(contentsOf: url)
        var note = try JSONDecoder().decode(Note.self, from: data)
        note.isClosed = false
        note.updatedAt = .now

        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }

        save()
    }

    private func load() {
        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode(PersistedState.self, from: data)
            notes = decoded.notes
            isAlwaysOnTop = decoded.isAlwaysOnTop
        } catch {
            notes = []
            isAlwaysOnTop = false
        }
    }

    private func normalizeFontSizeForExistingNotes() {
        var changed = false
        for index in notes.indices {
            if notes[index].fontSize != 12 {
                notes[index].fontSize = 12
                changed = true
            }
        }
        if changed {
            save()
        }
    }

    private func save() {
        do {
            let state = PersistedState(notes: notes, isAlwaysOnTop: isAlwaysOnTop)
            let data = try JSONEncoder().encode(state)
            try data.write(to: storageURL, options: .atomic)
            try writePerNoteFiles()
            NotificationCenter.default.post(name: Self.didSaveNotification, object: self)
        } catch {
            fputs("Failed to save notes: \(error)\n", stderr)
        }
    }

    private func startAutosaveTimer() {
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.save()
            }
        }
    }

    private func writePerNoteFiles() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: notesDirectoryURL.path) {
            try fileManager.createDirectory(at: notesDirectoryURL, withIntermediateDirectories: true)
        }

        let existing = try fileManager.contentsOfDirectory(at: notesDirectoryURL, includingPropertiesForKeys: nil)
        for url in existing where url.pathExtension == "stickynote" {
            try? fileManager.removeItem(at: url)
        }

        var usedNames: Set<String> = []
        let encoder = JSONEncoder()

        for note in notes {
            if shouldSkipFilePersistence(note) {
                continue
            }
            let base = sanitizeFilename(note.title)
            let filename = uniqueFilename(base: base, used: &usedNames)
            let fileURL = notesDirectoryURL.appendingPathComponent(filename).appendingPathExtension("stickynote")
            let data = try encoder.encode(note)
            try data.write(to: fileURL, options: .atomic)
        }
    }

    private func shouldSkipFilePersistence(_ note: Note) -> Bool {
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasChecklistContent = note.checklist.contains {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return title == "새 스티커" && body.isEmpty && !hasChecklistContent
    }

    private func uniqueFilename(base: String, used: inout Set<String>) -> String {
        if !used.contains(base) {
            used.insert(base)
            return base
        }

        var index = 2
        while used.contains("\(base)-\(index)") {
            index += 1
        }
        let name = "\(base)-\(index)"
        used.insert(name)
        return name
    }

    private func sanitizeFilename(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.isEmpty ? "untitled-sticker" : trimmed
        let disallowed = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let pieces = candidate.components(separatedBy: disallowed)
        return pieces.joined(separator: "-")
    }

    private static func makeStoragePaths(fileManager: FileManager) -> (stateURL: URL, notesDirectoryURL: URL) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = appSupport.appendingPathComponent("MustDo", isDirectory: true)

        if !fileManager.fileExists(atPath: root.path) {
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }

        let notesDirectoryURL = root.appendingPathComponent("notes", isDirectory: true)
        if !fileManager.fileExists(atPath: notesDirectoryURL.path) {
            try? fileManager.createDirectory(at: notesDirectoryURL, withIntermediateDirectories: true)
        }

        return (root.appendingPathComponent("notes.json"), notesDirectoryURL)
    }

    private struct PersistedState: Codable {
        let notes: [Note]
        let isAlwaysOnTop: Bool
    }
}
