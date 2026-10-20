import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";

// Behavior of shadcn--calendar that the parity runner cannot compare with React: the events (React has callbacks), node identity across
// renders, reconnection, the port-only form wiring (name:, input:, label:, close_on_select:) and the Intl fallbacks of other locales.
// Pages are the real parity pages; options that no scenario sets are applied by rewriting the root's config value, which the controller
// observes (a config change re-renders from scratch).
browserTest.component = "calendar";

const ROOT = "[data-slot=calendar]";
const day = (iso) => `td[data-day="${iso}"] button`;
const captions = (page) => page.locator(`${ROOT} .rdp-caption_label`).allTextContents();

// Merges `patch` into the JSON config value of a calendar root (`null` deletes a key) and lets the controller re-render.
async function configure(page, patch, selector = ROOT) {
  await page.evaluate(({ patch, selector }) => {
    const root = document.querySelector(selector);
    const name = "data-shadcn--calendar-config-value";
    const config = { ...JSON.parse(root.getAttribute(name)), ...patch };
    for (const [key, value] of Object.entries(patch)) if (value === null) delete config[key];
    root.setAttribute(name, JSON.stringify(config));
  }, { patch, selector });
  await settle(page);
}

// Disconnects and reconnects the controller, like a Turbo snapshot restore (the DOM stays as it was).
async function reconnect(page, selector = ROOT) {
  await page.evaluate(({ selector }) => new Promise((resolve) => {
    const root = document.querySelector(selector);
    root.setAttribute("data-controller", "");
    requestAnimationFrame(() => { root.setAttribute("data-controller", "shadcn--calendar"); resolve(); });
  }), { selector });
  await settle(page);
}

async function record(page) {
  await page.evaluate(() => {
    window.__calendarEvents = [];
    for (const name of ["select", "month-change"]) {
      document.addEventListener(`shadcn--calendar:${name}`, (event) => window.__calendarEvents.push({ name, detail: event.detail, bubbles: event.bubbles, cancelable: event.cancelable, target: event.target.dataset.slot }));
    }
  });
}

const events = (page) => page.evaluate(() => window.__calendarEvents);

browserTest("calendar: select (single) bubbles from the root with the new value, the clicked day and its modifiers; clearing sends null", async ({ open }) => {
  const page = await open("mode-single__rest");
  await record(page);
  await page.click(day("2026-03-20"));
  await page.click(day("2026-03-20"));
  await page.click(day("2026-03-15"));
  const log = await events(page);
  assert.deepEqual(log.map((event) => event.detail.selected), ["2026-03-20", null, "2026-03-15"]);
  assert.deepEqual(log.map((event) => event.detail.date), ["2026-03-20", "2026-03-20", "2026-03-15"]);
  assert.equal(log[0].target, "calendar");
  assert.ok(log.every((event) => event.bubbles && !event.cancelable));
  assert.equal(log[0].detail.modifiers.today, false);
  assert.equal(log[2].detail.modifiers.today, true);
  assert.equal(log[0].detail.modifiers.disabled, false);
});

browserTest("calendar: select (multiple and range) carries arrays and { from, to }, and ignores clicks the rules refuse", async ({ open }) => {
  let page = await open("mode-multiple__min");
  await record(page);
  await page.click(day("2026-03-10"));
  assert.deepEqual(await events(page), [], "min reached: no event");
  await page.click(day("2026-03-14"));
  assert.deepEqual((await events(page)).map((event) => event.detail.selected), [["2026-03-10", "2026-03-12", "2026-03-14"]]);

  page = await open("mode-range__rest");
  await record(page);
  await page.click(day("2026-03-10"));
  await page.click(day("2026-03-16"));
  await page.click(day("2026-03-16"));
  assert.deepEqual((await events(page)).map((event) => event.detail.selected), [
    { from: "2026-03-10", to: "2026-03-10" }, { from: "2026-03-10", to: "2026-03-16" }, { from: "2026-03-16", to: "2026-03-16" },
  ]);
});

