// Quiz, matching and CSV import for the website: a port of the Mac app's SoccerCore library.
// web/tests/core.test.mjs checks it against Tests/Fixtures/parity.json, written by the Swift tests,
// so both apps give the same answers.

export const TRAITS = ["pace", "shooting", "passing", "dribbling", "defending", "physical"];
export const TRAIT_NAMES = { pace: "Pace", shooting: "Shooting", passing: "Passing", dribbling: "Dribbling", defending: "Defending", physical: "Physical" };
/** What each slot means on a goalkeeper card. */
export const KEEPER_NAMES = { pace: "Diving", shooting: "Handling", passing: "Kicking", dribbling: "Reflexes", defending: "Speed", physical: "Positioning" };
export const TRAIT_ABBR = { pace: "PAC", shooting: "SHO", passing: "PAS", dribbling: "DRI", defending: "DEF", physical: "PHY" };

export const GROUPS = ["goalkeeper", "defender", "midfielder", "forward"];
export const GROUP_NAMES = { goalkeeper: "Goalkeeper", defender: "Defender", midfielder: "Midfielder", forward: "Forward" };
export const ERAS = ["Current", "Legend", "Imported"];
export const GENDERS = ["Men", "Women"];
export const GENDER_NAMES = { Men: "Men's", Women: "Women's" };

const GROUP_OF = {};
for (const p of ["GK"]) GROUP_OF[p] = "goalkeeper";
for (const p of ["CB", "LB", "RB", "LWB", "RWB", "SW", "LCB", "RCB", "DF", "D"]) GROUP_OF[p] = "defender";
for (const p of ["CDM", "CM", "CAM", "LM", "RM", "LCM", "RCM", "LDM", "RDM", "MF", "M"]) GROUP_OF[p] = "midfielder";
for (const p of ["ST", "CF", "LW", "RW", "LF", "RF", "LS", "RS", "FW", "F"]) GROUP_OF[p] = "forward";

/** Maps an EA-style position (ST, CB, CAM…) to its group, or null. */
export function groupOf(position) {
  return GROUP_OF[String(position).trim().toUpperCase()] ?? null;
}

export function playerGroup(player) {
  for (const p of player.positions) { const g = groupOf(p); if (g) return g; }
  return "midfielder";
}

export const isKeeper = (player) => playerGroup(player) === "goalkeeper";
export const traitName = (player, trait) => (isKeeper(player) ? KEEPER_NAMES : TRAIT_NAMES)[trait];
export const playerId = (p) => `${p.name}|${p.club}|${p.era}`;

/** Reads Men, Male, M, Women, Female, F, W… */
export function genderFrom(text) {
  const t = String(text ?? "").trim().toLowerCase();
  if (["men", "man", "male", "m", "men's", "mens"].includes(t)) return "Men";
  if (["women", "woman", "female", "f", "w", "women's", "womens"].includes(t)) return "Women";
  return null;
}

// MARK: CSV

/** RFC 4180 CSV: quoted fields, escaped quotes, newlines in quotes, CRLF, BOM. */
export function parseCSV(text) {
  const rows = [];
  let row = [], field = "", inQuotes = false, i = 0;
  const endRow = () => {
    row.push(field); field = "";
    if (!(row.length === 1 && row[0] === "")) rows.push(row);
    row = [];
  };
  if (text.charCodeAt(0) === 0xfeff) i = 1;
  for (; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') { field += '"'; i++; } else inQuotes = false;
      } else field += c;
      continue;
    }
    if (c === '"' && field === "") inQuotes = true;
    else if (c === ",") { row.push(field); field = ""; }
    else if (c === "\r") { if (text[i + 1] === "\n") i++; endRow(); }
    else if (c === "\n") endRow();
    else field += c;
  }
  if (field !== "" || row.length) endRow();
  return rows;
}

