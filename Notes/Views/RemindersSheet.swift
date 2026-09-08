import SwiftUI

/// What the model found in the note, each with a circle to leave it out,
/// and one button that puts the rest in the iPhone's Reminders app.
struct RemindersSheet: View {
    let found: [Reminders.Found]
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Set<String>
    @State private var adding = false
    @State private var refused = false

    init(found: [Reminders.Found]) {
        self.found = found
        _chosen = State(initialValue: Set(found.map(\.id)))
    }

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
                if refused {
                    Text("Reminders access is off. Turn it on in Settings › Privacy & Security › Reminders.")
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, Theme.pagePadding)
                        .padding(.bottom, 12)
                }
                Button {
                    add()
                } label: {
                    Text(adding ? "Adding…" : chosen.count == 1 ? "Add 1 to Reminders" : "Add \(chosen.count) to Reminders")
                        .font(Theme.Font.toolbar)
                        .foregroundStyle(Theme.bg)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.tapTarget + 6)
                        .background(Theme.fg, in: Capsule())
                }
                .buttonStyle(PressedButtonStyle())
                .disabled(chosen.isEmpty || adding)
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
        let picked = found.filter { chosen.contains($0.id) }
        guard !picked.isEmpty, !adding else { return }
        adding = true
        refused = false
        Task { @MainActor in
            let done = await Reminders.add(picked)
            adding = false
            if done { dismiss() } else { refused = true }
        }
    }
}
