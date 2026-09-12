import SwiftUI

/// Hold the pencil and speak. The words appear as they are heard; Stop
/// ends it and hands them over.
///
/// The sheet does not tidy anything and does not wait for the model. It
/// used to: Stop asked Apple's model for a cleaned-up note and held the
/// sheet open, for up to twenty seconds, before the user saw anything at
/// all. The note is now written from the words at once and the model's
/// version arrives afterwards, in the editor, as an edit that can be
/// shaken away.
struct DictateSheet: View {
    enum Purpose {
        case newNote
        case intoNote
    }

    /// Called once with the words as they were heard. The caller decides
    /// what they become.
    let onDone: (String) -> Void
    /// Names out of the user's own notes, so they are heard as they are
    /// written. It never leaves the phone.
    var vocabulary: [String] = []
    /// What the words are for. It changes nothing that is drawn: only what
    /// the button tells VoiceOver it is about to do.
    var purpose: Purpose = .newNote
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var listener = SpeechListener()
    @State private var finishing = false
    /// The words go over exactly once, whichever way the sheet ends.
    @State private var delivered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(heading)
                    .font(Theme.Font.screenTitle)
                    .tracking(Theme.Font.screenTitleTracking)
                    .foregroundStyle(Theme.fg)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                // Swiping the sheet away keeps what was said, because
                // losing it cannot be undone and an unwanted note is one
                // swipe from the Trash. So there has to be a way to mean it.
                Button("Cancel") { cancel() }
                    .font(Theme.Font.toolbar)
                    .foregroundStyle(Theme.muted)
                    .buttonStyle(.plain)
                    .accessibilityHint("Throws away what was said")
            }
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
                // One element that changes, rather than a new one to read
                // out on every partial result.
                .accessibilityElement(children: .combine)
                .accessibilityLabel("What you said")
                .accessibilityValue(body_)
                .accessibilityAddTraits(.updatesFrequently)
            }
            Button {
                stop()
            } label: {
                Text(finishing ? "Finishing…" : listener.state == .listening ? "Stop" : "Done")
                    .font(Theme.Font.toolbar)
                    .foregroundStyle(Theme.bg)
                    .frame(maxWidth: .infinity)
                    // A minimum, not a fixed height: at the largest text
                    // sizes "Finishing…" was cut off.
                    .frame(minHeight: Theme.tapTarget + 6)
                    .background(Theme.fg, in: Capsule())
            }
            .buttonStyle(PressedButtonStyle())
            .disabled(finishing)
            .accessibilityHint(purpose == .newNote
                               ? "Ends the dictation and makes the note"
                               : "Ends the dictation and puts the words in the note")
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
        .task { await listener.start(vocabulary: vocabulary) }
        // A swipe while the last words are being settled would otherwise
        // hand over a sentence short. It is at most two seconds now.
        .interactiveDismissDisabled(finishing)
        .onDisappear {
            listener.stop()
            // Swiped away. There is no awaiting here, so it is the words on
            // screen rather than the recogniser's considered pass: worse
            // text than Stop gives, and far better than nothing.
            deliver(listener.transcript)
        }
        // There is no background audio mode, so iOS is about to take the
        // session down anyway. Stopping deliberately keeps the words.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { listener.stop() }
        }
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

    /// Stop listening and hand the words over.
    private func stop() {
        listener.stop()
        finishing = true
        Task { @MainActor in
            // The recogniser's considered pass fixes casing and punctuation
            // the partials got wrong, and is worth the moment it takes. It
            // is bounded, so Stop always lets the user out.
            let heard = await listener.settled()
            finishing = false
            deliver(heard)
            dismiss()
        }
    }

    private func cancel() {
        delivered = true
        listener.stop()
        dismiss()
    }

    private func deliver(_ words: String) {
        guard !delivered else { return }
        let heard = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heard.isEmpty else { return }
        delivered = true
        onDone(heard)
    }
}
