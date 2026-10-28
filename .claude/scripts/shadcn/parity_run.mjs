#!/usr/bin/env node
// Gates G2-G5 (DOM / style / behavior / theme parity) for the shadcn -> Phlex port.
//
// Renders every scenario of a component on BOTH catalogs (React = oracle, Phlex = port),
// replays the same interaction steps, snapshots after each step and diffs the snapshots.
//
//   cd <catalog dir> && node <repo>/.claude/scripts/shadcn/parity_run.mjs --component button
//   ... --theme slate       inject <presets dir>/slate.css into both pages (theme gate G4)
//   ... --dark              force .dark on <html> for every scenario
//   ... --shots DIR         also save side by side PNGs (artifact for humans, not a gate)
//   ... --only id1,id2      subset of scenario ids
//   ... --scenarios DIR / --presets DIR / --servers FILE   override the layout.rb defaults (SCENARIOS_DIR, PRESETS_DIR, SERVERS_FILE)
//   ... --dx helpers        ask the Phlex harness to render the same scenario tree through the yielded-root DX helpers
//                           (`table.header { ... }`) instead of the explicit nested classes; must match React just the same
//
// Charts: inside [data-slot="chart"] the numeric attributes of the SVG (NUMERIC_ATTR) and the pixel lengths left/bottom/width/height inside `style`
// are compared number by number within NUMERIC_TOLERANCE px, the text between the numbers exactly; everything else stays exact (dev/decisions/chart.md, "The G2 contract").
//
// Contract (see .ai/skills/shadcn-port/references/parity-gates.md):
//   React  : {REACT}/#/parity/<component>/<scenarioId>
//   Phlex  : {PHLEX}/design-system/parity/<component>/<scenarioId>
//   Scenarios: <scenarios dir>/<component>.json  (single source of truth for both sides)
// Failed renders never match: HTTP >= 400, [data-parity-error] and zero [data-slot] nodes (or, with a scenario `observe` list, zero observed nodes) are reported (PARITY_ERROR / HTTP_STATUS / EMPTY_RENDER).
// Output: JSON on stdout { component, pass, scenarios, diffs[] }; exit 1 when diffs exist.

import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const require = createRequire(path.join(process.cwd(), "package.json"));
const { chromium } = require("playwright");

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, a, i, all) => {
  if (a.startsWith("--")) acc.push([a.slice(2), all[i + 1]?.startsWith("--") || all[i + 1] === undefined ? true : all[i + 1]]);
  return acc;
}, []));
const component = args.component;
if (!component) { console.error("usage: --component NAME"); process.exit(2); }

const here = path.dirname(fileURLToPath(import.meta.url));
// Repo root: --root, else the root this script lives in. Every default path comes from layout.rb (the one place that knows them).
const ROOT = args.root ? path.resolve(process.cwd(), String(args.root)) : path.resolve(here, "../../..");
let layoutCache;
const layout = (key) => (layoutCache ??= JSON.parse(execFileSync("ruby", [path.join(here, "layout.rb"), "--json"], { encoding: "utf8" })))[key];
const resolveFlag = (flag, key) => (args[flag] && args[flag] !== true ? path.resolve(process.cwd(), String(args[flag])) : path.join(ROOT, layout(key)));
// Server URLs: --react/--phlex, then env, then the free ports servers.rb recorded, then the classic defaults.
const recorded = (() => { try { return JSON.parse(fs.readFileSync(resolveFlag("servers", "SERVERS_FILE"), "utf8")); } catch { return {}; } })();
const REACT = args.react || process.env.PARITY_REACT_URL || recorded.vite?.url || "http://localhost:5173";
const PHLEX = args.phlex || process.env.PARITY_PHLEX_URL || recorded.rails?.url || "http://localhost:3000";
const scenariosFile = path.join(resolveFlag("scenarios", "SCENARIOS_DIR"), `${component}.json`);
const spec = JSON.parse(fs.readFileSync(scenariosFile, "utf8"));
const only = args.only ? String(args.only).split(",") : null;
const themeCss = args.theme ? fs.readFileSync(path.join(resolveFlag("presets", "PRESETS_DIR"), `${args.theme}.css`), "utf8") : null;

