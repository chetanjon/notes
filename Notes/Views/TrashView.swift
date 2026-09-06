import SwiftData
import SwiftUI

/// Deleted notes, newest first. A tap puts one back in the list; a swipe
/// deletes it for good; Empty clears the lot, with the editor's two-tap
/// confirmation and no system alert. Once the last note is gone the
/// screen pops, so the list never shows an empty Trash.
struct TrashView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Note> { $0.deletedAt != nil }, sort: \Note.deletedAt, order: .reverse)
    private var notes: [Note]

    @State private var confirmingEmpty = false
    @State private var emptyTimer: Task<Void, Never>?

    /// The Empty button reverts from "Delete all" after this long.
    private static let confirmWindow: Duration = .seconds(3)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            bar
            Text("Trash")
                .font(Theme.Font.screenTitle)
                .tracking(Theme.Font.screenTitleTracking)
                .foregroundStyle(Theme.fg)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 8)
            Text("Tap a note to put it back. Swipe to delete for good. Gone after 30 days.")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 6)
                .padding(.bottom, 8)
            List {
                ForEach(notes) { note in
                    NoteRow(note: note, isLast: note.id == notes.last?.id, date: note.deletedAt)
                        .contentShape(Rectangle())
                        .onTapGesture { restore(note) }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Theme.bg)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                erase(note)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(Theme.field)
                        }
                        .contextMenu {
                            Button {
                                restore(note)
                            } label: {
                                Label("Put back", systemImage: "arrow.uturn.backward")
                            }
                            Button(role: .destructive) {
                                erase(note)
                            } label: {
                                Label("Delete for good", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: notes.isEmpty) { _, empty in
            if empty { dismiss() }
        }
        .onDisappear { emptyTimer?.cancel() }
    }

    // MARK: Bar

    private var bar: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.fg)
                    .frame(width: Theme.tapTarget, height: Theme.tapTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            Spacer()
            Button {
                if confirmingEmpty { emptyNow() } else { armEmpty() }
            } label: {
                Text(confirmingEmpty ? "Delete all" : "Empty")
                    .font(Theme.Font.toolbar)
                    .foregroundStyle(Theme.fg)
                    .frame(height: Theme.tapTarget)
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.pagePadding - 10)
        .frame(height: Theme.tapTarget)
        .background(Theme.bg)
        .animation(.easeOut(duration: 0.15), value: confirmingEmpty)
    }

    // MARK: Actions

    private func restore(_ note: Note) {
        withAnimation(.easeOut(duration: 0.2)) {
            NoteStore.restore(note, in: context)
        }
    }

    private func erase(_ note: Note) {
        withAnimation(.easeOut(duration: 0.2)) {
            NoteStore.erase(note, in: context)
        }
    }

    /// First tap: "Empty" becomes "Delete all". A second tap within three
    /// seconds empties the Trash; otherwise it reverts.
    private func armEmpty() {
        confirmingEmpty = true
        emptyTimer?.cancel()
        emptyTimer = Task { @MainActor in
            try? await Task.sleep(for: Self.confirmWindow)
            guard !Task.isCancelled else { return }
            confirmingEmpty = false
        }
    }

    private func emptyNow() {
        emptyTimer?.cancel()
        confirmingEmpty = false
        NoteStore.emptyTrash(in: context)
    }
}