browserTest("calendar: month-change fires on a nav click, a dropdown change and a keyboard move, but not for a nav button without a target", async ({ open }) => {
  let page = await open("nav__start-end-month");
  await record(page);
  await page.click(".rdp-button_next");
  await page.click(".rdp-button_next", { force: true });
  assert.deepEqual((await events(page)).map((event) => event.detail.month), ["2026-04-01"], "April is the end month: the second click has no target");

  page = await open("caption-dropdown__change-month");
  await record(page);
  await page.focus(".rdp-months_dropdown");
  await page.keyboard.type("Aug");
  assert.equal((await events(page)).at(-1).detail.month, "2026-08-01", "the select's type-ahead changes it once per matching prefix (A: April, Au: August)");

  page = await open("keyboard__page");
  await record(page);
  await page.focus(day("2026-03-15"));
  await page.keyboard.press("PageDown");
  assert.deepEqual((await events(page)).map((event) => event.name), ["month-change"]);
  assert.deepEqual((await events(page))[0].detail, { month: "2026-04-01" });
});

browserTest("calendar: a controlled month reports month-change but only moves when the month value changes", async ({ open }) => {
  const page = await open("mode-single__month-controlled");
  await record(page);
  assert.deepEqual(await captions(page), ["May 2026"]);
  await page.click(".rdp-button_next");
  assert.deepEqual((await events(page)).map((event) => event.detail.month), ["2026-06-01"]);
  assert.deepEqual(await captions(page), ["May 2026"], "refused like React without onMonthChange");
  await page.evaluate(() => document.querySelector("[data-slot=calendar]").setAttribute("data-shadcn--calendar-month-value", "2026-06-01"));
  await settle(page);
  assert.deepEqual(await captions(page), ["June 2026"]);
});

browserTest("calendar: a click or a keyboard move keeps the DOM nodes of the day, the nav and the caption (focus never drops)", async ({ open }) => {
  const page = await open("mode-single__rest");
  await page.evaluate(() => {
    window.__nodes = { nav: document.querySelector(".rdp-button_next"), caption: document.querySelector(".rdp-caption_label"), grid: document.querySelector("table"), friday: document.querySelector('td[data-day="2026-03-20"] button') };
  });
  const same = () => page.evaluate(() => ({
    nav: window.__nodes.nav === document.querySelector(".rdp-button_next"),
    caption: window.__nodes.caption === document.querySelector(".rdp-caption_label"),
    grid: window.__nodes.grid === document.querySelector("table"),
    friday: window.__nodes.friday === document.querySelector('td[data-day="2026-03-20"] button'),
    focusedIsFriday: document.activeElement === window.__nodes.friday,
  }));
  await page.click(day("2026-03-20"));
  assert.deepEqual(await same(), { nav: true, caption: true, grid: true, friday: true, focusedIsFriday: true });
  await page.keyboard.press("ArrowLeft");
  await page.keyboard.press("ArrowRight");
  assert.equal((await same()).focusedIsFriday, true);
  await page.click(".rdp-button_next");
  const afterNav = await same();
  assert.equal(afterNav.nav, true);
  assert.equal(afterNav.caption, true);
  assert.equal(afterNav.grid, true);
  assert.equal(await page.evaluate(() => document.activeElement === window.__nodes.nav), true, "focus stays on the clicked nav button");
  assert.deepEqual(await captions(page), ["April 2026"]);
});

browserTest("calendar: the dropdown selects keep their nodes and focus when the month changes", async ({ open }) => {
  const page = await open("caption-dropdown__change-month");
  await page.evaluate(() => { window.__select = document.querySelector(".rdp-months_dropdown"); });
  await page.focus(".rdp-months_dropdown");
  await page.keyboard.type("Jun");
  assert.equal(await page.evaluate(() => document.activeElement === window.__select && document.querySelector(".rdp-months_dropdown") === window.__select), true);
  assert.equal(await page.evaluate(() => window.__select.value), "5");
  assert.equal(await page.evaluate(() => document.querySelector("[data-slot=calendar] [role=status]:not(.rdp-caption_label)").textContent), "June 2026");
});