const NO_MOTION = "*,*::before,*::after{animation:none!important;transition:none!important;caret-color:transparent!important}";
const STYLE_PROPS = [
  "display", "position", "color", "backgroundColor", "borderTopColor", "borderRightColor", "borderBottomColor", "borderLeftColor",
  "borderTopWidth", "borderRightWidth", "borderBottomWidth", "borderLeftWidth", "borderTopLeftRadius", "borderTopRightRadius",
  "borderBottomLeftRadius", "borderBottomRightRadius", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
  "marginTop", "marginRight", "marginBottom", "marginLeft", "fontFamily", "fontSize", "fontWeight", "lineHeight", "letterSpacing",
  "textAlign", "boxShadow", "opacity", "transform", "cursor", "pointerEvents", "overflow", "gap", "outlineColor", "outlineWidth",
  "outlineStyle", "zIndex", "flexDirection", "alignItems", "justifyContent", "whiteSpace", "textDecorationLine",
];
const WRAPPER_POSITION_STYLE = new Set(["transform"]);
// Attributes that legitimately differ between React/Radix and Rails/Stimulus and carry no contract.
// Same variable and default as ShadcnLayout::STIMULUS_PREFIX (layout.rb): keep them in sync.
const STIMULUS_PREFIX = (process.env.SHADCN_STIMULUS_PREFIX || "chadcn").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const IGNORED_ATTR = new RegExp(
  "^(class|style|id|for|selected|data-controller|data-action|data-turbo.*|data-.*-target|data-.*-value|data-.*-class|data-parity.*|aria-labelledby|aria-controls|aria-describedby|aria-owns|aria-activedescendant|tabindex-managed)$" +
  `|^data-${STIMULUS_PREFIX}--|^data-radix|^data-reactroot`
);

// G2 contract for charts (dev/decisions/chart.md): recharts and the Phlex port write the same SVG numbers through different float
// operation orders and path formatters, so these attributes (and the px lengths left/bottom/width/height inside `style`) may differ by up to 1e-3 px.
// Applies only to nodes inside [data-slot="chart"]; every other attribute and every other component compares exactly.
const NUMERIC_TOLERANCE = 1e-3;
const NUMERIC_ATTR = new Set(["d", "points", "x", "y", "width", "height", "transform", "x1", "x2", "y1", "y2", "cx", "cy", "r"]);
// Inside `style` only the contract's pixel lengths get the slack; every other declaration (opacity, top...) stays exact.
const STYLE_LENGTHS = new Set(["left", "bottom", "width", "height"]);
const PX_LENGTH = /^-?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?px$/i;
const NUMBER = /-?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?/gi;

// The text between the numbers must be identical and each number pair within the tolerance.
function numbersClose(a, b) {
  const [textsA, textsB] = [String(a).split(NUMBER), String(b).split(NUMBER)];
  if (textsA.length !== textsB.length || textsA.some((t, i) => t !== textsB[i])) return false;
  const [numsA, numsB] = [String(a).match(NUMBER) ?? [], String(b).match(NUMBER) ?? []];
  // 1e-9 is float-noise headroom so a difference of exactly the tolerance (0.0005 vs 0.0015) is not lost to binary rounding.
  // A sign flip is never noise: it passes only when both magnitudes are under half the tolerance (-0.0004 vs 0.0004).
  return numsA.every((n, i) => {
    const m = numsB[i];
    if (n.startsWith("-") !== m.startsWith("-") && !(Math.abs(Number(n)) < NUMERIC_TOLERANCE / 2 && Math.abs(Number(m)) < NUMERIC_TOLERANCE / 2)) return false;
    return Math.abs(Number(n) - Number(m)) <= NUMERIC_TOLERANCE + 1e-9;
  });
}

const declarations = (style) => String(style).split(";").map((d) => d.trim()).filter(Boolean).map((d) => {
  const i = d.indexOf(":");
  return [d.slice(0, i).trim(), d.slice(i + 1).trim()];
});

function styleClose(a, b) {
  const [da, db] = [declarations(a), declarations(b)];
  if (da.length !== db.length) return false;
  return da.every(([prop, value], i) => {
    const [propB, valueB] = db[i];
    if (prop !== propB) return false;
    return value === valueB || (STYLE_LENGTHS.has(prop) && PX_LENGTH.test(value) && PX_LENGTH.test(valueB) && numbersClose(value, valueB));
  });
}

