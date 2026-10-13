# Instructions

## Requirements

- macOS 14 or later
- Xcode 16 or later, or the Swift 6 command-line tools

## Build the app

```bash
./scripts/build-app.sh
```

This makes `build/What Soccer Player Are Ya.app`. Open it from Finder, or with:

```bash
open "build/What Soccer Player Are Ya.app"
```

To drag it into Applications, copy it from `build/`. It's signed for this Mac only (ad hoc), so on another Mac you'll need to right-click and choose Open the first time.

For development you can also run `swift run WhatSoccerPlayerAreYa`.

The app icon is drawn by `scripts/make-icon.swift`. To change it, edit that script, then redraw it and rebuild:

```bash
swift scripts/make-icon.swift && ./scripts/build-app.sh
```

## Run the tests

```bash
swift test
```

## Use it

**Take the Quiz.** Enter a name if you like, then answer 12 questions. Click an answer or press its number key (1–6). You can go back with **Back**. When you finish you'll see:

- your closest player and a match score
- the traits you share with that player
- your style next to theirs, trait by trait
- the next-closest players

Every finished quiz is saved automatically.

**Results.** This page summarises every saved response:

- how many responses there are
- the most common match and position
- a chart of top matches
- the average style
- where people play

The table at the bottom lists each response. Select rows and press Delete to remove them. Use **Export CSV…** in the toolbar to save all responses as a spreadsheet, one column per question. **Clear All…** deletes every response.

**Players.** Browse the players the quiz matches against. Search by name, club or nation, and filter by position or era. Click a column header to sort.

**Import more players.** Any of these imports a CSV of players:

- the **Upload** button in the toolbar, or File ▸ Import Players… (⌘O)
- dragging a CSV anywhere onto the window
- copying a CSV file in Finder, or copying CSV text, then pressing ⌘V in the app (outside a text field)

The app reads two kinds of CSV:

- **Its own format:** `name,nationality,club,positions,era,overall,pace,shooting,passing,dribbling,defending,physical`
- **FIFA / EA FC exports**, such as sofifa or Kaggle files. These use columns like `short_name`, `player_positions`, `overall`, `pace`, `shooting`, `passing`, `dribbling`, `defending`, `physic`, `club_name` and `nationality_name`. For goalkeepers it uses `goalkeeping_*` columns when the outfield ones are blank.

Rows missing a name, a position or one of the six attributes are skipped, and the app tells you how many it skipped. Imported players are tagged **Imported**, and they're kept between launches.

**Settings (⌘, or the gear button).**

- **Quiz:** whether to ask for a name, how many matches to show (1–10), and appearance (System, Light or Dark).
- **Players:** which eras to match against (Current, Legends, Imported) and the minimum overall rating. The default is 75, which keeps matches to well-known names. You can also turn off the bundled players, upload a CSV, or remove imported players.
- **Data:** where your data is stored, Show in Finder, and Export Responses.

**Feedback.** The small **Feedback** link at the bottom of the sidebar, or Help ▸ Send Feedback…, saves a note to `Feedback.json` on this Mac. Nothing is sent anywhere.

## Where data lives

`~/Library/Application Support/What Soccer Player Are Ya/` holds three files:

- `Responses.json`
- `Imported Players.json`
- `Feedback.json`

Set the `WSPAY_DATA_DIR` environment variable to use a different folder, for example for demos.

## Screenshot helpers

Two launch arguments help with taking screenshots:

- `-startSection results` (or `players`) opens the app on that page.
- `-demoResult YES` opens on a sample result. That result isn't saved.

`-sizedOnce NO` resets the window to its first-launch size (1200×780).
