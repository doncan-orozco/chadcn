import fs from "node:fs";
import test, { after } from "node:test";
import { serversFile } from "./dev_kit.mjs";
import { PHLEX, assert, consoleErrors, launch, openPath, settle } from "./support.mjs";

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
  // Turbo first renders the cached snapshot as a preview and swaps the fresh page in afterwards: hovering the preview loses the tooltip.
  await page.waitForURL(`**${PAGE("bar")}`);
  await page.locator("html:not([data-turbo-preview])").waitFor({ state: "attached" });
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

// A polar chart publishes only its tooltip values and no data-action: the controller keeps the server-drawn default_index tooltip.
const tooltipState = (page) => page.locator(TOOLTIP).evaluate((el) => ({ visibility: el.style.visibility, transform: el.style.transform, text: el.textContent.trim() }));

async function pokeChart(page) {
  const box = await page.locator(PLOT).boundingBox();
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.move(box.x + box.width / 3, box.y + box.height / 3);
  await page.locator(SURFACE).focus();
  await page.keyboard.press("ArrowRight");
  await page.keyboard.press("Enter");
  await page.keyboard.press("Escape");
}

test("chart: a pie is an item tooltip, the controller leaves the server-drawn tooltip alone and nothing moves it", () => withPage("pie", async (page) => {
  assert.equal(await attribute(page, "tooltip-event-type"), "item");
  assert.equal(await attribute(page, "ticks"), "[]");
  assert.equal(await page.locator(PLOT).getAttribute("data-action"), null);
  await showsTooltip(page);
  const before = await tooltipState(page);
  assert.match(before.text, /Safari/);
  assert.equal(before.transform, "", "an item tooltip is never placed by the controller");

  await pokeChart(page);
  await settle(page);
  assert.deepEqual(await tooltipState(page), before);
  assert.equal(await attribute(page, "pointer-index"), "-1");
  assert.equal(await attribute(page, "keyboard-index"), "-1");
}));

