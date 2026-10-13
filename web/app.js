import * as core from "./core.js";

// MARK: Storage (this browser only; every read and write is guarded)

const KEYS = { settings: "wspay.settings", responses: "wspay.responses", imported: "wspay.imported", feedback: "wspay.feedback" };
function load(key, fallback) {
  try { const v = localStorage.getItem(key); return v ? JSON.parse(v) : fallback; } catch { return fallback; }
}
function save(key, value) {
  try { localStorage.setItem(key, JSON.stringify(value)); return true; } catch { return false; }
}

const DEFAULT_SETTINGS = {
  askForName: true, matchCount: 5, minimumOverall: 75, includeCurrent: true, includeLegends: true,
  includeImported: true, useBundled: true, gender: "All", appearance: "System",
};

const state = {
  section: "quiz",
  settings: { ...DEFAULT_SETTINGS, ...load(KEYS.settings, {}) },
  bundled: [],
  imported: load(KEYS.imported, []),
  responses: load(KEYS.responses, []),
  quiz: { stage: "start", index: 0, answers: {}, name: "", result: null },
  players: { search: "", group: "", era: "", gender: "All", sort: "overall", asc: false, limit: 300 },
  results: { selected: new Set() },
};

// MARK: Colours — related categories share a hue family (same scheme as the Mac app's Palette)

const isDark = () => document.documentElement.dataset.theme === "dark"
  || (document.documentElement.dataset.theme !== "light" && matchMedia("(prefers-color-scheme: dark)").matches);

function hsb(h, s, b) {
  h = ((h % 1) + 1) % 1;
  const i = Math.floor(h * 6), f = h * 6 - i, p = b * (1 - s), q = b * (1 - f * s), t = b * (1 - (1 - f) * s);
  const [r, g, bl] = [[b, t, p], [q, b, p], [p, b, t], [p, q, b], [t, p, b], [b, p, q]][i % 6];
  return `rgb(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(bl * 255)})`;
}
const dynamic = (h, s, lb, db) => (isDark() ? hsb(h, s * 0.75, db) : hsb(h, s, lb));
const GROUP_HUE = { forward: 0.0, midfielder: 0.36, defender: 0.60, goalkeeper: 0.78 };
const SHADES = [[0.00, 0.85, 0.72, 0.95], [0.05, 0.70, 0.55, 0.80], [-0.04, 0.95, 0.45, 1.00], [0.09, 0.60, 0.65, 0.88]];
function shade(position) {
  const p = position.toUpperCase();
  if (["CF", "CM", "LB", "RB"].includes(p)) return 1;
  if (["LW", "RW", "LF", "RF", "CAM", "LWB", "RWB"].includes(p)) return 2;
  if (["LS", "RS", "LM", "RM"].includes(p)) return 3;
  return 0;
}
const positionColor = (p) => { const [d, s, lb, db] = SHADES[shade(p)]; return dynamic(GROUP_HUE[core.groupOf(p) ?? "midfielder"] + d, s, lb, db); };
const groupColor = (g) => dynamic(GROUP_HUE[g], 0.85, 0.72, 0.95);
const TRAIT_COLOR = {
  shooting: [0.0, 0.80, 0.78, 0.95], dribbling: [0.07, 0.85, 0.85, 1.0], pace: [0.12, 0.90, 0.80, 1.0],
  passing: [0.36, 0.75, 0.62, 0.85], defending: [0.58, 0.85, 0.75, 1.0], physical: [0.66, 0.65, 0.60, 0.90],
};
const traitColor = (t) => dynamic(...TRAIT_COLOR[t]);
const ERA_COLOR = { Current: [0.50, 0.80, 0.60, 0.85], Legend: [0.13, 0.85, 0.65, 0.95], Imported: [0.60, 0.15, 0.50, 0.75] };
const eraColor = (e) => dynamic(...ERA_COLOR[e]);

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const chip = (text, color) => `<span class="chip" style="color:${color};background:color-mix(in srgb, ${color} 16%, transparent)">${esc(text)}</span>`;
const positionChips = (ps) => `<span class="chips">${ps.map((p) => chip(p, positionColor(p))).join("")}</span>`;
const $ = (sel) => document.querySelector(sel);

