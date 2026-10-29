import test, { after } from "node:test";
import { assert, consoleErrors, launch, openPath, settle } from "./support.mjs";

// chadcn--chart (dev/port/specs/chart.md, "Tooltip" and "Behavior"): what the parity scenarios (dev/port/scenarios/chart.json,
// interaction__*) cannot express: the public events, touch, Turbo cache restore, the click trigger, the precedence of the
// pointer / keyboard / default_index states and what a hostile template cannot do. Runs on dev/dummy's chart-demo pages (Turbo
// Drive on); the hover and keyboard steps against recharts itself are scenarios.
const PAGE = (family) => `/design-system/chart-demo/${family}`;
const CHART = "[data-slot=chart]";
const PLOT = `${CHART} .recharts-wrapper`;
const SURFACE = `${CHART} .recharts-surface`;
const TOOLTIP = `${CHART} .recharts-tooltip-wrapper`;
const CURSOR = `${CHART} .recharts-tooltip-cursor`;
const ACTIVE_DOT = `${CHART} .recharts-active-dot`;
const VALUE = (name) => `data-chadcn--chart-${name}-value`;

const browserPromise = launch();
after(async () => { await (await browserPromise).close(); });

async function withPage(family, fn, { touch = false } = {}) {
  const page = await openPath(await browserPromise, PAGE(family), { touch });
  try {
    const errors = consoleErrors(page);
    await fn(page);
    assert.deepEqual(errors, []);
    assert.deepEqual(page.jsErrors, []);
  } finally {
    await page.context().close();
  }
}

const ticks = async (page) => JSON.parse(await page.locator(CHART).getAttribute(VALUE("ticks")));
const attribute = (page, name) => page.locator(CHART).getAttribute(VALUE(name));

async function hoverCategory(page, index, y = 60) {
  const box = await page.locator(PLOT).boundingBox();
  const tick = (await ticks(page))[index];
  await page.mouse.move(box.x + tick.coordinate, box.y + y);
}

const showsTooltip = (page) => page.locator(TOOLTIP).waitFor({ state: "visible" });
const hidesTooltip = (page) => page.locator(TOOLTIP).waitFor({ state: "hidden" });
const tooltipText = (page) => page.locator(TOOLTIP).textContent();

// Dispatches a pointer event the way the browser does for a finger: Playwright's mouse has no touch pointerType.
const pointer = (page, type, { index, y = 60, pointerType = "touch" }) => page.evaluate(async ({ type, index, y, pointerType, chart, plot }) => {
  const value = JSON.parse(document.querySelector(chart).getAttribute("data-chadcn--chart-ticks-value"));
  const wrapper = document.querySelector(plot);
  const rect = wrapper.getBoundingClientRect();
  const clientX = rect.left + (index === undefined ? -20 : value[index].coordinate);
  wrapper.dispatchEvent(new PointerEvent(type, { bubbles: true, pointerType, clientX, clientY: rect.top + y }));
}, { type, index, y, pointerType, chart: CHART, plot: PLOT });

const recordEvents = (page) => page.evaluate(() => {
  window.__chartEvents = [];
  for (const name of ["activate", "deactivate"]) {
    document.addEventListener(`chadcn--chart:${name}`, (event) => window.__chartEvents.push({ name, ...event.detail, target: event.target.dataset.slot }));
  }
});
const recordedEvents = (page) => page.evaluate(() => window.__chartEvents);

test("chart: the pointer shows the tooltip of the nearest category with its cursor, and moving on swaps them", () => withPage("bar", async (page) => {
  assert.equal(await page.locator(TOOLTIP).isHidden(), true, "hidden at rest");
  assert.equal(await page.locator(TOOLTIP).evaluate((el) => el.childElementCount), 0, "and empty");
  assert.equal(await page.locator(CURSOR).count(), 0);

  await hoverCategory(page, 1);
  await showsTooltip(page);
  assert.match(await tooltipText(page), /February/);
  assert.equal(await page.locator(CURSOR).count(), 1);
  assert.equal(await page.locator(CURSOR).evaluate((el) => el.namespaceURI), "http://www.w3.org/2000/svg", "built as SVG, not parsed as HTML");
  assert.equal(await page.locator(CURSOR).evaluate((el) => el.parentElement.getAttribute("class")), "recharts-zIndex-layer_200");

  await hoverCategory(page, 4);
  await page.locator(TOOLTIP).filter({ hasText: "May" }).waitFor();
  assert.equal(await page.locator(CURSOR).count(), 1, "one cursor at a time");
}));

