import { assert, primitiveTest } from "./primitives_support.mjs";

// primitives/combobox_value.js: the hidden inputs, Value parts, chips and Clear button of the Combobox host, on a hand-written
// copy of the markup the Phlex part renders.

const P = (name) => `data-chadcn--combobox-part="${name}"`;
const chipProto = (key, label) => `<template ${P("value-prototype")} data-key="${key}"><div data-slot="combobox-chip" tabindex="-1">${label}<button ${P("chip-remove")} aria-label="Remove"></button></div></template>`;
const single = `
  <form id="form"><div id="host">
    <input type="hidden" ${P("hidden-input")} name="fruit" value="" required>
    <span id="label"><template ${P("value-start")} data-has-placeholder="true" data-placeholder="Pick one"></template>Pick one<template ${P("value-end")}></template></span>
    <template ${P("clear-template")}><button ${P("clear")} data-slot="combobox-clear">Clear</button></template>
  </div></form>`;
const multiple = `
  <form id="form"><div id="host">
    <input type="hidden" ${P("hidden-input")} value="">
    <div ${P("chips")}>
      <template ${P("value-start")}>${chipProto("a", "Apple")}${chipProto("b", "Banana")}${chipProto("c", "Cherry")}</template><div data-slot="combobox-chip" tabindex="-1">Apple</div><input ${P("input")} data-slot="combobox-chip-input"><template ${P("value-end")}></template>
    </div>
  </div></form>`;

primitiveTest("combobox_value: single selection writes the hidden input (with input/change events) and the Value text", async (page) => {
  const result = await page.evaluate(async () => {
    const { ComboboxValue } = await import("chadcn/primitives/combobox_value");
    const host = document.querySelector("#host");
    const value = new ComboboxValue(host, { single: true, required: true, name: "fruit" }, []);
    const events = [];
    value.hidden.addEventListener("change", () => events.push(["change", value.writing]));
    const labels = { apple: "Apple" };
    value.render(["apple"], { labelOf: (key) => labels[key] });
    const selected = [value.hidden.value, value.hidden.getAttribute("value"), document.querySelector("#label").textContent, new FormData(document.querySelector("#form")).get("fruit")];
    value.render(["apple"], { labelOf: (key) => labels[key] });
    value.render([], { labelOf: (key) => labels[key] });
    return { selected, events, writingAfter: value.writing, cleared: [value.hidden.value, document.querySelector("#label").textContent, value.hidden.required] };
  });
  assert.deepEqual(result, {
    selected: ["apple", "apple", "Apple", "apple"],
    events: [["change", true], ["change", true]],
    writingAfter: false,
    cleared: ["", "Pick one", true],
  });
}, { html: single });

primitiveTest("combobox_value: native autofill names an item by its value or label, case-insensitive", async (page) => {
  const result = await page.evaluate(async () => {
    const { ComboboxValue } = await import("chadcn/primitives/combobox_value");
    const value = new ComboboxValue(document.querySelector("#host"), { single: true }, []);
    const items = [{ k: "apple", l: "Apple" }, { k: "pear", l: "Conference pear" }];
    const ask = (text) => { value.hidden.value = text; return value.autofilled(items)?.k ?? null; };
    return { byValue: ask("APPLE"), byLabel: ask("conference PEAR"), none: ask("plum") };
  });
  assert.deepEqual(result, { byValue: "apple", byLabel: "pear", none: null });
}, { html: single });

