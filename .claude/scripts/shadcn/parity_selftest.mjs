#!/usr/bin/env node
// Self-test of parity_run.mjs. No Rails, no React: two tiny HTTP servers play the "React" side (hash route,
// client rendered) and the "Phlex" side (path route, server rendered). Every scenario has a KNOWN expected
// outcome, so the runner is proven to (a) pass identical pages, (b) report each kind of difference, and
// (c) never let a broken render pass as a match.
//
//   cd <dir containing node_modules/playwright> && node /path/to/.claude/scripts/shadcn/parity_selftest.mjs
//   PARITY_CHROMIUM=/path/to/chromium   # when the cached browser revision differs from playwright's
//
// Exit 0 = every scenario behaved as expected. Prints a JSON summary. Skips (exit 0, status "skipped") when
// playwright is not installed in the current directory.

import http from "node:http";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const here = path.dirname(fileURLToPath(import.meta.url));
// Same variable and default as ShadcnLayout::STIMULUS_PREFIX (layout.rb).
const PREFIX = process.env.SHADCN_STIMULUS_PREFIX || "chadcn";
try {
  createRequire(path.join(process.cwd(), "package.json"))("playwright");
} catch {
  console.log(JSON.stringify({ status: "skipped", reason: "playwright is not installed in the current directory" }));
  process.exit(0);
}

const CSS = `
body{margin:0;padding:32px;font:16px/1.5 sans-serif}
[data-slot]{display:inline-block}
.btn{padding:8px 16px;background:#2563eb;color:#fff;border:1px solid transparent;border-radius:6px;cursor:pointer;transition:none}
.btn:focus-visible{outline:3px solid #f59e0b}
.wide{padding:8px 40px}
.on{background:#16a34a}
.themed{background:var(--c,#dddddd);padding:8px}
html.dark body{background:#111;color:#eee}
@keyframes scroll-fade{from{opacity:0}to{opacity:1}}
.scroll-driven{animation:scroll-fade linear both;animation-timeline:scroll()}
`;
const btn = (extra = "", cls = "btn") => `<button data-slot="probe" class="${cls}" ${extra}>Hi</button>`;
// A plain 200px box; the click handler is attached by script (an onclick ATTRIBUTE would differ between the sides and
// report ATTR whatever the click position). React side: data-side is "right" when the click lands past x=150, else "left"
// (a centre click is x=100). "Phlex" side with positionAware=false always says "left", so the sides differ ONLY if the
// runner really clicks at the requested position.
const POS_BOX = `<div data-slot="probe" class="btn" style="width:200px;padding:0">x</div>`;
const POS_JS = (positionAware) => `document.querySelector("[data-slot=probe]").addEventListener("click", (e) => { e.currentTarget.dataset.side = ${positionAware ? "e.offsetX > 150 ? 'right' : 'left'" : "'left'"}; })`;
const PLAIN = `<div data-slot="probe" class="btn" style="padding:4px">x</div>`;
// A click starts a timer; data-ready appears `ms` later. Starting at the click (not at page load) means the wait step is what
// separates "not yet" from "ready": a runner that ignores `wait` snapshots ~100ms after the click, before the 200ms timer fires.
const LATE_JS = (ms) => `const el = document.querySelector("[data-slot=probe]"); el.addEventListener("click", () => setTimeout(() => el.setAttribute("data-ready", "1"), ${ms}))`;
// mousedown -> data-phase=down; mouseup -> data-phase=up (only when handled)
const MOUSE_JS = (handlesUp) => `const el = document.querySelector("[data-slot=probe]"); el.addEventListener("mousedown", () => { el.dataset.phase = "down"; }); ${handlesUp ? 'el.addEventListener("mouseup", () => { el.dataset.phase = "up"; });' : ""}`;
const CTX_JS = (listens) => listens ? `const el = document.querySelector("[data-slot=probe]"); el.addEventListener("contextmenu", (e) => { e.preventDefault(); el.dataset.menu = "open"; })` : "";
const SELECT_BOX = `<select data-slot="native-select"><option data-slot="o" value="a">A</option><option data-slot="o" value="b">B</option></select>`;
const SELECT_BOX_ATTR = (i) => `<select data-slot="native-select"><option data-slot="o" value="a"${i === 0 ? " selected" : ""}>A</option><option data-slot="o" value="b"${i === 1 ? " selected" : ""}>B</option></select>`;
const SELECT_JS = (i) => `document.querySelectorAll("option")[${i}].selected = true`;
// Charts (dev/decisions/chart.md, "The G2 contract"): the numeric SVG attributes inside [data-slot=chart] compare number by number
// within 1e-3 px. The svg nodes carry no data-slot, so these scenarios `observe` them.
const chart = (attrs = 'd="M10,20L30.4,40" x="5" class="bar"', extra = "", rootSlot = "chart") =>
  `<div data-slot="${rootSlot}"><svg width="100" height="100"><path ${attrs}/>${extra}</svg></div>`;