const ALIASES = {
  name: ["name", "short_name", "known_as", "common_name", "player", "player_name", "full name", "long_name"],
  nationality: ["nationality", "nationality_name", "nation", "country"],
  club: ["club", "club_name", "team", "team_name"],
  positions: ["positions", "player_positions", "position", "best_position", "best position", "pos"],
  alt_positions: ["alternative positions", "alternative_positions", "alt positions", "alt_positions", "other positions"],
  era: ["era"],
  gender: ["gender", "sex"],
  overall: ["overall", "ovr", "overall_rating", "overall rating", "rating"],
  pace: ["pace", "pac"],
  shooting: ["shooting", "sho"],
  passing: ["passing", "pas"],
  dribbling: ["dribbling", "dri"],
  defending: ["defending", "def"],
  physical: ["physical", "physic", "phy"],
  gk_diving: ["goalkeeping_diving", "gk_diving", "gk diving", "diving", "div"],
  gk_handling: ["goalkeeping_handling", "gk_handling", "gk handling", "handling", "han"],
  gk_kicking: ["goalkeeping_kicking", "gk_kicking", "gk kicking", "kicking", "kic"],
  gk_reflexes: ["goalkeeping_reflexes", "gk_reflexes", "gk reflexes", "reflexes", "ref"],
  // EA's keeper Speed is their sprint speed when an export has no separate keeper column.
  gk_speed: ["goalkeeping_speed", "gk_speed", "gk speed", "spd", "sprint speed", "sprint_speed", "movement_sprint_speed"],
  gk_positioning: ["goalkeeping_positioning", "gk_positioning", "gk positioning", "positioning_gk"],
};
const KEEPER_KEYS = ["gk_diving", "gk_handling", "gk_kicking", "gk_reflexes", "gk_speed", "gk_positioning"];

export class ImportError extends Error {}

const capitalized = (s) => s.toLowerCase().replace(/(^|\s)(\S)/g, (_, a, b) => a + b.toUpperCase());

/** CSV text → { players, skippedRows }. Reads the app's own format and FIFA / EA FC exports. */
export function loadPlayers(text, defaultEra = "Imported") {
  const rows = parseCSV(text);
  if (!rows.length) throw new ImportError("The file has no rows.");
  const header = rows[0].map((h) => h.trim().toLowerCase());
  const column = {};
  for (const [key, names] of Object.entries(ALIASES)) {
    for (const n of names) { const i = header.indexOf(n); if (i >= 0) { column[key] = i; break; } }
  }
  if (column.name === undefined) throw new ImportError("The file has no name column.");
  if (column.positions === undefined) throw new ImportError("The file has no position column.");
  const missing = TRAITS.find((t) => column[t] === undefined);
  if (missing) throw new ImportError(`The file has no ${missing} column.`);

  const players = [], seen = new Set();
  let skipped = 0;
  for (const row of rows.slice(1)) {
    const text = (key) => (column[key] !== undefined && column[key] < row.length ? row[column[key]].trim() : "");
    const number = (key) => {
      const base = (text(key).split(/[+-]/).find((s) => s !== "") ?? "").trim();
      if (!/^[0-9]+$/.test(base)) return null;
      const v = Number(base);
      return v >= 1 && v <= 99 ? v : null;
    };
    const name = text("name");
    const positions = [];
    for (const raw of [text("positions"), text("alt_positions")]) {
      for (const p of raw.split(/[,/; ]/).filter(Boolean)) {
        const code = p.toUpperCase();
        if (groupOf(code) && !positions.includes(code)) positions.push(code);
      }
    }
    if (!name || !positions.length) { skipped++; continue; }
    let traits = TRAITS.map(number).filter((v) => v !== null);
    if (groupOf(positions[0]) === "goalkeeper") {
      const keeper = KEEPER_KEYS.map(number).filter((v) => v !== null);
      if (keeper.length === 6) traits = keeper;
    }
    if (traits.length !== 6) { skipped++; continue; }
    const eraText = capitalized(text("era"));
    const era = ERAS.includes(eraText) ? eraText : defaultEra;
    const overall = number("overall") ?? Math.round(traits.reduce((a, b) => a + b, 0) / 6);
    const player = { name, nationality: text("nationality"), club: text("club"), positions, era, overall, traits, gender: genderFrom(text("gender")) };
    const id = playerId(player);
    if (seen.has(id)) { skipped++; continue; }
    seen.add(id);
    players.push(player);
  }
  if (!players.length) throw new ImportError("No rows had a name, a position and all six attributes.");
  return { players, skippedRows: skipped };
}