browserTest("calendar: reconnecting rebuilds one clean copy of the months and keeps the server nav", async ({ open }) => {
  const page = await open("mode-single__selected");
  const counts = () => page.evaluate(() => ({
    months: document.querySelectorAll(".rdp-month").length, navs: document.querySelectorAll(".rdp-nav").length,
    buttons: document.querySelectorAll("td button").length, selected: document.querySelectorAll("td[aria-selected=true]").length,
  }));
  const before = await counts();
  await reconnect(page);
  await reconnect(page);
  assert.deepEqual(await counts(), before);
  await record(page);
  await page.click(day("2026-03-12"));
  assert.equal((await events(page)).length, 1, "one listener, not one per connect");
});

browserTest("calendar: disconnect removes the listeners and a snapshot with a rendered grid is replaced on connect", async ({ open }) => {
  const page = await open("mode-single__rest");
  await record(page);
  await page.evaluate(() => document.querySelector("[data-slot=calendar]").setAttribute("data-controller", ""));
  await settle(page);
  await page.click(day("2026-03-12"), { force: true });
  await page.click(".rdp-button_next", { force: true });
  assert.deepEqual(await events(page), []);
  assert.deepEqual(await captions(page), ["March 2026"], "nothing responds after disconnect");
});

browserTest("calendar: changing the config value re-renders (more months, another locale)", async ({ open }) => {
  const page = await open("mode-single__rest");
  await configure(page, { numberOfMonths: 2 });
  assert.deepEqual(await captions(page), ["March 2026", "April 2026"]);
  await configure(page, { locale: "es", localeKind: "es", weekStartsOn: 1, firstWeekContainsDate: 1, labels: { ...(await page.evaluate(() => JSON.parse(document.querySelector("[data-slot=calendar]").getAttribute("data-shadcn--calendar-config-value")).labels)), today: "Hoy", selected: "seleccionado" } });
  assert.deepEqual(await captions(page), ["marzo 2026", "abril 2026"]);
  assert.equal(await page.locator(".rdp-weekday").first().textContent(), "lu");
});

browserTest("calendar: without today the browser's date decides the displayed month and the today cell", async ({ open }) => {
  const page = await open("mode-single__rest");
  await configure(page, { today: null, defaultMonth: null });
  const expected = await page.evaluate(() => {
    const now = new Date();
    const iso = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
    return { caption: `${new Intl.DateTimeFormat("en-US", { month: "long" }).format(now)} ${now.getFullYear()}`, iso };
  });
  assert.deepEqual(await captions(page), [expected.caption]);
  assert.equal(await page.locator('td[data-today="true"]').getAttribute("data-day"), expected.iso);
});

browserTest("calendar: day-button data-day is the browser's toLocaleDateString", async ({ open }) => {
  const page = await open("mode-single__rest");
  const result = await page.evaluate(() => ({
    actual: document.querySelector('td[data-day="2026-03-05"] button').getAttribute("data-day"), expected: new Date(2026, 2, 5).toLocaleDateString(),
  }));
  assert.equal(result.actual, result.expected);
});

browserTest("calendar: movement keys are consumed by the grid, other keys (the Shift modifier, Escape, Tab) still reach the document", async ({ open }) => {
  const page = await open("mode-single__rest");
  await page.evaluate(() => {
    window.__keys = [];
    document.addEventListener("keydown", (event) => window.__keys.push(event.key));
  });
  await page.focus(day("2026-03-15"));
  for (const key of ["ArrowRight", "ArrowDown", "Home", "End", "PageDown", "Shift+PageUp", "Escape", "Tab"]) await page.keyboard.press(key);
  assert.deepEqual(await page.evaluate(() => window.__keys), ["Shift", "Escape", "Tab"]);
});

browserTest("calendar: a locale without exact support uses Intl names, English labels and the browser's week start", async ({ open }) => {
  const page = await open("mode-single__rest");
  await configure(page, { locale: "de", localeKind: "other", weekStartsOn: null, firstWeekContainsDate: null });
  assert.deepEqual(await captions(page), ["März 2026"]);
  assert.equal(await page.locator(".rdp-weekday").first().getAttribute("aria-label"), "Montag");
  const label = await page.locator(day("2026-03-02")).getAttribute("aria-label");
  assert.equal(label, "Montag, 2. März 2026", "Intl dateStyle full");
  assert.equal(await page.locator('td[data-today="true"] button').getAttribute("aria-label"), "Today, Sonntag, 15. März 2026", "English prefix");
  await configure(page, { locale: "ja", localeKind: "other", yearFirst: true });
  assert.deepEqual(await captions(page), ["2026年3月"]);
});