test("chart: a radar keeps, places and restores its default_index tooltip, and no pointer or key moves it", () => withPage("radar", async (page) => {
  assert.equal(await attribute(page, "tooltip-event-type"), "axis");
  assert.equal(await attribute(page, "ticks"), "[]");
  assert.equal(await page.locator(PLOT).getAttribute("data-action"), null);
  await showsTooltip(page);
  await page.locator(TOOLTIP).filter({ hasText: "February" }).waitFor();
  const before = await tooltipState(page);
  assert.equal(before.visibility, "visible");
  assert.match(before.transform, /^translate\(/, "the controller placed the wrapper, which the server never does");
  assert.ok(before.text.length > 0);

  await pokeChart(page);
  await settle(page);
  assert.deepEqual(await tooltipState(page), before);
  assert.equal(await attribute(page, "pointer-index"), "-1");
  assert.equal(await attribute(page, "keyboard-index"), "-1");
}));

test("chart: a re-inserted radar shows its default_index tooltip again with one active dot", () => withPage("radar", async (page) => {
  await page.locator(TOOLTIP).filter({ hasText: "February" }).waitFor();
  assert.equal(await page.locator(ACTIVE_DOT).count(), 1);

  await page.evaluate(async () => {
    const chart = document.querySelector("[data-slot=chart]");
    const parent = chart.parentElement;
    chart.remove();
    await new Promise((resolve) => setTimeout(resolve));
    parent.append(chart);
  });
  await settle(page);
  await showsTooltip(page);
  await page.locator(TOOLTIP).filter({ hasText: "February" }).waitFor();
  assert.equal(await page.locator(ACTIVE_DOT).count(), 1, "the server-drawn dot is the activeDots target, so it is not drawn twice");
  assert.match((await tooltipState(page)).transform, /^translate\(/);
}));

test("chart: a re-inserted pie keeps its server-drawn default_index tooltip, an inert controller leaves the DOM alone", () => withPage("pie", async (page) => {
  await showsTooltip(page);
  assert.match(await tooltipText(page), /Safari/);

  const detached = await page.evaluate(async () => {
    const chart = document.querySelector("[data-slot=chart]");
    window.__chartParent = chart.parentElement;
    window.__chartNode = chart;
    chart.remove();
    await new Promise((resolve) => setTimeout(resolve));
    const wrapper = chart.querySelector(".recharts-tooltip-wrapper");
    return { visibility: wrapper.style.visibility, children: wrapper.childElementCount };
  });
  assert.equal(detached.visibility, "visible", "the inert controller did not hide the wrapper");
  assert.ok(detached.children > 0, "the inert controller did not empty the wrapper");

  await page.evaluate(() => window.__chartParent.append(window.__chartNode));
  await settle(page);
  await showsTooltip(page);
  assert.match(await tooltipText(page), /Safari/);
}));

test("chart: a radial bar keeps and places its default_index tooltip, nothing moves it and a re-insert shows it again", () => withPage("radial", async (page) => {
  assert.equal(await attribute(page, "tooltip-event-type"), "axis");
  assert.equal(await attribute(page, "ticks"), "[]");
  assert.equal(await page.locator(PLOT).getAttribute("data-action"), null);
  await showsTooltip(page);
  const before = await tooltipState(page);
  assert.equal(before.visibility, "visible");
  assert.match(before.transform, /^translate\(/, "the controller placed the wrapper, which the server never does");
  assert.ok(before.text.length > 0);

  await pokeChart(page);
  await settle(page);
  assert.deepEqual(await tooltipState(page), before);
  assert.equal(await attribute(page, "pointer-index"), "-1");
  assert.equal(await attribute(page, "keyboard-index"), "-1");

  await page.evaluate(async () => {
    const chart = document.querySelector("[data-slot=chart]");
    const parent = chart.parentElement;
    chart.remove();
    await new Promise((resolve) => setTimeout(resolve));
    parent.append(chart);
  });
  await settle(page);
  await showsTooltip(page);
  assert.deepEqual(await tooltipState(page), before);
}));

test("chart: the Turbo snapshot of a radar holds the server tooltip and the restore places it again with one active dot", () => withPage("radar", async (page) => {
  await page.locator(TOOLTIP).filter({ hasText: "February" }).waitFor();

  const snapshot = await page.evaluate(async () => {
    document.dispatchEvent(new Event("turbo:before-cache"));
    await new Promise((resolve) => setTimeout(resolve));
    const chart = document.querySelector("[data-slot=chart]");
    const wrapper = chart.querySelector(".recharts-tooltip-wrapper");
    return { text: wrapper.textContent, dots: chart.querySelectorAll(".recharts-active-dot").length, visibility: wrapper.style.visibility };
  });
  assert.match(snapshot.text, /February/, "the snapshot holds the server tooltip");
  assert.equal(snapshot.dots, 1);
  assert.equal(snapshot.visibility, "visible");

  await settle(page);
  await showsTooltip(page);
  assert.match((await tooltipState(page)).transform, /^translate\(/);
  assert.match(await tooltipText(page), /February/);
  assert.equal(await page.locator(ACTIVE_DOT).count(), 1);
}));

// --- Resize (dev/port/specs/chart.md, "Behavior", "Resize and re-measure"; item #107) --------------------------------------------
//
// The host's answer to the re-layout request is the Phlex parity page of the scenario at the requested width (resize__<family>-<width>
// in dev/port/scenarios/chart.json, which G2 compares with recharts at that size). Those pages render a container without
// relayout_url:, so the test adds the three re-layout values a host with relayout_url: writes (test/chadcn/chart/container_relayout_test.rb
// proves the container writes them), to the answer and to the start page. The swapped chart is compared with recharts resized in the
// browser, under G2's rules (observed selectors, data and controller attributes ignored, numbers within 1e-3 px).
const REACT = process.env.PARITY_REACT_URL || JSON.parse(fs.readFileSync(serversFile(), "utf8")).vite?.url;
const RELAYOUT_PATH = "/chart-relayout";
const RELAYOUT_URL = `${RELAYOUT_PATH}?source=test`;
const RESIZE_HEIGHTS = { 320: 200, 480: 300, 640: 400 };
const PARITY_TEXT_METRICS = { textHeight: 18, textCharWidth: 0.6 };
const RESIZE_OBSERVE = {
  bar: [".recharts-wrapper", "[class^=\"recharts-zIndex-layer_\"]", ".recharts-cartesian-axis-tick-value, .recharts-cartesian-axis-tick-value tspan", ".recharts-cartesian-grid line", ".recharts-bar-rectangle path"],
  pie: [".recharts-wrapper", ".recharts-pie-sector", "[class^=\"recharts-zIndex-layer_\"]"],
};
const IGNORED_ATTRIBUTE = /^(class|style|id|data-controller|data-action|data-.*-target|data-.*-value|tabindex-managed)$|^data-chadcn--/;
const scenarioPath = (family, width) => `/design-system/parity/chart/resize__${family}-${width}`;
const relayoutValues = (width, url = RELAYOUT_URL) => ({
  "relayout-url": url,
  dimension: JSON.stringify({ width, height: RESIZE_HEIGHTS[width] }),
  "text-metrics": JSON.stringify(PARITY_TEXT_METRICS),
});

const escapeAttribute = (text) => text.replaceAll("&", "&amp;").replaceAll('"', "&quot;");

function withRelayoutValues(html, family, width) {
  const marker = `data-chart="chart-resize-${family}"`;
  assert.ok(html.includes(marker), `the parity page holds ${marker}`);
  const attributes = Object.entries(relayoutValues(width)).map(([name, value]) => ` ${VALUE(name)}="${escapeAttribute(value)}"`).join("");
  return html.replace(marker, `${marker}${attributes}`);
}

// Answers GET /chart-relayout like a host: the chart at the requested width, or `answer(width)` -> { status, body, width }.
async function answerRelayout(page, family, { delays = [], answer = null } = {}) {
  const requests = [];
  await page.route((url) => url.pathname === RELAYOUT_PATH, async (route) => {
    const url = new URL(route.request().url());
    const number = requests.push(Object.fromEntries(url.searchParams));
    const delay = delays[number - 1] ?? 0;
    if (delay) await new Promise((resolve) => setTimeout(resolve, delay));
    const requested = Number(url.searchParams.get("chart[width]"));
    const custom = answer?.(requested) ?? {};
    try {
      if (custom.body !== undefined || custom.status) return await route.fulfill({ status: custom.status ?? 200, contentType: "text/html", body: custom.body ?? "" });
      const width = custom.width ?? requested;
      const response = await route.fetch({ url: `${PHLEX}${scenarioPath(family, width)}` });
      await route.fulfill({ response, body: withRelayoutValues(await response.text(), family, width) });
    } catch {
      // the controller aborted the request
    }
  });
  return requests;
}

async function withResizable(family, fn, { url = RELAYOUT_URL, loadErrors = false } = {}) {
  const page = await openPath(await browserPromise, scenarioPath(family, 320));
  try {
    const errors = consoleErrors(page);
    await page.evaluate(() => {
      window.__relayout = [];
      for (const name of ["relayout", "relayout-error"]) {
        document.addEventListener(`chadcn--chart:${name}`, (event) => window.__relayout.push({ name, ...event.detail }));
      }
    });
    await fn(page, () => enableRelayout(page, url));
    assert.deepEqual(errors.filter((text) => !(loadErrors && /Failed to load resource/.test(text))), []);
    assert.deepEqual(page.jsErrors, []);
  } finally {
    await page.context().close();
  }
}

const enableRelayout = (page, url) => page.evaluate(({ values }) => {
  const chart = document.querySelector("[data-slot=chart]");
  for (const [name, value] of Object.entries(values)) chart.setAttribute(`data-chadcn--chart-${name}-value`, value);
}, { values: relayoutValues(320, url) });

const resizeTo = (page, width, height = RESIZE_HEIGHTS[width]) => page.evaluate(({ width, height }) => {
  const chart = document.querySelector("[data-slot=chart]");
  chart.style.width = `${width}px`;
  chart.style.height = `${height}px`;
}, { width, height });

const relayoutEvents = (page) => page.evaluate(() => window.__relayout);
const waitForEvents = (page, count) => page.waitForFunction((count) => window.__relayout.length >= count, count);
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const wrapperStyle = (page) => page.locator(PLOT).getAttribute("style");

// The nodes G2 compares for these selectors, one list per page, in document order per selector.
function chartNodes(page, observe) {
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

function nodeDifferences(recharts, phlex) {
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

// recharts with shadcn's ChartContainer on the React parity page of the 320 scenario, its container resized and settled.
async function rechartsAt(family, width) {
  const context = await (await browserPromise).newContext({ viewport: { width: 1280, height: 720 } });
  try {
    const page = await context.newPage();
    await page.goto(`${REACT}/#/parity/chart/resize__${family}-320`, { waitUntil: "networkidle" });
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
    return await chartNodes(page, RESIZE_OBSERVE[family]);
  } finally {
    await context.close();
  }
}

test("chart: a chart with relayout_url: follows its container from 320 to 480 to 640 px and matches recharts at each width", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar");
  await enable();
  await pause(400);
  assert.deepEqual(requests, [], "no request while the box is the size the server laid out");

  await resizeTo(page, 480);
  await waitForEvents(page, 1);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 480, height: 300 }]);
  assert.deepEqual(nodeDifferences(await rechartsAt("bar", 480), await chartNodes(page, RESIZE_OBSERVE.bar)), []);

  await resizeTo(page, 640);
  await waitForEvents(page, 2);
  assert.deepEqual((await relayoutEvents(page))[1], { name: "relayout", width: 640, height: 400 });
  assert.deepEqual(nodeDifferences(await rechartsAt("bar", 640), await chartNodes(page, RESIZE_OBSERVE.bar)), []);
  assert.equal(await page.locator(CHART).count(), 1, "the chart was replaced, not added");
  assert.equal(await attribute(page, "dimension"), JSON.stringify({ width: 640, height: 400 }));

  assert.deepEqual(requests[0], {
    source: "test", "chart[id]": "resize-bar", "chart[width]": "480", "chart[height]": "300", "chart[text_height]": "18", "chart[text_char_width]": "0.6",
  });
  assert.equal(requests.length, 2);
}));

test("chart: a pie with relayout_url: follows its container to 640 px and matches recharts", () => withResizable("pie", async (page, enable) => {
  await answerRelayout(page, "pie");
  await enable();
  await resizeTo(page, 640);
  await waitForEvents(page, 1);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 640, height: 400 }]);
  assert.deepEqual(nodeDifferences(await rechartsAt("pie", 640), await chartNodes(page, RESIZE_OBSERVE.pie)), []);
}));