/** UTF-8 when valid; UTF-16 when the file starts with a byte-order mark (Excel's "Unicode text");
 *  otherwise Windows-1252, which older exports use, so accented names come through intact. */
export function decode(bytes) {
  const b = new Uint8Array(bytes);
  if (b[0] === 0xff && b[1] === 0xfe) return new TextDecoder("utf-16le").decode(b);
  if (b[0] === 0xfe && b[1] === 0xff) return new TextDecoder("utf-16be").decode(b);
  try { return new TextDecoder("utf-8", { fatal: true }).decode(b); }
  catch { return new TextDecoder("windows-1252").decode(b); }
}

// MARK: Quiz

export const QUESTIONS = [
  { id: "pitch", kind: "Playing style", prompt: "Five-a-side with friends. Where do you end up?", options: [
    { text: "Up front, waiting for the ball", traits: { shooting: 2 }, positions: { forward: 3 } },
    { text: "In the middle, touching it every play", traits: { passing: 2 }, positions: { midfielder: 3 } },
    { text: "At the back, keeping it tight", traits: { defending: 2 }, positions: { defender: 3 } },
    { text: "In goal — someone has to", traits: { physical: 1 }, positions: { goalkeeper: 3 } },
  ] },
  { id: "ball", kind: "Playing style", prompt: "The ball comes to you in space. First thought?", options: [
    { text: "Run at them", traits: { pace: 2, dribbling: 2 }, positions: { forward: 1 } },
    { text: "Pick out the perfect pass", traits: { passing: 3 }, positions: { midfielder: 1 } },
    { text: "Shoot from anywhere", traits: { shooting: 3 }, positions: { forward: 1 } },
    { text: "Keep it simple, recycle possession", traits: { passing: 1, defending: 1 }, positions: { defender: 1, midfielder: 1 } },
  ] },
  { id: "weapon", kind: "Playing style", prompt: "Pick your superpower.", options: [
    { text: "Blistering speed", traits: { pace: 3 }, positions: {} },
    { text: "Ice-cold finishing", traits: { shooting: 3 }, positions: {} },
    { text: "Seeing passes no one else sees", traits: { passing: 3 }, positions: {} },
    { text: "Ball glued to your feet", traits: { dribbling: 3 }, positions: {} },
    { text: "Reading the game, winning it back", traits: { defending: 3 }, positions: {} },
    { text: "Strength nobody can move", traits: { physical: 3 }, positions: {} },
  ] },
  { id: "duel", kind: "Playing style", prompt: "A big striker is bearing down on you. You…", options: [
    { text: "Time the slide tackle perfectly", traits: { defending: 3 }, positions: { defender: 2 } },
    { text: "Body them off the ball", traits: { physical: 3 }, positions: { defender: 1 } },
    { text: "Narrow the angle and spread yourself big", traits: { defending: 1, physical: 1 }, positions: { goalkeeper: 2 } },
    { text: "Chase them down — I'm quicker", traits: { pace: 3, defending: 1 }, positions: { defender: 1 } },
    { text: "Honestly? Hope someone else deals with it", traits: { shooting: 1, dribbling: 1 }, positions: { forward: 2 } },
  ] },
  { id: "goal", kind: "Playing style", prompt: "Your dream goal looks like…", options: [
    { text: "A 40-yard screamer into the top corner", traits: { shooting: 3, physical: 1 }, positions: {} },
    { text: "Beating four players and slotting it home", traits: { pace: 1, dribbling: 3 }, positions: {} },
    { text: "A tap-in after a perfect run", traits: { pace: 2, shooting: 2 }, positions: { forward: 1 } },
    { text: "A towering header from a corner", traits: { physical: 3 }, positions: { defender: 1 } },
    { text: "I'd rather make the assist", traits: { passing: 3 }, positions: { midfielder: 1 } },
  ] },
  { id: "fitness", kind: "Playing style", prompt: "Pre-season fitness tests. You're best at…", options: [
    { text: "The sprints", traits: { pace: 3 }, positions: {} },
    { text: "The long runs — I never stop", traits: { defending: 1, physical: 2 }, positions: { midfielder: 1 } },
    { text: "The gym — lifting heavy", traits: { physical: 3 }, positions: {} },
    { text: "The agility ladders", traits: { pace: 1, dribbling: 2 }, positions: {} },
  ] },
  { id: "captain", kind: "Personality", prompt: "In the dressing room, you're the one who…", options: [
    { text: "Gives the team talk", traits: { defending: 2, physical: 1 }, positions: { defender: 1 } },
    { text: "Controls the music and the mood", traits: { dribbling: 2 }, positions: { forward: 1 } },
    { text: "Studies the opponent on a tablet", traits: { passing: 2, defending: 1 }, positions: { midfielder: 1 } },
    { text: "Sits quietly, headphones on, focused", traits: { shooting: 2 }, positions: { goalkeeper: 1, forward: 1 } },
  ] },
  { id: "pressure", kind: "Personality", prompt: "Last minute, penalty to win the final. You…", options: [
    { text: "Grab the ball — it's mine", traits: { shooting: 3 }, positions: {} },
    { text: "Chip it down the middle, cheeky", traits: { shooting: 1, dribbling: 2 }, positions: {} },
    { text: "Let the designated taker do it and organise the rebound", traits: { passing: 1, defending: 1 }, positions: { defender: 1, midfielder: 1 } },
    { text: "Wish I was the keeper facing it", traits: { physical: 1 }, positions: { goalkeeper: 2 } },
  ] },
  { id: "style", kind: "Personality", prompt: "How would your friends describe you?", options: [
    { text: "A showman — style matters", traits: { dribbling: 3 }, positions: {} },
    { text: "The brains of the group", traits: { passing: 3 }, positions: { midfielder: 1 } },
    { text: "Reliable, steady, always there", traits: { defending: 3 }, positions: {} },
    { text: "Competitive to a fault", traits: { shooting: 1, physical: 2 }, positions: {} },
    { text: "Always in a hurry", traits: { pace: 3 }, positions: {} },
  ] },
  { id: "loss", kind: "Personality", prompt: "After a loss, you…", options: [
    { text: "Hit the gym that night", traits: { physical: 3 }, positions: {} },
    { text: "Rewatch the match and analyse it", traits: { passing: 2, defending: 1 }, positions: { midfielder: 1 } },
    { text: "Shake it off — next game I'll score two", traits: { pace: 1, shooting: 2 }, positions: {} },
    { text: "Blame the defence (quietly)", traits: { shooting: 1, dribbling: 1 }, positions: { forward: 1 } },
  ] },
  { id: "weekend", kind: "Personality", prompt: "Perfect day off?", options: [
    { text: "Chess, puzzles or a strategy game", traits: { passing: 3 }, positions: { midfielder: 1 } },
    { text: "Freestyle tricks in the park", traits: { dribbling: 3 }, positions: {} },
    { text: "A long run or a hike", traits: { pace: 1, physical: 2 }, positions: {} },
    { text: "Racing anything — karts, bikes, friends", traits: { pace: 3 }, positions: {} },
    { text: "Rest. Recovery is training too", traits: { defending: 1, physical: 1 }, positions: { goalkeeper: 1, defender: 1 } },
  ] },
  { id: "role", kind: "Personality", prompt: "Which job sounds most like you?", options: [
    { text: "Architect — designing how it all fits", traits: { passing: 3 }, positions: { midfielder: 2 } },
    { text: "Bodyguard — nobody gets past", traits: { defending: 3, physical: 1 }, positions: { defender: 2 } },
    { text: "Rock star — centre of the show", traits: { shooting: 2, dribbling: 2 }, positions: { forward: 2 } },
    { text: "Air-traffic controller — calm while chaos happens", traits: { passing: 1, physical: 1 }, positions: { goalkeeper: 2 } },
    { text: "Getaway driver — first off the mark", traits: { pace: 3 }, positions: { forward: 1 } },
  ] },
];

