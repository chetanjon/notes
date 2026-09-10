import SwiftData
import SwiftUI

/// The editor: one text view, a 44pt bar above it. The first line is the
/// title. Every change autosaves after a short pause; Done only dismisses.
struct EditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Navigation.self) private var navigation
    let note: Note

    @State private var text: String
    @State private var isFocused: Bool
    @State private var command: ChecklistTextView.Command?
    @State private var confirmingDelete = false
    @State private var deleteTimer: Task<Void, Never>?
    @State private var saveTask: Task<Void, Never>?
    /// Set by the trash: the note is gone, so onDisappear must not touch it.
    @State private var isDeleted = false
    @State private var wasBlankOnOpen = false
    /// The sparkle is at work; it is a spinner meanwhile.
    @State private var working = false
    /// What a sparkle action had to say when it changed nothing, in place
    /// of the date line for a moment.
    @State private var notice: String?
    @State private var noticeTimer: Task<Void, Never>?
    /// "Where did I leave off?": the brief in place of the date line, until
    /// a tap or a keystroke.
    @State private var brief: String?
    /// "You've thought about this before": an older note that bears on what
    /// is being written; a tap opens it.
    @State private var recall: RecallHint?
    @State private var recallTask: Task<Void, Never>?
    /// The recall line was tapped: open the older note, or move this there.
    @State private var recallChoice: RecallHint?
    /// Notes already brought up in this sitting, so one comes up once.
    @State private var recalled: Set<UUID> = []

    struct RecallHint: Equatable {
        var id: UUID
        var title: String
        var said: String
    }

    /// The recall waits this long after the last keystroke.
    private static let recallDelay: Duration = .milliseconds(2500)
    /// The model has this long to answer a sparkle action. Past it the
    /// spinner goes and the notice says so, rather than turning for ever.
    private static let modelLimit: Duration = .seconds(20)
    /// The sparkle action in flight, so leaving the note drops it.
    @State private var actionTask: Task<Void, Never>?
    /// What "Reminders" found, shown on a sheet.
    @State private var foundReminders: [Reminders.Found] = []
    @State private var showingReminders = false

    /// Autosave waits this long after the last keystroke.
    private static let saveDelay: Duration = .milliseconds(350)
    /// The trash button reverts from "Delete" after this long.
    private static let deleteWindow: Duration = .seconds(3)

    init(note: Note) {
        self.note = note
        _text = State(initialValue: note.text)
        // Whether it had anything in it when it opened. A note cleared by
        // hand goes to the Trash like any other; only one that was never
        // written in is dropped outright.
        _wasBlankOnOpen = State(initialValue: note.isBlank)
        // A new note opens with the keyboard up; an existing one waits for a tap.
        _isFocused = State(initialValue: note.isBlank)
    }

    var body: some View {
        VStack(spacing: 0) {
            bar
            // When the note was last edited: small, centred under the bar,
            // in the muted grey, the way a note's date sits. A notice or the
            // brief takes the same slot. It follows each autosave.
            Text(brief ?? notice ?? DateFormat.stamp(note.updatedAt))
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(brief == nil ? 1 : 4)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .onTapGesture { brief = nil }
                .animation(.easeOut(duration: 0.15), value: notice)
                .animation(.easeOut(duration: 0.15), value: brief)
            if let recall {
                // An older note that bears on this one. A tap asks: open it,
                // or move what was written here into it.
                Button {
                    recallChoice = recall
                } label: {
                    Text("You wrote about this in \(recall.title): “\(recall.said)”")
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, Theme.pagePadding)
                        .padding(.top, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
            ChecklistTextView(text: $text, isFocused: $isFocused, command: $command)
                .padding(.horizontal, Theme.pagePadding - 5)
        }
        .background(Theme.bg.ignoresSafeArea())
        .background(EdgeSwipeBack().frame(width: 0, height: 0))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(recallChoice?.title ?? "", isPresented: Binding(
            get: { recallChoice != nil }, set: { if !$0 { recallChoice = nil } }
        ), titleVisibility: .visible, presenting: recallChoice) { hint in
            Button("Open it") { openRecalled(hint) }
            Button("Move this there") { moveToRecalled(hint) }
        }
        .onAppear {
            // The list is in order of use; this note goes to the top.
            let lastOpened = NoteStore.markOpened(note, in: context)
            // So the first sparkle tap answers as fast as the second.
            OnDevice.prewarm()
            // Back after a day to a note with something in it: where it stands.
            if OnDevice.isAvailable, Brief.wanted(for: text),
               Date.now.timeIntervalSince(lastOpened ?? .distantPast) > Brief.away {
                loadBrief(onDemand: false)
            }
        }
        .sheet(isPresented: $showingReminders) {
            RemindersSheet(found: foundReminders, noteID: note.id, noteTitle: NoteText.title(text)) { count in
                show(count == 1 ? "Notification set" : "\(count) notifications set")
            }
        }
        .onChange(of: text) { _, newValue in
            scheduleSave(newValue)
            if brief != nil { brief = nil }
            scheduleRecall(newValue)
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
            noticeTimer?.cancel()
            recallTask?.cancel()
            actionTask?.cancel()
            saveTask?.cancel()
            saveTask = nil
            // A note taken away by another device is out of the store, and
            // writing to it would fault or bring it back from the dead.
            guard !isDeleted, note.modelContext != nil else { return }
            if NoteText.isBlank(text) {
                if wasBlankOnOpen {
                    // Never written in: discarded, not worth a place in the
                    // Trash.
                    NoteStore.erase(note, in: context)
                } else {
                    // It had something in it and now does not. That is a
                    // deletion the user may not have meant, so it goes to
                    // the Trash, where it can be got back.
                    NoteStore.trash(note, in: context)
                }
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
            } else {
                // The sparkle is a menu. Make a list, Tidy up and Reminders
                // work on every iPhone; the rest need Apple's on-device
                // model and are there only where it could be. When it is
                // off or still downloading, the menu says so instead of
                // pretending.
                Menu {
                    if OnDevice.status == .off {
                        Text("Apple Intelligence is off in Settings")
                    } else if OnDevice.status == .downloading {
                        Text("Apple Intelligence is still downloading")
                    }
                    Button("Make a list", systemImage: "checklist") { makeList() }
                        .disabled(!canMakeList)
                    if OnDevice.status != .none {
                        Button("Add a title", systemImage: "textformat") { addTitle() }
                            .disabled(isBlank || !OnDevice.isAvailable)
                    }
                    Button("Tidy up", systemImage: "wand.and.stars") { tidy() }
                        .disabled(isBlank)
                    if OnDevice.status != .none {
                        Button("Sort the list", systemImage: "arrow.up.arrow.down") { sortList() }
                            .disabled(!canSortList || !OnDevice.isAvailable)
                    }
                    Button("Reminders", systemImage: "bell") { findReminders() }
                        .disabled(isBlank)
                    if OnDevice.status != .none {
                        Button("Where did I leave off?", systemImage: "clock.arrow.circlepath") { loadBrief(onDemand: true) }
                            .disabled(!Brief.wanted(for: text) || !OnDevice.isAvailable)
                    }
                } label: {
                    Image(systemName: "sparkles")
                        .font(Theme.Font.barGlyph)
                        .foregroundStyle(Theme.fg)
                        .frame(width: Theme.tapTarget, height: Theme.tapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sparkle")
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
        guard !plain.isEmpty else { return }
        act({ await ListMaker.items(from: plain) }) { items in
            guard let items else { return }
            if items.isEmpty { show("No list in this note") } else { command = .makeList(items: items, from: plain) }
        }
    }

    /// The model reads the note and puts a title on a new first line, with
    /// the cursor at its end. One edit; a shake takes it back.
    private func addTitle() {
        guard !isBlank else { return }
        let snapshot = text
        act({ await OnDevice.title(for: snapshot) }) { title in
            if let title { command = .addTitle(title) } else { show("Couldn't find a title for this") }
        }
    }

    /// Each line made to read cleanly, line for line, with the checklist
    /// markers kept out of the model's hands and the items kept fragments.
    /// One edit; a shake takes it back.
    private func tidy() {
        guard !isBlank else { return }
        let lines = Checklist.bareLines(of: text)
        let items = Checklist.itemFlags(of: text)
        act({ await OnDevice.tidied(lines, items: items) }) { tidied in
            if let tidied { command = .tidy(lines: tidied, from: lines) } else { show("Nothing to fix") }
        }
    }

    /// Three items or more: enough to group.
    private var canSortList: Bool { Checklist.items(of: text).count >= 3 }

    /// The model groups the items by kind and gives back their order; the
    /// ticks and the plain lines stay where they are. One edit; a shake
    /// takes it back.
    private func sortList() {
        guard canSortList else { return }
        let items = Checklist.items(of: text)
        act({ await OnDevice.sorted(items) }) { sorted in
            guard let sorted else { return }
            switch sorted {
            case let .order(order): command = .sortList(order: order, items: items)
            case .alreadyGrouped: show("Already in order")
            case .noAnswer: show("Couldn't sort that")
            }
        }
    }

    /// The dates and times in the note, read off the lines and, with the
    /// model, found by it too; a sheet shows them, and one tap there puts
    /// them in the Reminders app or sets a notification.
    private func findReminders() {
        guard !isBlank else { return }
        let snapshot = text
        act({ await Reminders.find(in: snapshot) }) { found in
            // The sheet opens either way: with nothing found it says so,
            // which is better than a tap that appears to do nothing.
            foundReminders = found ?? []
            showingReminders = true
        }
    }

    /// The brief: what the note has settled, what is open, what is next,
    /// in place of the date line. On demand the spinner shows meanwhile.
    private func loadBrief(onDemand: Bool) {
        guard Brief.wanted(for: text) else { return }
        let snapshot = text
        guard onDemand else {
            // The one that appears on its own after a day away: no spinner,
            // and nothing to say if it comes back empty.
            Task { @MainActor in
                let made = await withTimeout(Self.modelLimit) { await OnDevice.brief(for: snapshot) }
                guard text == snapshot, let made else { return }
                brief = made.line
            }
            return
        }
        act({ await OnDevice.brief(for: snapshot) }) { made in
            guard text == snapshot else { return }
            if let made { brief = made.line } else { show("Nothing to sum up yet") }
        }
    }

    /// A pause in typing: is there an older note that bears on this? Only
    /// when the note has enough words, only for a note that shares three
    /// words or more with it, and each older note once per sitting.
    private func scheduleRecall(_ value: String) {
        recallTask?.cancel()
        // The writing has moved on, so a hint about the older text should
        // not stay pinned above it.
        if recall != nil { withAnimation(.easeOut(duration: 0.15)) { recall = nil } }
        guard OnDevice.isAvailable, ModelGuard.words(value).count >= Recall.minimumWords else { return }
        recallTask = Task { @MainActor in
            try? await Task.sleep(for: Self.recallDelay)
            guard !Task.isCancelled else { return }
            let candidates = Recall.candidates(for: value, among: NoteStore.liveCards(in: context, excluding: note.id))
                .filter { !recalled.contains($0.id) }
            guard !candidates.isEmpty else { return }
            guard let found = await OnDevice.recall(writing: value, candidates: candidates),
                  !Task.isCancelled,
                  let older = NoteStore.note(withID: found.id, in: context) else { return }
            recalled.insert(found.id)
            withAnimation(.easeOut(duration: 0.2)) {
                recall = RecallHint(id: found.id, title: older.title, said: found.said)
            }
        }
    }

    /// A word from the sparkle in place of the date line, for a moment.
    /// Runs a model action with a deadline, keeping `working` true only
    /// while it is really working. Nil means it gave up.
    private func act<T: Sendable>(_ work: @escaping @Sendable () async -> T?,
                                  then finish: @escaping (T?) -> Void) {
        guard !working else { return }
        working = true
        actionTask?.cancel()
        actionTask = Task { @MainActor in
            let made = await withTimeout(Self.modelLimit, work)
            guard !Task.isCancelled else { return }
            working = false
            if made == nil, OnDevice.isAvailable { show("That took too long") }
            finish(made)
        }
    }

    private func show(_ text: String) {
        // The brief sits in the same line and outranks the notice there, so
        // "Already in order" behind one would never be seen.
        if brief != nil { brief = nil }
        notice = text
        noticeTimer?.cancel()
        noticeTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            notice = nil
        }
    }

    private func scheduleSave(_ value: String) {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled, !isDeleted, note.modelContext != nil else { return }
            // Mid-edit: a line cut on its way to being pasted lower down is
            // absent for a moment, and its notification must not go with it.
            NoteStore.update(note, text: value, in: context, settled: false)
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
        // Cancelled first: a blank note returns early, and its pending save
        // would otherwise land after the view has gone.
        saveTask?.cancel()
        saveTask = nil
        // A note deleted on another device is out of the store already;
        // writing to it would either fault or bring it back from the dead.
        guard !isDeleted, note.modelContext != nil, !NoteText.isBlank(text) else { return }
        NoteStore.update(note, text: text, in: context)
    }

    private func openRecalled(_ hint: RecallHint) {
        withAnimation(.easeOut(duration: 0.15)) { recall = nil }
        navigation.open(hint.id)
    }

    /// What was written here goes to the end of the older note, this note
    /// goes to the Trash, and the older note opens in its place.
    private func moveToRecalled(_ hint: RecallHint) {
        guard let older = NoteStore.note(withID: hint.id, in: context) else { return }
        recallTask?.cancel()
        saveTask?.cancel()
        saveTask = nil
        isDeleted = true
        NoteStore.move(text: text, from: note, into: older, in: context)
        navigation.open(older.id)
    }

    private func deleteNow() {
        deleteTimer?.cancel()
        saveTask?.cancel()
        saveTask = nil
        // Save first, so what the Trash holds is what was on screen rather
        // than what it was a third of a second ago.
        if !NoteText.isBlank(text), note.modelContext != nil {
            NoteStore.update(note, text: text, in: context)
        }
        isDeleted = true
        NoteStore.trash(note, in: context)
        dismiss()
    }
}