test("chart: the wrapper is placed next to the pointer and flips at the right edge", () => withPage("bar", async (page) => {
  await hoverCategory(page, 0);
  await showsTooltip(page);
  assert.ok((await page.locator(TOOLTIP).evaluate((el) => el.classList.contains("recharts-tooltip-wrapper-right"))), "opens to the right of the first category");
  assert.match(await page.locator(TOOLTIP).evaluate((el) => el.style.transform), /^translate\(.+px, .+px\)$/);

  await hoverCategory(page, 5);
  await page.locator(`${TOOLTIP}.recharts-tooltip-wrapper-left`).waitFor();
  const [tooltip, plot] = await Promise.all([page.locator(TOOLTIP).boundingBox(), page.locator(PLOT).boundingBox()]);
  assert.ok(tooltip.x + tooltip.width <= plot.x + plot.width + 1, "stays inside the chart");
}));

test("chart: the mounted tooltip is a fresh clone of the template content and the template stays inert", () => withPage("bar", async (page) => {
  await hoverCategory(page, 2);
  await showsTooltip(page);
  const result = await page.evaluate(() => {
    const template = document.querySelector('template[data-index="2"]');
    const mounted = document.querySelector(".recharts-tooltip-wrapper").firstElementChild;
    return { sameMarkup: mounted.isEqualNode(template.content.firstElementChild), sameNode: mounted === template.content.firstElementChild, templates: document.querySelectorAll("template[data-index]").length };
  });
  assert.equal(result.sameMarkup, true);
  assert.equal(result.sameNode, false, "a clone, so the template can be mounted again");
  assert.equal(result.templates, 6);
}));

test("chart: a hostile template cannot add a tag or an attribute to the chart", () => withPage("bar", async (page) => {
  await page.evaluate(() => {
    const template = document.querySelector('template[data-index="1"]');
    template.dataset.cursor = JSON.stringify({ tag: "script", layer: 200, attrs: { d: "M 0,0" } });
    template.dataset.activeDots = JSON.stringify([{ cx: "5", cy: "5", r: "4", onclick: "window.__hacked = 1", href: "javascript:window.__hacked = 2", style: "fill: red" }]);
  });
  await hoverCategory(page, 1);
  await showsTooltip(page);
  assert.equal(await page.locator(`${SURFACE} script`).count(), 0, "a tag outside path and circle is ignored");
  assert.deepEqual(await page.locator(`${ACTIVE_DOT} circle`).evaluate((el) => el.getAttributeNames().sort()), ["class", "cx", "cy", "r"], "no onclick, href or style on a dot");

  await page.evaluate(() => {
    document.querySelector('template[data-index="3"]').dataset.cursor = JSON.stringify({
      tag: "path", layer: 200, attrs: { d: "M 0,0 h 5", onmouseover: "window.__hacked = 3", href: "javascript:1", style: "fill: red", fill: "#abc", "stroke-width": 2 },
    });
  });
  await hoverCategory(page, 3);
  await page.locator(TOOLTIP).filter({ hasText: "April" }).waitFor();
  const attributes = await page.locator(`${SURFACE} [data-chadcn--chart-target=cursor]`).evaluate((el) => el.getAttributeNames().sort());
  assert.deepEqual(attributes, ["d", "data-chadcn--chart-target", "fill", "stroke-width"], "only the whitelisted attributes were set");
  assert.equal(await page.evaluate(() => window.__hacked), undefined);
}));

