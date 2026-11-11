// chadcn--chart re-measure (dev/port/specs/chart.md, "Behavior", "Resize and re-measure", Measure; item #108): after
// document.fonts.ready the controller measures the tick text and the legend box the way recharts does and, when they differ from the
// metrics the server laid the chart out with, asks its relayout_url: for the chart at those metrics. In a font the server's assumptions
// do not describe, the swapped chart matches recharts in the same font under G2's rules, ticks it drops included.
// Its own file, apart from chart.test.mjs and chart_resize*.test.mjs, to keep each within node:test's per-file timeout on CI.
//
// The host is the dummy's chart_relayouts#show (dev/dummy/app/controllers/chart_relayouts_controller.rb): a parity scenario with
// relayout_url: pointing at itself, laid out with Chart::Container.relayout_options(params), like an application's action.
import test from "node:test";
import { PHLEX, assert, consoleErrors, settle } from "./support.mjs";
import { chartBrowser, chartNodes, nodeDifferences, pageCss, rechartsAt } from "./chart_resize_support.mjs";

const HOST = "/design-system/chart-relayout/";
// A font the defaults do not describe (text_height: 16, text_char_width: 0.6, legend_height: 28, and the parity page's 18): lines of
// 14 px (a 26 px legend) and monospace glyphs spaced 14 px apart, wide enough that recharts drops every other month label at 320 px.
const FONT = "html, body, [data-slot=chart] { font-family: monospace !important; line-height: 14px !important; letter-spacing: 14px !important }";
const LEGEND_OBSERVE = [
  ".recharts-wrapper", ".recharts-legend-wrapper", ".recharts-legend-wrapper *", "[class^=\"recharts-zIndex-layer_\"]", ".recharts-bar-rectangle path",
  ".recharts-cartesian-axis-tick-value, .recharts-cartesian-axis-tick-value tspan", ".recharts-cartesian-grid line",
];

// The page at `path` with `css` in place before its scripts run, the chart events recorded from the start and every request to the
// host that carries chart parameters (a re-layout request) collected.
async function withHost(path, css, scenario, { answer = null } = {}) {
  const context = await (await chartBrowser()).newContext({ viewport: { width: 1280, height: 720 } });
  const page = await context.newPage();
  try {
    if (css) await context.addInitScript(pageCss, css);
    await context.addInitScript(() => {
      window.__relayout = [];
      for (const name of ["relayout", "relayout-error"]) {
        document.addEventListener(`chadcn--chart:${name}`, (event) => window.__relayout.push({ name, ...event.detail }));
      }
    });
    const requests = [];
    await page.route((url) => url.pathname.startsWith(HOST) && url.searchParams.has("chart[id]"), async (route) => {
      const url = new URL(route.request().url());
      requests.push(Object.fromEntries(url.searchParams));
      if (answer) return route.fulfill(await answer(route, url));
      return route.continue();
    });
    const errors = consoleErrors(page);
    const jsErrors = [];
    page.on("pageerror", (error) => jsErrors.push(String(error)));
    await page.goto(`${PHLEX}${path}`, { waitUntil: "networkidle" });
    await page.evaluate(() => document.fonts.ready);
    await scenario(page, requests);
    assert.deepEqual(errors, []);
    assert.deepEqual(jsErrors, []);
  } finally {
    await context.close();
  }
}

const relayoutEvents = (page) => page.evaluate(() => window.__relayout);
const waitForEvents = (page, count) => page.waitForFunction((count) => window.__relayout.length >= count, count);

// Resolves once a settle observer, created after the chart's controller connected (and so after its own observer), reported the
// chart's size, and the fonts are ready: by then the controller has measured and, if it was going to, sent its request.
const measured = (page) => page.evaluate(async () => {
  const { observeSettledSize } = await import("chadcn/primitives/chart_relayout");
  await new Promise((resolve) => {
    const observer = observeSettledSize(document.querySelector("[data-slot=chart]"), () => { observer.disconnect(); resolve(); });
  });
  await document.fonts.ready;
  await new Promise((resolve) => setTimeout(resolve, 0));
});

test("chart: in a font the server does not assume, the chart re-measures once and matches recharts in that font", () =>
  withHost(`${HOST}legend__bottom`, FONT, async (page, requests) => {
    await waitForEvents(page, 1);
    assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 320, height: 200 }]);
    assert.equal(requests.length, 1);
    const [request] = requests;
    assert.deepEqual(
      { id: request["chart[id]"], width: request["chart[width]"], height: request["chart[height]"], textHeight: request["chart[text_height]"], legendHeight: request["chart[legend_height]"] },
      { id: "leg-bottom", width: "320", height: "200", textHeight: "14", legendHeight: "26" },
    );
    assert.ok(Number(request["chart[text_char_width]"]) > 1.5, `a 14 px letter spacing makes glyphs wider than 1.5 em (got ${request["chart[text_char_width]"]})`);

    const recharts = await rechartsAt("bar", 320, { css: FONT, scenario: "legend__bottom", observe: LEGEND_OBSERVE });
    assert.deepEqual(nodeDifferences(recharts, await chartNodes(page, LEGEND_OBSERVE)), []);
    assert.equal(await page.locator(".recharts-cartesian-axis-tick-value").count(), 3, "recharts keeps every other month in this font");

    await measured(page);
    assert.equal(requests.length, 1, "the swapped chart measures what it was laid out with: no second request");
  }));

test("chart: without the re-measure the same chart differs from recharts in that font (what the re-layout corrects)", () =>
  withHost("/design-system/parity/chart/legend__bottom", FONT, async (page) => {
    await settle(page);
    const recharts = await rechartsAt("bar", 320, { css: FONT, scenario: "legend__bottom", observe: LEGEND_OBSERVE });
    assert.notDeepEqual(nodeDifferences(recharts, await chartNodes(page, LEGEND_OBSERVE)), []);
  }));

test("chart: a chart laid out with the metrics the page measures sends no request", async () => {
  let query = null;
  await withHost(`${HOST}legend__bottom`, FONT, async (page, requests) => {
    await waitForEvents(page, 1);
    query = new URLSearchParams(requests[0]).toString();
  });
  await withHost(`${HOST}legend__bottom?${query}`, FONT, async (page, requests) => {
    await measured(page);
    assert.deepEqual(requests, []);
    assert.deepEqual(await relayoutEvents(page), []);
  });
});

test("chart: a chart without tick labels or legend measures nothing to correct and sends no request", () =>
  withHost(`${HOST}resize__pie-320`, FONT, async (page, requests) => {
    await measured(page);
    assert.deepEqual(requests, []);
  }));

test("chart: a host that ignores the metrics gets one request, never a loop", () => {
  const ignoring = async (route, url) => {
    const response = await route.fetch({ url: `${url.origin}${url.pathname}` });
    return { response, body: await response.text() };
  };
  return withHost(`${HOST}legend__bottom`, FONT, async (page, requests) => {
    await waitForEvents(page, 1);
    assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 320, height: 200 }]);
    await measured(page);
    assert.equal(requests.length, 1);
    assert.equal(await page.locator("[data-slot=chart]").count(), 1);
  }, { answer: ignoring });
});
