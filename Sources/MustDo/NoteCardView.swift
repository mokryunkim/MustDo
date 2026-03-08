import SwiftUI
import AppKit
import UniformTypeIdentifiers
import MustDoCore

struct NoteCardView: View {
    @EnvironmentObject private var store: NotesStore
    let noteID: UUID

    @State private var showOptions = false
    @State private var draftText: String = ""
    @FocusState private var focusedChecklistItemID: UUID?

    private var note: Note? {
        store.notes.first(where: { $0.id == noteID })
    }

    var body: some View {
        Group {
            if let note {
                content(note)
            } else {
                EmptyView()
            }
        }
    }

    private func content(_ note: Note) -> some View {
        let foreground = Color.black

        return VStack(alignment: .leading, spacing: 10) {
            // 1) 상단 영역: 제목 / 옵션 / 스티커 추가 / 닫기
            HStack(spacing: 8) {
                TextField("제목", text: Binding(
                    get: { note.title },
                    set: { store.setTitle(note.id, title: $0) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(foreground)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showOptions.toggle()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(foreground.opacity(0.85))
                }
                .buttonStyle(.plain)

                Button {
                    store.createNote()
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(foreground.opacity(0.85))
                }
                .buttonStyle(.plain)

                Button {
                    importStickerFromFile()
                } label: {
                    Image(systemName: "tray.and.arrow.down")
                        .foregroundStyle(foreground.opacity(0.85))
                }
                .buttonStyle(.plain)

                Button {
                    store.close(note.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(foreground.opacity(0.85))
                }
                .buttonStyle(.plain)
            }

            // 2) 체크리스트 영역
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("체크리스트")
                        .font(.caption)
                        .foregroundStyle(foreground)

                    Spacer()

                    Button {
                        createChecklistItemAndFocus(noteID: note.id, after: nil)
                    } label: {
                        Image(systemName: "plus.square")
                            .foregroundStyle(foreground)
                    }
                    .buttonStyle(.plain)
                }

                if note.checklist.isEmpty {
                    Text("+ 버튼으로 체크리스트를 추가하세요")
                        .font(.caption2)
                        .foregroundStyle(foreground.opacity(0.7))
                } else {
                    ForEach(note.checklist) { item in
                        HStack(spacing: 8) {
                            Button {
                                store.toggleChecklistItem(noteID: note.id, itemID: item.id)
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(foreground)
                            }
                            .buttonStyle(.plain)

                            if item.isDone {
                                Text(item.text)
                                    .font(.system(size: note.fontSize))
                                    .foregroundStyle(foreground)
                                    .strikethrough(true, color: foreground)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                TextField("할 일", text: Binding(
                                    get: { item.text },
                                    set: { store.setChecklistItemText(noteID: note.id, itemID: item.id, text: $0) }
                                ))
                                .focused($focusedChecklistItemID, equals: item.id)
                                .onSubmit {
                                    createChecklistItemAndFocus(noteID: note.id, after: item.id)
                                }
                                .textFieldStyle(.plain)
                                .font(.system(size: note.fontSize))
                                .foregroundStyle(foreground)
                            }

                            Button(role: .destructive) {
                                moveChecklistFocusAfterDelete(note: note, deletingItemID: item.id)
                                store.removeChecklistItem(noteID: note.id, itemID: item.id)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(foreground.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.24))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // 3) 자유 텍스트 영역
            TextEditor(text: $draftText)
            .font(.system(size: note.fontSize))
            .foregroundStyle(foreground)
            .frame(minHeight: 110)
            .scrollContentBackground(.hidden)
            .background(Color.white.opacity(0.24))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onAppear {
                if draftText != note.text {
                    draftText = note.text
                }
            }
            .onChange(of: note.text) { newValue in
                if newValue != draftText {
                    draftText = newValue
                }
            }
            .onChange(of: draftText) { newValue in
                if newValue != note.text {
                    store.setText(note.id, text: newValue)
                }
            }

            // 4) 옵션 영역
            if showOptions {
                VStack(alignment: .leading, spacing: 8) {
                    Text("글자 크기")
                        .font(.caption2)
                        .foregroundStyle(foreground)

                    Slider(
                        value: Binding(
                            get: { note.fontSize },
                            set: { store.setFontSize(note.id, fontSize: $0) }
                        ),
                        in: 12...42,
                        step: 1
                    )
                    .tint(.black)
                    .accentColor(.black)

                    HStack {
                        Text("스티커 색")
                            .font(.caption2)
                            .foregroundStyle(foreground)
                        colorPicker(note: note)
                        Spacer()
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .transition(.opacity)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: note.colorHex))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.12), lineWidth: 1))
    }

    private func colorPicker(note: Note) -> some View {
        HStack(spacing: 4) {
            ForEach(NoteColors.presets, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.black.opacity(note.colorHex == hex ? 0.6 : 0.2), lineWidth: 1))
                    .onTapGesture {
                        store.setColor(note.id, colorHex: hex)
                    }
            }
        }
    }

    private func importStickerFromFile() {
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
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    private func moveChecklistFocusAfterDelete(note: Note, deletingItemID: UUID) {
        let ids = note.checklist.map(\.id)
        guard let deletingIndex = ids.firstIndex(of: deletingItemID) else { return }

        let nextFocusID: UUID?
        if ids.indices.contains(deletingIndex + 1) {
            nextFocusID = ids[deletingIndex + 1]
        } else if deletingIndex > 0 {
            nextFocusID = ids[deletingIndex - 1]
        } else {
            nextFocusID = nil
        }

        DispatchQueue.main.async {
            focusedChecklistItemID = nextFocusID
        }
    }

    private func createChecklistItemAndFocus(noteID: UUID, after itemID: UUID?) {
        guard let newItemID = store.insertChecklistItem(noteID: noteID, after: itemID) else { return }
        DispatchQueue.main.async {
            focusedChecklistItemID = newItemID
        }
    }
}