test("chart: pointerleave hides the tooltip, the cursor and the dots", () => withPage("bar", async (page) => {
  await hoverCategory(page, 2);
  await showsTooltip(page);
  await page.mouse.move(2, 2);
  await hidesTooltip(page);
  assert.equal(await page.locator(CURSOR).count(), 0);
  assert.equal(await page.locator(TOOLTIP).evaluate((el) => el.childElementCount), 0);
  assert.equal(await attribute(page, "pointer-index"), "2", "the index is kept");
  assert.equal(await attribute(page, "pointer-active"), "false");
}));

test("chart: after the first hover default_index never returns, not even after leaving", () => withPage("line", async (page) => {
  await showsTooltip(page);
  assert.match(await tooltipText(page), /March/, "default_index 2 at rest");
  assert.equal(await page.locator(ACTIVE_DOT).count(), 1);

  await hoverCategory(page, 4);
  await page.locator(TOOLTIP).filter({ hasText: "May" }).waitFor();
  assert.equal(await page.locator(ACTIVE_DOT).count(), 1, "the dot follows");
  await page.mouse.move(2, 2);
  await hidesTooltip(page);
  assert.equal(await page.locator(ACTIVE_DOT).count(), 0);
  assert.equal(await page.locator(CURSOR).count(), 0);
}));

test("chart: activate and deactivate bubble with the index, the label and the payload", () => withPage("bar", async (page) => {
  await recordEvents(page);
  await hoverCategory(page, 3);
  await showsTooltip(page);
  await page.mouse.move(2, 2);
  await hidesTooltip(page);

  const [activate, deactivate] = await recordedEvents(page);
  assert.equal(activate.name, "activate");
  assert.equal(activate.index, 3);
  assert.equal(activate.label, "April");
  assert.deepEqual(activate.payload.map((item) => [item.name, item.value]), [["desktop", 73], ["mobile", 190]]);
  assert.equal(activate.target, "chart", "dispatched on the controller element and bubbled to the document");
  assert.equal(deactivate.name, "deactivate");
  assert.equal(deactivate.index, 3);
}));

test("chart: a touch pointermove takes the pointer path and a finger lifting is not a leave", () => withPage("bar", async (page) => {
  await pointer(page, "pointermove", { index: 2 });
  await showsTooltip(page);
  assert.match(await tooltipText(page), /March/);

  await pointer(page, "pointerleave", { index: 2 });
  await pointer(page, "pointermove", { index: undefined });
  assert.equal(await page.locator(TOOLTIP).isVisible(), true, "a touch outside the plot and a touch leave do nothing");

  await pointer(page, "pointermove", { index: 5 });
  await page.locator(TOOLTIP).filter({ hasText: "June" }).waitFor();
  await pointer(page, "pointermove", { index: undefined, pointerType: "mouse" });
  await hidesTooltip(page);
}, { touch: true }));

test("chart: a mouse moving over the margin of the plot clears the hover", () => withPage("bar", async (page) => {
  await hoverCategory(page, 1);
  await showsTooltip(page);
  const box = await page.locator(PLOT).boundingBox();
  await page.mouse.move(box.x + 1, box.y + 1);
  await hidesTooltip(page);
}));

test("chart: with trigger click only a click shows the tooltip and leaving does not hide it", () => withPage("area", async (page) => {
  await hoverCategory(page, 1);
  await settle(page);
  assert.equal(await page.locator(TOOLTIP).isHidden(), true, "hover alone shows nothing");

  await page.mouse.down();
  await page.mouse.up();
  await showsTooltip(page);
  assert.match(await tooltipText(page), /February/);
  await page.mouse.move(2, 2);
  await settle(page);
  assert.equal(await page.locator(TOOLTIP).isVisible(), true, "mouseLeaveChart clears the hover interaction only");
}));