const CHART_OBSERVE = ["svg path", "svg rect"];
const HOVER_BOX = `<div data-slot="probe" class="btn" style="width:200px;padding:0">x</div>`;
const HOVER_JS = (positionAware) => `document.querySelector("[data-slot=probe]").addEventListener("mousemove", (e) => { document.querySelector("[data-slot=probe]").dataset.side = ${positionAware ? "e.offsetX > 150 ? 'right' : 'left'" : "'left'"}; })`;
// Chrome sometimes leaves :hover stale under a still pointer after a DOM change (message-scroller's end button toggling `inert` after a
// click) and then repairs it only on the next mouse move; that race cannot be forced, so the React side fakes the outcome: its click handler
// forgets the hover (data-hot) and makes `:hover` report false until a mousemove arrives. The sides differ ONLY if the runner repeats the
// pointer move when the element under the pointer is not :hover.
const HOT_BOX = `<div data-slot="probe" class="btn" style="width:200px;padding:0">x</div>`;
const HOT_JS = (staleAfterClick) => `const el = document.querySelector("[data-slot=probe]"); el.addEventListener("mousemove", () => { el.dataset.hot = "1"; window.__stale = false; });
  ${staleAfterClick ? 'const matches = Element.prototype.matches; Element.prototype.matches = function (s) { return s === ":hover" && window.__stale ? false : matches.call(this, s); }; el.addEventListener("click", () => { el.dataset.hot = ""; window.__stale = true; });' : ""}`;
// A scroll-driven animation (animation-timeline: scroll()) has no document time: Chrome throws on `currentTime = ms`.
const SCROLL_DRIVEN = `<div data-slot="probe" class="btn scroll-driven">x</div>`;
const toggler = `onclick="this.dataset.state=this.dataset.state==='on'?'off':'on';this.classList.toggle('on')"`;

