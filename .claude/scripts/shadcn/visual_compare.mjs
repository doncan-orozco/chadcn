#!/usr/bin/env node
// Before/after comparison of the theme cutover on the REAL running app. Nothing in the repo changes: the app's
// tailwind stylesheet is intercepted and replaced by before.css / after.css (both built from the same sources).
//
//   cd <dir with node_modules/{playwright,pngjs,pixelmatch}> && node visual_compare.mjs \
//        --before before.css --after after.css [--base http://localhost:3000] [--out DIR] [--pages /en,/es] [--schemes light,dark] [--samples]
//
// Verdict (exit 1 when violated): layoutDiffs must be 0 on every page (nothing may move or resize), page errors must not
// appear after the cutover, and at most --max-pixels percent (default 2) of the pixels may change.
// Intended differences (zinc palette, radius derived from --radius) show up as colorDiffs / propDiffs, not as failures.
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
const require = createRequire(path.join(process.cwd(), "package.json"));
const { chromium } = require("playwright");
const { PNG } = require("pngjs");
const pixelmatch = (await import(require.resolve("pixelmatch"))).default;

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, a, i, all) => { if (a.startsWith("--")) acc.push([a.slice(2), all[i + 1]?.startsWith("--") || all[i + 1] === undefined ? true : all[i + 1]]); return acc; }, []));
if (!args.before || !args.after) { console.error("usage: --before before.css --after after.css"); process.exit(2); }
const BASE = args.base || "http://localhost:3000";
const layout = JSON.parse(execFileSync("ruby", [path.join(path.dirname(fileURLToPath(import.meta.url)), "layout.rb"), "--json"], { encoding: "utf8" }));
const DIR = path.resolve(args.out || path.join(layout.TMP_DIR, "_theme"));
const MAX_PIXELS = Number(args["max-pixels"] ?? 2);
const CSS = { before: fs.readFileSync(args.before, "utf8"), after: fs.readFileSync(args.after, "utf8") };
const PAGES = (args.pages ? String(args.pages).split(",") : ["/en", "/es", "/en/articles/art-of-slow-thinking", "/en/session/new", "/en/sign_up", "/en/about", "/design-system"]);
const SCHEMES = args.schemes ? String(args.schemes).split(",") : ["light", "dark"];
const COLOR_PROPS = ["color", "backgroundColor", "borderTopColor", "borderRightColor", "borderBottomColor", "borderLeftColor", "outlineColor", "fill", "stroke", "boxShadow"];
const LAYOUT_PROPS = ["fontSize", "fontWeight", "lineHeight", "paddingTop", "paddingLeft", "marginTop", "borderTopWidth", "borderTopLeftRadius", "display"];

async function capture(browser, url, scheme, which) {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 }, colorScheme: scheme, reducedMotion: "reduce" });
  const page = await ctx.newPage();
  const problems = [];
  page.on("pageerror", (e) => problems.push(`pageerror: ${String(e).slice(0, 120)}`));
  page.on("console", (m) => { if (m.type() === "error" && !/favicon|fonts\.g|net::ERR/.test(m.text())) problems.push(`console: ${m.text().slice(0, 120)}`); });
  await page.route("**/assets/tailwind-*.css", (r) => r.fulfill({ status: 200, contentType: "text/css", body: CSS[which] }));
  await page.route(/fonts\.(googleapis|gstatic)\.com/, (r) => r.abort()); // same (system) fonts both sides, no network flake
  const res = await page.goto(BASE + url, { waitUntil: "load" });
  await page.addStyleTag({ content: "*,*::before,*::after{animation:none!important;transition:none!important;scroll-behavior:auto!important}" });
  await page.waitForTimeout(250);
  const png = await page.screenshot({ fullPage: true });
  const dom = await page.evaluate(({ COLOR_PROPS, LAYOUT_PROPS }) => {
    const out = [];
    document.querySelectorAll("body, body *").forEach((el, i) => {
      if (["SCRIPT", "STYLE", "LINK", "META", "NOSCRIPT"].includes(el.tagName)) return;
      const r = el.getBoundingClientRect(); const cs = getComputedStyle(el);
      out.push({ i, tag: el.tagName.toLowerCase() + (el.className && typeof el.className === "string" ? "." + el.className.split(/\s+/).slice(0, 3).join(".") : ""),
        rect: [r.x, r.y, r.width, r.height].map((n) => Math.round(n * 2) / 2),
        color: Object.fromEntries(COLOR_PROPS.map((p) => [p, cs[p]])), layout: Object.fromEntries(LAYOUT_PROPS.map((p) => [p, cs[p]])) });
    });
    return { dark: document.documentElement.classList.contains("dark"), nodes: out };
  }, { COLOR_PROPS, LAYOUT_PROPS });
  await ctx.close();
  return { png, dom, status: res.status(), problems };
}

