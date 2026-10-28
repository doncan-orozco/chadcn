// Oracle for the chart spike. Renders the two examples of examples.tsx (stacked bar with CartesianGrid/XAxis/Legend/Tooltip defaultIndex,
// monotone line with dots and YAxis) with the real shadcn chart wrapper and recharts 3.8, at the shadcn initialDimension (320x200), and
// writes dev/spikes/chart/oracle/{bar,line}.html. Run from dev/react-shadcn-catalog (its node_modules provide react, recharts, esbuild,
// playwright):
//
//   cd dev/react-shadcn-catalog && node ../spikes/chart/oracle_ssr.mjs [--check] [--probe-ssr]
//
// --check      regenerates in memory and exits 1 when a committed file differs (0 otherwise).
// --probe-ssr  prints what react-dom `renderToStaticMarkup` returns for each example (the spike's first measurement).
//
// MEASURED (dev/decisions/chart.md): `renderToStaticMarkup` cannot be the oracle. recharts 3 registers axes, graphical items, legend and
// tooltip in its redux store from useEffect, which never runs on the server, so the server markup is an empty `.recharts-wrapper`.
// The oracle is therefore the settled client render: react-dom/client in headless chromium, with the page pinned for determinism:
// a 320x200 container (= initialDimension, so the ResponsiveContainer measures exactly the size it starts from), a fixed 12px/16px
// font, no animation (isAnimationActive={false}), and the one volatile value (the tooltip wrapper's measured position) normalized.
import { createRequire } from "node:module"
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"

// Packages resolve from the working directory (dev/react-shadcn-catalog), not from this file.
const nodeModules = resolve(process.cwd(), "node_modules")
const requireHere = createRequire(resolve(process.cwd(), "package.json"))
const { build } = requireHere("esbuild")
const { chromium } = requireHere("playwright")
const here = dirname(fileURLToPath(import.meta.url))
const outDir = join(here, "oracle")
const args = process.argv.slice(2)
const names = ["bar", "line"]

const bundleOptions = { entryPoints: [join(here, "examples.tsx")], bundle: true, jsx: "automatic", logLevel: "error", nodePaths: [nodeModules], write: false }

async function serverProbe() {
  const out = await build({ ...bundleOptions, format: "esm", platform: "node", packages: "external", outdir: join(nodeModules, ".cache") })
  const file = join(nodeModules, ".cache", `chart-spike-${process.pid}.mjs`)
  mkdirSync(dirname(file), { recursive: true })
  writeFileSync(file, out.outputFiles[0].text)
  const { renderToStaticMarkup } = await import(pathToFileURL(requireHere.resolve("react-dom/server")).href)
  try {
    const examples = await import(pathToFileURL(file).href)
    return Object.fromEntries(names.map((n) => [n, renderToStaticMarkup(examples[n]())]))
  } finally {
    rmSync(file, { force: true })
  }
}

async function clientRender() {
  const out = await build({
    ...bundleOptions, format: "iife", globalName: "Spike", platform: "browser", define: { "process.env.NODE_ENV": '"production"' }, outdir: "out",
  })
  const script = out.outputFiles[0].text
  const browser = await chromium.launch()
  try {
    const rendered = {}
    for (const name of names) {
      const page = await browser.newPage({ viewport: { width: 800, height: 600 } })
      await page.setContent(
        `<!doctype html><html><head><style>*{box-sizing:border-box;margin:0;padding:0;font:12px/16px monospace}html{font-size:16px}` +
          `[data-slot=chart]{display:flex;justify-content:center;width:320px;height:200px}` +
          // the Tailwind utilities of the legend: recharts measures the legend box and subtracts its height from the plot area
          `.flex{display:flex}.items-center{align-items:center}.justify-center{justify-content:center}.gap-4{gap:1rem}.gap-1\\.5{gap:.375rem}` +
          `.pt-3{padding-top:.75rem}.pb-3{padding-bottom:.75rem}.h-2{height:.5rem}.w-2{width:.5rem}.shrink-0{flex-shrink:0}</style></head><body><div id="host"></div></body></html>`
      )
      await page.addScriptTag({ content: script })
      await page.evaluate((n) => { window.__root = window.Spike.mount(n, document.getElementById("host")) }, name)
      // effects, ResizeObserver and the legend/tooltip measurements settle over a few frames: wait (at most 30 double frames) until two
      // consecutive snapshots are identical and the SVG surface exists
      let html = ""
      for (let i = 0; i < 30; i++) {
        await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))))
        const next = await page.evaluate(() => document.getElementById("host").innerHTML)
        const settled = next === html && next.includes("recharts-surface")
        html = next
        if (settled) break
      }
      if (!html.includes("recharts-surface")) throw new Error(`chart ${name} did not settle: no recharts-surface after 30 frames`)
      rendered[name] = normalize(html)
      await page.close()
    }
    return rendered
  } finally {
    await browser.close()
  }
}

// The tooltip wrapper is positioned from the measured size of its content (font dependent); the position (its `transform` and the
// `-left/-right/-top/-bottom` class modifiers, both the controller's output) is replaced by a fixed token / dropped so the committed
// oracle does not depend on the installed fonts. Everything else is kept verbatim.
function normalize(html) {
  return html
    .replace(/(class=")(recharts-tooltip-wrapper[^"]*)(" style=")([^"]*)(")/g, (_, a, classes, b, style, c) =>
      `${a}${classes.split(/\s+/).filter((k) => !/^recharts-tooltip-wrapper-/.test(k)).join(" ")}${b}${style.replace(/transform:[^;]*;?/g, "transform:TOOLTIP_POSITION;")}${c}`
    ) + "\n"
}

if (args.includes("--probe-ssr")) {
  for (const [n, html] of Object.entries(await serverProbe())) console.log(`${n}: ${html.length} bytes, svg elements: ${(html.match(/<svg/g) || []).length}\n${html}\n`)
  process.exit(0)
}

const rendered = await clientRender()
let drift = false
for (const name of names) {
  const file = join(outDir, `${name}.html`)
  if (args.includes("--check")) {
    if (!existsSync(file) || readFileSync(file, "utf8") !== rendered[name]) {
      console.error(`oracle drift: ${file} differs from a fresh render`)
      drift = true
    }
  } else {
    mkdirSync(outDir, { recursive: true })
    writeFileSync(file, rendered[name])
    console.log(`wrote ${file} (${rendered[name].length} bytes)`)
  }
}
if (args.includes("--check")) {
  if (drift) process.exit(1)
  console.log("oracle HTML is up to date")
}
