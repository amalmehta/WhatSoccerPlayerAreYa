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
│   └── make-icon.swift           Draws Assets/AppIcon.png
├── Sources/
│   ├── SoccerCore/               All logic, no UI
│   │   ├── Models.swift          Player, Gender, Trait, PositionGroup, Era
│   │   ├── CSVParser.swift       CSV reader
│   │   ├── PlayerImporter.swift  CSV → players (own and FIFA formats), bundled loader
│   │   ├── Quiz.swift            The 12 questions and answers → Profile
│   │   ├── Matcher.swift         Profile × players → ranked matches
│   │   ├── Responses.swift       Saved responses, summary, CSV export
│   │   └── Resources/
│   │       └── players.csv       228 bundled players
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
├── Tests/
│   └── SoccerCoreTests/
│       └── SoccerCoreTests.swift 18 tests for the core logic
├── docs/
│   ├── INSTRUCTIONS.md           Setup, run, use
│   ├── SYSTEM-DESIGN.md          Architecture, flows, decisions, limits
│   ├── FILE-STRUCTURE.md         This file
│   └── screenshots/              Images used in the README
└── build/                        Built app (not committed)
```
