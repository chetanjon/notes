import SwiftUI

/// Hold the pencil and speak. The words appear as they are heard; Stop
/// ends it, and the note lands cleaned: a title on top, spelling and
/// punctuation fixed, a list made where one was spoken, from Apple's
/// on-device model where there is one, or as the words were spoken where
/// there is not.
struct DictateSheet: View {
    /// Called with the note's text once; the sheet dismisses itself.
    let onDone: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var listener = SpeechListener()
    @State private var cleaning = false

    /// The model has this long to tidy the dictation before the words are
    /// used as they were heard.
    private static let cleanLimit: Duration = .seconds(20)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(heading)
                .font(Theme.Font.screenTitle)
                .tracking(Theme.Font.screenTitleTracking)
                .foregroundStyle(Theme.fg)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 28)
            ScrollView {
                Text(body_)
                    .font(Theme.Font.rowBody)
                    .foregroundStyle(listener.transcript.isEmpty ? Theme.muted : Theme.fg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, 12)
            }
            Button {
                stop()
            } label: {
                Text(cleaning ? "Cleaning up…" : listener.state == .listening ? "Stop" : "Done")
                    .font(Theme.Font.toolbar)
                    .foregroundStyle(Theme.bg)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.tapTarget + 6)
                    .background(Theme.fg, in: Capsule())
            }
            .buttonStyle(PressedButtonStyle())
            .disabled(cleaning)
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
        .task { await listener.start() }
        .onDisappear { listener.stop() }
        // A swipe down while it is thinking would otherwise still make the
        // note a moment later, after the user had given up on it.
        .interactiveDismissDisabled(cleaning)
    }

    private var heading: String {
        switch listener.state {
        case .idle: "One moment"
        case .listening: "Listening"
        case .stopped: "Heard"
        case .failed: "Cannot listen"
        }
    }

    private var body_: String {
        if case let .failed(reason) = listener.state { return reason }
        return listener.transcript.isEmpty ? "Say what the note should say." : listener.transcript
    }

    /// Stop listening, clean what was heard, hand it over.
    private func stop() {
        listener.stop()
        let heard = listener.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heard.isEmpty else {
            dismiss()
            return
        }
        cleaning = true
        Task { @MainActor in
            // The model has a limit here too: the words are already heard,
            // and a call that never returns must not cost the user the note.
            let cleaned = await withTimeout(Self.cleanLimit) { await OnDevice.cleaned(dictation: heard) }
            cleaning = false
            onDone(cleaned ?? Dictation.plain(heard))
            dismiss()
        }
    }
}
