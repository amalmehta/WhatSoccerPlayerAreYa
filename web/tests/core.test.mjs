// Run: node --test web/tests
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import * as core from "../core.js";

const root = new URL("../../", import.meta.url);
const read = (path) => readFileSync(new URL(path, root), "utf8");
const fixture = JSON.parse(read("Tests/Fixtures/parity.json"));
const bundled = core.loadPlayers(read("web/players.csv"), "Current").players;

test("web/players.csv is the same file the Mac app bundles", () => {
  assert.equal(read("web/players.csv"), read("Sources/SoccerCore/Resources/players.csv"));
});

test("questions match the Mac app", () => {
  const strip = (qs) => qs.map((q) => ({
    id: q.id, kind: q.kind, prompt: q.prompt,
    options: q.options.map((o) => ({ text: o.text, traits: o.traits, positions: o.positions })),
  }));
  const sortKeys = (v) => JSON.parse(JSON.stringify(v, (k, x) =>
    x && typeof x === "object" && !Array.isArray(x) ? Object.fromEntries(Object.entries(x).sort()) : x));
  assert.deepEqual(sortKeys(strip(core.QUESTIONS)), sortKeys(fixture.questions));
});

test("profiles and matches match the Mac app for every fixture case", () => {
  assert.equal(fixture.cases.length, 40);
  for (const [i, c] of fixture.cases.entries()) {
    const profile = core.profileFrom(c.answers);
    for (const [j, v] of profile.traits.entries()) assert.ok(Math.abs(v - c.profile.traits[j]) < 1e-9, `case ${i} trait ${j}`);
    for (const g of core.GROUPS) {
      assert.ok(Math.abs((profile.positions[g] ?? 0) - (c.profile.positions[g] ?? 0)) < 1e-9, `case ${i} ${g}`);
    }
    const filter = {
      minimumOverall: c.filter.minimumOverall, eras: c.filter.eras,
      gender: c.filter.gender === "All" ? null : c.filter.gender,
    };
    const matches = core.rank(profile, bundled, filter, 5)
      .map((m) => ({ name: m.player.name, score: m.score, shared: m.sharedStrengths }));
    assert.deepEqual(matches, c.matches, `case ${i} (${c.filter.label})`);
  }
});

test("CSV parser handles quotes, newlines, BOM and CRLF", () => {
  const rows = core.parseCSV('﻿a,b,c\r\n"x, y","say ""hi""","line\nbreak"\n\n1,2,3');
  assert.deepEqual(rows, [["a", "b", "c"], ["x, y", 'say "hi"', "line\nbreak"], ["1", "2", "3"]]);
});

test("imports sofifa exports with keeper fallback, skips and gender", () => {
  const csv = [
    "sofifa_id,short_name,long_name,player_positions,overall,pace,shooting,passing,dribbling,defending,physic,goalkeeping_diving,goalkeeping_handling,goalkeeping_kicking,goalkeeping_reflexes,goalkeeping_speed,goalkeeping_positioning,club_name,nationality_name,gender",
    '1,K. De Bruyne,Kevin De Bruyne,"CM, CAM",91,76,86,93,88,64,78,15,13,5,10,,13,Manchester City,Belgium,M',
    "2,Alisson,Alisson Ramses Becker,GK,89,,,,,,,86,85,85,89,54,90,Liverpool,Brazil,",
    "3,,Nameless,ST,70,70,70,70,70,70,70,,,,,,,X,Y,",
    "4,Half Data,Half Data,ST,70,70,,70,70,70,70,,,,,,,X,Y,",
  ].join("\n");
  const r = core.loadPlayers(csv);
  assert.deepEqual(r.players.map((p) => p.name), ["K. De Bruyne", "Alisson"]);
  assert.equal(r.skippedRows, 2);
  assert.equal(r.players[0].era, "Imported");
  assert.equal(r.players[0].gender, "Men");
  assert.equal(r.players[1].gender, null);
  assert.deepEqual(r.players[1].traits, [86, 85, 85, 89, 54, 90]);
});

test("imports EA FC Kaggle exports with alternative positions and sprint-speed keeper fallback", () => {
  const csv = [
    "Name,OVR,PAC,SHO,PAS,DRI,DEF,PHY,Position,Alternative positions,Team,Nation,GK Diving,GK Handling,GK Kicking,GK Positioning,GK Reflexes,Sprint Speed",
    'Bukayo Saka,87,86,82,84,87,63,72,RW,"RM, LW",Arsenal,England,,,,,,88',
    "David Raya,86,,,,,,,GK,,Arsenal,Spain,86,82,90,85,88,47",
  ].join("\n");
  const r = core.loadPlayers(csv);
  assert.deepEqual(r.players.map((p) => p.name), ["Bukayo Saka", "David Raya"]);
  assert.deepEqual(r.players[0].positions, ["RW", "RM", "LW"]);
  assert.equal(r.players[0].club, "Arsenal");
  assert.equal(r.players[0].nationality, "England");
  assert.deepEqual(r.players[1].traits, [86, 82, 90, 88, 47, 85]);
});

test("decodes non-UTF-8 files", () => {
  assert.equal(core.decode(new Uint8Array([0x4e, 0x61, 0x6d, 0x65, 0x0a, 0x4d, 0xfc, 0x6c, 0x6c, 0x65, 0x72])), "Name\nMüller");
  const pele = [0xff, 0xfe, ...[..."Pelé"].flatMap((c) => [c.charCodeAt(0) & 0xff, c.charCodeAt(0) >> 8])];
  assert.equal(core.decode(new Uint8Array(pele)), "Pelé");
  assert.equal(core.decode(new TextEncoder().encode("Mbappé")), "Mbappé");
});

test("missing columns are reported", () => {
  assert.throws(() => core.loadPlayers("foo,bar\n1,2"), /no name column/);
  assert.throws(() => core.loadPlayers("name,position,pace\nA,ST,80"), /no shooting column/);
  assert.throws(() => core.loadPlayers(""), /no rows/);
});

test("summary and CSV export", () => {
  const p = bundled[0];
  const mk = (name, pitch) => core.makeResponse(name, { pitch }, core.profileFrom({ pitch }),
    [{ player: p, score: 90, sharedStrengths: [] }]);
  const responses = [mk('Smith, "Jo"', 0), mk("", 0), mk("Al", 2)];
  const s = core.summarize(responses);
  assert.equal(s.total, 3);
  assert.deepEqual(s.topPlayers, [{ name: p.name, count: 3 }]);
  assert.equal(s.positions.forward, 2);
  assert.equal(s.positions.defender, 1);
  const rows = core.parseCSV(core.exportCSV(responses));
  assert.equal(rows.length, 4);
  assert.ok(rows.some((r) => r[1] === 'Smith, "Jo"'));
  assert.ok(rows.some((r) => r[1] === "Anonymous"));
  assert.ok(rows.every((r) => r.length === rows[0].length));
});
