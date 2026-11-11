// chadcn--chart on the polar charts (dev/port/specs/chart.md, "Tooltip" and "Behavior"; item #110): a RadarChart and a RadialBarChart
// map the pointer to the angle or ring category under it (recharts' polar branch of `combineActiveProps`), a PieChart activates the
// sector under it, and the three answer the keyboard layer and Escape. The parity scenarios (dev/port/scenarios/chart.json,
// tooltip__radar-*, tooltip__radial-*, tooltip__pie-*) compare the final DOM with recharts; G2 does not compare the wrapper's style, so
// this file walks the same steps in the port and in recharts and compares, after every step, the wrapper (visibility, side classes,
// translate within 0.01 px, content), the polar cursor (class, layer and geometry) and the active dots. It also covers what a scenario
// cannot express: the events, a finger and the Turbo cache. Kept out of chart.test.mjs, which is close to node:test's 60 s per-file limit.
import test, { after } from "node:test";
import fs from "node:fs";
import { serversFile } from "./dev_kit.mjs";
import { assert, consoleErrors, launch, openPath, openScenario, settle } from "./support.mjs";

const REACT = process.env.PARITY_REACT_URL || JSON.parse(fs.readFileSync(serversFile(), "utf8")).vite?.url;
const SCENARIOS = JSON.parse(fs.readFileSync(new URL("../../dev/port/scenarios/chart.json", import.meta.url), "utf8")).scenarios;
const CHART = "[data-slot=chart]";
const PLOT = `${CHART} .recharts-wrapper`;
const TOOLTIP = `${CHART} .recharts-tooltip-wrapper`;
const SURFACE = `${CHART} .recharts-surface`;
const LEAVE = { do: "hover", target: "body", position: { x: 2, y: 2 } };
const at = (x, y) => ({ do: "hover", target: ".recharts-wrapper", position: { x, y } });

const browserPromise = launch();
after(async () => { await (await browserPromise).close(); });

// A scenario step in the runner's vocabulary (`.claude/scripts/shadcn/parity_run.mjs`): hover or click at a point of the wrapper, a
// hover on the body, focus on the surface, a key.
async function step(page, action) {
  if (action.do === "focus") {
    await page.locator(SURFACE).focus();
  } else if (action.do === "press") {
    await page.keyboard.press(action.key);
  } else if (action.target === "body") {
    await page.mouse.move(action.position.x, action.position.y);
  } else {
    const box = await page.locator(PLOT).boundingBox();
    const [x, y] = [box.x + action.position.x, box.y + action.position.y];
    if (action.do === "click") await page.mouse.click(x, y);
    else await page.mouse.move(x, y);
  }
  await settle(page);
}

const chartState = (page) => page.locator(PLOT).evaluate((plot) => {
  const wrapper = plot.querySelector(".recharts-tooltip-wrapper");
  const visible = wrapper.style.visibility === "visible";
  const cursor = plot.querySelector(".recharts-tooltip-cursor");
  return {
    visible,
    transform: visible ? wrapper.style.transform : null,
    classes: visible ? [...wrapper.classList].filter((name) => name !== "recharts-tooltip-wrapper").sort() : [],
    text: visible ? wrapper.textContent.trim() : "",
    cursor: cursor && {
      class: cursor.getAttribute("class"),
      layer: cursor.closest("[class^='recharts-zIndex-layer_']")?.getAttribute("class") ?? null,
      geometry: ["d", "cx", "cy", "stroke", "pointer-events", "width", "height"].map((name) => `${name}=${cursor.getAttribute(name)}`).join(" "),
    },
    dots: [...plot.querySelectorAll(".recharts-active-dot circle")].map((dot) => `${dot.getAttribute("cx")},${dot.getAttribute("cy")}`),
  };
});

const NUMBER = /-?\d+(?:\.\d+)?/g;
function sameNumbers(port, recharts) {
  if (port === recharts) return true;
  if (port === null || recharts === null) return false;
  const [portNumbers, rechartsNumbers] = [port.match(NUMBER) ?? [], recharts.match(NUMBER) ?? []];
  const shape = (text) => text.replace(NUMBER, "#").replace(/\s+/g, " ");
  return shape(port) === shape(recharts) && portNumbers.length === rechartsNumbers.length && portNumbers.every((number, position) => Math.abs(Number(number) - Number(rechartsNumbers[position])) <= 0.01);
}