// MARK: Player pool and filter

const allPlayers = () => [...(state.settings.useBundled ? state.bundled : []), ...state.imported];
function filter() {
  const s = state.settings;
  const eras = [];
  if (s.includeCurrent) eras.push("Current");
  if (s.includeLegends) eras.push("Legend");
  if (s.includeImported) eras.push("Imported");
  return { minimumOverall: Number(s.minimumOverall), eras, gender: s.gender === "All" ? null : s.gender };
}
const eligibleCount = () => { const f = filter(); return allPlayers().filter((p) => core.allows(f, p)).length; };

// MARK: Banner

let bannerTimer;
function banner(message, error = false) {
  const el = $("#banner");
  el.hidden = false;
  el.className = "banner" + (error ? " error" : "");
  el.innerHTML = `<span>${error ? "⚠︎" : "✓"}</span><span>${esc(message)}</span><button type="button">Dismiss</button>`;
  el.querySelector("button").onclick = () => (el.hidden = true);
  clearTimeout(bannerTimer);
  bannerTimer = setTimeout(() => (el.hidden = true), error ? 10000 : 6000);
}

// MARK: Navigation

const TITLES = { quiz: "Take the Quiz", results: "Results", players: "Players" };
function go(section) {
  state.section = section;
  render();
}

function render() {
  for (const b of document.querySelectorAll(".nav-item")) b.classList.toggle("active", b.dataset.section === state.section);
  $("#title").textContent = TITLES[state.section];
  document.title = `${TITLES[state.section]} · What Soccer Player Are Ya`;
  $("#section-actions").innerHTML = "";
  ({ quiz: renderQuiz, results: renderResults, players: renderPlayers })[state.section]();
}

// MARK: Quiz

function renderQuiz() {
  const q = state.quiz;
  const view = $("#view");
  if (q.stage === "start") {
    const n = eligibleCount();
    view.innerHTML = `<div class="page"><div class="start">
      <img src="icon.png" alt="">
      <h2>Which soccer player are you?</h2>
      <p>${core.QUESTIONS.length} quick questions about how you play and who you are. We'll match you against ${n.toLocaleString()} players.</p>
      ${state.settings.askForName ? `<input class="text-input" id="name" placeholder="Your name (optional)" value="${esc(q.name)}" autocomplete="off">` : ""}
      <div class="match-with"><span>Match me with</span>${genderSegmented("quiz-gender", state.settings.gender)}</div>
      <button class="btn primary big" id="start" ${n ? "" : "disabled"}>Start the Quiz</button>
      ${n ? "" : `<p class="warn">No players match your Settings. Loosen the filters or import players.</p>`}
    </div></div>`;
    $("#name")?.addEventListener("input", (e) => (q.name = e.target.value));
    $("#name")?.addEventListener("keydown", (e) => e.key === "Enter" && $("#start").click());
    for (const input of view.querySelectorAll('input[name="quiz-gender"]')) {
      input.onchange = () => { updateSettings({ gender: input.value }); renderQuiz(); };
    }
    $("#start").onclick = () => { q.answers = {}; q.index = 0; q.stage = "question"; renderQuiz(); };
    return;
  }
  if (q.stage === "question") {
    const question = core.QUESTIONS[q.index];
    const kindColor = question.kind === "Playing style" ? groupColor("forward") : groupColor("goalkeeper");
    view.innerHTML = `<div class="page">
      <div class="q-head">${chip(question.kind, kindColor)}<span>Question ${q.index + 1} of ${core.QUESTIONS.length}</span></div>
      <div class="progress"><div style="width:${(q.index / core.QUESTIONS.length) * 100}%"></div></div>
      <p class="q-prompt">${esc(question.prompt)}</p>
      <div class="options">${question.options.map((o, i) =>
        `<button class="option ${q.answers[question.id] === i ? "chosen" : ""}" data-i="${i}"><kbd>${i + 1}</kbd>${esc(o.text)}</button>`).join("")}</div>
      <div class="q-foot"><button class="btn" id="back">Back</button><span>Tip: press 1–${question.options.length} to answer</span></div>
    </div>`;
    for (const b of view.querySelectorAll(".option")) b.onclick = () => answer(Number(b.dataset.i));
    $("#back").onclick = () => { if (q.index === 0) q.stage = "start"; else q.index--; renderQuiz(); };
    return;
  }
  renderResult();
}

