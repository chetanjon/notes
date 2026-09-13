import SwiftUI
import UIKit

/// A `UITextView` for the editor. SwiftUI's `TextEditor` hides the cursor,
/// and the checklist needs it: the toolbar button, tapping a marker, and the
/// Return key all act on the line under the cursor.
///
/// The first line is drawn semibold, the rest regular with the spec's line
/// height, at the phone's text size. That styling is applied to the storage
/// after every change, so the text itself stays a plain `String`: the
/// checklist markers are still `□ ` and `■ ` in it, and `MarkerLayoutFragment`
/// draws a circle over each in their place.
///
/// The view runs on TextKit 2, which is what lets iOS's Writing Tools
/// (Proofread, Rewrite, Summarize, on phones with Apple Intelligence) work
/// inline. The markers are kept out of their reach.
struct ChecklistTextView: UIViewRepresentable {
    enum Command: Equatable {
        /// The toolbar's checklist button.
        case toggleItem
        /// "Make a list": the plain lines under the title become these items.
        case makeList(items: [String], from: String)
        /// "Add a title": this goes on a new first line.
        case addTitle(String)
        /// "Tidy up": the note's lines, marker-less, as the model fixed them.
        case tidy(lines: [String], from: [String])
        /// "Sort the list": the items' new order, and the items it was made
        /// for, so a list that changed meanwhile is left alone.
        case sortList(order: [Int], items: [String])
        /// The model's version of a dictation, landing after the note has
        /// already opened with the words as they were spoken. It carries
        /// the text it was worked out against, so a note typed into
        /// meanwhile is left exactly as the user left it.
        case cleaned(was: String, now: String)
    }

    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var command: Command?

