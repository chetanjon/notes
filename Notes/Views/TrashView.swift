import SwiftData
import SwiftUI

/// Deleted notes, newest first. A tap asks: put it back, or delete it for
/// good; a swipe deletes it for good; Empty clears the lot, with the
/// editor's two-tap confirmation and no system alert. Empty, it says so.
struct TrashView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Note> { $0.deletedAt != nil }, sort: \Note.deletedAt, order: .reverse)
    private var notes: [Note]

    @State private var confirmingEmpty = false
    @State private var emptyTimer: Task<Void, Never>?
    /// The note tapped, while its two choices are up.
    @State private var chosen: Note?

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
            Text("Tap a note to put it back or delete it for good. Gone after 30 days.")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 6)
                .padding(.bottom, 8)
            if notes.isEmpty {
                Text("Nothing here.")
                    .font(Theme.Font.rowBody)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                List {
                    ForEach(notes) { note in
                        NoteRow(note: note, date: note.deletedAt)
                            .contentShape(Rectangle())
                            .onTapGesture { chosen = note }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Theme.bg)
                            .noteSeparator(isLast: note.id == notes.last?.id)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    erase(note)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .tint(Theme.field)
                                .accessibilityLabel("Delete for good")
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
                .confirmationDialog(chosen?.title ?? "", isPresented: Binding(
                    get: { chosen != nil }, set: { if !$0 { chosen = nil } }
                ), titleVisibility: .visible, presenting: chosen) { note in
                    Button("Put back") { restore(note) }
                    Button("Delete for good", role: .destructive) { erase(note) }
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { emptyTimer?.cancel() }
    }

    // MARK: Bar

    private var bar: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(Theme.Font.barGlyph)
                    .foregroundStyle(Theme.fg)
                    .frame(width: Theme.tapTarget, height: Theme.tapTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            Spacer()
            if !notes.isEmpty {
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
