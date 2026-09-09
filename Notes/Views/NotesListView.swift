import AppIntents
import SwiftData
import SwiftUI

/// The home screen: title, search, the notes, the way into the Trash, and
/// the pen.
struct NotesListView: View {
    @Environment(\.modelContext) private var context
    @Environment(Navigation.self) private var navigation
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<Note> { $0.deletedAt == nil }, sort: \Note.updatedAt, order: .reverse)
    private var notes: [Note]

    @State private var query = ""
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool
    /// Holding the pencil: the dictation sheet.
    @State private var showingDictate = false

    /// What the on-device model found for a question the letters did not
    /// answer; kept while the query is the one it was asked.
    struct Asked: Equatable {
        var query: String
        var found: NoteFinder.Found
    }
    @State private var asked: Asked?
    @State private var asking = false
    @State private var askTask: Task<Void, Never>?

    /// The model is asked this long after the last keystroke with no match.
    private static let askDelay: Duration = .milliseconds(700)

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    /// The notes the model picked for the current query, in its order.
    private var askedRows: [Note]? {
        guard let asked, asked.query == trimmedQuery else { return nil }
        return asked.found.ids.compactMap { id in notes.first { $0.id == id } }
    }

    /// Changes when a different note is pinned or the pinned note is edited,
    /// on this phone or, through iCloud, on another.
    private var pinnedSignature: String? {
        notes.first { $0.isPinned }.map { "\($0.id.uuidString)|\($0.updatedAt.timeIntervalSince1970)" }
    }

    /// Pinned first, then the most recently opened or edited first: the
    /// note the user was just in is at the top when they come back.
    private var visible: [Note] {
        let filtered = trimmedQuery.isEmpty
            ? Array(notes)
            : notes.filter { NoteText.matches($0.text, query: trimmedQuery) }
        return filtered.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.touchedAt > b.touchedAt
        }
    }

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.path) {
            ZStack(alignment: .bottomTrailing) {
                Theme.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    if !isSearching {
                        header
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                    }
                    searchBar
                        .padding(.horizontal, Theme.pagePadding)
                        .padding(.top, isSearching ? 8 : 0)
                        .padding(.bottom, 12)
                    content
                }
                composeButton
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, 24)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Navigation.Route.self) { route in
                switch route {
                case let .note(id):
                    if let note = NoteStore.note(withID: id, in: context), !note.isTrashed {
                        EditorView(note: note)
                    } else {
                        MissingNoteView()
                    }
                case .trash:
                    TrashView()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                OnDevice.prewarm()
                NoteStore.purgeTrash(in: context)
                NoteStore.syncLockScreen(in: context)
                NoteStore.syncRecent(in: context)
                // The phone's search index and Siri's list of note names
                // catch up with whatever iCloud brought in.
                NoteIndex.reindex(in: context)
                NotesShortcuts.updateAppShortcutParameters()
            }
        }
        .onChange(of: pinnedSignature) { _, _ in
            NoteStore.syncLockScreen(in: context)
        }
        .onChange(of: trimmedQuery) { _, _ in
            scheduleAsk()
        }
    }

    // MARK: Ask the note

    /// When the letters match nothing, or the search reads as a question
    /// ("when is the dentist"), and the phone has the on-device model, the
    /// question goes to it a moment after typing stops. A new keystroke
    /// cancels the wait; a result is kept for its query only.
    private func scheduleAsk() {
        askTask?.cancel()
        askTask = nil
        let question = trimmedQuery
        guard NoteFinder.isAvailable, !question.isEmpty,
              visible.isEmpty || NoteText.isQuestion(question),
              asked?.query != question else {
            asking = false
            return
        }
        asking = true
        let cards = notes
            .filter { !$0.isBlank }
            .map { NoteFinder.Card(id: $0.id, text: $0.text) }
        askTask = Task { @MainActor in
            try? await Task.sleep(for: Self.askDelay)
            guard !Task.isCancelled else { return }
            let found = await NoteFinder.find(question, in: cards)
            guard !Task.isCancelled else { return }
            asked = Asked(query: question, found: found ?? NoteFinder.Found(answer: "", ids: []))
            asking = false
        }
    }

    // MARK: Header

    /// The title, and the way into the Trash at the right, always there.
    private var header: some View {
        HStack(spacing: 0) {
            Text("Notes")
                .font(Theme.Font.screenTitle)
                .tracking(Theme.Font.screenTitleTracking)
                .foregroundStyle(Theme.fg)
            Spacer(minLength: 8)
            Button {
                searchFocused = false
                navigation.path.append(.trash)
            } label: {
                Image(systemName: "trash")
                    .font(Theme.Font.barGlyph)
                    .foregroundStyle(Theme.muted)
                    .frame(width: Theme.tapTarget, height: Theme.tapTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trash")
        }
        .padding(.leading, Theme.pagePadding)
        .padding(.trailing, Theme.pagePadding - 12)
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .foregroundStyle(isSearching ? Theme.fg : Theme.muted)
                TextField("", text: $query, prompt: Text("Search").foregroundStyle(Theme.faint))
                    .font(Theme.Font.rowBody)
                    .foregroundStyle(Theme.fg)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: searchFocused) { _, focused in
                        if focused { withAnimation(.easeOut(duration: 0.2)) { isSearching = true } }
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(Theme.muted)
                            .frame(width: Theme.tapTarget, height: Theme.tapTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, query.isEmpty ? 12 : 0)
            .frame(height: Theme.searchHeight)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.searchRadius, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { searchFocused = true }

            if isSearching {
                Button("Cancel") { cancelSearch() }
                    .font(.body)
                    .foregroundStyle(Theme.fg)
                    .frame(height: Theme.tapTarget)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private func cancelSearch() {
        query = ""
        searchFocused = false
        withAnimation(.easeOut(duration: 0.2)) { isSearching = false }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        // The letters first; when they match nothing, or the search is a
        // question the model has answered, what the model found.
        let matched = visible
        let picks = askedRows
        let answered = matched.isEmpty || (picks?.isEmpty == false) ? picks : nil
        let rows = answered ?? matched
        if notes.isEmpty {
            Text("No notes yet. Tap the pen to write one.")
                .font(Theme.Font.rowBody)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if !trimmedQuery.isEmpty, rows.isEmpty {
            Text(asking ? "Asking…" : asked?.query == trimmedQuery ? "Nothing in your notes answers that." : "No matches.")
                .font(Theme.Font.rowBody)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            List {
                if !trimmedQuery.isEmpty {
                    // The model's one-line answer, or that it is being
                    // asked, or the count.
                    let answer = answered == nil ? "" : (asked?.found.answer ?? "")
                    let count = rows.count == 1 ? "1 note" : "\(rows.count) notes"
                    Text(!answer.isEmpty ? answer : (asking ? "Asking…" : count))
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, Theme.pagePadding)
                        .padding(.bottom, 4)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Theme.bg)
                        .listRowSeparator(.hidden)
                }
                ForEach(rows) { note in
                    NoteRow(note: note, highlight: answered == nil ? trimmedQuery : "")
                        .contentShape(Rectangle())
                        .onTapGesture { open(note) }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Theme.bg)
                        .noteSeparator(isLast: note.id == rows.last?.id)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            // A white trash glyph on the field grey, and no
                            // word: swipe actions paint their label white
                            // whatever the tint. A full swipe deletes at once.
                            Button(role: .destructive) {
                                NoteStore.trash(note, in: context)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .tint(Theme.field)
                            .accessibilityLabel("Delete")
                        }
                        .contextMenu {
                            Button {
                                togglePin(note)
                            } label: {
                                Label(note.isPinned ? "Unpin" : "Pin to Lock Screen",
                                      systemImage: note.isPinned ? "pin.slash" : "pin")
                            }
                            Button(role: .destructive) {
                                NoteStore.trash(note, in: context)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                // Room so the last row clears the compose button.
                Color.clear
                    .frame(height: Theme.composeSize + 48)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Theme.bg)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    /// A tap starts a note; holding it starts a dictation.
    private var composeButton: some View {
        Button {
            let note = NoteStore.create(in: context)
            searchFocused = false
            navigation.open(note.id)
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(Theme.bg)
                .frame(width: Theme.composeSize, height: Theme.composeSize)
                .background(Theme.fg, in: Circle())
        }
        .buttonStyle(PressedButtonStyle())
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            searchFocused = false
            showingDictate = true
        })
        .accessibilityLabel("New note")
        .accessibilityHint("Hold to dictate a note")
        .sheet(isPresented: $showingDictate) {
            DictateSheet { text in
                let note = NoteStore.create(in: context)
                NoteStore.update(note, text: text, in: context)
                navigation.open(note.id)
            }
        }
    }

    private func open(_ note: Note) {
        searchFocused = false
        navigation.open(note.id)
    }

    private func togglePin(_ note: Note) {
        NoteStore.togglePin(note, in: context)
    }
}

/// Shown when a deep link names a note that no longer exists.
private struct MissingNoteView: View {
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            Text("That note is gone.")
                .font(Theme.Font.rowBody)
                .foregroundStyle(Theme.muted)
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    /// The rule under a note row: the list's own separator, in the rule
    /// grey, 20pt in from each edge, and none under the last row. Being
    /// the list's, it stays put while the row slides for a swipe.
    func noteSeparator(isLast: Bool) -> some View {
        listRowSeparator(isLast ? .hidden : .visible, edges: .bottom)
            .listRowSeparator(.hidden, edges: .top)
            .listRowSeparatorTint(Theme.rule)
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] + Theme.pagePadding }
            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - Theme.pagePadding }
    }
}

/// White fills dim to `field` grey while pressed; the only pressed state.
struct PressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
