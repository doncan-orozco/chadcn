// Browser half of the resize spike (driven by run.rb, which documents the command). Two modes, both from dev/react-shadcn-catalog (its
// node_modules provide esbuild, react, recharts and playwright):
//
//   node ../spikes/chart-resize/browser.mjs oracle <out-dir> <sizes-json>
//     renders ../chart/examples.tsx (stacked bar, monotone line) with recharts 3.8 in Chromium in a container of each size, on the page of
//     ../chart/oracle_ssr.mjs (font pinned to 12px/16px monospace) and on the same page with a host font (12px sans-serif, line height `normal`), and writes
//     <out-dir>/oracle.json: per chart, font and size the settled HTML, the boxes of the observed nodes, the measured text metrics, and the
//     time recharts takes to settle again after its container goes from the first size to that size (its own resize cost).
//   node ../spikes/chart-resize/browser.mjs boxes <out-dir>
//     loads every <out-dir>/phlex/*.html (written by run.rb: the gem's markup per option) into the same page and container and writes
//     <out-dir>/phlex.json with the boxes of the same nodes.
//
// The boxes are what the reader sees: `getBoundingClientRect` relative to `div[data-slot=chart]`, rounded to 1e-3 px.
import { createRequire } from "node:module"
import { readdirSync, readFileSync, writeFileSync } from "node:fs"
import { basename, dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const requireHere = createRequire(resolve(process.cwd(), "package.json"))
const { build } = requireHere("esbuild")
const { chromium } = requireHere("playwright")
const here = dirname(fileURLToPath(import.meta.url))
const [mode, outDir, sizesJson] = process.argv.slice(2)
const names = ["bar", "line"]
const fonts = { mono: "12px/16px monospace", sans: "12px sans-serif" }

// The nodes whose on-screen boxes are compared (a subset of the G2 `observe` selectors: what moves when the container changes size).
const OBSERVED = [
  ".recharts-surface", ".recharts-cartesian-grid-horizontal line", ".recharts-cartesian-axis-tick-value", ".recharts-bar-rectangle path",
  ".recharts-tooltip-cursor", ".recharts-line .recharts-curve", ".recharts-line-dot", ".recharts-legend-wrapper",
]

function pageHtml(font, width, height) {
  return `<!doctype html><html><head><style>*{box-sizing:border-box;margin:0;padding:0;font:${font}}html{font-size:16px}` +
    `[data-slot=chart]{display:flex;justify-content:center;width:${width}px;height:${height}px}` +
    `.flex{display:flex}.items-center{align-items:center}.justify-center{justify-content:center}.gap-4{gap:1rem}.gap-1\\.5{gap:.375rem}` +
    `.pt-3{padding-top:.75rem}.pb-3{padding-bottom:.75rem}.h-2{height:.5rem}.w-2{width:.5rem}.shrink-0{flex-shrink:0}</style></head>` +
    `<body><div id="host"></div></body></html>`
}

async function settle(page) {
  let html = ""
  for (let i = 0; i < 30; i++) {
    await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))))
    const next = await page.evaluate(() => document.getElementById("host").innerHTML)
    const settled = next === html && next.includes("recharts-surface")
    html = next
    if (settled) return html
  }
  throw new Error("chart did not settle after 30 frames")
}

function boxes(page) {
  return page.evaluate((selectors) => {
    const root = document.querySelector("[data-slot=chart]").getBoundingClientRect()
    const r = (n) => Math.round(n * 1000) / 1000
    return Object.fromEntries(selectors.map((s) => [s, [...document.querySelectorAll(s)].map((el) => {
      const b = el.getBoundingClientRect()
      return [r(b.left - root.left), r(b.top - root.top), r(b.width), r(b.height)]
    })]))
  }, OBSERVED)
}

