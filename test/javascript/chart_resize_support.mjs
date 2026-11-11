// Shared support of the chart re-layout browser tests (chart_resize.test.mjs: parity against recharts; chart_resize_lifecycle.test.mjs:
// debounce, abort, errors, disconnect, Turbo). Not a test file itself (bin/test-js runs *.test.mjs). Spec: dev/port/specs/chart.md,
// "Behavior", "Resize and re-measure"; decision: dev/decisions/chart.md, "Item #107".
import fs from "node:fs";
import { after } from "node:test";
import { serversFile } from "./dev_kit.mjs";
import { PHLEX, assert, consoleErrors, launch, openPath, settle } from "./support.mjs";

export const CHART = "[data-slot=chart]";
const PLOT = `${CHART} .recharts-wrapper`;
export const SURFACE = `${CHART} .recharts-surface`;
export const TOOLTIP = `${CHART} .recharts-tooltip-wrapper`;
const valueAttribute = (name) => `data-chadcn--chart-${name}-value`;
export const chartValue = (page, name) => page.locator(CHART).getAttribute(valueAttribute(name));

const browserPromise = launch();
after(async () => { await (await browserPromise).close(); });
export const chartBrowser = () => browserPromise;

// The host's answer to the re-layout request is the Phlex parity page of the scenario at the requested width (resize__<family>-<width>
// in dev/port/scenarios/chart.json, which G2 compares with recharts at that size). Those pages render a container without
// relayout_url:, so the test adds the three re-layout values a host with relayout_url: writes (test/chadcn/chart/container_relayout_test.rb
// proves the container writes them), to the answer and to the start page. The swapped chart is compared with recharts resized in the
// browser, under G2's rules (observed selectors, data and controller attributes ignored, numbers within 1e-3 px).
// These tests are about the size: the text metrics they write are the ones the page measures (the start page) and the ones the request
// carries (the answer), so the controller's re-measure (item #108, chart_remeasure.test.mjs) finds nothing to correct. The parity pages
// are laid out at the parity metrics, which the measured ones do not change for these short labels.
export const REACT = process.env.PARITY_REACT_URL || JSON.parse(fs.readFileSync(serversFile(), "utf8")).vite?.url;
const RELAYOUT_PATH = "/chart-relayout";
const RELAYOUT_URL = `${RELAYOUT_PATH}?source=test`;
const RESIZE_HEIGHTS = { 320: 200, 480: 300, 640: 400 };

export const RESIZE_OBSERVE = {
  bar: [".recharts-wrapper", "[class^=\"recharts-zIndex-layer_\"]", ".recharts-cartesian-axis-tick-value, .recharts-cartesian-axis-tick-value tspan", ".recharts-cartesian-grid line", ".recharts-bar-rectangle path"],
  pie: [".recharts-wrapper", ".recharts-pie-sector", "[class^=\"recharts-zIndex-layer_\"]"],
};
const IGNORED_ATTRIBUTE = /^(class|style|id|data-controller|data-action|data-.*-target|data-.*-value|tabindex-managed)$|^data-chadcn--/;
const scenarioPath = (family, width) => `/design-system/parity/chart/resize__${family}-${width}`;
const relayoutValues = (width, metrics, url = RELAYOUT_URL) => ({
  "relayout-url": url,
  dimension: JSON.stringify({ width, height: RESIZE_HEIGHTS[width] }),
  "text-metrics": JSON.stringify(metrics),
});

// The metrics a re-layout request carries, as the textMetrics value of its answer.
const requestedMetrics = (url) => {
  const number = (name) => (url.searchParams.has(`chart[${name}]`) ? Number(url.searchParams.get(`chart[${name}]`)) : undefined);
  return { textHeight: number("text_height"), textCharWidth: number("text_char_width"), legendHeight: number("legend_height") };
};

const escapeAttribute = (text) => text.replaceAll("&", "&amp;").replaceAll('"', "&quot;");

function withRelayoutValues(html, family, width, metrics) {
  const marker = `data-chart="chart-resize-${family}"`;
  assert.ok(html.includes(marker), `the parity page holds ${marker}`);
  const attributes = Object.entries(relayoutValues(width, metrics)).map(([name, value]) => ` ${valueAttribute(name)}="${escapeAttribute(value)}"`).join("");
  return html.replace(marker, `${marker}${attributes}`);
}

const ROUTE_GONE = /Route is already handled|Target page, context or browser has been closed|net::ERR_ABORTED/;

