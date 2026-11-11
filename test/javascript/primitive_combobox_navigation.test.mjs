import { assert, primitiveTest } from "./primitives_support.mjs";

// primitives/combobox_navigation.js: arrow-key highlight steps, the opening highlight, chip keys and the selection toggles of
// the Combobox. Pure functions, exercised without the controller.

primitiveTest("combobox_navigation: arrows clamp without loopFocus and wrap with it, through 'none' unless autoHighlight", async (page) => {
  const result = await page.evaluate(async () => {
    const { nextHighlight } = await import("chadcn/primitives/combobox_navigation");
    const step = (current, decrement, loopFocus, autoHighlight = false) => nextHighlight(current, 3, { decrement, loopFocus, autoHighlight });
    return {
      clampDown: [step(-1, false, false), step(0, false, false), step(2, false, false)],
      clampUp: [step(2, true, false), step(0, true, false), step(-1, true, false)],
      loopDown: [step(-1, false, true), step(1, false, true), step(2, false, true)],
      loopUp: [step(-1, true, true), step(1, true, true), step(0, true, true)],
      autoDown: step(2, false, true, true),
      autoUp: step(0, true, true, "always"),
    };
  });
  assert.deepEqual(result, {
    clampDown: [0, 1, 2],
    clampUp: [1, 0, 0],
    loopDown: [0, 2, -1],
    loopUp: [2, 0, -1],
    autoDown: 0,
    autoUp: 2,
  });
});

primitiveTest("combobox_navigation: an opening popup highlights the selection, else the first/last enabled item for an arrow key", async (page) => {
  const result = await page.evaluate(async () => {
    const { openHighlight } = await import("chadcn/primitives/combobox_navigation");
    const entries = [{ key: "a", disabled: true }, { key: "b", disabled: false }, { key: "c", disabled: false }, { key: "d", disabled: true }];
    const start = (options) => openHighlight(entries, { reason: "trigger-press", selected: [], keyOpened: null, autoHighlight: false, ...options });
    return {
      selected: start({ selected: ["c"] }),
      arrowDown: start({ keyOpened: "ArrowDown" }),
      arrowUp: start({ keyOpened: "ArrowUp" }),
      always: start({ autoHighlight: "always" }),
      none: start({}),
      allDisabled: openHighlight([{ key: "a", disabled: true }], { reason: "x", selected: [], keyOpened: "ArrowDown", autoHighlight: false }),
      empty: openHighlight([], { reason: "x", selected: [], keyOpened: null, autoHighlight: "always" }),
    };
  });
  assert.deepEqual(result, {
    selected: { index: 2, reason: "trigger-press", scroll: true },
    arrowDown: { index: 1, reason: "list-navigation", scroll: true },
    arrowUp: { index: 2, reason: "list-navigation", scroll: true },
    always: { index: 0, reason: "none", scroll: false },
    none: null,
    allDisabled: null,
    empty: null,
  });
});

primitiveTest("combobox_navigation: chip keys move, remove, return to the input or open, and follow the writing direction", async (page) => {
  const result = await page.evaluate(async () => {
    const { chipArrowKeys, chipKeyAction } = await import("chadcn/primitives/combobox_navigation");
    const ltr = chipArrowKeys("ltr");
    const action = (key, index, extra = {}) => chipKeyAction({ key, ...extra }, index, { count: 3, selectedCount: 3, arrows: ltr });
    return {
      rtl: chipArrowKeys("rtl"),
      previous: action("ArrowLeft", 1),
      previousFromFirst: action("ArrowLeft", 0),
      next: action("ArrowRight", 1),
      nextFromLast: action("ArrowRight", 2),
      backspaceLast: action("Backspace", 2),
      deleteMiddle: action("Delete", 1),
      deleteOnly: chipKeyAction({ key: "Delete" }, 0, { count: 1, selectedCount: 1, arrows: ltr }),
      enter: action("Enter", 1),
      space: action(" ", 1),
      down: action("ArrowDown", 1),
      printable: action("x", 1),
      modified: action("x", 1, { ctrlKey: true }),
      other: action("Tab", 1),
    };
  });
  assert.deepEqual(result, {
    rtl: { previous: "ArrowRight", next: "ArrowLeft" },
    previous: { focus: 0, prevent: true },
    previousFromFirst: { focus: null, prevent: true },
    next: { focus: 2, prevent: true },
    nextFromLast: { focus: null, prevent: true },
    backspaceLast: { focus: 1, remove: true, stop: true },
    deleteMiddle: { focus: 1, remove: true, stop: true },
    deleteOnly: { focus: null, remove: true, stop: true },
    enter: { focus: null, stop: true },
    space: { focus: null, stop: true },
    down: { focus: null, stop: true, open: true },
    printable: { focus: null },
    modified: { focus: 1 },
    other: { focus: 1 },
  });
});

primitiveTest("combobox_navigation: toggleValue appends or removes a value, withoutIndex drops one position", async (page) => {
  const result = await page.evaluate(async () => {
    const { toggleValue, withoutIndex } = await import("chadcn/primitives/combobox_navigation");
    const selected = ["a", "b"];
    return {
      add: toggleValue(selected, "c"),
      remove: toggleValue(selected, "a"),
      drop: withoutIndex(["a", "b", "c"], 1),
      outOfRange: withoutIndex(["a"], 3),
      untouched: selected,
    };
  });
  assert.deepEqual(result, { add: ["a", "b", "c"], remove: ["b"], drop: ["a", "c"], outOfRange: ["a"], untouched: ["a", "b"] });
});
