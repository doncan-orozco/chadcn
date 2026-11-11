import { assert, primitiveTest } from "./primitives_support.mjs";

// primitives/combobox_state.js: the Base UI state machine of the Combobox (selection, text, query, open requests, highlight),
// driven through a recording host instead of the controller. `cancel` lists event names the host reports as cancelled.

// Defined in the page: window.comboboxState(options) -> { state, log, host }.
const setup = (page) => page.evaluate(async () => {
  const { ComboboxState } = await import("chadcn/primitives/combobox_state");
  window.comboboxState = ({ single = true, inPopup = false, selected = [], text = "", controlled = {}, cancel = [], shown = ["a", "b", "c"], disabled = [] } = {}) => {
    const log = [];
    const labels = { a: "Apple", b: "Banana", c: "Cherry" };
    let mounted = false;
    const emit = (name, detail, cancelable = true) => { log.push(["emit", name, detail, cancelable]); return cancel.includes(name); };
    const host = {
      valueChange: (detail) => emit("value-change", detail),
      inputValueChange: (detail) => emit("input-value-change", detail),
      openChange: (detail) => emit("open-change", detail),
      itemHighlighted: (detail) => { emit("item-highlighted", detail, false); },
      labelOf: (key) => labels[key] ?? key,
      canOpen: () => true,
      selectionChanged: (next) => log.push(["selection", [...next]]),
      writeText: (value, { store }) => log.push(["text", value, store]),
      queryChanged: () => log.push(["query"]),
      openChanged: (open, reason) => { mounted = open; log.push(["open", open, reason]); },
      shownKeys: () => (mounted ? shown : []),
      shownDisabled: () => shown.map((key) => disabled.includes(key)),
      mounted: () => mounted,
      paintHighlight: (index) => log.push(["paint", index]),
      scrollToShown: (index) => log.push(["scroll", index]),
    };
    const state = new ComboboxState({ single, inPopup, selected, text, controlled }, host);
    return { state, log, host, mount: (value) => { mounted = value; } };
  };
});

primitiveTest("combobox_state: a selection change is offered first; cancelled or controlled it stays, single shows the new label", async (page) => {
  await setup(page);
  const result = await page.evaluate(() => {
    const plain = window.comboboxState();
    const applied = plain.state.setSelected(["b"], "item-press");
    const cancelled = window.comboboxState({ cancel: ["value-change"] });
    const refused = cancelled.state.setSelected(["b"], "item-press");
    const controlled = window.comboboxState({ controlled: { value: true } });
    controlled.state.setSelected(["b"], "item-press");
    const multiple = window.comboboxState({ single: false, selected: ["a"] });
    multiple.state.setSelected(["a", "c"], "item-press");
    return {
      applied, selected: plain.state.selected, text: plain.state.text, log: plain.log,
      refused, cancelledSelected: cancelled.state.selected, cancelledLog: cancelled.log.map(([kind, name]) => [kind, name]),
      controlledSelected: controlled.state.selected, controlledKinds: controlled.log.map(([kind]) => kind),
      multipleLog: multiple.log,
    };
  });
  assert.equal(result.applied, true);
  assert.deepEqual(result.selected, ["b"]);
  assert.equal(result.text, "Banana");
  assert.deepEqual(result.log, [
    ["emit", "value-change", { value: "b", reason: "item-press" }, true],
    ["selection", ["b"]],
    ["emit", "input-value-change", { inputValue: "Banana", reason: "item-press" }, true],
    ["text", "Banana", true],
    ["query"],
  ]);
  assert.equal(result.refused, false);
  assert.deepEqual(result.cancelledSelected, []);
  assert.deepEqual(result.cancelledLog, [["emit", "value-change"]], "nothing applied after a cancel");
  assert.deepEqual(result.controlledSelected, [], "controlled: the caller changes the value");
  assert.deepEqual(result.controlledKinds, ["emit", "emit", "text", "query"], "the event fires, no selection render, the text follows");
  assert.deepEqual(result.multipleLog, [["emit", "value-change", { value: ["a", "c"], reason: "item-press" }, true], ["selection", ["a", "c"]]], "multiple: no text change");
});

primitiveTest("combobox_state: text changes are offered first; controlled text is written back unchanged and not stored", async (page) => {
  await setup(page);
  const result = await page.evaluate(() => {
    const controlled = window.comboboxState({ text: "Ap", controlled: { inputValue: true } });
    controlled.state.setText("App", "input-change");
    const cancelled = window.comboboxState({ cancel: ["input-value-change"] });
    const accepted = cancelled.state.setText("x", "input-change");
    const cleared = window.comboboxState({ text: "Ap" });
    cleared.state.setText("", "input-clear");
    return { controlledLog: controlled.log, controlledText: controlled.state.text, accepted, cancelledLog: cancelled.log.length, hadInputClear: cleared.state.hadInputClear };
  });
  assert.deepEqual(result.controlledLog, [["emit", "input-value-change", { inputValue: "App", reason: "input-change" }, true], ["text", "Ap", false]]);
  assert.equal(result.controlledText, "Ap");
  assert.equal(result.accepted, false);
  assert.equal(result.cancelledLog, 1);
  assert.equal(result.hadInputClear, true);
});

