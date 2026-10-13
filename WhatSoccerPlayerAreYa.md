PROJECT NAME: WhatSoccerPlayerAreYa

META-INSTRUCTIONS:

<Read it all before acting. Ask about anything unclear, contradictory or
 underspecified — before starting and mid-build. Ask in the question widget
 (AskUserQuestion): related questions batched, concrete options, your
 recommendation first. Plain text only if the widget isn't available.>

<Don't expand scope. Anything not listed here is a proposal, including changes
 to this file — propose it, don't do it.>

<Prefer doing over describing: run the code, write the files, test it.>

<Always in scope, no proposal needed: when it goes on GitHub, a README that is
 easy to read at a glance — a line on what it is, then clear visuals
 (screenshots, a diagram or a chart), then links. Everything else goes in
 linked files: docs/INSTRUCTIONS.md (setup, run, use),
 docs/SYSTEM-DESIGN.md (see below) and docs/FILE-STRUCTURE.md (what's where). If what you're
 building is an application rather than a script, also a small unobtrusive feedback tab, and a settings
 button or tab (⌘, on the Mac) that gathers its preferences in one place.>

<If what you're building is an application, build it as a Mac app first; the
 website comes after, as its own step.>

<When an application takes files as input, offer a visible Upload button that
 opens the file picker, accept files dragged anywhere onto the window (not
 only onto a small drop zone), and accept pasting them with ⌘V.>

<Color-code tags, categories and types by similarity: related ones share a
 hue family, with shades far enough apart to tell them apart at a glance, in
 both light and dark mode.>

<Name things the way a person would say them — "Goal Tracker", not
 goal_tracker — for the app, its windows, titles, files people open, repo
 descriptions and README headings. When you create the GitHub repo, name it
 with no "_" or "-": one word or joined words, e.g. GoalTracker.>

<Always in scope: a system design doc in the codebase, docs/SYSTEM-DESIGN.md,
 kept current as the build changes. Cover the architecture (with a Mermaid
 diagram), each component's job, the main flows, where data lives, the key
 design decisions and their trade-offs, how it's tested, and known limits.>

<Finish by listing every deliverable: path, what it is, how to check it works.>

<Git rules (no Claude attribution, never commit .claude/) are in
 ~/.claude/CLAUDE.md and apply on their own — nothing to repeat here.>

<Keep the changelog at the bottom current.>

CONTEXT:

Project type: Survey / form tool (collecting responses with questions and forms, and summarising the answers).

survey app to figure out what soccer player you resemble the best

DELIVERABLES:

mac app

OPEN QUESTIONS / ASSUMPTIONS:

Asked and answered (2026-10-12):
- Player pool: a large dataset. I recommended, and went ahead with, 228 bundled
  players (current and legends, men's and women's) plus importing any FIFA / EA FC
  CSV. A scraped third-party dataset wasn't bundled because its licence is unclear.
- Questions: a mix of playing style and personality (12 questions).
- Responses: saved on this Mac, with a Results summary and CSV export.
- GitHub: local git at first; on 2026-10-13 asked to create the repo and push.
  Created it private (no visibility was given): github.com/amalmehta/WhatSoccerPlayerAreYa

Decided without asking:
- Bundled ratings are approximate EA FC-style values compiled from memory (peak
  values for legends, clubs as of summer 2025), not official data.
- Matching compares the shape of the traits (which ones stand out), not absolute
  ratings, and weights position. Goalkeepers use a trait translation.
  Default minimum overall rating is 75 so matches are well-known names.
- Feedback is saved to a local file, not emailed.
- Men's / women's filter: one shared setting (quiz start screen and Settings).
  Imported players whose file has no gender column are left out unless
  matching against both.
- Built as a SwiftPM package plus a build script (no Xcode project). The app is
  ad hoc signed.
- Two screenshot-only launch arguments (-startSection, -demoResult) and a
  WSPAY_DATA_DIR override for demo data.
- The website version hasn't been started (it's its own later step).

Proposals (not done):
- The website version.

CHANGELOG:

- 2026-10-12 — created
- 2026-09-15 — added meta-instruction: built-out applications include a small feedback tab
- 2026-09-15 — added meta-instruction: no "Claude" attribution in commits, PRs, or branches
- 2026-09-16 — added meta-instruction: always include a README when adding to GitHub
- 2026-09-16 — changed meta-instruction: ask clarifying questions in the question widget
- 2026-09-17 — added meta-instructions: Claude never a contributor; never commit .claude/
- 2026-09-26 — compressed the meta-instructions and every field prompt; git rules moved to the global instruction file
- 2026-09-27 — added meta-instruction: applications are built as a Mac app first, then a website
- 2026-09-28 — folded inputs, instructions, constraints, deliverables and done criteria into one free-form CONTEXT
- 2026-09-28 — changed meta-instruction: a README on GitHub always includes a visual
- 2026-09-28 — added meta-instruction: name things like a person would, never snake_case
- 2026-09-28 — changed meta-instruction: README leads with visuals; instructions live in a linked guide
- 2026-09-28 — changed meta-instruction: README is visuals and links; details in docs/INSTRUCTIONS.md and docs/FILE-STRUCTURE.md
- 2026-09-29 — changed meta-instruction: GitHub repo names have no "_" or "-"
- 2026-10-02 — added a DELIVERABLES field after CONTEXT
- 2026-10-02 — added meta-instruction: every project has a system design doc at docs/SYSTEM-DESIGN.md
- 2026-10-05 — added meta-instruction: applications include a settings button or tab
- 2026-10-08 — added meta-instruction: color-code tags by similarity (related share a hue family, each distinct)
- 2026-10-09 — added meta-instruction: apps that take files have an Upload button, drop anywhere, and paste
- 2026-10-12 — built the Mac app: quiz, matching against 228 bundled players + CSV import, saved responses with summary and export, settings, feedback, docs
- 2026-10-13 — created the private GitHub repo WhatSoccerPlayerAreYa and pushed
- 2026-10-13 — added an app icon (soccer ball on a pitch with a "?" badge), drawn in code
- 2026-10-13 — added a men's / women's filter (quiz start screen, Settings, Players page) and a gender column in the player data
