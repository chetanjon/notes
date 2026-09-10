import SwiftUI

/// What the model found in the note, each with a circle to leave it out,
/// and two ways to keep the rest: the iPhone's Reminders app, or a
/// notification from this app at the time, which opens the note.
struct RemindersSheet: View {
    let found: [Reminders.Found]
    let noteID: UUID
    let noteTitle: String
    /// Called with how many notifications were set, before the sheet goes.
    var onNotified: (Int) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Set<String>
    @State private var working = false
    @State private var trouble: String?

    init(found: [Reminders.Found], noteID: UUID, noteTitle: String, onNotified: @escaping (Int) -> Void = { _ in }) {
        self.found = found
        self.noteID = noteID
        self.noteTitle = noteTitle
        self.onNotified = onNotified
        _chosen = State(initialValue: Set(found.map(\.id)))
    }

    private var picked: [Reminders.Found] { found.filter { chosen.contains($0.id) } }
    /// What "Notify me" will really set: a time that has passed cannot be.
    private var notifiable: [Reminders.Found] { picked.filter { $0.due > .now } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Reminders")
                .font(Theme.Font.screenTitle)
                .tracking(Theme.Font.screenTitleTracking)
                .foregroundStyle(Theme.fg)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 28)
            if found.isEmpty {
                Text("No dates or times in this note.")
                    .font(Theme.Font.rowBody)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, 12)
                Text("Put a day or a time on the line, like “dentist tuesday 3pm” or “call mum tomorrow at 10”.")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, 6)
                Spacer()
            } else {
                Text("Found in the note. Tap a circle to leave one out.")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                List {
                    ForEach(found) { item in
                        row(item)
                            .contentShape(Rectangle())
                            .onTapGesture { toggle(item) }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Theme.bg)
                            .noteSeparator(isLast: item.id == found.last?.id)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                if let trouble {
                    Text(trouble)
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, Theme.pagePadding)
                        .padding(.bottom, 12)
                }
                VStack(spacing: 10) {
                    // From this app, at the time, opening the note.
                    pill(working ? "Setting…" : String(format: "Notify me for %ld", notifiable.count), filled: true) { notify() }
                    // Apple's app, with its repeats and snooze.
                    pill(count("Add %ld to Reminders"), filled: false) { add() }
                }
                .disabled(chosen.isEmpty || working)
                .opacity(chosen.isEmpty ? 0.35 : 1)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
    }

    private func count(_ form: String) -> String {
        String(format: form, chosen.count)
    }

    /// A white pill, or an outlined one for the second choice.
    private func pill(_ label: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Font.toolbar)
                .foregroundStyle(filled ? Theme.bg : Theme.fg)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.tapTarget + 6)
                .background(filled ? Theme.fg : Theme.bg, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.fg, lineWidth: filled ? 0 : 1))
        }
        .buttonStyle(PressedButtonStyle())
    }

    private func row(_ item: Reminders.Found) -> some View {
        HStack(spacing: 12) {
            Image(systemName: chosen.contains(item.id) ? "circle.fill" : "circle")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.fg)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(Theme.Font.rowTitle)
                    .foregroundStyle(Theme.fg)
                    .lineLimit(2)
                Text(DateFormat.stamp(item.due))
                    .font(Theme.Font.rowBody)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.vertical, 12)
        .opacity(chosen.contains(item.id) ? 1 : 0.5)
    }

    private func toggle(_ item: Reminders.Found) {
        if chosen.contains(item.id) { chosen.remove(item.id) } else { chosen.insert(item.id) }
    }

    private func add() {
        let items = picked
        guard !items.isEmpty, !working else { return }
        working = true
        trouble = nil
        Task { @MainActor in
            let outcome = await Reminders.add(items)
            working = false
            switch outcome {
            case .added:
                dismiss()
            case .denied:
                trouble = "Reminders access is off. Turn it on in Settings › Privacy & Security › Reminders."
            case .noList:
                trouble = "There is no list to add to. Open the Reminders app once and make a list."
            case .failed:
                trouble = "Those could not be added to Reminders."
            }
        }
    }

    private func notify() {
        guard !working else { return }
        let items = notifiable
        guard !items.isEmpty else {
            trouble = "Those times have passed."
            return
        }
        working = true
        trouble = nil
        Task { @MainActor in
            let outcome = await Notify.schedule(items, noteID: noteID, noteTitle: noteTitle)
            working = false
            switch outcome {
            case let .set(count):
                onNotified(count)
                dismiss()
            case .denied:
                trouble = "Notifications are off for Matte. Turn them on in Settings › Notifications › Matte."
            case .full:
                trouble = "Too many notifications are already set. Some have to pass or be removed first."
            }
        }
    }
}