// Answers GET /chart-relayout like a host: the chart at the requested width, or `answer(width)` -> { status, body, width }.
// The array it returns holds the query of each request; `reached(count)` resolves once that many arrived and `answered[n]` once the
// handler of request n is done (answered, or abandoned because the controller aborted it): positive signals to wait on, never a sleep.
export async function answerRelayout(page, family, { delays = [], answer = null } = {}) {
  const requests = [];
  const waiting = [];
  requests.answered = [];
  requests.reached = (count) => (requests.length >= count ? Promise.resolve() : new Promise((resolve) => waiting.push({ count, resolve })));
  await page.route((url) => url.pathname === RELAYOUT_PATH, async (route) => {
    const url = new URL(route.request().url());
    const number = requests.push(Object.fromEntries(url.searchParams));
    let markAnswered;
    requests.answered.push(new Promise((resolve) => { markAnswered = resolve; }));
    for (const waiter of waiting.filter((waiter) => waiter.count <= requests.length)) waiter.resolve();
    const delay = delays[number - 1] ?? 0;
    try {
      if (delay) await new Promise((resolve) => setTimeout(resolve, delay));
      const requested = Number(url.searchParams.get("chart[width]"));
      const override = answer?.(requested) ?? {};
      if (override.body !== undefined || override.status) return await route.fulfill({ status: override.status ?? 200, contentType: "text/html", body: override.body ?? "" });
      const width = override.width ?? requested;
      const response = await route.fetch({ url: `${PHLEX}${scenarioPath(family, width)}` });
      await route.fulfill({ response, body: withRelayoutValues(await response.text(), family, width, requestedMetrics(url)) });
    } catch (error) {
      // the controller aborted the request or the page is gone; anything else is a bug of the test
      if (!ROUTE_GONE.test(error.message)) throw error;
    } finally {
      markAnswered();
    }
  });
  return requests;
}

export async function expectRequests(requests, count) {
  await requests.reached(count);
  assert.equal(requests.length, count);
}

export async function withResizable(family, scenario, { url = RELAYOUT_URL, loadErrors = false } = {}) {
  const page = await openPath(await browserPromise, scenarioPath(family, 320));
  try {
    const errors = consoleErrors(page);
    await page.evaluate(() => {
      window.__relayout = [];
      for (const name of ["relayout", "relayout-error"]) {
        document.addEventListener(`chadcn--chart:${name}`, (event) => window.__relayout.push({ name, ...event.detail }));
      }
    });
    await scenario(page, () => enableRelayout(page, url));
    assert.deepEqual(errors.filter((text) => !(loadErrors && /Failed to load resource/.test(text))), []);
    assert.deepEqual(page.jsErrors, []);
  } finally {
    await page.context().close();
  }
}

// Writes the re-layout values on the start page, with the text metrics the page measures as the served ones.
const enableRelayout = (page, url) => page.evaluate(async ({ values }) => {
  const { measureTextMetrics } = await import("chadcn/primitives/chart_measure");
  const chart = document.querySelector("[data-slot=chart]");
  const metrics = measureTextMetrics(chart, { textHeight: 18, textCharWidth: 0.6 });
  for (const [name, value] of Object.entries({ ...values, "text-metrics": JSON.stringify(metrics) })) chart.setAttribute(`data-chadcn--chart-${name}-value`, value);
}, { values: relayoutValues(320, {}, url) });

// The text metrics the start page measures, as the re-layout request writes them.
export const pageMetrics = (page) => page.evaluate(async () => {
  const { measureTextMetrics } = await import("chadcn/primitives/chart_measure");
  const metrics = measureTextMetrics(document.querySelector("[data-slot=chart]"), { textHeight: 18, textCharWidth: 0.6 });
  return { "chart[text_height]": String(metrics.textHeight), "chart[text_char_width]": String(metrics.textCharWidth) };
});

// Resolves once the box has been seen at the new width: a companion ResizeObserver, created after the controller's own, hears the
// resize after it, so the controller has handled it (its interim scaling is in place, its debounce is running).
export const resizeTo = (page, width, height = RESIZE_HEIGHTS[width]) => page.evaluate(({ width, height }) => new Promise((resolve) => {
  const chart = document.querySelector("[data-slot=chart]");
  const companion = new ResizeObserver((entries) => {
    if (Math.round(entries[entries.length - 1].contentRect.width) === width) { companion.disconnect(); resolve(); }
  });
  companion.observe(chart);
  chart.style.width = `${width}px`;
  chart.style.height = `${height}px`;
}), { width, height });

// Resolves once a settle observer, created after the controller's own and with the same delay, reports the new width: its debounce
// timer starts after the controller's, so by then the controller's has fired. A request it started may still be in flight: the
// control that follows (a reconnect with another URL must be the next request) is what proves nothing was requested.
export const resizeAndSettle = (page, width, height = RESIZE_HEIGHTS[width]) => page.evaluate(async ({ width, height }) => {
  const { observeSettledSize } = await import("chadcn/primitives/chart_relayout");
  const chart = document.querySelector("[data-slot=chart]");
  await new Promise((resolve) => {
    const observer = observeSettledSize(chart, (size) => {
      if (size.width !== width) return;
      observer.disconnect();
      resolve();
    });
    chart.style.width = `${width}px`;
    chart.style.height = `${height}px`;
  });
}, { width, height });

export const relayoutEvents = (page) => page.evaluate(() => window.__relayout);
export const waitForEvents = (page, count) => page.waitForFunction((count) => window.__relayout.length >= count, count);
export const wrapperStyle = (page) => page.locator(PLOT).getAttribute("style");