// html: [reactHtml, phlexHtml, optional phlexStatus, optional phlexScript]
const S = [
  { id: "identical", html: [btn(), btn()], expect: { pass: true } },
  { id: "extra-class", html: [btn(), btn("", "btn wide")], expect: { kinds: ["CLASS", "STYLE", "BOX"] } },
  { id: "attr-differs", html: [btn('aria-pressed="false"'), btn('aria-pressed="true"')], expect: { kinds: ["ATTR"] } },
  { id: "text-differs", html: [btn(), btn().replace(">Hi<", ">Hello<")], expect: { kinds: ["TEXT"] } },
  { id: "framework-noise-ignored", html: [btn(), btn(`id="x1" data-controller="${PREFIX}--probe" data-action="click->${PREFIX}--probe#go" data-${PREFIX}--probe-target="t" data-turbo-permanent`)], expect: { pass: true } },
  {
    id: "id-normalization",
    html: [
      `<span data-slot="l" id="radix-:r1:">Name</span><button data-slot="probe" class="btn" aria-labelledby="radix-:r1:">Hi</button>`,
      `<span data-slot="l" id="label-9">Name</span><button data-slot="probe" class="btn" aria-labelledby="label-9">Hi</button>`,
    ],
    expect: { pass: true },
  },
  {
    id: "unreferenced-ids-ignored",
    html: [
      `<i data-slot="n"></i><span data-slot="l" id="a">Name</span><button data-slot="probe" class="btn" aria-labelledby="a">Hi</button>`,
      `<i data-slot="n" id="noise-1"></i><span data-slot="l" id="b">Name</span><button data-slot="probe" class="btn" aria-labelledby="b" id="noise-2">Hi</button>`,
    ],
    expect: { pass: true },
  },
  {
    id: "id-relation-differs",
    html: [
      `<span data-slot="l" id="a">Name</span><button data-slot="probe" class="btn" aria-labelledby="a">Hi</button>`,
      `<span data-slot="l" id="a">Name</span><button data-slot="probe" class="btn" aria-labelledby="zzz">Hi</button>`,
    ],
    expect: { kinds: ["A11Y_REL"] },
  },
  { id: "click-same", steps: [{ do: "click", target: "[data-slot=probe]" }], html: [btn(toggler), btn(toggler)], expect: { pass: true } },
  { id: "click-missing-handler", steps: [{ do: "click", target: "[data-slot=probe]" }], html: [btn(toggler), btn()], expect: { kinds: ["ATTR", "CLASS", "STYLE"], step: "0:click" } },
  { id: "click-position-honored", steps: [{ do: "click", target: "[data-slot=probe]", position: { x: 180, y: 5 } }], html: [POS_BOX, POS_BOX], js: [POS_JS(true), POS_JS(true)], expect: { pass: true } },
  { id: "click-position-differs", steps: [{ do: "click", target: "[data-slot=probe]", position: { x: 180, y: 5 } }], html: [POS_BOX, POS_BOX], js: [POS_JS(true), POS_JS(false)], expect: { kinds: ["ATTR"], step: "0:click" } },
  { id: "wait-honored", steps: [{ do: "click", target: "[data-slot=probe]" }, { do: "wait", ms: 500 }], html: [PLAIN, PLAIN], js: [LATE_JS(200), LATE_JS(200)], expect: { pass: true } },
  { id: "wait-differs", steps: [{ do: "click", target: "[data-slot=probe]" }, { do: "wait", ms: 500 }], html: [PLAIN, PLAIN], js: [LATE_JS(200), LATE_JS(1500)], expect: { kinds: ["ATTR"], step: "1:wait" } },
  { id: "mouse-down-up-honored", steps: [{ do: "mousedown", target: "[data-slot=probe]" }, { do: "mouseup", target: "[data-slot=probe]" }], html: [PLAIN, PLAIN], js: [MOUSE_JS(true), MOUSE_JS(true)], expect: { pass: true } },
  { id: "mouse-up-missing", steps: [{ do: "mousedown", target: "[data-slot=probe]" }, { do: "mouseup", target: "[data-slot=probe]" }], html: [PLAIN, PLAIN], js: [MOUSE_JS(true), MOUSE_JS(false)], expect: { kinds: ["ATTR"], step: "1:mouseup" } },
  // Right click (context-menu opens on it). Only the React side listens for contextmenu, so the sides differ ONLY if the runner
  // really presses the right button; a runner that ignores `button` left-clicks, nothing fires, and the test notices.
  { id: "right-click-honored", steps: [{ do: "click", target: "[data-slot=probe]", button: "right" }], html: [PLAIN, PLAIN], js: [CTX_JS(true), CTX_JS(false)], expect: { kinds: ["ATTR"], step: "0:click" } },
  // React sets option.selected as a PROPERTY (no attribute); the port can only write the attribute. Same property = no diff.
  { id: "selected-property-same", html: [SELECT_BOX, SELECT_BOX_ATTR(1)], js: [SELECT_JS(1), ""], expect: { pass: true } },
  { id: "selected-property-differs", html: [SELECT_BOX, SELECT_BOX_ATTR(0)], js: [SELECT_JS(1), ""], expect: { kinds: ["PROP"] } },
  // --dx helpers: the harness renders the SAME tree through the DX helpers; the runner must pass the flag on and still compare to React.
  { id: "dx-helpers-differs", html: [btn(), btn()], dxHtml: btn("", "btn wide"), runnerArgs: ["--dx", "helpers"], expect: { kinds: ["CLASS"] } },
  { id: "dx-helpers-same", html: [btn(), btn()], dxHtml: btn(), runnerArgs: ["--dx", "helpers"], expect: { pass: true } },
  { id: "dx-not-requested", html: [btn(), btn()], dxHtml: btn("", "btn wide"), expect: { pass: true } },
  { id: "tab-same", steps: [{ do: "tab" }], html: [btn(), btn()], expect: { pass: true } },
  { id: "tab-not-focusable", steps: [{ do: "tab" }], html: [btn(), btn('tabindex="-1"')], expect: { kinds: ["FOCUS", "FOCUSED"], step: "0:tab" } },
  { id: "chart-numbers-equal", observe: CHART_OBSERVE, html: [chart(), chart()], expect: { pass: true } },
  { id: "chart-number-within-tolerance", observe: CHART_OBSERVE, html: [chart(), chart('d="M10.0005,20L30.4004,40" x="5.0009" class="bar"')], expect: { pass: true } },
  { id: "chart-number-outside-tolerance", observe: CHART_OBSERVE, html: [chart(), chart('d="M10,20L30.402,40" x="5" class="bar"')], expect: { kinds: ["ATTR"] } },
  { id: "chart-text-between-numbers-exact", observe: CHART_OBSERVE, html: [chart(), chart('d="M10,20C30.4,40" x="5" class="bar"')], expect: { kinds: ["ATTR"] } },
  { id: "chart-number-count-differs", observe: CHART_OBSERVE, html: [chart(), chart('d="M10,20L30.4,40,1" x="5" class="bar"')], expect: { kinds: ["ATTR"] } },
  { id: "chart-attribute-outside-list-exact", observe: CHART_OBSERVE, html: [chart('d="M10,20" stroke-width="2" class="bar"'), chart('d="M10,20" stroke-width="2.0005" class="bar"')], expect: { kinds: ["ATTR"] } },
  { id: "chart-class-exact", observe: CHART_OBSERVE, html: [chart(), chart('d="M10,20L30.4,40" x="5" class="bar2"')], expect: { kinds: ["CLASS"] } },
  { id: "chart-style-lengths-tolerant", observe: CHART_OBSERVE, html: [chart('d="M1,1" style="left:10px;top:5px"'), chart('d="M1,1" style="left:10.0004px;top:5px"')], expect: { pass: true } },
  { id: "chart-style-text-exact", observe: CHART_OBSERVE, html: [chart('d="M1,1" style="left:10px"'), chart('d="M1,1" style="right:10px"')], expect: { kinds: ["ATTR"] } },
  { id: "chart-style-unitless-exact", observe: CHART_OBSERVE, html: [chart('d="M1,1" style="opacity:0.6"'), chart('d="M1,1" style="opacity:0.6005"')], expect: { kinds: ["ATTR"] } },
  { id: "chart-style-top-exact", observe: CHART_OBSERVE, html: [chart('d="M1,1" style="top:5px"'), chart('d="M1,1" style="top:5.0004px"')], expect: { kinds: ["ATTR"] } },
  { id: "chart-tooltip-content-moves-with-wrapper", observe: [".recharts-tooltip-wrapper *"], html: [`<div data-slot="chart"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper" style="position:absolute;left:0;top:0;transform:translate(10px, 20px)"><div class="w-1" style="position:absolute;left:3px;top:4px">x</div></div></div>`, `<div data-slot="chart"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper" style="position:absolute;left:0;top:0;transform:translate(90px, 20px)"><div class="w-1" style="position:absolute;left:3px;top:4px">x</div></div></div>`], expect: { pass: true } },
  { id: "chart-tooltip-content-compared", observe: [".recharts-tooltip-wrapper *"], html: [`<div data-slot="chart"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper" style="position:absolute;left:0;top:0;transform:translate(10px, 20px)"><div class="h-2.5 w-2.5" style="position:absolute;left:3px;top:4px">x</div></div></div>`, `<div data-slot="chart"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper" style="position:absolute;left:0;top:0;transform:translate(10px, 20px)"><div class="w-1" style="position:absolute;left:3px;top:4px">x</div></div></div>`], expect: { kinds: ["CLASS"] } },
  // The tolerance is for chart nodes only: the same drift on a node outside [data-slot=chart] is a difference.
  { id: "tolerance-only-inside-chart", observe: CHART_OBSERVE, html: [chart("", "", "other"), chart('d="M10.0005,20L30.4004,40"', "", "other")], expect: { kinds: ["ATTR"] } },
  { id: "chart-tooltip-position-not-compared", observe: ["svg path", ".recharts-tooltip-wrapper"], html: [`<div data-slot="chart"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper recharts-tooltip-wrapper-left" style="transform: translate(10px, 20px)"></div></div>`, `<div data-slot="chart"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper recharts-tooltip-wrapper-right" style="transform: translate(90px, 20px)"></div></div>`], expect: { pass: true } },
  { id: "tooltip-wrapper-outside-chart-compared", observe: ["svg path", ".recharts-tooltip-wrapper"], html: [`<div data-slot="other"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper" style="position:absolute;left:10px;top:20px"></div></div>`, `<div data-slot="other"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper" style="position:absolute;left:90px;top:20px"></div></div>`], expect: { kinds: ["BOX"] } },
  { id: "chart-tooltip-wrapper-opacity-compared", observe: ["svg path", ".recharts-tooltip-wrapper"], html: [`<div data-slot="chart"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper" style="opacity:1"></div></div>`, `<div data-slot="chart"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper" style="opacity:0"></div></div>`], expect: { kinds: ["STYLE"] } },
  { id: "chart-tooltip-wrapper-display-compared", observe: ["svg path", ".recharts-tooltip-wrapper"], html: [`<div data-slot="chart"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper" style="display:block"></div></div>`, `<div data-slot="chart"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper" style="display:none"></div></div>`], expect: { kinds: ["STYLE"] } },
  // The computed `transform` of a chart node follows its tolerant attribute (the browser reflects it into matrix(...)); outside a chart it is exact.
  { id: "chart-transform-within-tolerance", observe: ["svg path", "svg g"], html: [chart('d="M1,1"', '<g transform="translate(10, 20)"><rect width="5" height="5"/></g>'), chart('d="M1,1"', '<g transform="translate(10.0004, 20)"><rect width="5" height="5"/></g>')], expect: { pass: true } },
  { id: "chart-transform-outside-tolerance", observe: ["svg path", "svg g"], html: [chart('d="M1,1"', '<g transform="translate(10, 20)"><rect width="5" height="5"/></g>'), chart('d="M1,1"', '<g transform="translate(10.01, 20)"><rect width="5" height="5"/></g>')], expect: { kinds: ["ATTR"] } },
  { id: "transform-outside-chart-exact", observe: ["svg path", "svg g"], html: [chart('d="M1,1"', '<g transform="translate(10, 20)"><rect width="5" height="5"/></g>', "other"), chart('d="M1,1"', '<g transform="translate(10.0004, 20)"><rect width="5" height="5"/></g>', "other")], expect: { kinds: ["ATTR"] } },
  { id: "chart-tooltip-content-offset-differs", observe: [".recharts-tooltip-wrapper *"], html: [`<div data-slot="chart"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper" style="position:absolute;left:0;top:0"><div class="w-1" style="position:absolute;left:3px;top:4px">x</div></div></div>`, `<div data-slot="chart"><svg><path d="M1,1"/></svg><div class="recharts-tooltip-wrapper" style="position:absolute;left:50px;top:0"><div class="w-1" style="position:absolute;left:9px;top:4px">x</div></div></div>`], expect: { kinds: ["BOX"] } },
  { id: "chart-dropped-sign", observe: CHART_OBSERVE, html: [chart('d="M1,1" x="-0.0005"'), chart('d="M1,1" x="0.0005"')], expect: { kinds: ["ATTR"] } },
  { id: "hover-position-honored", steps: [{ do: "hover", target: "[data-slot=probe]", position: { x: 180, y: 5 } }], html: [HOVER_BOX, HOVER_BOX], js: [HOVER_JS(true), HOVER_JS(true)], expect: { pass: true } },
  { id: "hover-position-differs", steps: [{ do: "hover", target: "[data-slot=probe]", position: { x: 180, y: 5 } }], html: [HOVER_BOX, HOVER_BOX], js: [HOVER_JS(true), HOVER_JS(false)], expect: { kinds: ["ATTR"], step: "0:hover" } },
  { id: "hover-restored-after-stale", steps: [{ do: "hover", target: "[data-slot=probe]", position: { x: 20, y: 5 } }, { do: "click", target: "[data-slot=probe]", position: { x: 20, y: 5 } }], html: [HOT_BOX, HOT_BOX], js: [HOT_JS(true), HOT_JS(false)], expect: { pass: true } },
  { id: "scroll-driven-animation-ok", animations: true, html: [SCROLL_DRIVEN, SCROLL_DRIVEN], expect: { pass: true } },
  { id: "scroll-driven-animation-differs", animations: true, html: [SCROLL_DRIVEN, SCROLL_DRIVEN.replace("scroll-driven", "wide")], expect: { kinds: ["CLASS"] } },
  { id: "dark-same", dark: true, html: [btn(), btn()], expect: { pass: true } },
  { id: "hidden-differs", html: [btn(), btn('style="display:none"')], expect: { kinds: ["VISIBLE"] } },
  { id: "extra-node", html: [btn(), btn() + `<i data-slot="extra"></i>`], expect: { kinds: ["NODE_COUNT"] } },
  { id: "slot-order", html: [`<i data-slot="a"></i><i data-slot="b"></i>`, `<i data-slot="b"></i><i data-slot="a"></i>`], expect: { kinds: ["SLOT_ORDER"] } },
  { id: "theme-off", html: [`<div data-slot="probe" class="themed">x</div>`, `<div data-slot="probe" class="themed" style="background:#dddddd">x</div>`], expect: { pass: true } },
  { id: "theme-on", theme: "probe", html: [`<div data-slot="probe" class="themed">x</div>`, `<div data-slot="probe" class="themed" style="background:#dddddd">x</div>`], expect: { kinds: ["STYLE"] }, sameScenario: "theme-off" },
  { id: "phlex-js-error", html: [btn(), btn() + `<script>throw new Error("boom")</script>`], expect: { kinds: ["PHLEX_JS_ERROR"] } },
  // The holes this runner must not have: broken renders that would otherwise compare as equal.
  { id: "empty-both", html: ["", ""], expect: { kinds: ["EMPTY_RENDER"] } },
  { id: "parity-error-marker", html: [btn(), `<p data-parity-error>Unknown component Nope</p>`], expect: { kinds: ["PARITY_ERROR", "EMPTY_RENDER"] } },
  { id: "phlex-http-500", html: [btn(), `<h1>Internal Server Error</h1>`], status: 500, expect: { kinds: ["HTTP_STATUS", "EMPTY_RENDER"] } },
];