/** answers: { questionId: optionIndex } → { traits: [6 numbers 0–1], positions: { group: share } } */
export function profileFrom(answers, questions = QUESTIONS) {
  const traits = TRAITS.map(() => 0);
  const positions = {};
  for (const q of questions) {
    const index = answers[q.id];
    if (!Number.isInteger(index) || index < 0 || index >= q.options.length) continue;
    const option = q.options[index];
    for (const [t, amount] of Object.entries(option.traits)) traits[TRAITS.indexOf(t)] += amount;
    for (const [g, amount] of Object.entries(option.positions)) positions[g] = (positions[g] ?? 0) + amount;
  }
  const low = Math.min(...traits), high = Math.max(...traits);
  const scaled = high > low ? traits.map((v) => (v - low) / (high - low)) : traits.map(() => 0.5);
  const total = Object.values(positions).reduce((a, b) => a + b, 0);
  const shares = {};
  if (total > 0) for (const [g, v] of Object.entries(positions)) shares[g] = v / total;
  else for (const g of GROUPS) shares[g] = 0.25;
  return { traits: scaled, positions: shares };
}

/** The group with the biggest share; ties go to the first in GROUPS order. */
export function topPosition(profile) {
  let best = GROUPS[0];
  for (const g of GROUPS) if ((profile.positions[g] ?? 0) > (profile.positions[best] ?? 0)) best = g;
  return best;
}