function attrsSame(react, phlex, tolerant) {
  const keys = Object.keys(react).sort();
  if (!same(keys, Object.keys(phlex).sort())) return false;
  return keys.every((k) => react[k] === phlex[k] || (tolerant && (k === "style" ? styleClose(react[k], phlex[k]) : NUMERIC_ATTR.has(k) && numbersClose(react[k], phlex[k]))));
}

// Computed styles are strict, except `transform` on chart nodes: the contract's tolerant `transform` attribute is reflected by
// the browser into the computed matrix(...), so its numbers get the same slack (the tooltip wrapper pair skips transform earlier).
function styleSame(prop, a, b, tolerant) {
  return a === b || (tolerant && prop === "transform" && numbersClose(a, b));
}

async function snapshot(page, observe = []) {
  return page.evaluate(({ STYLE_PROPS, IGNORED_ATTR, observe }) => {
    const ignored = new RegExp(IGNORED_ATTR);
    const ids = new Map();
    const norm = (v) => (v == null ? v : v.split(/\s+/).map((t) => (ids.has(t) ? ids.get(t) : t)).join(" "));
    // Ids only matter through the relations that reference them, so number REFERENCED ids by first reference (DOM order).
    // An unreferenced id (or a different id string) must not register as a difference.
    const REF_ATTRS = ["aria-labelledby", "aria-controls", "aria-describedby", "aria-owns", "aria-activedescendant", "for"];
    document.querySelectorAll("*").forEach((el) => REF_ATTRS.forEach((a) => (el.getAttribute(a) ?? "").split(/\s+/).filter(Boolean).forEach((t) => { if (!ids.has(t)) ids.set(t, `#${ids.size + 1}`); })));
    const active = document.activeElement;
    // `observe` selectors (scenario key) add slot-less elements (e.g. an svg icon) to the compared nodes under the synthetic slot `observe:<selector>[<index>]`.
    const slotOf = new Map();
    const observed = [];
    observe.forEach((sel) => {
      let i = 0;
      document.querySelectorAll(sel).forEach((el) => {
        if (el.hasAttribute("data-slot") || slotOf.has(el)) return;
        slotOf.set(el, `observe:${sel}[${i++}]`);
        observed.push(el);
      });
    });
    const compared = observed.length ? [...document.querySelectorAll("[data-slot]"), ...observed].sort((a, b) => (a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1)) : [...document.querySelectorAll("[data-slot]")];
    const slotPath = (el) => (el && el !== document.body ? (el.closest("[data-slot]")?.getAttribute("data-slot") ?? slotOf.get(el) ?? el.tagName.toLowerCase()) : "body");
    const rel = (el, name) => { const v = el.getAttribute(name); return v ? norm(v) : null; };
    return {
      focus: slotPath(active),
      scrollLocked: getComputedStyle(document.body).overflow === "hidden" || document.body.hasAttribute("data-scroll-locked"),
      nodes: compared.map((el) => {
        const cs = getComputedStyle(el);
        const r = el.getBoundingClientRect();
        const attrs = {};
        for (const a of [...el.attributes].sort((x, y) => (x.name < y.name ? -1 : 1))) if (!ignored.test(a.name)) attrs[a.name] = a.value;
        // Chart nodes: `style` carries the pixel lengths (left, width...) and is compared with the numbers; the tooltip wrapper's
        // position is the controller's output, only its content is compared (dev/decisions/chart.md).
        const inChart = Boolean(el.closest('[data-slot="chart"]'));
        const tooltipWrapper = inChart && el.matches(".recharts-tooltip-wrapper");
        if (inChart && !tooltipWrapper && el.hasAttribute("style")) attrs.style = el.getAttribute("style");
        // Content inside a tooltip wrapper is measured from the wrapper's corner: its own placement is compared, the wrapper's is not.
        const wrapperEl = inChart && !tooltipWrapper ? el.closest(".recharts-tooltip-wrapper") : null;
        const origin = wrapperEl ? wrapperEl.getBoundingClientRect() : { x: 0, y: 0 };
        const classes = [...new Set(el.className?.baseVal === undefined ? el.className.split(/\s+/) : el.className.baseVal.split(/\s+/))].filter(Boolean).sort();
        return {
          inChart,
          tooltipWrapper,
          slot: el.getAttribute("data-slot") ?? slotOf.get(el),
          tag: el.tagName.toLowerCase(),
          classes: tooltipWrapper ? classes.filter((c) => !/^recharts-tooltip-wrapper-(left|right|top|bottom)$/.test(c)) : classes,
          attrs,
          rel: { labelledby: rel(el, "aria-labelledby"), controls: rel(el, "aria-controls"), describedby: rel(el, "aria-describedby"), owns: rel(el, "aria-owns"), activedescendant: rel(el, "aria-activedescendant"), for: rel(el, "for"), id: el.id ? (ids.get(el.id) ?? null) : null },
          text: [...el.childNodes].filter((n) => n.nodeType === 3).map((n) => n.textContent.trim()).filter(Boolean).join(" "),
          visible: el.checkVisibility?.({ checkOpacity: false, checkVisibilityCSS: true }) ?? true,
          focused: el === active,
          // React sets these as DOM properties, never as attributes; a server render can only write the attribute. Compare the property.
          props: el.tagName === "OPTION" ? { selected: el.selected } : el.tagName === "SELECT" ? { value: el.value } : {},
          box: [r.x - origin.x, r.y - origin.y, r.width, r.height].map((n) => Math.round(n * 2) / 2),
          style: Object.fromEntries(STYLE_PROPS.map((p) => [p, cs[p]])),
        };
      }),
    };
  }, { STYLE_PROPS, IGNORED_ATTR: IGNORED_ATTR.source, observe });
}