const reactPage = () => `<!doctype html><meta charset=utf-8><style>${CSS}</style><div id=root></div><script>
const T=${JSON.stringify(Object.fromEntries(S.map((s) => [s.id, s.html[0]])))};
const J=${JSON.stringify(Object.fromEntries(S.filter((s) => s.js).map((s) => [s.id, s.js[0]])))};
const id=location.hash.split("/").pop();document.getElementById("root").innerHTML=T[id]??"";if(J[id])new Function(J[id])();</script>`;

// `?dx=helpers` stands for "render the same tree through the DX helpers": a scenario may give a different (e.g. broken) dxHtml for it.
const phlexPage = (id, dx) => {
  const sc = S.find((s) => s.id === id);
  const body = dx === "helpers" && sc?.dxHtml ? sc.dxHtml : sc?.html[1];
  return sc ? `<!doctype html><meta charset=utf-8><style>${CSS}</style><div id=root>${body}</div>${sc.js ? `<script>${sc.js[1]}</script>` : ""}` : "";
};

const servers = [
  http.createServer((_req, res) => { res.setHeader("content-type", "text/html"); res.end(reactPage()); }),
  http.createServer((req, res) => {
    const url = new URL(req.url, "http://x");
    const id = decodeURIComponent(url.pathname.split("/").pop());
    const sc = S.find((s) => s.id === id);
    res.statusCode = sc?.status ?? 200;
    res.setHeader("content-type", "text/html");
    res.end(phlexPage(id, url.searchParams.get("dx")));
  }),
];
await Promise.all(servers.map((s) => new Promise((r) => s.listen(0, "127.0.0.1", r))));
const [reactUrl, phlexUrl] = servers.map((s) => `http://127.0.0.1:${s.address().port}`);

