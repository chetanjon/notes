# Notes

Instructions for agents working in this repository. `README.md` says what
the app is and how to build it; `NOTES_APP_SPEC.md` is the spec it was
built from and wins on any question of behaviour.

## Git workflow

- Never commit directly to main.
- Create a branch for each unit of work (feat/*, fix/*, chore/*).
- Commit to the branch, push, then open a PR.
- Do not merge. Leave the PR open for me.
- "Merge it" is the only thing that authorises a merge. Not an approving
  comment, not "looks good", not silence on an open PR, and not my having
  asked for the work in the first place. When I say it, squash-merge,
  delete the branch, then `git checkout main && git pull`.

## The project

- `project.yml` is the source of truth. `xcodegen generate` writes the
  Xcode project, both Info.plists and both entitlements files; none of
  those is checked in.
- Version and build number live in `project.yml` (`MARKETING_VERSION`,
  `CURRENT_PROJECT_VERSION`), never in a plist.
- The app icon is drawn by `scripts/make-icon.py`. Change a number there
  and run it; never edit the PNG.
- Checklist, note-text and date logic is pure `String` code in
  `Notes/Logic/` with tests in `NotesTests/`. Keep it that way: it is the
  part that can be tested without a simulator.
- `PinStore.swift` and `PinnedNoteAttributes.swift` are compiled into the
  widget extension too. They must not import SwiftData or reference `Note`.
  `PinActivity.swift` starts Live Activities and is app-only: extensions
  cannot start them.