test("chart: resizing is debounced to one request, and the chart is scaled into its box until the answer arrives", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar", { delays: [600] });
  await enable();
  for (const width of [360, 400, 440, 480]) {
    await resizeTo(page, width, 300);
    await pause(30);
  }
  assert.match(await wrapperStyle(page), /width: 100%; height: 100%;/, "scaled while the re-layout is pending");
  await page.waitForFunction(() => document.querySelector("[data-slot=chart] .recharts-wrapper").parentElement.style.width === "100%");
  await waitForEvents(page, 1);
  assert.equal(requests.length, 1, "one request for the settled size");
  assert.equal(requests[0]["chart[width]"], "480");
  assert.match(await wrapperStyle(page), /width: 480px; height: 300px;/, "the answer is drawn at its own pixel size");
}));

test("chart: a new size aborts the pending request and only the last answer is swapped in", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar", { delays: [1000, 0] });
  await enable();
  await resizeTo(page, 480);
  await expectRequests(requests, 1);
  await resizeTo(page, 640);
  await waitForEvents(page, 1);
  await pause(1200);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 640, height: 400 }]);
  assert.equal(await attribute(page, "dimension"), JSON.stringify({ width: 640, height: 400 }));
}));

async function expectRequests(requests, count) {
  for (let attempt = 0; attempt < 100 && requests.length < count; attempt += 1) await pause(20);
  assert.equal(requests.length, count);
}

