import SwiftUI

/// Hold the pencil and speak. The words appear as they are heard; Stop
/// ends it, and the note lands cleaned: a title on top, spelling and
/// punctuation fixed, a list made where one was spoken, from Apple's
/// on-device model where there is one, or as the words were spoken where
/// there is not.
struct DictateSheet: View {
    /// Called with the note's text once; the sheet dismisses itself.
    let onDone: (String) -> Void
    /// Names out of the user's own notes, so they are heard as they are
    /// written. It never leaves the phone.
    var vocabulary: [String] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
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
                VStack(alignment: .leading, spacing: 10) {
                    Text(body_)
                        .font(Theme.Font.rowBody)
                        .foregroundStyle(listener.transcript.isEmpty ? Theme.muted : Theme.fg)
                    // Something took the microphone away mid-sentence. The
                    // words above are all there is, and saying so is the
                    // only way the user finds out.
                    if let notice = listener.notice {
                        Text(notice)
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 12)
                .animation(.easeOut(duration: 0.15), value: listener.notice)
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
        .task { await listener.start(vocabulary: vocabulary) }
        .onDisappear { listener.stop() }
        // There is no background audio mode, so iOS is about to take the
        // session down anyway. Stopping deliberately keeps the words.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { listener.stop() }
        }
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
        return listener.transcript.isEmpty ? listener.placeholder : listener.transcript
    }

    /// Stop listening, clean what was heard, hand it over.
    private func stop() {
        listener.stop()
        cleaning = true
        Task { @MainActor in
            // The recogniser's considered pass fixes casing and
            // punctuation the partials got wrong, and is worth the moment
            // it takes. It is bounded, so Stop always lets the user out.
            let heard = await listener.settled().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !heard.isEmpty else {
                cleaning = false
                dismiss()
                return
            }
            // The model has a limit here too: the words are already heard,
            // and a call that never returns must not cost the user the note.
            let cleaned = await withTimeout(Self.cleanLimit) { await OnDevice.cleaned(dictation: heard) }
            cleaning = false
            onDone(cleaned ?? Dictation.plain(heard))
            dismiss()
        }
    }
}
