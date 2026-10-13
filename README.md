<img src="Assets/AppIcon.png" width="96" alt="App icon">

# What Soccer Player Are Ya

A Mac app and website with a 12-question quiz that tells you which soccer player you play like. It saves every response and shows a summary of everyone's answers.

**[Take the quiz on the web →](https://amalmehta.github.io/WhatSoccerPlayerAreYa/)**

![Your match](docs/screenshots/Your%20Match.png)

| Kick off | Answer 12 questions (dark mode) |
|---|---|
| ![Welcome](docs/screenshots/Quiz.png) | ![Question](docs/screenshots/Question.png) |

| Everyone's results (dark mode) | The squad |
|---|---|
| ![Results](docs/screenshots/Results.png) | ![Players](docs/screenshots/Players.png) |

| The website | On a phone (dark mode) |
|---|---|
| ![Website](docs/screenshots/Website.png) | <img src="docs/screenshots/Website%20on%20a%20Phone.png" width="260" alt="Website on a phone"> |

```mermaid
flowchart LR
    Q[12 answers] --> P[Your style profile<br/>6 traits + position]
    D[(228 bundled players<br/>+ imported CSVs)] --> M{Matcher}
    P --> M --> R[Top match + runners-up]
    R --> S[(Saved responses)] --> X[Results summary · CSV export]
```

- [How to build, run and use it](docs/INSTRUCTIONS.md)
- [System design](docs/SYSTEM-DESIGN.md)
- [What's where](docs/FILE-STRUCTURE.md)