// MARK: Matching

const SHAPE_WEIGHT = 0.60, POSITION_WEIGHT = 0.35, FAME_WEIGHT = 0.05;
/** How much a player's alternative positions count next to their best one. */
const ALTERNATIVE_POSITION_WEIGHT = 0.7;
/** Which of a person's traits stands in for each keeper slot (Diving, Handling, Kicking, Reflexes, Speed, Positioning). */
export const KEEPER_SOURCE = ["pace", "defending", "passing", "dribbling", "pace", "physical"];

function centered(v) {
  let sum = 0;
  for (const x of v) sum += x;
  const mean = sum / v.length;
  return v.map((x) => x - mean);
}

function cosine(a, b) {
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]; }
  const norms = Math.sqrt(na) * Math.sqrt(nb);
  return norms > 0 ? dot / norms : 0;
}

export const defaultFilter = () => ({ minimumOverall: 0, eras: [...ERAS], gender: null });

export function allows(filter, player) {
  return player.overall >= filter.minimumOverall && filter.eras.includes(player.era)
    && (!filter.gender || player.gender === filter.gender);
}

/** How well the player's positions suit where the person plays: the best position counts in full,
 *  alternatives at ALTERNATIVE_POSITION_WEIGHT. Squared so the position people lean towards clearly beats a close second. */
function positionFit(profile, player, bestShare) {
  if (!(bestShare > 0)) return 0;
  let fit = 0;
  player.positions.forEach((code, i) => {
    const group = groupOf(code);
    if (!group) return;
    const relative = (profile.positions[group] ?? 0) / bestShare;
    fit = Math.max(fit, (i === 0 ? 1 : ALTERNATIVE_POSITION_WEIGHT) * relative * relative);
  });
  return fit;
}

/** Every keeper card has a low Speed and high everything else, so raw keeper shapes are nearly identical.
 *  Comparing each keeper stat with the other keepers' (a z-score) brings out what makes each keeper different. */
function keeperScale(keepers) {
  if (keepers.length < 2) return (p) => p.traits;
  const means = [], deviations = [];
  for (let i = 0; i < TRAITS.length; i++) {
    let sum = 0;
    for (const k of keepers) sum += k.traits[i];
    const mean = sum / keepers.length;
    let squares = 0;
    for (const k of keepers) squares += (k.traits[i] - mean) * (k.traits[i] - mean);
    const sd = Math.sqrt(squares / keepers.length);
    means.push(mean);
    deviations.push(sd > 0 ? sd : 1);
  }
  return (p) => p.traits.map((v, i) => (v - means[i]) / deviations[i]);
}