browserTest("calendar: formatters take Intl.DateTimeFormat options and replace the default text", async ({ open }) => {
  const page = await open("caption-dropdown__change-month");
  await configure(page, { captionLayout: "label", formatters: { formatCaption: { month: "short", year: "numeric" }, formatDay: { day: "2-digit" }, formatWeekdayName: { weekday: "narrow" } } });
  assert.deepEqual(await captions(page), ["Mar 2026"]);
  assert.equal(await page.locator(day("2026-03-05")).textContent(), "05");
  assert.deepEqual(await page.locator(".rdp-weekday").allTextContents(), ["S", "M", "T", "W", "T", "F", "S"]);
  assert.equal(await page.locator("table").getAttribute("aria-label"), "March 2026", "the grid label ignores formatCaption");
});

browserTest("calendar: inline name: inputs follow the selection", async ({ open }) => {
  const page = await open("mode-multiple__rest");
  await page.evaluate(() => {
    const root = document.querySelector("[data-slot=calendar]");
    const blank = Object.assign(document.createElement("input"), { type: "hidden", name: "days[]", value: "" });
    blank.setAttribute("data-shadcn--calendar-field", "blank");
    root.append(blank);
  });
  await reconnect(page);
  await page.click(day("2026-03-05"));
  await page.click(day("2026-03-09"));
  await page.click(day("2026-03-05"));
  assert.deepEqual(await page.$$eval("input[type=hidden]", (inputs) => inputs.map((input) => [input.name, input.value])), [["days[]", ""], ["days[]", "2026-03-09"]]);
});

browserTest("calendar: input: is the source of truth, receives input and change events and the first month follows it", async ({ open }) => {
  const page = await open("mode-single__rest");
  await page.evaluate(() => {
    const input = Object.assign(document.createElement("input"), { type: "hidden", id: "chosen", value: "2026-07-09" });
    window.__input = [];
    for (const name of ["input", "change"]) input.addEventListener(name, (event) => window.__input.push([name, event.bubbles, event.target.value]));
    document.body.append(input);
  });
  await configure(page, { input: "#chosen", defaultMonth: null, selected: "2026-03-10" });
  assert.deepEqual(await captions(page), ["July 2026"], "the month of the input value, not of selected:");
  assert.equal(await page.locator('td[aria-selected="true"]').getAttribute("data-day"), "2026-07-09");
  await page.click(day("2026-07-20"));
  assert.equal(await page.inputValue("#chosen"), "2026-07-20");
  assert.deepEqual(await page.evaluate(() => window.__input), [["input", true, "2026-07-20"], ["change", true, "2026-07-20"]]);
  await page.click(day("2026-07-20"));
  assert.equal(await page.inputValue("#chosen"), "", "clearing writes an empty value");
  const warnings = [];
  page.on("console", (message) => { if (message.type() === "warning") warnings.push(message.text()); });
  await page.evaluate(() => { document.querySelector("#chosen").value = "nonsense"; });
  await reconnect(page);
  assert.ok(warnings.some((text) => text.includes('"nonsense"') && text.includes("no selection")), warnings.join("|"));
  assert.equal(await page.locator('td[aria-selected="true"]').count(), 0, "an unparsable value means no selection");
});