async function rechartsStates(scenario) {
  const context = await (await browserPromise).newContext({ viewport: { width: 1280, height: 720 } });
  try {
    const page = await context.newPage();
    await page.goto(`${REACT}/#/parity/chart/${scenario.id}`, { waitUntil: "networkidle" });
    await page.evaluate(() => document.fonts?.ready);
    await page.locator(".recharts-surface").waitFor();
    const states = [await chartState(page)];
    for (const action of scenario.steps) {
      await step(page, action);
      states.push(await chartState(page));
    }
    return states;
  } finally {
    await context.close();
  }
}

async function withScenario(id, fn, options) {
  const page = await openScenario(await browserPromise, "chart", id, options);
  try {
    const errors = consoleErrors(page);
    await fn(page);
    assert.deepEqual(errors, []);
    assert.deepEqual(page.jsErrors, []);
  } finally {
    await page.context().close();
  }
}

function compare(where, state, expected) {
  assert.equal(state.visible, expected.visible, `${where}: visibility`);
  assert.equal(state.text, expected.text, `${where}: content`);
  assert.deepEqual(state.classes, expected.classes, `${where}: side classes`);
  assert.ok(sameNumbers(state.transform, expected.transform), `${where}: transform ${state.transform} != ${expected.transform}`);
  assert.equal(Boolean(state.cursor), Boolean(expected.cursor), `${where}: cursor drawn`);
  if (expected.cursor) {
    assert.equal(state.cursor.class, expected.cursor.class, `${where}: cursor class`);
    assert.equal(state.cursor.layer, expected.cursor.layer, `${where}: cursor layer`);
    assert.ok(sameNumbers(state.cursor.geometry, expected.cursor.geometry), `${where}: cursor ${state.cursor.geometry} != ${expected.cursor.geometry}`);
  }
  assert.equal(state.dots.length, expected.dots.length, `${where}: active dots`);
  state.dots.forEach((dot, index) => assert.ok(sameNumbers(dot, expected.dots[index]), `${where}: active dot ${dot} != ${expected.dots[index]}`));
}

// Walks the port through the scenario's own steps and compares it with recharts after every one (the first state is the one at rest).
function matchesRecharts(id) {
  const scenario = SCENARIOS.find((candidate) => candidate.id === id);
  assert.ok(scenario, `scenario ${id}`);
  return withScenario(id, async (page) => {
    const expected = await rechartsStates(scenario);
    const actual = [await chartState(page)];
    for (const action of scenario.steps) {
      await step(page, action);
      actual.push(await chartState(page));
    }
    actual.forEach((state, index) => {
      compare(`${id} after ${index === 0 ? "rest" : JSON.stringify(scenario.steps[index - 1])}`, state, expected[index]);
    });
    assert.ok(expected.some((state) => state.visible), `${id}: recharts showed a tooltip`);
  });
}

test("polar tooltip: the pointer over a radar activates the angle category under it, with the polar cursor, like recharts", () =>
  matchesRecharts("tooltip__radar-hover"));

test("polar tooltip: the keyboard and Escape on a radar, with a hover in between, like recharts", () =>
  matchesRecharts("tooltip__radar-keyboard"));

test("polar tooltip: with trigger click only a click on a radar shows a category, and leaving keeps it", () =>
  matchesRecharts("tooltip__radar-click"));

test("polar tooltip: the pointer over an axis radial bar chart activates the ring under it, with the arc cursor, like recharts", () =>
  matchesRecharts("tooltip__radial-hover"));

test("polar tooltip: the keyboard, Enter and Escape on a radial bar chart, like recharts", () =>
  matchesRecharts("tooltip__radial-keyboard"));

test("polar tooltip: the pointer over a pie activates the sector under it, placed at its tooltip position, like recharts", () =>
  matchesRecharts("tooltip__pie-hover"));

test("polar tooltip: the keyboard on a pie shows nothing until the pointer activated a sector, then follows the index, like recharts", () =>
  matchesRecharts("tooltip__pie-keyboard"));

test("polar tooltip: with trigger click only a click on a pie sector shows it, and leaving keeps it", () =>
  matchesRecharts("tooltip__pie-click"));