function score(profile, player, bestShare, scaleKeeper) {
  const keeper = isKeeper(player);
  const personShape = keeper ? KEEPER_SOURCE.map((t) => profile.traits[TRAITS.indexOf(t)]) : profile.traits;
  const playerShape = keeper ? scaleKeeper(player) : player.traits;
  const shape = (cosine(centered(personShape), centered(playerShape)) + 1) / 2;
  const position = positionFit(profile, player, bestShare);
  const fame = Math.max(0, player.overall - 40) / 59;
  return SHAPE_WEIGHT * shape + POSITION_WEIGHT * position + FAME_WEIGHT * fame;
}

function sharedStrengths(profile, player) {
  if (isKeeper(player)) return [];
  const byValue = (values) => [...TRAITS].sort((a, b) => values[TRAITS.indexOf(b)] - values[TRAITS.indexOf(a)]);
  const mine = byValue(profile.traits).slice(0, 3);
  const theirs = new Set(byValue(player.traits).slice(0, 3));
  return mine.filter((t) => theirs.has(t));
}

/** Best-fitting players first: [{ player, score 0–100, sharedStrengths }]. */
export function rank(profile, players, filter = defaultFilter(), limit = 5) {
  const shares = Object.values(profile.positions);
  const bestShare = shares.length ? Math.max(...shares) : 1;
  const scaleKeeper = keeperScale(players.filter(isKeeper));
  return players
    .filter((p) => allows(filter, p))
    .map((player) => ({ player, s: score(profile, player, bestShare, scaleKeeper) }))
    .sort((a, b) => (a.s !== b.s ? b.s - a.s : a.player.name < b.player.name ? -1 : a.player.name > b.player.name ? 1 : 0))
    .slice(0, limit)
    .map(({ player, s }) => ({ player, score: Math.round(s * 100), sharedStrengths: sharedStrengths(profile, player) }));
}

// MARK: Responses

export function makeResponse(name, answers, profile, matches) {
  return {
    id: globalThis.crypto?.randomUUID?.() ?? String(Date.now() + Math.random()),
    date: new Date().toISOString(),
    name, answers, profile,
    matches: matches.map((m) => ({ name: m.player.name, club: m.player.club, positions: m.player.positions, score: m.score })),
  };
}

export const displayName = (r) => r.name || "Anonymous";

export function summarize(responses) {
  const counts = {};
  for (const r of responses) if (r.matches[0]) counts[r.matches[0].name] = (counts[r.matches[0].name] ?? 0) + 1;
  const topPlayers = Object.entries(counts).map(([name, count]) => ({ name, count }))
    .sort((a, b) => (a.count !== b.count ? b.count - a.count : a.name < b.name ? -1 : 1));
  const averageTraits = TRAITS.map((_, i) =>
    responses.length ? responses.reduce((s, r) => s + r.profile.traits[i], 0) / responses.length : 0);
  const positions = {};
  for (const r of responses) { const g = topPosition(r.profile); positions[g] = (positions[g] ?? 0) + 1; }
  return { total: responses.length, topPlayers, averageTraits, positions };
}

const escapeCSV = (s) => (/[",\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s);

/** Same columns as the Mac app's export. */
export function exportCSV(responses, questions = QUESTIONS) {
  const header = ["Date", "Name", "Top Match", "Club", "Score", "Runners-Up", "Top Position",
    ...TRAITS.map((t) => TRAIT_NAMES[t]), ...questions.map((q) => q.prompt)];
  const lines = [header.map(escapeCSV).join(",")];
  for (const r of [...responses].sort((a, b) => (a.date < b.date ? -1 : 1))) {
    const top = r.matches[0];
    const fields = [
      r.date.replace(/\.\d+Z$/, "Z"), displayName(r), top?.name ?? "", top?.club ?? "", top ? String(top.score) : "",
      r.matches.slice(1).map((m) => m.name).join("; "), GROUP_NAMES[topPosition(r.profile)],
      ...r.profile.traits.map((v) => v.toFixed(2)),
      ...questions.map((q) => q.options[r.answers[q.id]]?.text ?? ""),
    ];
    lines.push(fields.map(escapeCSV).join(","));
  }
  return lines.join("\n") + "\n";
}