primitiveTest("combobox_state: an edited query is frozen while the popup closes and forgotten after the exit", async (page) => {
  await setup(page);
  const result = await page.evaluate(() => {
    const { state, log } = window.comboboxState({ selected: ["a"], text: "Apple" });
    state.requestOpen(true, "input-press", null);
    state.isOpen = true;
    const unedited = state.queryEdited;
    state.applyText("Ban");
    const edited = state.queryEdited;
    state.requestOpen(false, "escape-key", null);
    state.isOpen = false;
    const whileClosing = state.query();
    state.applyText("Banana split");
    const stillFrozen = state.query();
    log.length = 0;
    state.finish();
    return { unedited, edited, whileClosing, stillFrozen, afterExit: state.query(), text: state.text, finishLog: log, queryEdited: state.queryEdited };
  });
  assert.equal(result.unedited, false);
  assert.equal(result.edited, true, "a text away from the initial text and the label is an edit");
  assert.equal(result.whileClosing, "Ban");
  assert.equal(result.stillFrozen, "Ban", "the list does not jump during the exit");
  assert.equal(result.afterExit, "Apple", "the text settles back on the selection label");
  assert.equal(result.text, "Apple");
  assert.deepEqual(result.finishLog, [["emit", "input-value-change", { inputValue: "Apple", reason: "none" }, true], ["text", "Apple", true], ["query"]]);
  assert.equal(result.queryEdited, false);
});

primitiveTest("combobox_state: open requests are offered first, controlled ones wait, and a reopen during the exit lifts the freeze", async (page) => {
  await setup(page);
  const result = await page.evaluate(() => {
    const cancelled = window.comboboxState({ cancel: ["open-change"] });
    cancelled.state.requestOpen(true, "trigger-press", null);
    const controlled = window.comboboxState({ controlled: { open: true } });
    controlled.state.requestOpen(true, "trigger-press", null);
    const same = window.comboboxState();
    same.state.requestOpen(false, "none", null);
    const reopened = window.comboboxState({ single: false, inPopup: true, text: "" });
    reopened.state.isOpen = true;
    reopened.state.applyText("ch");
    reopened.state.requestOpen(false, "outside-press", null);
    reopened.state.isOpen = false;
    const frozen = reopened.state.closeQuery;
    reopened.log.length = 0;
    reopened.state.requestOpen(true, "trigger-press", null);
    return {
      cancelled: cancelled.log.map(([kind]) => kind),
      controlled: controlled.log.map(([kind]) => kind),
      same: same.log.length,
      frozen,
      reopenLog: reopened.log,
      afterReopen: { closeQuery: reopened.state.closeQuery, queryEdited: reopened.state.queryEdited, text: reopened.state.text },
    };
  });
  assert.deepEqual(result.cancelled, ["emit"], "a cancelled open changes nothing");
  assert.deepEqual(result.controlled, ["emit"], "a controlled open waits for the caller");
  assert.equal(result.same, 0, "a request for the current state is not even offered");
  assert.equal(result.frozen, "ch");
  assert.deepEqual(result.reopenLog, [
    ["emit", "open-change", { open: true, reason: "trigger-press" }, true],
    ["emit", "input-value-change", { inputValue: "", reason: "input-clear" }, true],
    ["text", "", true],
    ["query"],
    ["open", true, "trigger-press"],
  ]);
  assert.deepEqual(result.afterReopen, { closeQuery: null, queryEdited: false, text: "" });
});

primitiveTest("combobox_state: selecting an item closes a single combobox and toggles a multiple one", async (page) => {
  await setup(page);
  const result = await page.evaluate(() => {
    const single = window.comboboxState();
    single.state.isOpen = true;
    single.mount(true);
    single.state.select("b", null, { filtering: () => true });
    const multiple = window.comboboxState({ single: false, inPopup: true, selected: ["a"], text: "ch" });
    multiple.state.isOpen = true;
    multiple.mount(true);
    multiple.state.select("c", null, { filtering: () => true });
    const unfiltered = window.comboboxState({ single: false, selected: ["a"] });
    unfiltered.state.isOpen = true;
    unfiltered.state.select("a", null, { filtering: () => false });
    return {
      single: { selected: single.state.selected, opens: single.log.filter(([kind]) => kind === "open") },
      multiple: { selected: multiple.state.selected, text: multiple.state.text, active: multiple.state.active, opens: multiple.log.filter(([kind]) => kind === "open").length },
      unfiltered: { selected: unfiltered.state.selected, opens: unfiltered.log.filter(([kind]) => kind === "open").length },
    };
  });
  assert.deepEqual(result.single, { selected: ["b"], opens: [["open", false, "item-press"]] });
  assert.deepEqual(result.multiple, { selected: ["a", "c"], text: "", active: 2, opens: 0 }, "the search field clears and the toggled item stays highlighted");
  assert.deepEqual(result.unfiltered, { selected: [], opens: 0 });
});

primitiveTest("combobox_state: the highlight reports changes once, maps private reasons to none and scrolls on keyboard moves", async (page) => {
  await setup(page);
  const result = await page.evaluate(() => {
    const { state, log, mount } = window.comboboxState({ selected: ["b"], disabled: ["a"] });
    state.setActive(1, "keyboard");
    const unmounted = { active: state.active, log: [...log] };
    mount(true);
    log.length = 0;
    state.openHighlight("trigger-press", null, false);
    state.setActive(1, "pointer");
    state.pointerModality = false;
    state.navigate(false, null, { loopFocus: true, autoHighlight: false });
    state.navigate(false, null, { loopFocus: true, autoHighlight: false });
    return { unmounted, log, active: state.active };
  });
  assert.deepEqual(result.unmounted, { active: -1, log: [["paint", -1]] }, "nothing is highlighted while unmounted");
  assert.deepEqual(result.log, [
    ["paint", 1],
    ["emit", "item-highlighted", { value: "b", index: 1, reason: "none" }, false],
    ["scroll", 1],
    ["paint", 1],
    ["paint", 2],
    ["emit", "item-highlighted", { value: "c", index: 2, reason: "keyboard" }, false],
    ["scroll", 2],
    ["paint", -1],
    ["emit", "item-highlighted", { value: undefined, index: -1, reason: "keyboard" }, false],
  ]);
  assert.equal(result.active, -1);
});