test("chart: focus activates category 0, the arrows step and stop at the ends, Enter toggles and other keys do nothing", () => withPage("bar", async (page) => {
  await page.locator(SURFACE).focus();
  await showsTooltip(page);
  assert.match(await tooltipText(page), /January/);
  await page.keyboard.press("ArrowLeft");
  assert.equal(await attribute(page, "keyboard-index"), "0", "stops at the first tick");

  await page.keyboard.press("ArrowRight");
  await page.locator(TOOLTIP).filter({ hasText: "February" }).waitFor();
  await page.keyboard.press("a");
  assert.equal(await attribute(page, "keyboard-index"), "1");

  await page.keyboard.press("Enter");
  await hidesTooltip(page);
  assert.equal(await attribute(page, "keyboard-index"), "1", "toggling keeps the index");
  await page.keyboard.press("Enter");
  await showsTooltip(page);

  for (let step = 0; step < 6; step += 1) await page.keyboard.press("ArrowRight");
  assert.equal(await attribute(page, "keyboard-index"), "5", "stops at the last tick");
}));

test("chart: blur hides the tooltip and a remembered index is not activated again by focus", () => withPage("bar", async (page) => {
  await page.locator(SURFACE).focus();
  await page.keyboard.press("ArrowRight");
  await page.locator(TOOLTIP).filter({ hasText: "February" }).waitFor();

  await page.locator(SURFACE).blur();
  await hidesTooltip(page);
  assert.equal(await attribute(page, "keyboard-index"), "1");

  await page.locator(SURFACE).focus();
  await settle(page);
  assert.equal(await page.locator(TOOLTIP).isHidden(), true, "focus does not re-activate a remembered index");
  await page.keyboard.press("ArrowRight");
  await page.locator(TOOLTIP).filter({ hasText: "March" }).waitFor();
}));

test("chart: Escape hides the tooltip until the active coordinate changes and leaves the keyboard index alone", () => withPage("bar", async (page) => {
  await page.locator(SURFACE).focus();
  await page.keyboard.press("ArrowRight");
  await page.locator(TOOLTIP).filter({ hasText: "February" }).waitFor();

  await page.keyboard.press("Escape");
  await hidesTooltip(page);
  assert.equal(await attribute(page, "keyboard-index"), "1");
  assert.equal(await attribute(page, "keyboard-active"), "true");

  await page.keyboard.press("ArrowRight");
  await page.locator(TOOLTIP).filter({ hasText: "March" }).waitFor();
}));

test("chart: Escape is heard on the document, not only on the chart", () => withPage("bar", async (page) => {
  await hoverCategory(page, 1);
  await showsTooltip(page);
  await page.evaluate(() => document.body.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true })));
  await hidesTooltip(page);
  await hoverCategory(page, 2);
  await page.locator(TOOLTIP).filter({ hasText: "March" }).waitFor();
}));

test("chart: the pointer wins over the keyboard, and a pointer activation turns the keyboard's active flag off", () => withPage("line", async (page) => {
  await page.locator(SURFACE).focus();
  await page.locator(TOOLTIP).filter({ hasText: "January" }).waitFor();
  assert.equal(await attribute(page, "keyboard-active"), "true", "keyboard before default_index (2)");

  await hoverCategory(page, 4);
  await page.locator(TOOLTIP).filter({ hasText: "May" }).waitFor();
  assert.equal(await attribute(page, "keyboard-active"), "false");
  assert.equal(await attribute(page, "keyboard-index"), "0", "its index is remembered");
}));

test("chart: reduced motion drops the transition of an auto animated tooltip", () => withPage("bar", async (page) => {
  await hoverCategory(page, 1);
  await showsTooltip(page);
  assert.equal(await page.locator(TOOLTIP).evaluate((el) => el.style.transition), "transform 400ms");

  await page.emulateMedia({ reducedMotion: "reduce" });
  await hoverCategory(page, 2);
  await page.locator(TOOLTIP).filter({ hasText: "March" }).waitFor();
  assert.equal(await page.locator(TOOLTIP).evaluate((el) => el.style.transition), "");
}));