// Temp dir with the scenario file and a theme preset, passed to parity_run.mjs through --scenarios / --presets.
const root = fs.mkdtempSync(path.join(os.tmpdir(), "parity-selftest-"));
const scenariosDir = path.join(root, "scenarios");
const presetsDir = path.join(root, "presets");
fs.mkdirSync(scenariosDir, { recursive: true });
fs.mkdirSync(presetsDir, { recursive: true });
fs.writeFileSync(path.join(presetsDir, "probe.css"), ":root{--c:#ff0000}");
fs.writeFileSync(
  path.join(scenariosDir, "probe.json"),
  JSON.stringify({ component: "probe", scenarios: S.map(({ id, steps, dark, allowEmpty, observe, animations }) => ({ id, steps, dark, allowEmpty, observe, animations })) }),
);

const results = [];
for (const sc of S) {
  const args = [path.join(here, "parity_run.mjs"), "--component", "probe", "--react", reactUrl, "--phlex", phlexUrl, "--scenarios", scenariosDir, "--presets", presetsDir, "--servers", path.join(root, "servers.json"), "--only", sc.id];
  if (sc.theme) args.push("--theme", sc.theme);
  if (sc.runnerArgs) args.push(...sc.runnerArgs);
  // Async on purpose: the fixture servers live in THIS process, so a blocking spawn would deadlock the browser's requests.
  const run = await new Promise((resolve) => {
    const child = spawn("node", args, { cwd: process.cwd(), env: process.env });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    const timer = setTimeout(() => child.kill("SIGKILL"), 60000);
    child.on("close", (status) => { clearTimeout(timer); resolve({ status, stdout, stderr }); });
  });
  let report;
  try { report = JSON.parse(run.stdout); } catch { report = { pass: false, diffs: [{ kind: "UNPARSEABLE", detail: (run.stderr || run.stdout).slice(0, 200) }] }; }
  const kinds = [...new Set(report.diffs.map((d) => d.kind))];
  let ok;
  let why = "";
  if (sc.expect.pass) {
    ok = report.pass === true && run.status === 0;
    why = ok ? "" : `expected pass, got ${kinds.join(",")}`;
  } else {
    const missing = sc.expect.kinds.filter((k) => !kinds.includes(k));
    ok = report.pass === false && run.status === 1 && missing.length === 0;
    if (ok && sc.expect.step) ok = report.diffs.some((d) => String(d.step).startsWith(sc.expect.step));
    why = ok ? "" : `expected ${sc.expect.kinds.join(",")}${sc.expect.step ? ` at ${sc.expect.step}` : ""}, got ${kinds.join(",") || "pass"}`;
  }
  results.push({ id: sc.id, ok, kinds, why });
}

