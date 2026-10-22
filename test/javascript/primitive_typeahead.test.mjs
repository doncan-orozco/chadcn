import { assert, primitiveTest, useFakeTimers } from "./primitives_support.mjs";

primitiveTest("typeahead: nextMatch finds the first prefix match, cycles on a repeated letter and skips the current match", async (page) => {
  const result = await page.evaluate(async () => {
    const { nextMatch } = await import("chadcn/primitives/typeahead");
    const values = ["Apple", "Avocado", "Banana", "Apricot"];
    return {
      prefix: nextMatch(values, "ba"),
      caseInsensitive: nextMatch(values, "AV"),
      single: nextMatch(values, "a"),
      cycle: nextMatch(values, "a", "Apple"),
      repeated: nextMatch(values, "aa", "Apple"),
      cycleWrap: nextMatch(values, "a", "Apricot"),
      none: nextMatch(values, "zz"),
      sameOnly: nextMatch(["Apple"], "ap", "Apple"),
    };
  });
  assert.deepEqual(result, {
    prefix: "Banana", caseInsensitive: "Avocado", single: "Apple", cycle: "Avocado", repeated: "Avocado", cycleWrap: "Apple", none: undefined, sameOnly: undefined,
  });
});

primitiveTest("typeahead: matchItem is identity based (equal labels stay distinct) and honors a custom text function", async (page) => {
  const result = await page.evaluate(async () => {
    const { matchItem } = await import("chadcn/primitives/typeahead");
    const make = (text) => Object.assign(document.createElement("div"), { textContent: text });
    const [one, two, other] = [make("Same"), make("Same"), make("Other")];
    const items = [one, two, other];
    return {
      first: matchItem(items, "s") === one,
      next: matchItem(items, "s", one) === two,
      custom: matchItem([{ n: "x" }, { n: "yy" }], "y", undefined, (item) => item.n).n,
      none: matchItem(items, "q"),
    };
  });
  assert.deepEqual(result, { first: true, next: true, custom: "yy", none: undefined });
});

primitiveTest("typeahead: isCharacterKey accepts printable keys without ctrl/alt/meta only", async (page) => {
  const result = await page.evaluate(async () => {
    const { isCharacterKey } = await import("chadcn/primitives/typeahead");
    return [
      isCharacterKey({ key: "a" }), isCharacterKey({ key: "A", shiftKey: true }), isCharacterKey({ key: "Enter" }),
      isCharacterKey({ key: "a", ctrlKey: true }), isCharacterKey({ key: "a", altKey: true }), isCharacterKey({ key: "a", metaKey: true }),
    ];
  });
  assert.deepEqual(result, [true, true, false, false, false, false]);
});

primitiveTest("typeahead: the buffer accumulates keys, onSearch sees the next buffer first and it resets after the timeout", async (page) => {
  await useFakeTimers(page);
  const result = await page.evaluate(async () => {
    const { typeahead, RESET_MS } = await import("chadcn/primitives/typeahead");
    const seen = [];
    let buffer;
    const t = typeahead({ onSearch: (search) => { seen.push(search); buffer = t.search } });
    t.push("a");
    t.push("b");
    const afterKeys = t.search;
    window.__clock.advance(RESET_MS - 1);
    const beforeReset = t.search;
    t.push("c"); // restarts the timer
    window.__clock.advance(RESET_MS - 1);
    const stillThere = t.search;
    window.__clock.advance(1);
    return { seen, bufferDuringLastSearch: buffer, afterKeys, beforeReset, stillThere, afterReset: t.search, RESET_MS };
  });
  assert.deepEqual(result, { seen: ["a", "ab", "abc"], bufferDuringLastSearch: "ab", afterKeys: "ab", beforeReset: "ab", stillThere: "abc", afterReset: "", RESET_MS: 1000 });
});

primitiveTest("typeahead: reset() clears the buffer and release() cancels the pending timer", async (page) => {
  await useFakeTimers(page);
  const result = await page.evaluate(async () => {
    const { typeahead } = await import("chadcn/primitives/typeahead");
    const t = typeahead({ onSearch() {}, timeout: 50 });
    t.push("x");
    t.reset();
    const afterReset = { search: t.search, timers: window.__clock.pending() };
    t.push("y");
    const armed = window.__clock.pending();
    t.release();
    return { afterReset, armed, afterRelease: window.__clock.pending() };
  });
  assert.deepEqual(result, { afterReset: { search: "", timers: 0 }, armed: 1, afterRelease: 0 });
});

primitiveTest("typeahead: after release() no reset fires past the timeout and the buffer is kept", async (page) => {
  await useFakeTimers(page);
  const result = await page.evaluate(async () => {
    const { typeahead } = await import("chadcn/primitives/typeahead");
    const seen = [];
    const t = typeahead({ onSearch: (search) => seen.push(search), timeout: 50 });
    t.push("x");
    t.release();
    window.__clock.advance(500);
    return { search: t.search, seen, pending: window.__clock.pending() };
  });
  assert.deepEqual(result, { search: "x", seen: ["x"], pending: 0 });
});
