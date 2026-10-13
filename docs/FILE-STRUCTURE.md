# File Structure

```
WhatSoccerPlayerAreYa/
├── README.md                     What it is, screenshots, links
├── WhatSoccerPlayerAreYa.md      The project spec, with assumptions and changelog
├── Package.swift                 SwiftPM manifest: SoccerCore library, app, tests
├── Assets/
│   └── AppIcon.png               App icon (1024×1024), drawn by make-icon.swift
├── scripts/
│   ├── build-app.sh              Builds "build/What Soccer Player Are Ya.app" (and its .icns icon)
│   ├── make-icon.swift           Draws Assets/AppIcon.png
│   └── sync-web.sh               Copies players.csv and the icon into web/
├── Sources/
│   ├── SoccerCore/               All logic, no UI
│   │   ├── Models.swift          Player, Gender, Trait, PositionGroup, Era
│   │   ├── CSVParser.swift       CSV reader
│   │   ├── PlayerImporter.swift  CSV → players (own and FIFA formats), bundled loader
│   │   ├── Quiz.swift            The 12 questions and answers → Profile
│   │   ├── Matcher.swift         Profile × players → ranked matches
│   │   ├── Responses.swift       Saved responses, summary, CSV export
│   │   └── Resources/
│   │       └── players.csv       228 bundled players (EA FC 27 cards)
│   └── WhatSoccerPlayerAreYa/    The Mac app (SwiftUI)
│       ├── App.swift             App entry, menus, Settings scene, settings keys
│       ├── AppModel.swift        Shared state: players, responses, import, feedback
│       ├── ContentView.swift     Sidebar, toolbar (Upload, Settings), drop, ⌘V
│       ├── QuizView.swift        Quiz flow, result card, trait comparison
│       ├── ResultsView.swift     Summary tiles, charts, response table, export
│       ├── PlayersView.swift     Searchable, filterable player table
│       ├── SettingsView.swift    Quiz / Players / Data settings tabs
│       ├── FeedbackView.swift    Feedback sheet
│       └── Palette.swift         Category colours, chips
├── web/                          The website (static, no build step)
│   ├── index.html                Page shell, Settings and Feedback dialogs
│   ├── styles.css                Layout, light/dark themes, phone layout
│   ├── core.js                   Quiz, matching, CSV import (port of SoccerCore)
│   ├── app.js                    Pages, importing, settings, storage
│   ├── players.csv               Copy of the bundled players
│   ├── icon.png                  Copy of the app icon
│   └── tests/
│       └── core.test.mjs         Website tests, including parity with the Mac app
├── Tests/
│   ├── SoccerCoreTests/
│   │   ├── SoccerCoreTests.swift 18 tests for the core logic
│   │   ├── ParityTests.swift     Writes and checks Fixtures/parity.json
│   │   └── AccuracyTests.swift   Persona benchmark, position/trait balance, keeper matching
│   └── Fixtures/
│       ├── parity.json           Questions + 40 worked matches shared with web/tests
│       └── personas.json         How 30 well-known players would answer the quiz
├── .github/workflows/
│   └── website.yml               Tests the website, then deploys web/ to GitHub Pages
├── docs/
│   ├── INSTRUCTIONS.md           Setup, run, use
│   ├── SYSTEM-DESIGN.md          Architecture, flows, decisions, limits
│   ├── FILE-STRUCTURE.md         This file
│   ├── Player Data Sources.csv   Where each bundled player's ratings came from
│   └── screenshots/              Images used in the README
└── build/                        Built app (not committed)
```