// animations: true scenarios: CSS animations/transitions are sampled at a LOGICAL time instead of wall-clock time, so both pages
// are compared at the same animation offset (see parity-gates.md, "Animation determinism"). `clock` is the sum of the `wait`
// steps so far; an animation is anchored at the clock value of the first snapshot that sees it. Seeked animations are paused for
// the snapshot and resumed after it (JS that waits for animationend, e.g. Radix Presence, keeps working); finished ones are finished.
async function withAnimationClock(page, sc, clock, take) {
  if (!sc.animations) return take();
  const seek = (now) => page.evaluate((now) => {
    const seen = (window.__parityAnim ??= new WeakMap());
    const held = (window.__parityHeld = []);
    for (const a of document.getAnimations()) {
      if (!(a instanceof CSSAnimation || a instanceof CSSTransition) || a.playState === "idle" || a.playState === "finished") continue;
      // Scroll/view-driven animations (animation-timeline: scroll()) have no time to seek: Chrome rejects currentTime for them
      // ("Invalid currentTime"). Their progress follows the scroll position, identical on both sides, so the computed styles are read as they are.
      // A null timeline (animation-timeline: none) is inactive on both sides and skipped too.
      if (!(a.timeline instanceof DocumentTimeline)) continue;
      if (!seen.has(a)) seen.set(a, now);
      const end = a.effect.getComputedTiming().endTime;
      const at = now - seen.get(a);
      if (at >= end) { a.finish(); continue; }
      a.pause();
      a.currentTime = at;
      held.push(a);
    }
  }, now);
  await seek(clock);
  try { return await take(); } finally { await page.evaluate(() => { (window.__parityHeld ?? []).forEach((a) => a.play()); window.__parityHeld = []; }); }
}

// Settle = quiescence before every snapshot, identical on both sides: macrotask turn (setTimeout(0) focus hops, Presence/mount effects),
// 2 rAF, macrotask turn again (work those frames scheduled). Real timers are NOT waited for; `wait` steps keep their meaning.
async function frames(page) {
  await page.evaluate(async () => {
    const turn = () => new Promise((r) => setTimeout(r, 0));
    await turn();
    await turn();
    await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
    await turn();
    await turn();
  });
}

// A real key press stays down for tens of ms, so setTimeout(0) hops started by keydown (roving focus, then arrow-select on focus while
// the arrow is still held) run BEFORE keyup. keyboard.press fires keyup immediately, racing those hops; hold the key for two
// macrotask turns instead (single keys only: chords keep Playwright's modifier handling).
async function pressKey(page, key) {
  if (key.includes("+") && key.length > 1) return page.keyboard.press(key);
  await page.keyboard.down(key);
  await page.evaluate(() => new Promise((r) => setTimeout(() => setTimeout(r, 0), 0)));
  await page.keyboard.up(key);
}