test("polar tooltip: activate and deactivate carry the radar category, its label and both series", () => withScenario("tooltip__radar-hover", async (page) => {
  await page.evaluate(() => {
    window.__chartEvents = [];
    for (const name of ["activate", "deactivate"]) {
      document.addEventListener(`chadcn--chart:${name}`, (event) => window.__chartEvents.push({ name, ...event.detail }));
    }
  });
  await step(page, at(160, 50));
  await step(page, at(203, 75));
  await step(page, LEAVE);
  const events = await page.evaluate(() => window.__chartEvents);
  assert.deepEqual(events.map((event) => [event.name, event.index, event.label]), [
    ["activate", 0, "January"], ["activate", 1, "February"], ["deactivate", 1, null],
  ]);
  assert.deepEqual(events[1].payload.map((item) => [item.dataKey, item.value]), [["desktop", 305], ["mobile", 200]]);
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

test("polar tooltip: a finger on a pie sector shows it (recharts reads the sector's item index under a touch)", () => withScenario("tooltip__pie-hover", async (page) => {
  await pointerMoveAs(page, "touch", { x: 118, y: 72 });
  assert.equal((await chartState(page)).text, "Safari200");
}));

test("polar tooltip: a finger on a radar activates the category, off the radius it changes nothing", () => withScenario("tooltip__radar-hover", async (page) => {
  await pointerMoveAs(page, "touch", { x: 203, y: 75 });
  assert.match((await chartState(page)).text, /^February/);
  await pointerMoveAs(page, "touch", { x: 160, y: 10 });
  assert.match((await chartState(page)).text, /^February/);
}));

test("polar tooltip: the Turbo snapshot holds no stale tooltip or cursor and the restore brings them back", () => withScenario("tooltip__radar-hover", async (page) => {
  await step(page, at(203, 75));
  const live = await chartState(page);
  assert.ok(live.cursor);

  const snapshot = await page.evaluate(async (chart) => {
    document.dispatchEvent(new Event("turbo:before-cache"));
    await new Promise((resolve) => setTimeout(resolve));
    const node = document.querySelector(chart);
    return {
      index: node.getAttribute("data-chadcn--chart-pointer-index-value"),
      children: node.querySelector(".recharts-tooltip-wrapper").childElementCount,
      cursors: node.querySelectorAll(".recharts-tooltip-cursor").length,
    };
  }, CHART);
  assert.deepEqual(snapshot, { index: "-1", children: 0, cursors: 0 });

  await page.locator(TOOLTIP).filter({ hasText: "February" }).waitFor();
  assert.deepEqual(await chartState(page), live);
}));

// The demo pages (dev/dummy, /design-system/chart-demo/<family>) draw a pie and a radial bar chart with `default_index`.
async function withDemo(family, fn) {
  const page = await openPath(await browserPromise, `/design-system/chart-demo/${family}`);
  try {
    const errors = consoleErrors(page);
    await fn(page);
    assert.deepEqual(errors, []);
    assert.deepEqual(page.jsErrors, []);
  } finally {
    await page.context().close();
  }
}

async function reinsert(page) {
  await page.evaluate(async (chart) => {
    const node = document.querySelector(chart);
    const parent = node.parentElement;
    node.remove();
    await new Promise((resolve) => setTimeout(resolve));
    parent.append(node);
  }, CHART);
  await settle(page);
}

for (const family of ["pie", "radial"]) {
  test(`polar tooltip: a ${family}'s default_index tooltip is placed at rest, a pointer replaces it, and a re-inserted chart shows it again`, () => withDemo(family, async (page) => {
    await page.locator(TOOLTIP).waitFor({ state: "visible" });
    const rest = await chartState(page);
    assert.match(rest.transform, /^translate\(/, "the controller placed the server-drawn tooltip");

    const box = await page.locator(PLOT).boundingBox();
    assert.equal(await page.locator(CHART).getAttribute("data-chadcn--chart-pointer-active-value"), "false", "control: no pointer activation at rest");
    const inside = await page.locator(`${CHART} ${family === "pie" ? ".recharts-pie-sector" : ".recharts-radial-bar-sector"}`).first().evaluate((node) => {
      const shape = node.querySelector("path") ?? node;
      const { x, y, width, height } = shape.getBoundingClientRect();
      for (let step = 0; step < 400; step += 1) {
        const point = { x: x + width * (((step * 7) % 20) + 0.5) / 20, y: y + height * (Math.floor(step / 20) + 0.5) / 20 };
        const local = new DOMPoint(point.x, point.y).matrixTransform(shape.getScreenCTM().inverse());
        if (shape.isPointInFill(local)) return point;
      }
      return null;
    });
    assert.ok(inside, "a point inside the first sector");
    await page.mouse.move(inside.x, inside.y);
    await settle(page);
    assert.equal(await page.locator(CHART).getAttribute("data-chadcn--chart-pointer-active-value"), "true", "the pointer activated a shape");
    assert.notEqual((await chartState(page)).text, "", "a pointer activation shows a tooltip");
    await page.mouse.move(box.x - 20, box.y - 20);
    await settle(page);

    await reinsert(page);
    await page.locator(TOOLTIP).waitFor({ state: "visible" });
    assert.deepEqual(await chartState(page), rest);
  }));
}