test("chart: the Turbo snapshot holds no stale tooltip and the restore brings the live one back", () => withPage("bar", async (page) => {
  await hoverCategory(page, 3);
  await showsTooltip(page);

  const snapshot = await page.evaluate(async () => {
    document.dispatchEvent(new Event("turbo:before-cache"));
    await new Promise((resolve) => setTimeout(resolve));
    const chart = document.querySelector("[data-slot=chart]");
    const wrapper = chart.querySelector(".recharts-tooltip-wrapper");
    return {
      visibility: wrapper.style.visibility,
      children: wrapper.childElementCount,
      cursors: chart.querySelectorAll(".recharts-tooltip-cursor").length,
      pointerIndex: chart.getAttribute("data-chadcn--chart-pointer-index-value"),
      pointerActive: chart.getAttribute("data-chadcn--chart-pointer-active-value"),
    };
  });
  assert.deepEqual(snapshot, { visibility: "hidden", children: 0, cursors: 0, pointerIndex: "-1", pointerActive: "false" });

  await page.locator(TOOLTIP).filter({ hasText: "April" }).waitFor();
  assert.equal(await attribute(page, "pointer-index"), "3", "restored");
  assert.equal(await page.locator(CURSOR).count(), 1);
}));

test("chart: the Turbo snapshot of a default_index chart shows the default tooltip, not the hovered one", () => withPage("line", async (page) => {
  await hoverCategory(page, 4);
  await page.locator(TOOLTIP).filter({ hasText: "May" }).waitFor();

  const text = await page.evaluate(async () => {
    document.dispatchEvent(new Event("turbo:before-cache"));
    await new Promise((resolve) => setTimeout(resolve));
    return document.querySelector(".recharts-tooltip-wrapper").textContent;
  });
  assert.match(text, /March/);
  assert.doesNotMatch(text, /May/);
}));

test("chart: a snapshot restored by Turbo (the host re-inserted as saved) connects, adopts the server tooltip and works", () => withPage("line", async (page) => {
  const html = await page.evaluate(async () => {
    document.dispatchEvent(new Event("turbo:before-cache"));
    await new Promise((resolve) => setTimeout(resolve));
    return document.querySelector("[data-slot=chart]").outerHTML;
  });
  await page.evaluate((markup) => {
    const chart = document.querySelector("[data-slot=chart]");
    chart.insertAdjacentHTML("afterend", markup);
    chart.remove();
  }, html);
  await showsTooltip(page);
  assert.match(await tooltipText(page), /March/);
  assert.equal(await page.locator(CURSOR).count(), 1);
  assert.equal(await page.locator(ACTIVE_DOT).count(), 1);

  await hoverCategory(page, 0);
  await page.locator(TOOLTIP).filter({ hasText: "January" }).waitFor();
}));

test("chart: a real Turbo visit away and back leaves no error and a working chart", () => withPage("bar", async (page) => {
  await hoverCategory(page, 1);
  await showsTooltip(page);
  await page.locator("#to-other").click();
  await page.locator("#to-bar").waitFor();
  await page.locator("#to-bar").click();
  await page.locator(PLOT).waitFor();

  await hoverCategory(page, 2);
  await page.locator(TOOLTIP).filter({ hasText: "March" }).waitFor();
}));

test("chart: a removed chart stops listening to the document", () => withPage("bar", async (page) => {
  await hoverCategory(page, 1);
  await showsTooltip(page);
  const visibility = await page.evaluate(async () => {
    const chart = document.querySelector("[data-slot=chart]");
    const wrapper = chart.querySelector(".recharts-tooltip-wrapper");
    chart.remove();
    await new Promise((resolve) => setTimeout(resolve));
    wrapper.style.visibility = "visible"; // the control: only a live listener would hide it again
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    return wrapper.style.visibility;
  });
  assert.equal(visibility, "visible", "the detached chart did not react to Escape");
}));