test("chart: the tooltip and the keyboard carry over the swap", () => withResizable("bar", async (page, enable) => {
  await answerRelayout(page, "bar");
  await enable();
  await page.locator(SURFACE).focus();
  await page.keyboard.press("ArrowRight");
  await page.locator(TOOLTIP).filter({ hasText: "February" }).waitFor({ state: "visible" });

  await resizeTo(page, 640);
  await waitForEvents(page, 1);
  assert.equal(await attribute(page, "keyboard-index"), "1");
  assert.equal(await attribute(page, "keyboard-active"), "true");
  assert.equal(await page.evaluate(() => document.activeElement.matches("[data-slot=chart] svg.recharts-surface")), true, "the new svg has the focus");
  await page.locator(TOOLTIP).filter({ hasText: "February" }).waitFor({ state: "visible" });
  await page.keyboard.press("ArrowRight");
  assert.equal(await attribute(page, "keyboard-index"), "2", "the keyboard keeps working on the new chart");
}));

test("chart: an error answer keeps the chart, reports relayout-error once and stops re-laying out", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar", { answer: () => ({ status: 500 }) });
  await enable();
  await resizeTo(page, 480);
  await waitForEvents(page, 1);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout-error", status: 500 }]);
  assert.equal(await attribute(page, "dimension"), JSON.stringify({ width: 320, height: 200 }), "the current chart stays");
  assert.match(await wrapperStyle(page), /width: 100%; height: 100%;/, "and stays scaled into its box");

  await resizeTo(page, 640);
  await pause(500);
  assert.equal(requests.length, 1, "no request loop");
  assert.equal((await relayoutEvents(page)).length, 1);
}, { loadErrors: true }));