// What a re-measure pass hands the layout, measured the way recharts does (util/DOMUtils.js `measureTextWithDOM`: a `white-space: pre` span
// under body, `getBoundingClientRect`): the height of a line of tick text, the average glyph width of the tick labels in em of 12px, and the height of the legend box (recharts'
// `useElementOffset`, which it subtracts from the plot).
function textMetrics(page) {
  return page.evaluate(() => {
    const labels = [...document.querySelectorAll(".recharts-cartesian-axis-tick-value")].map((t) => t.textContent)
    const span = document.body.appendChild(document.createElement("span"))
    Object.assign(span.style, { position: "absolute", top: "-20000px", left: 0, padding: 0, margin: 0, border: "none", whiteSpace: "pre" })
    const rects = labels.map((text) => { span.textContent = text; return span.getBoundingClientRect() })
    span.remove()
    const chars = labels.reduce((n, text) => n + text.length, 0)
    const width = rects.reduce((n, r) => n + r.width, 0)
    const legend = document.querySelector(".recharts-legend-wrapper")
    return {
      text_height: rects[0].height, text_char_width: Math.round((width / chars / 12) * 1e4) / 1e4,
      ...(legend ? { legend_height: legend.getBoundingClientRect().height } : {}),
    }
  })
}

// recharts' own resize: mount at `from`, settle, set the container to `to`, time until the DOM is stable again.
async function resizeCost(page, from, to) {
  await page.evaluate(([w, h]) => Object.assign(document.querySelector("[data-slot=chart]").style, { width: `${w}px`, height: `${h}px` }), to)
  const start = await page.evaluate(() => performance.now())
  await settle(page)
  return Math.round((await page.evaluate(() => performance.now())) - start)
}

async function oracle(sizes) {
  const out = await build({
    entryPoints: [join(here, "../chart/examples.tsx")], bundle: true, jsx: "automatic", logLevel: "error", write: false,
    nodePaths: [resolve(process.cwd(), "node_modules")], format: "iife", globalName: "Spike", platform: "browser",
    define: { "process.env.NODE_ENV": '"production"' }, outdir: "out",
  })
  const script = out.outputFiles[0].text
  const browser = await chromium.launch()
  const result = { bundle_bytes: Buffer.byteLength(script), charts: {} }
  try {
    for (const name of names) {
      for (const [fontName, font] of Object.entries(fonts)) {
        for (const [width, height] of sizes) {
          const page = await browser.newPage({ viewport: { width: 1024, height: 768 } })
          await page.setContent(pageHtml(font, width, height))
          await page.addScriptTag({ content: script })
          await page.evaluate((n) => { window.Spike.mount(n, document.getElementById("host")) }, name)
          const html = await settle(page)
          const entry = { html, boxes: await boxes(page), metrics: await textMetrics(page) }
          if (width !== sizes[0][0]) {
            // a second page mounted at the first size measures recharts' re-layout to this one
            const resized = await browser.newPage({ viewport: { width: 1024, height: 768 } })
            await resized.setContent(pageHtml(font, ...sizes[0]))
            await resized.addScriptTag({ content: script })
            await resized.evaluate((n) => { window.Spike.mount(n, document.getElementById("host")) }, name)
            await settle(resized)
            entry.resize_ms = await resizeCost(resized, sizes[0], [width, height])
            await resized.close()
          }
          result.charts[`${name}-${fontName}-${width}x${height}`] = entry
          await page.close()
        }
      }
    }
  } finally {
    await browser.close()
  }
  writeFileSync(join(outDir, "oracle.json"), JSON.stringify(result))
}

async function phlexBoxes() {
  const dir = join(outDir, "phlex")
  const browser = await chromium.launch()
  const result = {}
  try {
    for (const file of readdirSync(dir).filter((f) => f.endsWith(".html"))) {
      // <chart>-<font>-<w>x<h>-<option>.html
      const [, , fontName, size] = basename(file, ".html").match(/^(\w+)-(\w+)-(\d+x\d+)-/)
      const [width, height] = size.split("x").map(Number)
      const page = await browser.newPage({ viewport: { width: 1024, height: 768 } })
      await page.setContent(pageHtml(fonts[fontName], width, height))
      await page.evaluate((html) => { document.getElementById("host").innerHTML = html }, readFileSync(join(dir, file), "utf8"))
      result[basename(file, ".html")] = await boxes(page)
      await page.close()
    }
  } finally {
    await browser.close()
  }
  writeFileSync(join(outDir, "phlex.json"), JSON.stringify(result))
}

if (mode === "oracle") await oracle(JSON.parse(sizesJson))
else if (mode === "boxes") await phlexBoxes()
else throw new Error(`unknown mode ${mode}: oracle | boxes`)
