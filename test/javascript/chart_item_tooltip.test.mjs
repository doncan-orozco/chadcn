// chadcn--chart item tooltips (dev/port/specs/chart.md, "Tooltip" and "Behavior"; item #109): `Tooltip shared: false` on a BarChart
// and a RadialBarChart shows the series under the pointer alone. The parity scenarios (dev/port/scenarios/chart.json, tooltip__item-*)
// compare the content with recharts; G2 does not compare the wrapper's style, so this file proves the placement: after every step
// the wrapper of the port and of recharts on the same scenario has the same visibility, side classes and translate (within 0.01 px).
// It also covers what a scenario cannot express: the events, touch and a re-inserted chart. Kept out of chart.test.mjs, which is
// close to node:test's 60 s per-file limit.
import test, { after } from "node:test";
import fs from "node:fs";
import { serversFile } from "./dev_kit.mjs";
import { assert, consoleErrors, launch, openScenario, settle } from "./support.mjs";

const REACT = process.env.PARITY_REACT_URL || JSON.parse(fs.readFileSync(serversFile(), "utf8")).vite?.url;
const CHART = "[data-slot=chart]";
const PLOT = `${CHART} .recharts-wrapper`;
const TOOLTIP = `${CHART} .recharts-tooltip-wrapper`;
const SURFACE = `${CHART} .recharts-surface`;

const browserPromise = launch();
after(async () => { await (await browserPromise).close(); });

// The bar centers and gaps of tooltip__item-bar-*, and the arcs of tooltip__item-radial-* (chart pixels, read from recharts).
const DESKTOP_FEBRUARY = { x: 70, y: 100 };
const GAP = { x: 56, y: 100 };
const MOBILE_APRIL = { x: 196, y: 130 };
const OUTSIDE = { body: true };
const RADIAL = [{ x: 194, y: 94 }, { x: 205, y: 92 }, { x: 239, y: 86 }, { x: 160, y: 100 }];

async function step(page, action) {
  if (action.key === "focus") {
    await page.locator(SURFACE).focus();
  } else if (action.key) {
    await page.keyboard.press(action.key);
  } else if (action.body) {
    await page.mouse.move(2, 2);
  } else {
    const box = await page.locator(PLOT).boundingBox();
    if (action.click) await page.mouse.click(box.x + action.x, box.y + action.y);
    else await page.mouse.move(box.x + action.x, box.y + action.y);
  }
  await settle(page);
}

const wrapperState = (page) => page.locator(TOOLTIP).evaluate((wrapper) => {
  const visible = wrapper.style.visibility === "visible";
  return {
    visible,
    transform: visible ? wrapper.style.transform : null,
    classes: visible ? [...wrapper.classList].filter((name) => name !== "recharts-tooltip-wrapper").sort() : [],
    text: visible ? wrapper.textContent.trim() : "",
  };
});

const NUMBER = /-?\d+(?:\.\d+)?/g;
function sameTransform(port, recharts) {
  if (port === recharts) return true;
  if (port === null || recharts === null) return false;
  const [a, b] = [port.match(NUMBER) ?? [], recharts.match(NUMBER) ?? []];
  return port.replace(NUMBER, "#") === recharts.replace(NUMBER, "#") && a.length === b.length && a.every((n, i) => Math.abs(Number(n) - Number(b[i])) <= 0.01);
}

async function rechartsStates(scenario, actions) {
  const context = await (await browserPromise).newContext({ viewport: { width: 1280, height: 720 } });
  try {
    const page = await context.newPage();
    await page.goto(`${REACT}/#/parity/chart/${scenario}`, { waitUntil: "networkidle" });
    await page.evaluate(() => document.fonts?.ready);
    await page.locator(".recharts-surface").waitFor();
    const states = [await wrapperState(page)];
    for (const action of actions) {
      await step(page, action);
      states.push(await wrapperState(page));
    }
    return states;
  } finally {
    await context.close();
  }
}

async function withScenario(scenario, fn, options) {
  const page = await openScenario(await browserPromise, "chart", scenario, options);
  try {
    const errors = consoleErrors(page);
    await fn(page);
    assert.deepEqual(errors, []);
    assert.deepEqual(page.jsErrors, []);
  } finally {
    await page.context().close();
  }
}

// Walks the port through `actions` and compares the wrapper with recharts after every one (the first state is the one at rest).
function matchesRecharts(scenario, actions) {
  return withScenario(scenario, async (page) => {
    const expected = await rechartsStates(scenario, actions);
    const actual = [await wrapperState(page)];
    for (const action of actions) {
      await step(page, action);
      actual.push(await wrapperState(page));
    }
    actual.forEach((state, index) => {
      const where = `${scenario} after ${index === 0 ? "rest" : JSON.stringify(actions[index - 1])}`;
      const want = expected[index];
      assert.equal(state.visible, want.visible, `${where}: visibility`);
      assert.equal(state.text, want.text, `${where}: content`);
      assert.deepEqual(state.classes, want.classes, `${where}: side classes`);
      assert.ok(sameTransform(state.transform, want.transform), `${where}: transform ${state.transform} != ${want.transform}`);
    });
    assert.ok(expected.some((state) => state.visible), `${scenario}: recharts showed a tooltip`);
  });
}