browserTest("calendar: input: formats of multiple, range and { from, to } inputs", async ({ open }) => {
  let page = await open("mode-multiple__rest");
  await page.evaluate(() => document.body.append(Object.assign(document.createElement("input"), { type: "hidden", id: "days", value: "2026-03-03,2026-03-10" })));
  await configure(page, { input: "#days" });
  assert.equal(await page.locator('td[aria-selected="true"]').count(), 2);
  await page.click(day("2026-03-20"));
  assert.equal(await page.inputValue("#days"), "2026-03-03,2026-03-10,2026-03-20");

  page = await open("mode-range__rest");
  await page.evaluate(() => document.body.append(Object.assign(document.createElement("input"), { type: "hidden", id: "stay", value: "2026-03-10/" })));
  await configure(page, { input: "#stay" });
  await page.click(day("2026-03-14"));
  assert.equal(await page.inputValue("#stay"), "2026-03-10/2026-03-14");
  await page.click(day("2026-03-14"));
  assert.equal(await page.inputValue("#stay"), "2026-03-14/2026-03-14");

  page = await open("mode-range__rest");
  await page.evaluate(() => {
    for (const id of ["from", "to"]) document.body.append(Object.assign(document.createElement("input"), { type: "hidden", id }));
  });
  await configure(page, { input: { from: "#from", to: "#to" } });
  await page.click(day("2026-03-10"));
  await page.click(day("2026-03-12"));
  assert.deepEqual([await page.inputValue("#from"), await page.inputValue("#to")], ["2026-03-10", "2026-03-12"]);
});

browserTest("calendar: label: shows the formatted selection, keeps the first text as the placeholder and marks data-empty", async ({ open }) => {
  const page = await open("mode-single__rest");
  await page.evaluate(() => document.body.append(Object.assign(document.createElement("span"), { id: "shown", textContent: "Pick a date" })));
  await configure(page, { label: "#shown" });
  assert.equal(await page.getAttribute("#shown", "data-shadcn--calendar-placeholder"), "Pick a date");
  assert.equal(await page.getAttribute("#shown", "data-empty"), "true");
  await page.click(day("2026-03-22"));
  assert.equal(await page.textContent("#shown"), "March 22nd, 2026");
  assert.equal(await page.getAttribute("#shown", "data-empty"), "false");
  await page.click(day("2026-03-22"));
  assert.equal(await page.textContent("#shown"), "Pick a date");
  assert.equal(await page.getAttribute("#shown", "data-empty"), "true");
  await reconnect(page);
  assert.equal(await page.getAttribute("#shown", "data-shadcn--calendar-placeholder"), "Pick a date", "stored once");
});

browserTest("calendar: label: formats multiple selections and ranges", async ({ open }) => {
  let page = await open("mode-multiple__rest");
  await page.evaluate(() => document.body.append(Object.assign(document.createElement("span"), { id: "shown", textContent: "Pick dates" })));
  await configure(page, { label: "#shown" });
  await page.click(day("2026-03-01"));
  await page.click(day("2026-03-03"));
  await page.click(day("2026-03-11"));
  assert.equal(await page.textContent("#shown"), "March 1st, 2026, March 3rd, 2026, March 11th, 2026");

  page = await open("mode-range__rest");
  await page.evaluate(() => document.body.append(Object.assign(document.createElement("span"), { id: "shown", textContent: "Pick a range" })));
  await configure(page, { label: "#shown" });
  await page.click(day("2026-03-10"));
  await page.click(day("2026-03-14"));
  assert.equal(await page.textContent("#shown"), "Mar 10, 2026 - Mar 14, 2026");
  await page.click(day("2026-03-20"));
  assert.equal(await page.textContent("#shown"), "Mar 10, 2026 - Mar 20, 2026");
  await page.click(day("2026-03-20"));
  await page.click(day("2026-03-10"));
  assert.equal(await page.textContent("#shown"), "Mar 10, 2026 - Mar 20, 2026");
});

// The Popover mounts a fresh copy of its content template on every open, so the wiring is applied to the calendar inside the template.
async function wirePicker(page, config) {
  await page.evaluate((config) => {
    const template = document.querySelector("template[data-shadcn--popover-template]");
    const root = template.content.querySelector("[data-slot=calendar]");
    const name = "data-shadcn--calendar-config-value";
    root.setAttribute(name, JSON.stringify({ ...JSON.parse(root.getAttribute(name)), ...config }));
  }, config);
}