// The worker pool must not change the report: run the whole scenario file with 1 and with 4 workers and compare.
const full = (workers) => new Promise((resolve) => {
  const child = spawn("node", [path.join(here, "parity_run.mjs"), "--component", "probe", "--react", reactUrl, "--phlex", phlexUrl, "--scenarios", scenariosDir, "--presets", presetsDir, "--servers", path.join(root, "servers.json"), "--workers", String(workers), "--max", "10000"], { cwd: process.cwd(), env: process.env });
  let out = "";
  child.stdout.on("data", (d) => (out += d));
  child.on("close", () => { try { resolve(JSON.parse(out)); } catch { resolve(null); } });
});
const [one, four] = [await full(1), await full(4)];
const key = (r) => (r ? r.diffs.map((d) => `${d.scenario}|${d.kind}|${d.step ?? ""}|${d.at ?? ""}`).join("\n") : "unparseable");
if (!one || !four || key(one) !== key(four)) results.push({ id: "workers-1-vs-4", ok: false, kinds: [], why: `reports differ (1 worker: ${one?.total_diffs} diffs, 4 workers: ${four?.total_diffs} diffs)` });
else results.push({ id: "workers-1-vs-4", ok: true, kinds: [], why: "" });

servers.forEach((s) => s.close());
fs.rmSync(root, { recursive: true, force: true });
const failed = results.filter((r) => !r.ok);
if (process.env.SELFTEST_VERBOSE) for (const r of results) console.error(`${r.ok ? "ok  " : "FAIL"} ${r.id.padEnd(28)} kinds=${r.kinds.join(",") || "-"}`);
console.log(JSON.stringify({ status: failed.length ? "fail" : "pass", scenarios: results.length, failed: failed.map((r) => ({ id: r.id, why: r.why, kinds: r.kinds })) }, null, 2));
process.exit(failed.length ? 1 : 0);