test("chart item tooltip: hovering a bar shows that series alone, placed at the bar like recharts, and a gap hides it", () =>
  matchesRecharts("tooltip__item-bar-hover", [DESKTOP_FEBRUARY, GAP, MOBILE_APRIL, OUTSIDE]));

test("chart item tooltip: the keyboard shows the series the pointer last activated at the axis anchor, and Escape hides it", () =>
  matchesRecharts("tooltip__item-bar-keyboard", [{ key: "focus" }, { key: "ArrowRight" }, MOBILE_APRIL, OUTSIDE, { key: "ArrowRight" }, { key: "Escape" }]));

test("chart item tooltip: default_index shows the first series, the keyboard starts from it, a hover replaces it", () =>
  matchesRecharts("tooltip__item-bar-default-index", [{ key: "focus" }, { key: "ArrowRight" }, MOBILE_APRIL, OUTSIDE]));

test("chart item tooltip: with trigger click only a click on a bar shows it, and leaving keeps it", () =>
  matchesRecharts("tooltip__item-bar-click", [DESKTOP_FEBRUARY, { ...DESKTOP_FEBRUARY, click: true }, OUTSIDE, { ...MOBILE_APRIL, click: true }]));

test("chart item tooltip: hovering a radial bar sector shows that series, unplaced like recharts (a sector has no tooltip position)", () =>
  matchesRecharts("tooltip__item-radial-hover", [...RADIAL, OUTSIDE]));

test("chart item tooltip: with default_index a radial bar hover is placed at the default anchor, like recharts", () =>
  matchesRecharts("tooltip__item-radial-default-index", [RADIAL[1], OUTSIDE]));

test("chart item tooltip: activate and deactivate carry the index, no label and the one series", () => withScenario("tooltip__item-bar-hover", async (page) => {
  await page.evaluate(() => {
    window.__chartEvents = [];
    for (const name of ["activate", "deactivate"]) {
      document.addEventListener(`chadcn--chart:${name}`, (event) => window.__chartEvents.push({ name, ...event.detail }));
    }
  });
  await step(page, DESKTOP_FEBRUARY);
  await step(page, MOBILE_APRIL);
  await step(page, OUTSIDE);
  const events = await page.evaluate(() => window.__chartEvents);
  assert.deepEqual(events.map((event) => [event.name, event.index, event.label]), [
    ["activate", 1, null], ["activate", 3, null], ["deactivate", 3, null],
  ]);
  assert.deepEqual(events[1].payload.map((item) => [item.dataKey, item.value]), [["mobile", 190]]);
}));

// A bubbling pointermove of `pointerType` on whatever is under the plot point (what a finger or a mouse dispatches).
async function pointerMoveAs(page, pointerType, point) {
  await page.evaluate(({ plot, point, pointerType }) => {
    const rect = document.querySelector(plot).getBoundingClientRect();
    const [x, y] = [rect.left + point.x, rect.top + point.y];
    document.elementFromPoint(x, y).dispatchEvent(new PointerEvent("pointermove", { bubbles: true, pointerType, clientX: x, clientY: y }));
  }, { plot: PLOT, point, pointerType });
  await settle(page);
}

test("chart item tooltip: a finger on a bar shows nothing (recharts finds no item under a touch on a bar), the same move as a mouse does", () => withScenario("tooltip__item-bar-hover", async (page) => {
  await pointerMoveAs(page, "touch", DESKTOP_FEBRUARY);
  assert.equal((await wrapperState(page)).visible, false);
  await pointerMoveAs(page, "mouse", DESKTOP_FEBRUARY);
  assert.match((await wrapperState(page)).text, /305/);
}));

test("chart item tooltip: the Turbo snapshot holds no stale tooltip and the restore brings the live one back", () => withScenario("tooltip__item-bar-hover", async (page) => {
  await step(page, MOBILE_APRIL);
  assert.match((await wrapperState(page)).text, /190/);

  const snapshot = await page.evaluate(async (chart) => {
    document.dispatchEvent(new Event("turbo:before-cache"));
    await new Promise((resolve) => setTimeout(resolve));
    const node = document.querySelector(chart);
    return {
      series: node.getAttribute("data-chadcn--chart-pointer-series-value"),
      children: node.querySelector(".recharts-tooltip-wrapper").childElementCount,
    };
  }, CHART);
  assert.deepEqual(snapshot, { series: "-1", children: 0 });

  await page.locator(TOOLTIP).filter({ hasText: "190" }).waitFor();
  assert.equal(await page.locator(CHART).getAttribute("data-chadcn--chart-pointer-series-value"), "1");
}));

test("chart item tooltip: a re-inserted chart starts from the server state and still answers the pointer", () => withScenario("tooltip__item-bar-hover", async (page) => {
  await step(page, MOBILE_APRIL);
  assert.equal(await page.locator(CHART).getAttribute("data-chadcn--chart-pointer-series-value"), "1");
  await page.evaluate((chart) => {
    const node = document.querySelector(chart);
    const parent = node.parentNode;
    const next = node.nextSibling;
    node.remove();
    parent.insertBefore(node, next);
  }, CHART);
  await settle(page);
  assert.equal(await page.locator(CHART).getAttribute("data-chadcn--chart-pointer-series-value"), "-1");
  assert.equal((await wrapperState(page)).visible, false);
  await step(page, OUTSIDE);
  await step(page, DESKTOP_FEBRUARY);
  assert.match((await wrapperState(page)).text, /305/);
}));