    func makeUIView(context: Context) -> UITextView {
        // TextKit 2: the layout manager asks the coordinator for each
        // paragraph's fragment, and item lines get one that draws a circle.
        let view = UITextView(usingTextLayoutManager: true)
        view.textLayoutManager?.delegate = context.coordinator
        view.backgroundColor = .black
        view.textColor = .white
        view.tintColor = .white
        view.font = Style.body
        view.adjustsFontForContentSizeCategory = true
        view.keyboardAppearance = .dark
        view.keyboardDismissMode = .interactive
        view.alwaysBounceVertical = true
        view.textContainerInset = UIEdgeInsets(top: 12, left: 0, bottom: 40, right: 0)
        view.autocorrectionType = .default
        view.smartDashesType = .no
        view.smartQuotesType = .default
        view.dataDetectorTypes = []
        if #available(iOS 18.0, *) {
            // Writing Tools inline, and plain text only: a list or a table
            // would need rich text, and a note is a string.
            view.writingToolsBehavior = .complete
            view.allowedWritingToolsResultOptions = .plainText
        }
        view.delegate = context.coordinator
        view.text = text
        // The cursor lands at the end on open, as the spec says.
        view.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        view.typingAttributes = Style.attributes(semibold: text.isEmpty || !text.contains("\n"))
        context.coordinator.restyle(view)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.tapped(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        context.coordinator.textView = view
        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.textSizeChanged),
            name: UIContentSizeCategory.didChangeNotification, object: nil)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if view.text != text, !coordinator.writingToolsActive {
            // A change from outside (sync, or the delete blanking the note).
            let selection = view.selectedRange
            view.text = text
            coordinator.restyle(view)
            let end = (text as NSString).length
            view.selectedRange = NSRange(location: min(selection.location, end), length: 0)
        }
        if let command {
            // Cleared before the hop, not after: this runs on every parent
            // redraw, and the date line alone redraws on each autosave, so
            // a command left set would be run again by the next update.
            self.command = nil
            DispatchQueue.main.async {
                coordinator.run(command, on: view)
            }
        }
        if isFocused, !view.isFirstResponder {
            DispatchQueue.main.async {
                let end = (view.text as NSString).length
                view.selectedRange = NSRange(location: end, length: 0)
                view.becomeFirstResponder()
            }
        } else if !isFocused, view.isFirstResponder {
            DispatchQueue.main.async { view.resignFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: Style

    enum Style {
        /// The spec's sizes at the default text size, scaled with the body
        /// and title styles so they follow Settings > Display > Text Size.
        /// Computed, not stored: the size can change while the view lives.
        static var body: UIFont {
            UIFontMetrics(forTextStyle: .body)
                .scaledFont(for: .systemFont(ofSize: Theme.Font.editorSize, weight: .regular))
        }
        static var title: UIFont {
            UIFontMetrics(forTextStyle: .title2)
                .scaledFont(for: .systemFont(ofSize: Theme.Font.editorTitleSize, weight: .semibold))
        }
        static let muted = UIColor(Theme.muted)

        static var paragraph: NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            let font = body
            let target = font.pointSize * Theme.Font.editorLineHeight
            style.lineSpacing = max(0, target - font.lineHeight)
            return style
        }

        static func attributes(semibold: Bool) -> [NSAttributedString.Key: Any] {
            [
                .font: semibold ? title : body,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
            ]
        }

        /// The marker character: invisible, and widened so the circle drawn
        /// over it has room before the item's text.
        static func markerAttributes(font: UIFont) -> [NSAttributedString.Key: Any] {
            [.foregroundColor: UIColor.clear, .kern: font.pointSize * 0.25]
        }
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate,
                             NSTextLayoutManagerDelegate {
        var parent: ChecklistTextView
        weak var textView: UITextView?
        /// True while Writing Tools has the text. iOS is then rewriting it in
        /// place and asks that nothing else touch the storage until it is done.
        var writingToolsActive = false

        init(_ parent: ChecklistTextView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        /// Settings > Display > Text Size changed while the note was open.
        @objc func textSizeChanged() {
            guard let view = textView else { return }
            restyle(view)
        }

        // MARK: Layout

        /// An item line gets the fragment that draws its circle; every other
        /// paragraph the plain one.
        func textLayoutManager(_ textLayoutManager: NSTextLayoutManager,
                               textLayoutFragmentFor location: any NSTextLocation,
                               in textElement: NSTextElement) -> NSTextLayoutFragment {
            if let paragraph = textElement as? NSTextParagraph,
               Checklist.isItem(paragraph.attributedString.string) {
                return MarkerLayoutFragment(textElement: paragraph, range: paragraph.elementRange)
            }
            return NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange)
        }

        // MARK: Editing

        func textViewDidChange(_ view: UITextView) {
            guard !writingToolsActive else { return }
            // Text pasted from a PDF or a Windows file carries other line
            // breaks, which the text view honours but the rest of the app,
            // which splits on "\n", does not: a marker after one of those
            // would be a glyph with no circle.
            let tidy = NoteText.normalised(view.text)
            if tidy != view.text, view.markedTextRange == nil {
                let selection = view.selectedRange
                view.text = tidy
                let end = (tidy as NSString).length
                view.selectedRange = NSRange(location: min(selection.location, end), length: 0)
            }
            restyle(view)
            parent.text = view.text
        }

        func textViewDidChangeSelection(_ view: UITextView) {
            let firstLine = Checklist.lineRange(in: view.text, at: 0)
            let onFirstLine = view.selectedRange.location <= firstLine.length
            view.typingAttributes = Style.attributes(semibold: onFirstLine)
        }

        func textViewDidBeginEditing(_ view: UITextView) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textViewDidEndEditing(_ view: UITextView) {
            if parent.isFocused { parent.isFocused = false }
            // Writing Tools tells us when it begins and ends, and a rewrite
            // interrupted by the app going away may never report the end.
            // Left set, the flag stops every later keystroke reaching the
            // store, and the note would be saved as it was before.
            if writingToolsActive {
                writingToolsActive = false
                restyle(view)
                parent.text = view.text
            }
        }

        /// Return continues or ends a list; a deletion that touches a marker
        /// takes the whole marker, so backspace never leaves a bare glyph.
        func textView(_ view: UITextView, shouldChangeTextIn range: NSRange,
                      replacementText replacement: String) -> Bool {
            let edit: Checklist.Edit?
            if replacement == "\n" {
                edit = Checklist.handleReturn(in: view.text, selection: range)
            } else if replacement.isEmpty {
                edit = Checklist.handleDeletion(in: view.text, range: range)
            } else {
                edit = nil
            }
            guard let edit else { return true }
            apply(edit, to: view)
            return false
        }

        // MARK: Writing Tools

        /// The markers of the item lines in what Writing Tools is about to
        /// rewrite. iOS leaves these ranges as they are, so a rewritten
        /// checklist is still a checklist.
        @available(iOS 18.0, *)
        func textView(_ view: UITextView,
                      writingToolsIgnoredRangesInEnclosingRange enclosingRange: NSRange) -> [NSValue] {
            Checklist.markerRanges(in: view.text, within: enclosingRange).map { NSValue(range: $0) }
        }

        @available(iOS 18.0, *)
        func textViewWritingToolsWillBegin(_ view: UITextView) {
            writingToolsActive = true
        }

        /// The rewrite is in the text now: style it and save it.
        @available(iOS 18.0, *)
        func textViewWritingToolsDidEnd(_ view: UITextView) {
            writingToolsActive = false
            restyle(view)
            parent.text = view.text
        }

        // MARK: Commands

        func run(_ command: Command, on view: UITextView) {
            switch command {
            case .toggleItem:
                // The line under the cursor, or every line in a selection.
                apply(Checklist.toggleItems(in: view.text, selection: view.selectedRange), to: view)
                if !view.isFirstResponder { view.becomeFirstResponder() }
            case let .makeList(items, from):
                // The note may have been typed in while the model was
                // thinking; the list is only put in if it is still the note
                // the model was given, or the typing would be thrown away.
                guard Checklist.plainBody(of: view.text) == from else { return }
                // One replacement, so a shake takes the whole list back.
                apply(Checklist.replacingPlainBody(in: view.text, with: items), to: view)
            case let .addTitle(title):
                apply(Checklist.addingTitle(title, to: view.text), to: view)
            case let .tidy(lines, from):
                // As above: a line corrected by hand under the spinner is
                // not overwritten by the model's version of the old line.
                guard Checklist.bareLines(of: view.text) == from else { return }
                // The markers go back on line for line; if the text changed
                // under the spinner and the lines no longer match, nothing
                // happens, which is the safe outcome.
                if let text = Checklist.restoringMarkers(from: view.text, lines: lines) {
                    apply(Checklist.Edit(text: text, cursor: view.selectedRange.location), to: view)
                }
            case let .sortList(order, items):
                guard Checklist.items(of: view.text) == items,
                      let edit = Checklist.reordering(items: order, in: view.text) else { return }
                apply(edit, to: view)
            case let .cleaned(was, now):
                // The note is already open and already the user's. If they
                // have touched a character of it, the model's version is
                // out of date and is dropped rather than imposed.
                guard view.text == was else { return }
                // One replacement, so a shake takes the whole tidy back and
                // leaves the words as they were spoken.
                let cursor = min(view.selectedRange.location, (now as NSString).length)
                apply(Checklist.Edit(text: now, cursor: cursor), to: view)
            }
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? UITextView else { return }
            let point = gesture.location(in: view)
            guard let position = view.closestPosition(to: point) else { return }
            let offset = view.offset(from: view.beginningOfDocument, to: position)
            guard Checklist.isOnMarker(in: view.text, at: offset) else { return }
            // The text view also handles this tap and moves the cursor; wait
            // for it, then put the cursor after the marker on that line. The
            // tick is worked out after the wait, not before: the tap is also
            // what commits a pending autocorrection, and deciding beforehand
            // would apply a snapshot from before the correction.
            DispatchQueue.main.async { [weak self] in
                guard let self, Checklist.isOnMarker(in: view.text, at: offset) else { return }
                let line = Checklist.lineRange(in: view.text, at: offset)
                let edit = Checklist.toggleDone(in: view.text, at: offset)
                self.apply(Checklist.Edit(text: edit.text,
                                          cursor: line.location + Checklist.markerLength), to: view)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        // MARK: Helpers

        /// Applies a checklist edit as one replacement of the changed range,
        /// through `replace(_:withText:)`, so it lands on the text view's undo
        /// stack like typing does and a shake takes it back.
        private func apply(_ edit: Checklist.Edit, to view: UITextView) {
            let old = view.text ?? ""
            guard old != edit.text else {
                view.selectedRange = NSRange(location: edit.cursor, length: 0)
                return
            }
            let change = Checklist.difference(from: old, to: edit.text)
            if let start = view.position(from: view.beginningOfDocument, offset: change.range.location),
               let end = view.position(from: start, offset: change.range.length),
               let textRange = view.textRange(from: start, to: end) {
                view.replace(textRange, withText: change.replacement)
            } else {
                view.text = edit.text
            }
            restyle(view)
            let length = (view.text as NSString).length
            view.selectedRange = NSRange(location: min(edit.cursor, length), length: 0)
            parent.text = view.text
        }

        /// First line semibold, the rest regular, everything white with the
        /// spec's line height; on an item line the marker is hidden (the
        /// layout fragment draws a circle there) and a done item's text is
        /// muted. Edits the storage directly, which does not call back into
        /// `textViewDidChange`.
        func restyle(_ view: UITextView) {
            // Mid-composition, with a Japanese keyboard or dictation, the
            // clause being typed carries the system's own styling and the
            // selection belongs to the input method: setting either flattens
            // the candidate or commits it early.
            guard view.markedTextRange == nil else { return }
            let storage = view.textStorage
            let length = storage.length
            guard length > 0 else {
                view.typingAttributes = Style.attributes(semibold: true)
                return
            }
            let text = view.text ?? ""
            let ns = text as NSString
            let firstLine = Checklist.lineRange(in: text, at: 0)
            let selection = view.selectedRange
            storage.beginEditing()
            storage.setAttributes(Style.attributes(semibold: false),
                                  range: NSRange(location: 0, length: length))
            if firstLine.length > 0 {
                storage.addAttributes(Style.attributes(semibold: true), range: firstLine)
            }
            var index = 0
            while index < length {
                let line = Checklist.lineRange(in: text, at: index)
                let content = ns.substring(with: line)
                if Checklist.isItem(content) {
                    let font = storage.attribute(.font, at: line.location, effectiveRange: nil) as? UIFont ?? Style.body
                    storage.addAttributes(Style.markerAttributes(font: font),
                                          range: NSRange(location: line.location, length: 1))
                    if Checklist.isDone(content), line.length > Checklist.markerLength {
                        storage.addAttribute(.foregroundColor, value: Style.muted,
                                             range: NSRange(location: line.location + Checklist.markerLength,
                                                            length: line.length - Checklist.markerLength))
                    }
                }
                // Past this line and its break; a final empty line ends the loop.
                let next = ns.lineRange(for: NSRange(location: line.location, length: 0))
                if next.length == 0 { break }
                index = NSMaxRange(next)
            }
            storage.endEditing()
            // Only when it moved: reassigning it on every keystroke is one
            // of the ways an input method is made to commit early.
            if view.selectedRange != selection { view.selectedRange = selection }
            view.typingAttributes = Style.attributes(semibold: selection.location <= firstLine.length)
        }
    }
}

/// The layout fragment for an item line. Draws the paragraph as TextKit
/// would, then a circle over its marker: empty for an open item, filled with
/// a check for a done one, in white and muted. The marker character itself is
/// drawn clear by `restyle`, so only the circle shows; the text underneath is
/// unchanged, and so are taps, the cursor, and Writing Tools.
final class MarkerLayoutFragment: NSTextLayoutFragment {
    override func draw(at point: CGPoint, in context: CGContext) {
        super.draw(at: point, in: context)
        guard let paragraph = textElement as? NSTextParagraph,
              let line = textLineFragments.first else { return }
        let text = paragraph.attributedString
        guard text.length > 0, Checklist.isItem(text.string) else { return }
        let done = Checklist.isDone(text.string)
        let font = text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            ?? ChecklistTextView.Style.body
        let configuration = UIImage.SymbolConfiguration(pointSize: font.pointSize * 0.8, weight: .regular)
        guard let image = UIImage(systemName: done ? "checkmark.circle.fill" : "circle",
                                  withConfiguration: configuration)?
            .withTintColor(done ? ChecklistTextView.Style.muted : .white, renderingMode: .alwaysOriginal)
        else { return }
        // The marker is the first glyph of the first line. Sit the circle on
        // that glyph's baseline, centred on the cap height like a letter.
        let bounds = line.typographicBounds
        let baseline = point.y + bounds.minY + line.glyphOrigin.y
        let x = point.x + bounds.minX + line.glyphOrigin.x
        let y = baseline - font.capHeight / 2 - image.size.height / 2
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: x, y: y, width: image.size.width, height: image.size.height))
        UIGraphicsPopContext()
    }
}

/// Hiding the back button turns off the swipe-from-the-left-edge pop. The
/// editor hides the whole bar and draws its own, so put the gesture back.
///
/// The conformance has to be on the navigation controller, since it is the
/// delegate iOS asks. What it must not do is claim every navigation
/// controller in the process: a share sheet or a system picker brings its
/// own, and overriding `viewDidLoad` in an extension would take those too.
/// So the wiring is done by the editor, on the stack the editor is in.
extension UINavigationController: UIGestureRecognizerDelegate {
    /// The name matters: `gestureRecognizer(_:shouldBegin:)` is not in the
    /// protocol, so it was never called and the edge swipe was live on the
    /// list as well, where there is nothing to go back to.
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else { return true }
        return viewControllers.count > 1
    }
}

/// Puts the edge-swipe pop back on the stack this view is in, and nowhere
/// else. Nothing is drawn.
struct EdgeSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { Holder() }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    final class Holder: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            guard let navigation = parent?.navigationController else { return }
            navigation.interactivePopGestureRecognizer?.delegate = navigation
        }
    }
}