test("chart: disconnect leaves the server state, so a re-inserted chart starts clean", () => withPage("bar", async (page) => {
  await hoverCategory(page, 3);
  await page.locator(TOOLTIP).filter({ hasText: "April" }).waitFor();

  const detached = await page.evaluate(async () => {
    const chart = document.querySelector("[data-slot=chart]");
    window.__chartParent = chart.parentElement;
    window.__chartNode = chart;
    chart.remove();
    await new Promise((resolve) => setTimeout(resolve));
    const wrapper = chart.querySelector(".recharts-tooltip-wrapper");
    return {
      pointerIndex: chart.getAttribute("data-chadcn--chart-pointer-index-value"),
      pointerActive: chart.getAttribute("data-chadcn--chart-pointer-active-value"),
      visibility: wrapper.style.visibility,
      children: wrapper.childElementCount,
      cursors: chart.querySelectorAll(".recharts-tooltip-cursor").length,
    };
  });
  assert.deepEqual(detached, { pointerIndex: "-1", pointerActive: "false", visibility: "hidden", children: 0, cursors: 0 });

  await page.evaluate(() => window.__chartParent.append(window.__chartNode));
  await settle(page);
  assert.equal(await page.locator(TOOLTIP).isHidden(), true, "no stale tooltip after the re-insert");
  assert.equal(await page.locator(CURSOR).count(), 0);

  await hoverCategory(page, 2);
  await page.locator(TOOLTIP).filter({ hasText: "March" }).waitFor();
}));

test("chart: a pointer move inside the snapshot window does not reach the cached page", () => withPage("bar", async (page) => {
  const snapshot = await page.evaluate(async ({ chart, plot }) => {
    const ticks = JSON.parse(document.querySelector(chart).getAttribute("data-chadcn--chart-ticks-value"));
    const wrapper = document.querySelector(plot);
    const rect = wrapper.getBoundingClientRect();
    document.dispatchEvent(new Event("turbo:before-cache"));
    wrapper.dispatchEvent(new PointerEvent("pointermove", { bubbles: true, pointerType: "mouse", clientX: rect.left + ticks[2].coordinate, clientY: rect.top + 60 }));
    await new Promise((resolve) => setTimeout(resolve));
    const tooltip = document.querySelector(chart).querySelector(".recharts-tooltip-wrapper");
    return { visibility: tooltip.style.visibility, children: tooltip.childElementCount };
  }, { chart: CHART, plot: PLOT });
  assert.deepEqual(snapshot, { visibility: "hidden", children: 0 });

  await settle(page);
  await hoverCategory(page, 2);
  await page.locator(TOOLTIP).filter({ hasText: "March" }).waitFor();
}));

test("chart: a second turbo:before-cache inside the window keeps the live tooltip for the restore", () => withPage("bar", async (page) => {
  await hoverCategory(page, 3);
  await page.locator(TOOLTIP).filter({ hasText: "April" }).waitFor();

  await page.evaluate(async () => {
    document.dispatchEvent(new Event("turbo:before-cache"));
    await new Promise((resolve) => setTimeout(resolve));
    document.dispatchEvent(new Event("turbo:before-cache"));
  });
  await page.locator(TOOLTIP).filter({ hasText: "April" }).waitFor();
  assert.equal(await attribute(page, "pointer-index"), "3");
}));

test("chart: position, wrapperStyle and tooltipActive reach the wrapper", () => withPage("bar", async (page) => {
  await page.evaluate((chart) => {
    const element = document.querySelector(chart);
    element.setAttribute("data-chadcn--chart-position-value", JSON.stringify({ x: 7, y: 9 }));
    element.setAttribute("data-chadcn--chart-wrapper-style-value", JSON.stringify({ "z-index": "42" }));
  }, CHART);
  await hoverCategory(page, 2);
  await showsTooltip(page);
  assert.equal(await page.locator(TOOLTIP).evaluate((el) => el.style.transform), "translate(7px, 9px)", "a fixed position wins over the pointer");
  assert.equal(await page.locator(TOOLTIP).evaluate((el) => el.style.zIndex), "42");

  await page.evaluate((chart) => document.querySelector(chart).setAttribute("data-chadcn--chart-tooltip-active-value", "false"), CHART);
  await hoverCategory(page, 4);
  await hidesTooltip(page);
  assert.equal(await attribute(page, "pointer-index"), "4", "the pointer still moved");
}));