browserTest("calendar: close_on_select closes the enclosing popover after a completing selection and returns focus to the trigger", async ({ open }) => {
  const page = await open("example__date-picker-demo");
  await page.evaluate(() => document.body.append(Object.assign(document.createElement("input"), { type: "hidden", id: "event_date" })));
  await wirePicker(page, { closeOnSelect: true, input: "#event_date" });
  await page.click("[data-slot=popover-trigger]");
  await page.waitForSelector("[data-slot=popover-content]");
  await settle(page);
  await page.click(day("2026-03-20"));
  await page.waitForSelector("[data-slot=popover-content]", { state: "detached" });
  assert.equal(await page.inputValue("#event_date"), "2026-03-20", "the input outlives the popover content");
  // The popover returns focus in its own close-auto-focus, after the content is gone: wait for it instead of reading once.
  await page.waitForFunction(() => document.activeElement?.getAttribute("data-slot") === "popover-trigger", null, { timeout: 5000 });
  await page.click("[data-slot=popover-trigger]");
  await page.waitForSelector("[data-slot=popover-content]");
  await settle(page);
  assert.equal(await page.locator('td[aria-selected="true"]').getAttribute("data-day"), "2026-03-20", "each open reads the input again");
});

browserTest("calendar: close_on_select stays open for multiple mode and for a range that is not complete, and is off by default", async ({ open }) => {
  let page = await open("example__date-picker-with-range");
  await wirePicker(page, { closeOnSelect: true, selected: null });
  await page.click("#date");
  await page.waitForSelector("[data-slot=popover-content]");
  await settle(page);
  await page.click(day("2022-01-25"));
  await settle(page);
  assert.equal(await page.locator("[data-slot=popover-content]").count(), 1, "range: from is not complete");
  await page.click(day("2022-01-27"));
  await page.waitForSelector("[data-slot=popover-content]", { state: "detached" });

  page = await open("example__date-picker-demo");
  await page.click("[data-slot=popover-trigger]");
  await page.waitForSelector("[data-slot=popover-content]");
  await settle(page);
  await page.click(day("2026-03-20"));
  await settle(page);
  assert.equal(await page.locator("[data-slot=popover-content]").count(), 1, "off by default");
});

browserTest("calendar: close_on_select outside a popover does nothing", async ({ open }) => {
  const page = await open("mode-single__rest");
  await configure(page, { closeOnSelect: true });
  await page.click(day("2026-03-20"));
  assert.equal(await page.locator('td[aria-selected="true"]').count(), 1);
});

browserTest("calendar: auto_focus takes focus on connect and a focused day that leaves the grid falls back to the focus target", async ({ open }) => {
  const page = await open("mode-single__rest");
  await configure(page, { autoFocus: true, selected: "2026-03-10" });
  assert.equal(await page.evaluate(() => document.activeElement.closest("td")?.getAttribute("data-day")), "2026-03-10");
  await page.click(".rdp-button_next");
  assert.equal(await page.locator('td[data-focused="true"]').count(), 0, "focus moved to the nav button");
});

browserTest("calendar: disabled and hidden matchers are data: ranges, intervals and day of week all skip in the keyboard walk", async ({ open }) => {
  const page = await open("mode-single__rest");
  await configure(page, { disabled: [{ from: "2026-03-16", to: "2026-03-18" }, { dayOfWeek: 6 }], hidden: "2026-03-20" });
  await page.focus(day("2026-03-15"));
  await page.keyboard.press("ArrowRight");
  assert.equal(await page.evaluate(() => document.activeElement.closest("td").dataset.day), "2026-03-19");
  await page.keyboard.press("ArrowRight");
  assert.equal(await page.evaluate(() => document.activeElement.closest("td").dataset.day), "2026-03-22", "20th hidden, 21st a Saturday");
  assert.equal(await page.locator('td[data-day="2026-03-20"] button').count(), 0);
});

browserTest("calendar: a pre-filled label with a declared placeholder falls back to it when the selection is cleared", async ({ open }) => {
  const page = await open("mode-single__rest");
  await page.evaluate(() => document.body.append(Object.assign(document.createElement("span"), { id: "shown", textContent: "March 22nd, 2026" })));
  await page.evaluate(() => { const label = document.querySelector("#shown"); label.setAttribute("data-shadcn--calendar-placeholder", "Pick a date"); label.setAttribute("data-empty", "false"); });
  await configure(page, { label: "#shown", selected: "2026-03-22" });
  assert.equal(await page.getAttribute("#shown", "data-shadcn--calendar-placeholder"), "Pick a date", "the declared placeholder is kept");
  assert.equal(await page.getAttribute("#shown", "data-empty"), "false");
  await page.click(day("2026-03-22"));
  assert.equal(await page.textContent("#shown"), "Pick a date");
  assert.equal(await page.getAttribute("#shown", "data-empty"), "true");
});

