import { assert, primitiveTest } from "./primitives_support.mjs";

// The separator keyboard of the resizable group, called directly: a key and an orientation in, an intent out.

primitiveTest("resizable_keyboard: arrows step along the orientation, Home/End go to the limits, Enter toggles and F6 cycles", async (page) => {
  const intents = await page.evaluate(async () => {
    const { keyboardIntent, KEYBOARD_STEP } = await import("chadcn/primitives/resizable_keyboard");
    const keys = ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End", "Enter", "F6", "Tab", "a"];
    return {
      step: KEYBOARD_STEP,
      horizontal: keys.map((key) => keyboardIntent({ key, orientation: "horizontal" }) ?? null),
      vertical: keys.map((key) => keyboardIntent({ key, orientation: "vertical" }) ?? null),
      backwards: keyboardIntent({ key: "F6", orientation: "horizontal", shiftKey: true }),
    };
  });
  const resize = (delta) => ({ type: "resize", delta });
  const rest = [resize(-100), resize(100), { type: "toggle-collapse" }, { type: "focus", backwards: false }, null, null];
  assert.equal(intents.step, 5);
  assert.deepEqual(intents.horizontal, [resize(-5), resize(5), { type: "none" }, { type: "none" }, ...rest]);
  assert.deepEqual(intents.vertical, [{ type: "none" }, { type: "none" }, resize(-5), resize(5), ...rest]);
  assert.deepEqual(intents.backwards, { type: "focus", backwards: true });
});

primitiveTest("resizable_keyboard: Enter collapses the panel, expands it back to its remembered size or its minimum, and ignores a fixed panel", async (page) => {
  const deltas = await page.evaluate(async () => {
    const { collapseToggleDelta } = await import("chadcn/primitives/resizable_keyboard");
    const constraints = { collapsible: true, collapsedSize: 0, minSize: 20 };
    return {
      collapse: collapseToggleDelta({ constraints, size: 40 }),
      expandToRemembered: collapseToggleDelta({ constraints, size: 0, expandedSize: 35 }),
      expandToMinimum: collapseToggleDelta({ constraints, size: 0 }),
      fixedPanel: collapseToggleDelta({ constraints: { collapsible: false, collapsedSize: 0, minSize: 20 }, size: 40 }) ?? null,
    };
  });
  assert.deepEqual(deltas, { collapse: -40, expandToRemembered: 35, expandToMinimum: 20, fixedPanel: null });
});

primitiveTest("resizable_keyboard: nextSeparatorIndex wraps forwards and backwards", async (page) => {
  const indexes = await page.evaluate(async () => {
    const { nextSeparatorIndex } = await import("chadcn/primitives/resizable_keyboard");
    return [[0, false], [2, false], [0, true], [1, true]].map(([index, backwards]) => nextSeparatorIndex({ index, count: 3, backwards }));
  });
  assert.deepEqual(indexes, [1, 0, 2, 0]);
});
