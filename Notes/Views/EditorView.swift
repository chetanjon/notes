import SwiftData
import SwiftUI

/// The editor: one text view, a 44pt bar above it. The first line is the
/// title. Every change autosaves after a short pause; Done only dismisses.
struct EditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let note: Note

    @State private var text: String
    @State private var isFocused: Bool
    @State private var command: ChecklistTextView.Command?
    @State private var confirmingDelete = false
    @State private var deleteTimer: Task<Void, Never>?
    @State private var saveTask: Task<Void, Never>?
    /// Set by the trash: the note is gone, so onDisappear must not touch it.
    @State private var isDeleted = false
    /// The sparkle is at work; it is a spinner meanwhile.
    @State private var working = false

    /// Autosave waits this long after the last keystroke.
    private static let saveDelay: Duration = .milliseconds(350)
    /// The trash button reverts from "Delete" after this long.
    private static let deleteWindow: Duration = .seconds(3)

    init(note: Note) {
        self.note = note
        _text = State(initialValue: note.text)
        // A new note opens with the keyboard up; an existing one waits for a tap.
        _isFocused = State(initialValue: note.isBlank)
    }

    var body: some View {
        VStack(spacing: 0) {
            bar
            // When the note was last edited, in the muted grey, where the
            // list used to say it. It follows each autosave.
            Text(DateFormat.stamp(note.updatedAt))
                .font(Theme.Font.label)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            ChecklistTextView(text: $text, isFocused: $isFocused, command: $command)
                .padding(.horizontal, Theme.pagePadding - 5)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // The list is in order of use; this note goes to the top.
            NoteStore.markOpened(note, in: context)
        }
        .onChange(of: text) { _, newValue in
            scheduleSave(newValue)
        }
        .onChange(of: note.text) { _, synced in
            // Another device edited this note while it was open.
            if synced != text, saveTask == nil { text = synced }
        }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the foreground: save now, not in 350 ms. Killing the
            // app then loses nothing.
            if phase != .active { flush() }
        }
        .onDisappear {
            deleteTimer?.cancel()
            guard !isDeleted else { return }
            saveTask?.cancel()
            saveTask = nil
            if NoteText.isBlank(text) {
                // Only whitespace: discarded, not worth a place in the Trash.
                NoteStore.erase(note, in: context)
            } else {
                NoteStore.update(note, text: text, in: context)
            }
        }
    }

    // MARK: Bar

    private var bar: some View {
        HStack(spacing: 0) {
            barButton("chevron.left", label: "Back") { dismiss() }
            Spacer()
            if working {
                ProgressView()
                    .tint(Theme.fg)
                    .frame(width: Theme.tapTarget, height: Theme.tapTarget)
            } else if OnDevice.isAvailable {
                // With Apple's on-device model, the sparkle is a menu.
                Menu {
                    Button("Make a list", systemImage: "checklist") { makeList() }
                        .disabled(!canMakeList)
                    Button("Add a title", systemImage: "textformat") { addTitle() }
                        .disabled(isBlank)
                    Button("Tidy up", systemImage: "wand.and.stars") { tidy() }
                        .disabled(isBlank)
                    Button("Sort the list", systemImage: "arrow.up.arrow.down") { sortList() }
                        .disabled(!canSortList)
                } label: {
                    Image(systemName: "sparkles")
                        .font(Theme.Font.barGlyph)
                        .foregroundStyle(Theme.fg)
                        .frame(width: Theme.tapTarget, height: Theme.tapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Apple Intelligence")
            } else {
                barButton("sparkles", label: "Make a list") { makeList() }
                    .disabled(!canMakeList)
                    .opacity(canMakeList ? 1 : 0.35)
            }
            barButton("checklist", label: "Checklist") { command = .toggleItem }
            barButton(note.isPinned ? "pin.fill" : "pin",
                      label: note.isPinned ? "Unpin" : "Pin to Lock Screen") { togglePin() }
            if confirmingDelete {
                Button {
                    deleteNow()
                } label: {
                    Text("Delete")
                        .font(Theme.Font.toolbar)
                        .foregroundStyle(Theme.fg)
                        .frame(height: Theme.tapTarget)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            } else {
                barButton("trash", label: "Delete") { armDelete() }
            }
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(Theme.Font.toolbar)
                    .foregroundStyle(Theme.fg)
                    .frame(height: Theme.tapTarget)
                    .padding(.leading, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.pagePadding - 10)
        .frame(height: Theme.tapTarget)
        .background(Theme.bg)
        .animation(.easeOut(duration: 0.15), value: confirmingDelete)
    }

    private func barButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Theme.Font.barGlyph)
                .foregroundStyle(Theme.fg)
                .frame(width: Theme.tapTarget, height: Theme.tapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Actions

    /// There is something under the title that is not an item yet.
    private var canMakeList: Bool { !Checklist.plainBody(of: text).isEmpty }
    private var isBlank: Bool { NoteText.isBlank(text) }

    /// The sparkle: the plain lines under the title become checklist items,
    /// with Apple's on-device model where there is one and a plain split
    /// elsewhere. Applied as one edit, so a shake takes it back.
    private func makeList() {
        let plain = Checklist.plainBody(of: text)
        guard !plain.isEmpty, !working else { return }
        working = true
        Task { @MainActor in
            let items = await ListMaker.items(from: plain)
            working = false
            if !items.isEmpty { command = .makeList(items: items) }
        }
    }

    /// The model reads the note and puts a title on a new first line, with
    /// the cursor at its end. One edit; a shake takes it back.
    private func addTitle() {
        guard !isBlank, !working else { return }
        working = true
        let snapshot = text
        Task { @MainActor in
            let title = await OnDevice.title(for: snapshot)
            working = false
            if let title { command = .addTitle(title) }
        }
    }

    /// The model fixes spelling, capitalisation and punctuation across the
    /// note, line for line, with the checklist markers kept out of its
    /// hands. One edit; a shake takes it back.
    private func tidy() {
        guard !isBlank, !working else { return }
        working = true
        let lines = Checklist.bareLines(of: text)
        Task { @MainActor in
            let tidied = await OnDevice.tidied(lines)
            working = false
            if let tidied { command = .tidy(lines: tidied) }
        }
    }

    /// Three items or more: enough to group.
    private var canSortList: Bool { Checklist.items(of: text).count >= 3 }

    /// The model groups the items by kind and gives back their order; the
    /// ticks and the plain lines stay where they are. One edit; a shake
    /// takes it back.
    private func sortList() {
        guard canSortList, !working else { return }
        working = true
        let items = Checklist.items(of: text)
        Task { @MainActor in
            let order = await OnDevice.sorted(items)
            working = false
            if let order { command = .sortList(order: order, items: items) }
        }
    }

    private func scheduleSave(_ value: String) {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            NoteStore.update(note, text: value, in: context)
            saveTask = nil
        }
    }

    private func togglePin() {
        // Save first so the Lock Screen shows what is on screen, not what was.
        saveTask?.cancel()
        saveTask = nil
        NoteStore.update(note, text: text, in: context)
        NoteStore.togglePin(note, in: context)
    }

    /// First tap: the icon becomes the word. A second tap within three
    /// seconds moves the note to the Trash; otherwise it reverts. No
    /// system alert.
    private func armDelete() {
        confirmingDelete = true
        deleteTimer?.cancel()
        deleteTimer = Task { @MainActor in
            try? await Task.sleep(for: Self.deleteWindow)
            guard !Task.isCancelled else { return }
            confirmingDelete = false
        }
    }

    /// Save whatever is on screen right now.
    private func flush() {
        guard !isDeleted, !NoteText.isBlank(text) else { return }
        saveTask?.cancel()
        saveTask = nil
        NoteStore.update(note, text: text, in: context)
    }

    private func deleteNow() {
        deleteTimer?.cancel()
        saveTask?.cancel()
        saveTask = nil
        isDeleted = true
        NoteStore.trash(note, in: context)
        dismiss()
    }
}
