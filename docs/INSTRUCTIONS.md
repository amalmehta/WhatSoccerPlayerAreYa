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

## The website

The website lives in `web/`: plain HTML, CSS and JavaScript with no build step. It's published at https://amalmehta.github.io/WhatSoccerPlayerAreYa/ by the **Website** GitHub Actions workflow on every push to `main`. The workflow runs the website's tests first and only deploys if they pass.

To run it locally (it needs a web server, not a `file://` page, because it loads JavaScript modules and `players.csv`):

```bash
python3 -m http.server 8791 -d web
```

Then open http://localhost:8791.

To run the website's tests (Node 18 or later):

```bash
node --test web/tests/*.test.mjs
```

The website reads its own copies of the bundled players and the app icon. After changing either, copy them over:

```bash
./scripts/sync-web.sh
```

The website works like the Mac app, with a few differences:

- Responses, imported players, settings and feedback are kept in the visitor's browser (`localStorage`), not on a Mac.
- Settings open with the gear button, ⌘, on a Mac or Ctrl+, elsewhere.
- Feedback can be saved in the browser or opened as a pre-filled GitHub issue, which the visitor reviews before posting.
- Very large imports may be too big to keep in the browser. They still work for that visit, and the site says so.
- Screenshot helpers are URL parameters: `?section=results` (or `players`) and `?demo=1`.

## Use it

**Take the Quiz.** Enter a name if you like and pick who to be matched with (Men's & Women's, Men's or Women's), then answer 12 questions. Click an answer or press its number key (1–6). You can go back with **Back**. When you finish you'll see:

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

**Players.** Browse the players the quiz matches against. Search by name, club or nation, and filter by position, era or game (men's or women's). Click a column header to sort.

**Import more players.** Any of these imports a CSV of players:

- the **Upload** button in the toolbar, or File ▸ Import Players… (⌘O)
- dragging a CSV anywhere onto the window
- copying a CSV file in Finder, or copying CSV text, then pressing ⌘V in the app (outside a text field)

The app reads two kinds of CSV:

- **Its own format:** `name,nationality,club,positions,era,overall,pace,shooting,passing,dribbling,defending,physical,gender`
- **FIFA / EA FC exports**, such as sofifa or Kaggle files. These use columns like:
  - `short_name`, `player_positions`, `overall`, `pace`, `shooting`, `passing`, `dribbling`, `defending`, `physic`, `club_name`, `nationality_name`
  - or EA FC's `Name`, `OVR`, `PAC`, `SHO`, `PAS`, `DRI`, `DEF`, `PHY`, `Position`, `Alternative positions`, `Team`, `Nation`

  For goalkeepers it uses the `goalkeeping_*` or `GK …` columns when the outfield ones are blank. If there's no keeper Speed column, it uses Sprint Speed. Alternative positions are added after the best position. Files can be UTF-8, UTF-16 (Excel's "Unicode text") or Windows-1252.

An optional `gender` (or `sex`) column marks men's and women's players. It accepts values like Men/Women, Male/Female or M/F. Players from a file without that column are only matched when the filter is set to Men's & Women's.

Rows missing a name, a position or one of the six attributes are skipped, and the app tells you how many it skipped. Imported players are tagged **Imported**, and they're kept between launches.

**Settings (⌘, or the gear button).**

- **Quiz:** whether to ask for a name, how many matches to show (1–10), and appearance (System, Light or Dark).
- **Players:** men's, women's or both (the same choice as on the quiz start screen), which eras to match against (Current, Legends, Imported) and the minimum overall rating. The default is 75, which keeps matches to well-known names. You can also turn off the bundled players, upload a CSV, or remove imported players.
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