// Chrome refreshes :hover after a layout change only when it schedules a fake mouse move, which it skips for some DOM changes (an element
// under the pointer toggling `inert`): the same page then ends hovered on one side and not on the other. When the element under the last
// pointer position is not :hover, repeat a REAL move at that position: the page receives mousemove/pointermove (and boundary events) at an
// unchanged position, exactly what a user's next pointer jitter would deliver. When it is :hover, nothing is dispatched, so scenarios whose
// hover state is current see no extra pointer events. Hit-testing skips inert and pointer-events:none elements, so a page that genuinely
// does not hover is never "repaired". A step that leaves a button held (a bare mousedown) makes the repair move a drag move at the same position; it reaches the page only when :hover is stale, identically on both sides.
async function refreshHover(page) {
  const at = await page.evaluate(() => {
    const p = window.__parityPointer;
    const el = p && document.elementFromPoint(p.x, p.y);
    return el && !el.matches(":hover") ? p : null;
  });
  if (!at) return;
  await page.mouse.move(at.x, at.y);
  await frames(page);
}

function trackPointer() {
  const save = (e) => { window.__parityPointer = { x: e.clientX, y: e.clientY }; };
  for (const type of ["mousemove", "mousedown", "mouseup"]) window.addEventListener(type, save, true);
}

async function runStep(page, step) {
  const target = step.target ? page.locator(step.target).first() : null;
  switch (step.do) {
    case "click": /* force: disabled / pointer-events-none targets would time out in actionability; the browser still dispatches or suppresses events like for a user */ await target.click({ force: true, ...(step.position ? { position: step.position } : {}), ...(step.button ? { button: step.button } : {}) }); break; // button: "left"|"right"|"middle" (context-menu opens on a right click); position: {x, y} relative to the element's top-left
    case "wait": await page.waitForTimeout(step.ms); break; // real timers: Radix delays (100ms sub-open, 300ms grace, 1000ms typeahead reset)
    case "mousedown": if (target) await target.hover({ force: true, ...(step.position ? { position: step.position } : {}) }); await page.mouse.down(step.button ? { button: step.button } : {}); break;
    case "mouseup": if (target) await target.hover({ force: true, ...(step.position ? { position: step.position } : {}) }); await page.mouse.up(step.button ? { button: step.button } : {}); break; // press-drag-release selection
    case "dblclick": await target.dblclick({ force: true }); break;
    case "hover": await target.hover({ force: true, ...(step.position ? { position: step.position } : {}) }); break; // position: {x, y} relative to the element's top-left (a chart is hovered at a data position)
    case "focus": await target.focus(); break;
    case "fill": await target.fill(step.value ?? ""); break;
    case "press": await pressKey(page, step.key); break;
    case "type": await page.keyboard.type(step.text, { delay: 5 }); break;
    case "tab": await pressKey(page, step.shift ? "Shift+Tab" : "Tab"); break;
    case "viewport": await page.setViewportSize({ width: step.width, height: step.height ?? 800 }); break;
    case "snapshot": break;
    default: throw new Error(`unknown step ${step.do}`);
  }
  await frames(page);
  await refreshHover(page);
}

function installNoMotion(css) {
  const add = () => {
    if (!document.documentElement || document.getElementById("__parity-no-motion")) return !!document.documentElement;
    const el = document.createElement("style");
    el.id = "__parity-no-motion";
    el.textContent = css;
    document.documentElement.appendChild(el);
    return true;
  };
  if (add()) return;
  const obs = new MutationObserver(() => { if (add()) obs.disconnect(); });
  obs.observe(document, { childList: true });
}

// Dark class + theme CSS before any page script/first style computation, so no colour transition ever starts after load.
// Theme goes in adoptedStyleSheets: they sort after every document stylesheet, matching the old post-load <style> append.
function installTheme({ css, dark }) {
  try {
    if (css) {
      const sheet = new CSSStyleSheet();
      sheet.replaceSync(css);
      document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet];
    }
  } catch (_) { /* fallback: post-load style tag */ }
  if (!dark) return;
  const add = () => {
    if (!document.documentElement) return false;
    document.documentElement.classList.add("dark");
    return true;
  };
  if (add()) return;
  const obs = new MutationObserver(() => { if (add()) obs.disconnect(); });
  obs.observe(document, { childList: true });
}

