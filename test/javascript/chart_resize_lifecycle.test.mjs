// chadcn--chart re-layout lifecycle (dev/port/specs/chart.md, "Behavior", "Resize and re-measure"; item #107): debounce and interim
// scaling, abort on a new size, the carried interaction state, error and foreign answers, same-origin only, disconnect and the Turbo
// cache. Parity against recharts is chart_resize.test.mjs; shared support: chart_resize_support.mjs.
import test from "node:test";
import { assert } from "./support.mjs";
import {
  CHART, SURFACE, TOOLTIP, chartValue, answerRelayout, withResizable, resizeTo, resizeAndSettle, relayoutEvents, waitForEvents, wrapperStyle, expectRequests,
} from "./chart_resize_support.mjs";

test("chart: resizing is debounced to one request, and the chart is scaled into its box until the answer arrives", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar", { delays: [600] });
  await enable();
  // One evaluate, a frame per size: the four sizes land well inside the 150 ms debounce.
  await page.evaluate(async () => {
    const chart = document.querySelector("[data-slot=chart]");
    for (const width of [360, 400, 440, 480]) {
      chart.style.width = `${width}px`;
      chart.style.height = "300px";
      await new Promise((resolve) => requestAnimationFrame(() => resolve()));
    }
  });
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
  await Promise.all(requests.answered);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 640, height: 400 }], "the aborted 480 answer never arrived");
  assert.equal(await chartValue(page, "dimension"), JSON.stringify({ width: 640, height: 400 }));
}));

test("chart: the tooltip and the keyboard carry over the swap", () => withResizable("bar", async (page, enable) => {
  await answerRelayout(page, "bar");
  await enable();
  await page.locator(SURFACE).focus();
  await page.keyboard.press("ArrowRight");
  await page.locator(TOOLTIP).filter({ hasText: "February" }).waitFor({ state: "visible" });

  await resizeTo(page, 640);
  await waitForEvents(page, 1);
  assert.equal(await chartValue(page, "keyboard-index"), "1");
  assert.equal(await chartValue(page, "keyboard-active"), "true");
  assert.deepEqual(JSON.parse(await chartValue(page, "served-state")), { pointerIndex: -1, pointerActive: false, keyboardIndex: -1, keyboardActive: false }, "the answer's own state, for the Turbo snapshot");
  assert.equal(await page.evaluate(() => document.activeElement.matches("[data-slot=chart] svg.recharts-surface")), true, "the new svg has the focus");
  await page.locator(TOOLTIP).filter({ hasText: "February" }).waitFor({ state: "visible" });
  await page.keyboard.press("ArrowRight");
  assert.equal(await chartValue(page, "keyboard-index"), "2", "the keyboard keeps working on the new chart");
}));

test("chart: an error answer keeps the chart, reports relayout-error once and stops re-laying out", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar", { answer: () => ({ status: 500 }) });
  await enable();
  await resizeTo(page, 480);
  await waitForEvents(page, 1);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout-error", status: 500 }]);
  assert.equal(await chartValue(page, "dimension"), JSON.stringify({ width: 320, height: 200 }), "the current chart stays");
  assert.match(await wrapperStyle(page), /width: 100%; height: 100%;/, "and stays scaled into its box");

  await resizeAndSettle(page, 640);
  assert.equal(requests.length, 1, "no request loop");
  assert.equal((await relayoutEvents(page)).length, 1);

  // Control: the same element, put back with another URL, does request, so the silence above was the stop and not a dead route.
  await page.evaluate(() => {
    const chart = document.querySelector("[data-slot=chart]");
    const [parent, next] = [chart.parentNode, chart.nextSibling];
    chart.remove();
    chart.setAttribute("data-chadcn--chart-relayout-url-value", "/chart-relayout?source=control");
    parent.insertBefore(chart, next);
  });
  await waitForEvents(page, 2);
  assert.equal(requests.length, 2, "the reconnect is the second request");
  assert.equal(requests[1].source, "control");
  assert.equal(requests[1]["chart[width]"], "640");
}, { loadErrors: true }));

test("chart: an answer without the chart is an error", () => withResizable("bar", async (page, enable) => {
  await answerRelayout(page, "bar", { answer: () => ({ body: "<p>signed out</p>" }) });
  await enable();
  await resizeTo(page, 480);
  await waitForEvents(page, 1);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout-error", status: 200 }]);
}));