// G2's comparison rules, for the swapped chart against recharts: a copy of the snapshot and attribute rules of
// .claude/scripts/shadcn/parity_run.mjs (IGNORED_ATTR, NUMERIC_ATTR, NUMERIC_TOLERANCE 1e-3, numbersClose), restricted to the observed
// selectors of the resize scenarios. Keep it in step with that file: the runner compares two pages it loads itself, not a chart that a
// test swapped in, so it cannot be called from here.
//
// The nodes G2 compares for these selectors, one list per page, in document order per selector.
export function chartNodes(page, observe) {
  return page.evaluate(({ observe, ignored }) => {
    const pattern = new RegExp(ignored);
    const chart = document.querySelector("[data-slot=chart]");
    return observe.flatMap((selector) => [...chart.querySelectorAll(selector)].map((element) => {
      const attributes = {};
      for (const attribute of [...element.attributes].sort((a, b) => (a.name < b.name ? -1 : 1))) {
        if (!pattern.test(attribute.name)) attributes[attribute.name] = attribute.value;
      }
      if (!element.matches(".recharts-tooltip-wrapper") && element.hasAttribute("style")) attributes.style = element.getAttribute("style");
      const className = element.className?.baseVal ?? element.className;
      return {
        selector,
        tag: element.tagName.toLowerCase(),
        classes: [...new Set(String(className).split(/\s+/).filter(Boolean))].sort().join(" "),
        attributes,
        text: [...element.childNodes].filter((node) => node.nodeType === 3).map((node) => node.textContent.trim()).filter(Boolean).join(" "),
      };
    }));
  }, { observe, ignored: IGNORED_ATTRIBUTE.source });
}

const NUMBER = /-?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?/gi;
const NUMERIC_ATTRIBUTES = new Set(["d", "points", "x", "y", "width", "height", "transform", "x1", "x2", "y1", "y2", "cx", "cy", "r", "style"]);

function numbersClose(a, b) {
  const [textsA, textsB] = [String(a).split(NUMBER), String(b).split(NUMBER)];
  if (textsA.length !== textsB.length || textsA.some((text, index) => text !== textsB[index])) return false;
  const [numbersA, numbersB] = [String(a).match(NUMBER) ?? [], String(b).match(NUMBER) ?? []];
  return numbersA.every((number, index) => Math.abs(Number(number) - Number(numbersB[index])) <= 1e-3 + 1e-9);
}

export function nodeDifferences(recharts, phlex) {
  if (recharts.length < 10) return [`only ${recharts.length} observed nodes in recharts: the page did not draw the chart`];
  if (recharts.length !== phlex.length) return [`${recharts.length} nodes in recharts, ${phlex.length} in the port`];
  return recharts.flatMap((expected, index) => {
    const actual = phlex[index];
    const where = `${expected.selector} #${index} <${expected.tag}>`;
    const differences = [];
    for (const key of ["tag", "classes", "text"]) if (expected[key] !== actual[key]) differences.push(`${where} ${key}: ${expected[key]} != ${actual[key]}`);
    const names = new Set([...Object.keys(expected.attributes), ...Object.keys(actual.attributes)]);
    for (const name of names) {
      const [a, b] = [expected.attributes[name], actual.attributes[name]];
      if (a === b || (a !== undefined && b !== undefined && NUMERIC_ATTRIBUTES.has(name) && numbersClose(a, b))) continue;
      differences.push(`${where} ${name}: ${a} != ${b}`);
    }
    return differences;
  });
}

// recharts with shadcn's ChartContainer on the React parity page of the 320 scenario, its container resized and settled. `css` is
// added to the page before it renders (pageCss), so recharts measures its text in it.
export async function rechartsAt(family, width, { css = "", scenario = `resize__${family}-320`, observe = RESIZE_OBSERVE[family] } = {}) {
  const context = await (await browserPromise).newContext({ viewport: { width: 1280, height: 720 } });
  try {
    if (css) await context.addInitScript(pageCss, css);
    const page = await context.newPage();
    await page.goto(`${REACT}/#/parity/chart/${scenario}`, { waitUntil: "networkidle" });
    await page.evaluate(() => document.fonts?.ready);
    await page.locator(".recharts-surface").waitFor();
    await resizeTo(page, width);
    await page.waitForFunction((width) => document.querySelector(".recharts-wrapper")?.style.width === `${width}px`, width);
    let previous = "";
    for (let frame = 0; frame < 30; frame += 1) {
      await settle(page);
      const html = await page.locator("[data-slot=chart]").innerHTML();
      if (html === previous) break;
      previous = html;
    }
    return await chartNodes(page, observe);
  } finally {
    await context.close();
  }
}


// An init script that adds `css` to the page as soon as it has a head, before any of its scripts run (the controller measures after
// document.fonts.ready, recharts while it renders): pass it to `context.addInitScript(pageCss, css)`.
export function pageCss(css) {
  const add = () => {
    if (!document.head) return false;
    const style = document.createElement("style");
    style.textContent = css;
    document.head.append(style);
    return true;
  };
  if (add()) return;
  const observer = new MutationObserver(() => { if (add()) observer.disconnect(); });
  observer.observe(document, { childList: true, subtree: true });
}