async function capture(browser, base, urlPath, sc, side) {
  const ctx = await browser.newContext({ viewport: { width: sc.viewport?.width ?? 900, height: sc.viewport?.height ?? 700 }, deviceScaleFactor: 1, reducedMotion: "no-preference" });
  // Host-only `prefers-reduced-motion` rules must not make the two pages differ, so never emulate reduce; NO_MOTION goes in before any page script/layout.
  await ctx.addInitScript(installTheme, { css: themeCss, dark: Boolean(args.dark || sc.dark) });
  if (!sc.animations) await ctx.addInitScript(installNoMotion, NO_MOTION);
  await ctx.addInitScript(trackPointer);
  const page = await ctx.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e)));
  const response = await page.goto(`${base}${urlPath}`, { waitUntil: "networkidle" });
  const httpStatus = response ? response.status() : 0;
  if (!sc.animations) await page.addStyleTag({ content: NO_MOTION });
  if (themeCss && !(await page.evaluate(() => document.adoptedStyleSheets.length > 0))) await page.addStyleTag({ content: themeCss });
  if (args.dark || sc.dark) await page.evaluate(() => document.documentElement.classList.add("dark"));
  await page.evaluate(() => document.fonts?.ready);
  await frames(page);
  const parityError = await page.evaluate(() => document.querySelector("[data-parity-error]")?.textContent?.trim() ?? null);
  let clock = 0;
  const snaps = [{ step: "initial", ...(await withAnimationClock(page, sc, clock, () => snapshot(page, sc.observe))) }];
  for (const [i, step] of (sc.steps ?? []).entries()) {
    await runStep(page, step);
    if (step.do === "wait") clock += step.ms;
    if (step.snapshot === false) continue; // runs on both sides, compared by the next snapshot (see state-matrix.md)
    snaps.push({ step: `${i}:${step.do}${step.target ? `(${step.target})` : step.key ? `(${step.key})` : ""}`, ...(await withAnimationClock(page, sc, clock, () => snapshot(page, sc.observe))) });
  }
  if (args.shots) {
    fs.mkdirSync(args.shots, { recursive: true });
    await page.screenshot({ path: path.join(args.shots, `${component}__${sc.id}__${side}.png`), fullPage: true });
  }
  await ctx.close();
  return { snaps, errors, httpStatus, parityError };
}

// Key-order insensitive (attribute order differs between React and Phlex); values and array order still count.
const canon = (v) => (Array.isArray(v) ? v.map(canon) : v && typeof v === "object" ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, canon(v[k])])) : v);
const same = (a, b) => JSON.stringify(canon(a)) === JSON.stringify(canon(b));

function diffSnapshots(id, reactSnap, phlexSnap) {
  const out = [];
  const add = (kind, extra) => out.push({ scenario: id, step: reactSnap.step, kind, ...extra });
  if (reactSnap.focus !== phlexSnap.focus) add("FOCUS", { react: reactSnap.focus, phlex: phlexSnap.focus });
  if (reactSnap.scrollLocked !== phlexSnap.scrollLocked) add("SCROLL_LOCK", { react: reactSnap.scrollLocked, phlex: phlexSnap.scrollLocked });
  if (reactSnap.nodes.length !== phlexSnap.nodes.length) {
    add("NODE_COUNT", { react: reactSnap.nodes.map((n) => n.slot), phlex: phlexSnap.nodes.map((n) => n.slot) });
    return out;
  }
  reactSnap.nodes.forEach((rn, i) => {
    const pn = phlexSnap.nodes[i];
    const at = `${rn.slot}[${i}]`;
    if (rn.slot !== pn.slot) return add("SLOT_ORDER", { at, react: rn.slot, phlex: pn.slot });
    if (rn.tag !== pn.tag) add("TAG", { at, react: rn.tag, phlex: pn.tag });
    if (!same(rn.classes, pn.classes)) add("CLASS", { at, onlyReact: rn.classes.filter((c) => !pn.classes.includes(c)), onlyPhlex: pn.classes.filter((c) => !rn.classes.includes(c)) });
    if (!attrsSame(rn.attrs, pn.attrs, rn.inChart && pn.inChart)) add("ATTR", { at, react: rn.attrs, phlex: pn.attrs });
    if (!same(rn.props, pn.props)) add("PROP", { at, react: rn.props, phlex: pn.props });
    if (!same(rn.rel, pn.rel)) add("A11Y_REL", { at, react: rn.rel, phlex: pn.rel });
    if (rn.text !== pn.text) add("TEXT", { at, react: rn.text, phlex: pn.text });
    if (rn.visible !== pn.visible) add("VISIBLE", { at, react: rn.visible, phlex: pn.visible });
    if (rn.focused !== pn.focused) add("FOCUSED", { at, react: rn.focused, phlex: pn.focused });
    // A chart tooltip wrapper's position (box, computed transform) is the controller's output; every other property still compares.
    const wrapper = rn.tooltipWrapper && pn.tooltipWrapper;
    if (!wrapper && !same(rn.box, pn.box)) add("BOX", { at, react: rn.box, phlex: pn.box });
    const styleDiff = Object.keys(rn.style).filter((k) => !(wrapper && WRAPPER_POSITION_STYLE.has(k)) && !styleSame(k, rn.style[k], pn.style[k], rn.inChart && pn.inChart)).map((k) => ({ prop: k, react: rn.style[k], phlex: pn.style[k] }));
    if (styleDiff.length) add("STYLE", { at, props: styleDiff });
  });
  return out;
}