primitiveTest("combobox_value: multiple selection keeps one named input per value and keeps the chips that did not change", async (page) => {
  const result = await page.evaluate(async () => {
    const { ComboboxValue } = await import("chadcn/primitives/combobox_value");
    const host = document.querySelector("#host");
    const value = new ComboboxValue(host, { single: false, name: "fruits[]", form: "form", disabled: false }, ["a"]);
    const firstChip = value.chips()[0];
    const labelOf = (key) => key.toUpperCase();
    value.render(["a", "b"], { labelOf });
    const formValues = () => [...host.querySelectorAll("[data-chadcn--combobox-part=form-value]")].map((input) => [input.name, input.value, input.getAttribute("form")]);
    const added = { chips: value.chips().map((chip) => chip.textContent), kept: value.chips()[0] === firstChip, inputs: formValues(), role: value.chipsRoot.getAttribute("role") };
    const inputB = host.querySelector("[data-chadcn--combobox-part=form-value][value=b]");
    value.render(["b", "c"], { labelOf });
    const replaced = { chips: value.chips().map((chip) => chip.textContent), inputs: formValues(), keptInput: host.contains(inputB), inputLast: host.querySelector("[data-chadcn--combobox-part=value-end]").previousElementSibling === host.querySelector("[data-slot=combobox-chip-input]") };
    value.render([], { labelOf });
    return { added, replaced, empty: { chips: value.chips().length, inputs: formValues().length, role: value.chipsRoot.hasAttribute("role") } };
  });
  assert.deepEqual(result.added, { chips: ["Apple", "Banana"], kept: true, inputs: [["fruits[]", "a", "form"], ["fruits[]", "b", "form"]], role: "toolbar" });
  assert.deepEqual(result.replaced, { chips: ["Banana", "Cherry"], inputs: [["fruits[]", "b", "form"], ["fruits[]", "c", "form"]], keptInput: true, inputLast: true });
  assert.deepEqual(result.empty, { chips: 0, inputs: 0, role: false });
}, { html: multiple });

primitiveTest("combobox_value: chip keys move the focus, remove a chip, return to the input and open", async (page) => {
  const result = await page.evaluate(async () => {
    const { ComboboxValue } = await import("chadcn/primitives/combobox_value");
    const host = document.querySelector("#host");
    const value = new ComboboxValue(host, { single: false }, ["a"]);
    value.render(["a", "b", "c"], { labelOf: (key) => key });
    const input = host.querySelector("input[data-slot]");
    const calls = [];
    const press = (key, chipIndex) => {
      const chip = value.chips()[chipIndex];
      chip.focus();
      const event = new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true });
      Object.defineProperty(event, "target", { value: chip });
      value.chipKeydown(event, { selectedCount: 3, direction: "ltr", input, onRemove: (index) => calls.push(["remove", index]), onOpen: () => calls.push(["open"]) });
      return [event.defaultPrevented, document.activeElement === input ? "input" : value.chips().indexOf(document.activeElement)];
    };
    return { left: press("ArrowLeft", 2), rightFromLast: press("ArrowRight", 2), backspace: press("Backspace", 1), down: press("ArrowDown", 0), letter: press("x", 1), calls };
  });
  assert.deepEqual(result, {
    left: [true, 1],
    rightFromLast: [true, "input"],
    backspace: [true, 1],
    down: [true, "input"],
    letter: [false, "input"],
    calls: [["remove", 1], ["open"]],
  });
}, { html: multiple });

primitiveTest("combobox_value: the Clear button mounts with a selection, leaves after its exit, and a snapshot drops a leaving one", async (page) => {
  const first = await page.evaluate(async () => {
    const { ComboboxValue } = await import("chadcn/primitives/combobox_value");
    const host = document.querySelector("#host");
    window.clearValue = new ComboboxValue(host, { single: true }, []);
    const clear = () => host.querySelector("[data-chadcn--combobox-part=clear]");
    window.clearValue.syncClear(false, false);
    const none = clear() === null;
    window.clearValue.syncClear(true, true);
    const mounted = [clear().hasAttribute("data-visible"), clear().hasAttribute("data-popup-open")];
    window.clearValue.syncClear(false, false);
    const leaving = [clear()?.hasAttribute("data-ending-style"), clear()?.hasAttribute("data-visible")];
    return { none, mounted, leaving };
  });
  await page.waitForFunction((selector) => document.querySelector(selector) === null, "[data-chadcn--combobox-part=clear]");
  const second = await page.evaluate(() => {
    const value = window.clearValue;
    const clear = () => document.querySelector("[data-chadcn--combobox-part=clear]");
    value.syncClear(true, false);
    value.syncClear(false, false);
    value.syncClear(true, false);
    const interrupted = [clear().hasAttribute("data-ending-style"), clear().hasAttribute("data-visible")];
    value.syncClear(false, false);
    value.resetClear(false);
    return { interrupted, snapshot: clear() === null };
  });
  assert.deepEqual(first, { none: true, mounted: [true, true], leaving: [true, false] });
  assert.deepEqual(second, { interrupted: [false, true], snapshot: true });
}, { html: single });