const browser = await chromium.launch();
const report = [];
fs.mkdirSync(`${DIR}/shots`, { recursive: true });
for (const url of PAGES) for (const scheme of SCHEMES) {
  const b = await capture(browser, url, scheme, "before");
  const a = await capture(browser, url, scheme, "after");
  const slug = `${url.replace(/\W+/g, "_")}__${scheme}`;
  const pb = PNG.sync.read(b.png), pa = PNG.sync.read(a.png);
  const w = Math.min(pb.width, pa.width), h = Math.min(pb.height, pa.height);
  const crop = (p) => { const o = new PNG({ width: w, height: h }); PNG.bitblt(p, o, 0, 0, w, h, 0, 0); return o; };
  const diff = new PNG({ width: w, height: h });
  const px = pixelmatch(crop(pb).data, crop(pa).data, diff.data, w, h, { threshold: 0.1 });
  fs.writeFileSync(`${DIR}/shots/${slug}__before.png`, b.png); fs.writeFileSync(`${DIR}/shots/${slug}__after.png`, a.png); fs.writeFileSync(`${DIR}/shots/${slug}__diff.png`, PNG.sync.write(diff));
  const propSamples = {}; let layoutDiffs = 0, layoutPropDiffs = 0, colorDiffs = 0; const colorSamples = {}; const layoutSamples = [];
  if (b.dom.nodes.length !== a.dom.nodes.length) layoutDiffs = Math.abs(b.dom.nodes.length - a.dom.nodes.length);
  b.dom.nodes.forEach((nb, k) => {
    const na = a.dom.nodes[k]; if (!na) return;
    if (nb.rect.some((v, j) => Math.abs(v - na.rect[j]) > 0.5)) { layoutDiffs++; if (layoutSamples.length < 4) layoutSamples.push(`${nb.tag}: ${nb.rect} -> ${na.rect}`); }
    for (const p of LAYOUT_PROPS) if (nb.layout[p] !== na.layout[p]) { layoutPropDiffs++; ((propSamples[p] ??= [])).length < 3 && propSamples[p].push(`${nb.tag.slice(0,40)}: ${nb.layout[p]} -> ${na.layout[p]}`); }
    for (const p of COLOR_PROPS) if (nb.color[p] !== na.color[p]) { colorDiffs++; (colorSamples[p] ??= []).length < 1 && colorSamples[p].push(`${nb.color[p]} -> ${na.color[p]}`); }
  });
  report.push({ page: url, scheme, status: [b.status, a.status], darkClass: [b.dom.dark, a.dom.dark], nodes: a.dom.nodes.length, pixelsChangedPct: +((px / (w * h)) * 100).toFixed(2), heightBefore: pb.height, heightAfter: pa.height,
    layoutDiffs, layoutPropDiffs, colorDiffs, layoutSamples, colorSamples, propSamples, problems: [...new Set([...b.problems.map((p) => "before " + p), ...a.problems.map((p) => "after " + p)])].slice(0, 4) });
}
await browser.close();
fs.writeFileSync(`${DIR}/visual-report.json`, JSON.stringify(report, null, 2));
const bad = report.filter((r) => r.layoutDiffs > 0 || r.pixelsChangedPct > MAX_PIXELS || r.status.some((s) => s >= 400) || r.problems.some((p) => p.startsWith("after ")));
for (const r of report) { if (args.samples) { console.log(r.page, r.scheme, "PROP SAMPLES", JSON.stringify(r.propSamples, null, 1)); console.log("COLOR SAMPLES", JSON.stringify(r.colorSamples, null, 1)); } console.log(`${r.page.padEnd(36)} ${r.scheme.padEnd(5)} http=${r.status} dark=${r.darkClass} px=${String(r.pixelsChangedPct).padStart(5)}% layoutDiffs=${r.layoutDiffs} propDiffs=${r.layoutPropDiffs} colorDiffs=${r.colorDiffs} h:${r.heightBefore}->${r.heightAfter}${r.problems.length ? " PROBLEMS:" + r.problems.join(" | ") : ""}`); }
console.log(bad.length ? `VISUAL: FAIL (${bad.length} of ${report.length} page/scheme combinations: layout moved, >${MAX_PIXELS}% pixels changed, HTTP error or new page error)` : `VISUAL: PASS (${report.length} combinations: no layout change, <= ${MAX_PIXELS}% pixels changed)`);
process.exit(bad.length ? 1 : 0);