browserTest("calendar: an input: selector that matches nothing logs an error and never overrides selected:", async ({ open }) => {
  const page = await open("mode-single__selected");
  const errors = [];
  page.on("console", (message) => { if (message.type() === "error") errors.push(message.text()); });
  await configure(page, { input: "#nope" });
  assert.equal(await page.locator('td[aria-selected="true"]').getAttribute("data-day"), "2026-03-10");
  assert.ok(errors.some((text) => text.includes('"#nope"')), errors.join("|"));
  await page.click(day("2026-03-12"));
  assert.equal(await page.locator('td[aria-selected="true"]').getAttribute("data-day"), "2026-03-12");

  const range = await open("mode-range__selected");
  await configure(range, { input: { from: "#nope-from", to: "#nope-to" } });
  assert.equal(await range.locator('td[aria-selected="true"]').count(), 5, "range keeps selected:");
  const multiple = await open("mode-multiple__selected");
  await configure(multiple, { input: "#nope" });
  assert.equal(await multiple.locator('td[aria-selected="true"]').count(), 3);
});

browserTest("calendar: without input: the inline name: inputs are the source on a reconnect", async ({ open }) => {
  const page = await open("mode-single__selected");
  await page.evaluate(() => {
    const field = Object.assign(document.createElement("input"), { type: "hidden", name: "day", value: "2026-03-18" });
    field.setAttribute("data-shadcn--calendar-field", "single");
    document.querySelector("[data-slot=calendar]").append(field);
  });
  await reconnect(page);
  assert.equal(await page.locator('td[aria-selected="true"]').getAttribute("data-day"), "2026-03-18");
});

browserTest("calendar: a label: selector that matches nothing logs an error and the selection still works", async ({ open }) => {
  const page = await open("mode-single__rest");
  const errors = [];
  page.on("console", (message) => { if (message.type() === "error") errors.push(message.text()); });
  await configure(page, { label: "#nope" });
  assert.ok(errors.some((text) => text.includes('label "#nope"') && text.includes("matches no element")), errors.join("|"));
  await page.click(day("2026-03-12"));
  assert.equal(await page.locator('td[aria-selected="true"]').getAttribute("data-day"), "2026-03-12");
});

browserTest("calendar: unparsable multiple and range input values warn and read as no selection", async ({ open }) => {
  for (const [scenario, value] of [["mode-multiple__rest", "2026-03-03,bogus"], ["mode-range__rest", "2026-03-10/xx"], ["mode-range__rest", "2026-03-10/2026-03-12/junk"]]) {
    const page = await open(scenario);
    const warnings = [];
    page.on("console", (message) => { if (message.type() === "warning") warnings.push(message.text()); });
    await page.evaluate((value) => document.body.append(Object.assign(document.createElement("input"), { type: "hidden", id: "bad", value })), value);
    await configure(page, { input: "#bad" });
    assert.ok(warnings.some((text) => text.includes(`"${value}"`)), warnings.join("|"));
    assert.equal(await page.locator('td[aria-selected="true"]').count(), 0, `${scenario}: a partly valid value is no selection`);
  }

  const page = await open("mode-range__rest");
  const warnings = [];
  page.on("console", (message) => { if (message.type() === "warning") warnings.push(message.text()); });
  await page.evaluate(() => {
    document.body.append(Object.assign(document.createElement("input"), { type: "hidden", id: "from", value: "2026-03-10" }));
    document.body.append(Object.assign(document.createElement("input"), { type: "hidden", id: "to", value: "garbage" }));
  });
  await configure(page, { input: { from: "#from", to: "#to" } });
  assert.ok(warnings.some((text) => text.includes('"2026-03-10/garbage"')), warnings.join("|"));
  assert.equal(await page.locator('td[aria-selected="true"]').count(), 0, "{ from, to }: a partly valid pair is no selection");
});