function genderSegmented(name, value) {
  const options = [["All", "Men's & Women's"], ["Men", "Men's"], ["Women", "Women's"]];
  return `<div class="segmented" role="radiogroup">${options.map(([v, label]) =>
    `<label><input type="radio" name="${name}" value="${v}" ${v === value ? "checked" : ""}><span>${label}</span></label>`).join("")}</div>`;
}

function answer(i) {
  const q = state.quiz;
  const question = core.QUESTIONS[q.index];
  if (i < 0 || i >= question.options.length) return;
  q.answers[question.id] = i;
  if (q.index + 1 < core.QUESTIONS.length) { q.index++; renderQuiz(); return; }
  const profile = core.profileFrom(q.answers);
  const matches = core.rank(profile, allPlayers(), filter(), Math.max(1, Number(state.settings.matchCount)));
  const response = core.makeResponse(q.name.trim(), { ...q.answers }, profile, matches);
  state.responses.push(response);
  if (!save(KEYS.responses, state.responses)) banner("Couldn't save this response — browser storage is full or blocked.", true);
  q.result = { profile, matches };
  q.stage = "result";
  renderQuiz();
  $("#view").scrollTop = 0;
}

function renderResult() {
  const { profile, matches } = state.quiz.result;
  const name = state.quiz.name.trim();
  const view = $("#view");
  const top = matches[0];
  if (!top) {
    view.innerHTML = `<div class="page"><div class="empty"><h2>No players to match</h2><p>Loosen the filters in Settings or import players.</p>
      <button class="btn primary" id="again">Take It Again</button></div></div>`;
    $("#again").onclick = restart;
    return;
  }
  const p = top.player;
  const lowHigh = [Math.min(...p.traits), Math.max(...p.traits)];
  const rel = (v) => (lowHigh[1] > lowHigh[0] ? (v - lowHigh[0]) / (lowHigh[1] - lowHigh[0]) : 0.5);
  const keeper = core.isKeeper(p);
  const list = new Intl.ListFormat("en", { type: "conjunction" });
  view.innerHTML = `<div class="page">
    <div class="hero">
      <div class="lead">${name ? `${esc(name)}, you're most like` : "You're most like"}</div>
      <div class="hero-name"><h2>${esc(p.name)}</h2><span class="pct">${top.score}% match</span></div>
      <div class="meta">${positionChips(p.positions)}${chip(p.era, eraColor(p.era))}<span>${esc([p.club, p.nationality].filter(Boolean).join(" · "))}</span></div>
      ${top.sharedStrengths.length ? `<div class="why">You both stand out for ${esc(list.format(top.sharedStrengths.map((t) => core.TRAIT_NAMES[t].toLowerCase())))}.</div>` : ""}
    </div>
    <h3>Your style vs ${esc(p.name)} <small>Bars show each side's relative strengths</small></h3>
    <div class="compare">${core.TRAITS.map((t, i) => {
      const mine = keeper ? profile.traits[core.TRAITS.indexOf(core.KEEPER_SOURCE[i])] : profile.traits[i];
      const color = traitColor(t);
      return `<div>${esc(core.traitName(p, t))}</div><div class="bars">
        <span>You</span><div class="track"><div style="width:${mine * 100}%;background:${color}"></div></div>
        <span>${p.traits[i]}</span><div class="track"><div style="width:${rel(p.traits[i]) * 100}%;background:${color};opacity:.45"></div></div>
      </div>`;
    }).join("")}</div>
    ${matches.length > 1 ? `<h3>Also a lot like</h3>${matches.slice(1).map((m) =>
      `<div class="runner"><strong>${esc(m.player.name)}</strong>${positionChips(m.player.positions.slice(0, 2))}<span class="club">${esc(m.player.club)}</span><span class="pct">${m.score}%</span></div>`).join("")}` : ""}
    <div class="actions"><button class="btn primary" id="again">Take It Again</button><button class="btn" id="see-all">See Everyone's Results</button></div>
  </div>`;
  $("#again").onclick = restart;
  $("#see-all").onclick = () => go("results");
}

function restart() {
  Object.assign(state.quiz, { stage: "start", index: 0, answers: {}, name: "", result: null });
  renderQuiz();
}

// MARK: Results

function renderResults() {
  const view = $("#view");
  const responses = state.responses;
  if (!responses.length) {
    view.innerHTML = `<div class="empty"><h2>No responses yet</h2><p>Each completed quiz is saved in this browser with a summary of everyone's answers.</p>
      <button class="btn primary" id="take">Take the Quiz</button></div>`;
    $("#take").onclick = () => go("quiz");
    return;
  }
  $("#section-actions").innerHTML = `<button class="btn" id="export" title="Save every response as a spreadsheet">Export CSV…</button>
    <button class="btn danger" id="clear" title="Delete every saved response">Clear All…</button>`;
  $("#export").onclick = exportResponses;
  $("#clear").onclick = () => {
    if (confirm(`Delete all ${responses.length} responses? This can't be undone. Export a CSV first if you want a copy.`)) {
      state.responses = []; save(KEYS.responses, []); renderResults();
    }
  };
  const s = core.summarize(responses);
  const topGroup = core.GROUPS.reduce((best, g) => ((s.positions[g] ?? 0) > (s.positions[best] ?? 0) ? g : best), core.GROUPS[0]);
  const maxTop = Math.max(1, ...s.topPlayers.map((x) => x.count));
  const maxPos = Math.max(1, ...Object.values(s.positions));
  const bar = (label, value, max, color, note) => `<div class="hbar"><div class="label"><span>${esc(label)}</span><span>${note}</span></div>
    <div class="track"><div style="width:${(value / max) * 100}%;background:${color}"></div></div></div>`;
  const sorted = [...responses].sort((a, b) => (a.date < b.date ? 1 : -1));
  const sel = state.results.selected;
  view.innerHTML = `<div class="page wide">
    <div class="tiles">
      <div class="tile"><small>Responses</small><div>${s.total.toLocaleString()}</div></div>
      <div class="tile"><small>Most common match</small><div>${s.topPlayers[0] ? `${esc(s.topPlayers[0].name)} (${s.topPlayers[0].count})` : "—"}</div></div>
      <div class="tile"><small>Most common position</small><div>${s.total ? core.GROUP_NAMES[topGroup] : "—"}</div></div>
    </div>
    <div class="charts">
      <div><h3>Top matches</h3>${s.topPlayers.slice(0, 10).map((x) => bar(x.name, x.count, maxTop, "var(--accent)", x.count)).join("")}</div>
      <div>
        <h3>Average style</h3>${core.TRAITS.map((t, i) => bar(core.TRAIT_NAMES[t], s.averageTraits[i], 1, traitColor(t), "")).join("")}
        <h3>Where people play</h3>${core.GROUPS.map((g) => bar(core.GROUP_NAMES[g], s.positions[g] ?? 0, maxPos, groupColor(g), s.positions[g] ?? 0)).join("")}
      </div>
    </div>
    <h3>Responses <small>Select rows, then press Delete or use the button</small></h3>
    <div class="row" style="margin-bottom:8px"><button class="btn danger" id="delete-selected" ${sel.size ? "" : "disabled"}>Delete Selected (${sel.size})</button></div>
    <div class="table-wrap"><table>
      <thead><tr><th></th><th>Date</th><th>Name</th><th>Top Match</th><th>Positions</th><th class="num">Score</th><th>Plays as</th></tr></thead>
      <tbody>${sorted.map((r) => {
        const top = r.matches[0];
        const g = core.topPosition(r.profile);
        return `<tr data-id="${esc(r.id)}" class="${sel.has(r.id) ? "selected" : ""}">
          <td><input type="checkbox" ${sel.has(r.id) ? "checked" : ""} aria-label="Select"></td>
          <td>${esc(new Date(r.date).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" }))}</td>
          <td>${esc(core.displayName(r))}</td><td>${esc(top?.name ?? "—")}</td>
          <td>${positionChips((top?.positions ?? []).slice(0, 2))}</td>
          <td class="num">${top ? top.score + "%" : "—"}</td><td>${chip(core.GROUP_NAMES[g], groupColor(g))}</td></tr>`;
      }).join("")}</tbody></table></div>
  </div>`;
  for (const tr of view.querySelectorAll("tbody tr")) {
    tr.querySelector("input").onchange = (e) => {
      if (e.target.checked) sel.add(tr.dataset.id); else sel.delete(tr.dataset.id);
      renderResults();
    };
  }
  $("#delete-selected").onclick = deleteSelected;
}

function deleteSelected() {
  const sel = state.results.selected;
  if (!sel.size) return;
  state.responses = state.responses.filter((r) => !sel.has(r.id));
  sel.clear();
  save(KEYS.responses, state.responses);
  renderResults();
}

function download(filename, text, type = "text/csv") {
  const url = URL.createObjectURL(new Blob([text], { type }));
  const a = Object.assign(document.createElement("a"), { href: url, download: filename });
  document.body.append(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function exportResponses() {
  if (!state.responses.length) return;
  download("Soccer Player Quiz Responses.csv", core.exportCSV(state.responses));
  banner(`Exported ${state.responses.length} responses.`);
}

// MARK: Players

function renderPlayers() {
  const view = $("#view");
  const ps = state.players;
  const all = allPlayers();
  if (!all.length) {
    view.innerHTML = `<div class="empty"><h2>No players</h2><p>Turn the bundled players back on in Settings, or upload a CSV. You can also drop a file anywhere on this page or paste it with ⌘V / Ctrl+V.</p>
      <button class="btn primary" id="empty-upload">Upload Players…</button></div>`;
    $("#empty-upload").onclick = () => $("#file-input").click();
    return;
  }
  if (state.imported.length) $("#section-actions").innerHTML = `<small style="color:var(--muted)">${state.imported.length.toLocaleString()} imported</small>`;
  const term = ps.search.trim().toLocaleLowerCase();
  const rows = all.filter((p) => (!ps.group || core.playerGroup(p) === ps.group) && (!ps.era || p.era === ps.era)
    && (ps.gender === "All" || p.gender === ps.gender)
    && (!term || [p.name, p.club, p.nationality].some((x) => x.toLocaleLowerCase().includes(term))));
  const key = (p) => (core.TRAITS.includes(ps.sort) ? p.traits[core.TRAITS.indexOf(ps.sort)] : p[ps.sort]);
  rows.sort((a, b) => {
    const x = key(a), y = key(b);
    const c = typeof x === "number" ? x - y : String(x).localeCompare(String(y));
    return ps.asc ? c : -c;
  });
  const th = (k, label, num = false) => `<th class="sortable ${num ? "num" : ""} ${ps.sort === k ? "sorted" + (ps.asc ? " asc" : "") : ""}" data-sort="${k}">${label}</th>`;
  const select = (id, value, options) => `<select id="${id}">${options.map(([v, l]) => `<option value="${v}" ${v === value ? "selected" : ""}>${l}</option>`).join("")}</select>`;
  view.innerHTML = `<div class="page wide">
    <div class="filters">
      <input type="search" id="search" placeholder="Name, club or nation" value="${esc(ps.search)}">
      ${select("f-group", ps.group, [["", "All positions"], ...core.GROUPS.map((g) => [g, core.GROUP_NAMES[g] + "s"])])}
      ${select("f-era", ps.era, [["", "All eras"], ...core.ERAS.map((e) => [e, e])])}
      ${select("f-gender", ps.gender, [["All", "Men's & Women's"], ["Men", "Men's"], ["Women", "Women's"]])}
      <span class="count">${rows.length.toLocaleString()} players</span>
    </div>
    <div class="table-wrap"><table>
      <thead><tr>${th("name", "Name")}<th>Positions</th>${th("club", "Club")}${th("nationality", "Nation")}<th>Era</th>${th("overall", "OVR", true)}
        ${core.TRAITS.map((t) => th(t, core.TRAIT_ABBR[t], true)).join("")}</tr></thead>
      <tbody>${rows.slice(0, ps.limit).map((p) => `<tr>
        <td><strong>${esc(p.name)}</strong></td><td>${positionChips(p.positions.slice(0, 3))}</td>
        <td>${esc(p.club)}</td><td>${esc(p.nationality)}</td><td>${chip(p.era, eraColor(p.era))}</td>
        <td class="num"><strong>${p.overall}</strong></td>
        ${core.TRAITS.map((t, i) => `<td class="num" title="${esc(core.traitName(p, t))}" ${p.traits[i] >= 85 ? `style="color:${traitColor(t)};font-weight:600"` : ""}>${p.traits[i]}</td>`).join("")}
      </tr>`).join("")}</tbody></table></div>
    ${rows.length > ps.limit ? `<div class="more"><button class="btn" id="more">Show more (${(rows.length - ps.limit).toLocaleString()} left)</button></div>` : ""}
  </div>`;
  const search = $("#search");
  search.oninput = () => { ps.search = search.value; ps.limit = 300; renderPlayers(); const s = $("#search"); s.focus(); s.setSelectionRange(s.value.length, s.value.length); };
  $("#f-group").onchange = (e) => { ps.group = e.target.value; renderPlayers(); };
  $("#f-era").onchange = (e) => { ps.era = e.target.value; renderPlayers(); };
  $("#f-gender").onchange = (e) => { ps.gender = e.target.value; renderPlayers(); };
  for (const h of view.querySelectorAll("th.sortable")) {
    h.onclick = () => {
      if (ps.sort === h.dataset.sort) ps.asc = !ps.asc;
      else { ps.sort = h.dataset.sort; ps.asc = ["name", "club", "nationality"].includes(ps.sort); }
      renderPlayers();
    };
  }
  $("#more")?.addEventListener("click", () => { ps.limit += 500; renderPlayers(); });
}

// MARK: Importing (Upload button, drop anywhere, paste)

function mergeImported(result, source) {
  const byId = new Map(state.imported.map((p) => [core.playerId(p), p]));
  for (const p of result.players) byId.set(core.playerId(p), p);
  state.imported = [...byId.values()].sort((a, b) => (a.overall !== b.overall ? b.overall - a.overall : a.name.localeCompare(b.name)));
  const kept = save(KEYS.imported, state.imported);
  let message = `Imported ${result.players.length.toLocaleString()} players from ${source}.`;
  if (result.skippedRows) message += ` Skipped ${result.skippedRows.toLocaleString()} incomplete rows.`;
  if (!kept) message += " They're too big to keep in this browser, so they'll be gone after you leave.";
  banner(message);
  go("players");
}

async function importFiles(files) {
  const csvs = [...files].filter((f) => /\.(csv|txt|tsv)$/i.test(f.name) || f.type === "text/csv" || f.type === "text/plain");
  if (!csvs.length) { banner("Drop a .csv file of players (FIFA / EA FC exports work).", true); return; }
  for (const file of csvs) {
    try { mergeImported(core.loadPlayers(core.decode(await file.arrayBuffer())), file.name); }
    catch (e) { banner(`Couldn't import ${file.name}: ${e.message}`, true); }
  }
}

function importText(text) {
  try { mergeImported(core.loadPlayers(text), "pasted text"); }
  catch (e) { banner(`The pasted text isn't a player CSV: ${e.message}`, true); }
}

function setUpImporting() {
  const input = $("#file-input");
  $("#upload").onclick = () => input.click();
  input.onchange = () => { importFiles(input.files); input.value = ""; };

  const overlay = $("#drop-overlay");
  let depth = 0;
  const hasFiles = (e) => [...(e.dataTransfer?.types ?? [])].includes("Files");
  addEventListener("dragenter", (e) => { if (hasFiles(e)) { depth++; overlay.hidden = false; e.preventDefault(); } });
  addEventListener("dragover", (e) => { if (hasFiles(e)) e.preventDefault(); });
  addEventListener("dragleave", (e) => { if (hasFiles(e) && --depth <= 0) { depth = 0; overlay.hidden = true; } });
  addEventListener("drop", (e) => {
    if (!hasFiles(e)) return;
    e.preventDefault(); depth = 0; overlay.hidden = true;
    importFiles(e.dataTransfer.files);
  });

  // ⌘V / Ctrl+V anywhere outside a text field: import copied CSV files or CSV text.
  document.addEventListener("paste", (e) => {
    const t = e.target;
    if (t instanceof HTMLInputElement || t instanceof HTMLTextAreaElement || t?.isContentEditable) return;
    const files = e.clipboardData?.files;
    if (files?.length) { e.preventDefault(); importFiles(files); return; }
    const text = e.clipboardData?.getData("text/plain") ?? "";
    if (text.includes(",") && text.includes("\n")) { e.preventDefault(); importText(text); }
  });
}

// MARK: Settings (⌘, / Ctrl+,)

function applyAppearance() {
  const a = state.settings.appearance;
  if (a === "System") delete document.documentElement.dataset.theme;
  else document.documentElement.dataset.theme = a.toLowerCase();
}

function updateSettings(changes) {
  Object.assign(state.settings, changes);
  save(KEYS.settings, state.settings);
  applyAppearance();
  refreshSettingsInfo();
}

function refreshSettingsInfo() {
  const form = $("#settings form");
  form.elements.minOut.value = state.settings.minimumOverall;
  $("#eligible").textContent = `${eligibleCount().toLocaleString()} players are eligible. A higher minimum keeps matches to well-known names. Choosing men's or women's only leaves out imported players whose file doesn't say which.`;
  $("#bundled-count").textContent = state.bundled.length;
  $("#imported-count").textContent = state.imported.length.toLocaleString();
  $("#response-count").textContent = state.responses.length.toLocaleString();
  $("#clear-imported").disabled = !state.imported.length;
  $("#settings-export").disabled = !state.responses.length;
}

function openSettings() {
  const dialog = $("#settings");
  const form = dialog.querySelector("form");
  for (const [k, v] of Object.entries(state.settings)) {
    const el = form.elements[k];
    if (!el) continue;
    if (el.type === "checkbox") el.checked = v; else el.value = v;
  }
  refreshSettingsInfo();
  if (!dialog.open) dialog.showModal();
}

function setUpSettings() {
  const dialog = $("#settings");
  const form = dialog.querySelector("form");
  form.addEventListener("input", (e) => {
    const el = e.target;
    if (!el.name || !(el.name in DEFAULT_SETTINGS)) return;
    let v = el.type === "checkbox" ? el.checked : el.value;
    if (el.name === "matchCount") v = Math.min(10, Math.max(1, Number(v) || 5));
    if (el.name === "minimumOverall") v = Number(v);
    updateSettings({ [el.name]: v });
  });
  dialog.addEventListener("close", render);
  $("#settings-open").onclick = openSettings;
  $("#settings-upload").onclick = () => $("#file-input").click();
  $("#settings-export").onclick = exportResponses;
  $("#clear-imported").onclick = () => {
    if (!confirm("Remove all imported players?")) return;
    state.imported = []; save(KEYS.imported, []); refreshSettingsInfo();
  };
}

// MARK: Feedback

const REPO = "https://github.com/amalmehta/WhatSoccerPlayerAreYa";
function setUpFeedback() {
  const dialog = $("#feedback");
  const form = $("#feedback-form");
  const message = () => form.elements.message.value.trim();
  const kind = () => form.elements.kind.value;
  const sync = () => { $("#feedback-save").disabled = $("#feedback-github").disabled = !message(); };
  form.elements.message.addEventListener("input", sync);
  $("#feedback-open").onclick = () => { form.reset(); sync(); dialog.showModal(); };
  $("#feedback-github").onclick = () => {
    const url = `${REPO}/issues/new?title=${encodeURIComponent(`${kind()}: ${message().slice(0, 60)}`)}&body=${encodeURIComponent(message())}`;
    window.open(url, "_blank", "noopener");
  };
  dialog.addEventListener("close", () => {
    if (dialog.returnValue !== "save" || !message()) return;
    const all = load(KEYS.feedback, []);
    all.push({ date: new Date().toISOString(), kind: kind(), message: message() });
    const ok = save(KEYS.feedback, all);
    banner(ok ? "Thanks — feedback saved in this browser." : "Couldn't save feedback in this browser.", !ok);
  });
}

// MARK: Keyboard

function setUpKeys() {
  addEventListener("keydown", (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === ",") { e.preventDefault(); openSettings(); return; }
    const t = e.target;
    const typing = t instanceof HTMLInputElement || t instanceof HTMLTextAreaElement || t instanceof HTMLSelectElement;
    if (typing || document.querySelector("dialog[open]") || e.metaKey || e.ctrlKey || e.altKey) return;
    if (state.section === "quiz" && state.quiz.stage === "question" && /^[1-9]$/.test(e.key)) { answer(Number(e.key) - 1); return; }
    if (state.section === "results" && (e.key === "Delete" || e.key === "Backspace") && state.results.selected.size) { e.preventDefault(); deleteSelected(); }
  });
}

// MARK: Start

async function start() {
  applyAppearance();
  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", render);
  for (const b of document.querySelectorAll(".nav-item")) b.onclick = () => go(b.dataset.section);
  setUpImporting();
  setUpSettings();
  setUpFeedback();
  setUpKeys();
  // Screenshot helpers: ?section=results|players, ?demo=1 shows a sample result without saving it.
  const params = new URLSearchParams(location.search);
  if (TITLES[params.get("section")]) state.section = params.get("section");
  try {
    const res = await fetch("players.csv");
    state.bundled = core.loadPlayers(await res.text(), "Current").players;
  } catch (e) {
    banner(`Couldn't load the bundled players: ${e.message}`, true);
  }
  if (params.get("demo") === "1") {
    const answers = { pitch: 0, ball: 0, weapon: 3, duel: 3, goal: 1, fitness: 3, captain: 1, pressure: 1, style: 0, loss: 2, weekend: 1, role: 2 };
    const profile = core.profileFrom(answers);
    Object.assign(state.quiz, { stage: "result", name: "Sam", answers, result: { profile, matches: core.rank(profile, allPlayers(), filter(), state.settings.matchCount) } });
  }
  render();
}

start();