test("chart: an answer without the chart, or with the chart at another size, is an error", async () => {
  await withResizable("bar", async (page, enable) => {
    await answerRelayout(page, "bar", { answer: () => ({ body: "<p>signed out</p>" }) });
    await enable();
    await resizeTo(page, 480);
    await waitForEvents(page, 1);
    assert.deepEqual(await relayoutEvents(page), [{ name: "relayout-error", status: 200 }]);
  });
  await withResizable("bar", async (page, enable) => {
    await answerRelayout(page, "bar", { answer: () => ({ width: 640 }) });
    await enable();
    await resizeTo(page, 480);
    await waitForEvents(page, 1);
    assert.deepEqual(await relayoutEvents(page), [{ name: "relayout-error", status: 200 }], "a host that ignored the parameters");
    assert.equal(await attribute(page, "dimension"), JSON.stringify({ width: 320, height: 200 }));
  });
});

test("chart: a cross-origin relayout_url is never requested", () => withResizable("bar", async (page, enable) => {
  const outside = [];
  await page.route("https://example.test/**", (route) => { outside.push(route.request().url()); return route.abort(); });
  await enable();
  await resizeTo(page, 480);
  await waitForEvents(page, 1);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout-error", status: 0 }]);
  assert.deepEqual(outside, []);
}, { url: "https://example.test/chart" }));

test("chart: disconnect before the debounce fires sends no request", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar", { delays: [500] });
  await enable();
  await resizeTo(page, 480);
  await page.evaluate(() => document.querySelector("[data-slot=chart]").remove());
  await pause(400);
  assert.equal(requests.length, 0, "the debounce died with the element");

  assert.deepEqual(await relayoutEvents(page), []);
}));

test("chart: disconnect while the request is pending swaps nothing in", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar", { delays: [500] });
  await enable();
  await resizeTo(page, 480);
  await expectRequests(requests, 1);
  await page.evaluate(() => { window.__detached = document.querySelector("[data-slot=chart]"); window.__detached.remove(); });
  await pause(900);
  assert.deepEqual(await relayoutEvents(page), []);
  assert.equal(await page.locator(CHART).count(), 0);
}));

test("chart: turbo:before-cache aborts the request and removes the interim scaling; the restore re-lays out", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar", { delays: [600, 0] });
  await enable();
  await resizeTo(page, 480);
  await expectRequests(requests, 1);
  const snapshot = await page.evaluate(() => {
    document.dispatchEvent(new Event("turbo:before-cache"));
    const wrapper = document.querySelector("[data-slot=chart] .recharts-wrapper");
    return { wrapper: wrapper.getAttribute("style"), inner: wrapper.parentElement.getAttribute("style") };
  });
  assert.equal(snapshot.wrapper, "position: relative; cursor: default; width: 320px; height: 200px;", "the snapshot holds the server markup");
  assert.equal(snapshot.inner, "width: 0px; height: 0px; overflow: visible;");

  await waitForEvents(page, 1);
  await pause(800);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 480, height: 300 }], "the aborted answer is never swapped in");
  assert.equal(requests.length, 2);
}));