test("chart: an answer with the chart at another size is an error", () => withResizable("bar", async (page, enable) => {
  await answerRelayout(page, "bar", { answer: () => ({ width: 640 }) });
  await enable();
  await resizeTo(page, 480);
  await waitForEvents(page, 1);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout-error", status: 200 }], "a host that ignored the parameters");
  assert.equal(await chartValue(page, "dimension"), JSON.stringify({ width: 320, height: 200 }));
}));

test("chart: a cross-origin relayout_url is never requested", () => withResizable("bar", async (page, enable) => {
  const outside = [];
  await page.route("https://example.test/**", (route) => { outside.push(route.request().url()); return route.abort(); });
  await enable();
  await resizeTo(page, 480);
  await waitForEvents(page, 1);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout-error", status: 0 }]);
  assert.deepEqual(outside, []);
}, { url: "https://example.test/chart" }));

test("chart: a same-origin relayout_url on the same page is requested (the control of the cross-origin test)", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar");
  await enable();
  await resizeTo(page, 480);
  await waitForEvents(page, 1);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 480, height: 300 }]);
  assert.equal(requests.length, 1);
}));

test("chart: disconnect before the debounce fires sends no request", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar");
  await enable();
  await resizeTo(page, 480);
  await page.evaluate(() => { window.__detached = document.querySelector("[data-slot=chart]"); window.__detached.remove(); });
  assert.deepEqual(await relayoutEvents(page), []);

  // Control: the same element, put back with another URL, does request. Its own debounce outlasts the one that died, so a stale
  // request of the removed element would be the first in the list.
  await page.evaluate(() => {
    window.__detached.setAttribute("data-chadcn--chart-relayout-url-value", "/chart-relayout?source=control");
    document.body.append(window.__detached);
  });
  await waitForEvents(page, 1);
  assert.equal(requests.length, 1);
  assert.equal(requests[0].source, "control", "the debounce died with the element");
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 480, height: 300 }]);
}));

test("chart: disconnect while the request is pending swaps nothing in", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar", { delays: [500] });
  await enable();
  await resizeTo(page, 480);
  await expectRequests(requests, 1);
  await page.evaluate(() => { window.__detached = document.querySelector("[data-slot=chart]"); window.__detached.remove(); });
  await Promise.all(requests.answered);
  assert.deepEqual(await relayoutEvents(page), []);
  assert.equal(await page.locator(CHART).count(), 0);

  // Control: the route answers and the chart swaps in when the element comes back.
  await page.evaluate(() => document.body.append(window.__detached));
  await waitForEvents(page, 1);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 480, height: 300 }]);
  assert.equal(requests.length, 2);
}));

test("chart: turbo:before-cache aborts the request and removes the interim scaling; the restore re-lays out", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar", { delays: [600, 0] });
  await enable();
  await resizeTo(page, 480);
  await expectRequests(requests, 1);
  const snapshot = await page.evaluate(() => {
    document.dispatchEvent(new Event("turbo:before-cache"));
    const wrapper = document.querySelector("[data-slot=chart] .recharts-wrapper");
    return { wrapper: wrapper.style.width, height: wrapper.style.height, inner: wrapper.parentElement.style.width };
  });
  assert.notEqual(snapshot.wrapper, "100%", "the snapshot holds the server markup, not the interim scaling");
  assert.notEqual(snapshot.inner, "100%");
  assert.equal(snapshot.wrapper, "320px");
  assert.equal(snapshot.height, "200px");

  await waitForEvents(page, 1);
  await Promise.all(requests.answered);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 480, height: 300 }], "the aborted answer is never swapped in");
  assert.equal(requests.length, 2);
}));

test("chart: a Turbo cache restore re-measures: the cached clone at another size is requested and swapped in", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar");
  await enable();
  // What Turbo does: snapshot the page after turbo:before-cache, and later show a copy of it in a box of another size.
  await page.evaluate(() => {
    const chart = document.querySelector("[data-slot=chart]");
    document.dispatchEvent(new Event("turbo:before-cache"));
    const clone = chart.cloneNode(true);
    chart.replaceWith(clone);
    clone.style.width = "640px";
    clone.style.height = "400px";
  });
  await waitForEvents(page, 1);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 640, height: 400 }]);
  assert.equal(await page.locator(CHART).count(), 1, "one chart on the page");
  assert.equal(requests.length, 1);
  assert.equal(requests[0]["chart[width]"], "640");
}));