const browser = await chromium.launch(process.env.PARITY_CHROMIUM ? { executablePath: process.env.PARITY_CHROMIUM } : {});
const WORKERS = Math.max(1, Number(args.workers ?? 4)); // scenarios in flight at once (use --workers 1 for timing-sensitive reruns)
const todo = spec.scenarios.filter((s) => !only || only.includes(s.id));
const ran = todo.map((s) => s.id);

async function runScenario(sc) {
  const diffs = [];
  try {
    if (sc.observe !== undefined && !(Array.isArray(sc.observe) && sc.observe.length >= 1 && sc.observe.length <= 5 && sc.observe.every((o) => typeof o === "string" && o.trim() !== ""))) throw new Error(`observe of ${sc.id} must be an array of 1..5 non-empty CSS selector strings`);
    if (sc.steps?.at(-1)?.snapshot === false) throw new Error(`last step of ${sc.id} has snapshot:false; the scenario would compare nothing after it`);
    const [r, p] = await Promise.all([
      capture(browser, REACT, `/#/parity/${component}/${sc.id}`, sc, "react"),
      capture(browser, PHLEX, `/design-system/parity/${component}/${args["phlex-scenario"] ?? sc.id}${args.dx ? `?dx=${encodeURIComponent(args.dx)}` : ""}`, sc, "phlex"),
    ]);
    // A page that failed to render must never "match": both sides empty/erroring would otherwise compare equal.
    for (const [side, cap] of [["react", r], ["phlex", p]]) {
      if (cap.httpStatus >= 400) diffs.push({ scenario: sc.id, kind: "HTTP_STATUS", side, detail: String(cap.httpStatus) });
      if (cap.parityError) diffs.push({ scenario: sc.id, kind: "PARITY_ERROR", side, detail: cap.parityError.slice(0, 200) });
      if (!sc.allowEmpty && cap.snaps[0].nodes.length === 0) diffs.push({ scenario: sc.id, kind: "EMPTY_RENDER", side, detail: sc.observe ? "no [data-slot] or observed elements rendered" : "no [data-slot] elements rendered" });
    }
    r.errors.forEach((e) => diffs.push({ scenario: sc.id, kind: "REACT_PAGE_ERROR", detail: e }));
    p.errors.forEach((e) => diffs.push({ scenario: sc.id, kind: "PHLEX_JS_ERROR", detail: e }));
    r.snaps.forEach((rs, i) => diffs.push(...diffSnapshots(sc.id, rs, p.snaps[i])));
  } catch (e) {
    diffs.push({ scenario: sc.id, kind: "HARNESS_ERROR", detail: String(e).split("\n")[0] });
  }
  return diffs;
}

// Fixed-size pool; results are kept in scenario order so the report is identical for any --workers value.
const results = new Array(todo.length);
let cursor = 0;
await Promise.all(Array.from({ length: Math.min(WORKERS, todo.length) }, async () => {
  for (let i = cursor++; i < todo.length; i = cursor++) results[i] = await runScenario(todo[i]);
}));
const diffs = results.flat();
await browser.close();

const capped = diffs.slice(0, Number(args.max ?? 200));
console.log(JSON.stringify({ component, theme: args.theme ?? "default", dark: Boolean(args.dark), pass: diffs.length === 0, scenarios: ran, total_diffs: diffs.length, diffs: capped }, null, 2));
process.exit(diffs.length ? 1 : 0);
