import { assert, primitiveTest } from "./primitives_support.mjs";

// primitives/combobox_filter.js: the matching of the Combobox list (Base UI contains filter, the fuzzy scorer, the selected-label
// bypass, the limit) and the closed-trigger typeahead. Pure functions, exercised without the controller.

primitiveTest("combobox_filter: the contains filter is a collator substring match (case, accents and punctuation ignored)", async (page) => {
  const result = await page.evaluate(async () => {
    const { collatorContains } = await import("chadcn/primitives/combobox_filter");
    const contains = collatorContains("en");
    return {
      caseInsensitive: contains("Next.js", "JS"),
      punctuation: contains("Next.js", "next-js"),
      accents: contains("Crème brûlée", "creme"),
      substring: contains("SvelteKit", "elte"),
      noSubsequence: contains("Next.js", "nxt"),
      emptyQuery: contains("Astro", ""),
      longerQuery: contains("Vue", "Vue.js!"),
    };
  });
  assert.deepEqual(result, { caseInsensitive: true, punctuation: true, accents: true, substring: true, noSubsequence: false, emptyQuery: true, longerQuery: false });
});

primitiveTest("combobox_filter: an unedited query equal to the single selection's label filters nothing", async (page) => {
  const result = await page.evaluate(async () => {
    const { collatorContains, filterQuery } = await import("chadcn/primitives/combobox_filter");
    const contains = collatorContains("en");
    const base = { selectedLabel: "Astro", single: true, queryEdited: false, contains };
    return {
      bypassed: filterQuery("Astro", base),
      caseFolded: filterQuery("astro", base),
      edited: filterQuery("Astro", { ...base, queryEdited: true }),
      multiple: filterQuery("Astro", { ...base, single: false }),
      otherText: filterQuery("Astr", base),
      noSelection: filterQuery("Astro", { ...base, selectedLabel: "" }),
    };
  });
  assert.deepEqual(result, { bypassed: "", caseFolded: "", edited: "Astro", multiple: "Astro", otherText: "Astr", noSelection: "Astro" });
});

primitiveTest("combobox_filter: fuzzy ranks best first and cuts after ranking, contains keeps source order, null filters nothing", async (page) => {
  const result = await page.evaluate(async () => {
    const { collatorContains, matchItems } = await import("chadcn/primitives/combobox_filter");
    const contains = collatorContains("en");
    const items = ["Next.js", "SvelteKit", "Nuxt.js", "Remix", "Astro"].map((l) => ({ k: l.toLowerCase(), l }));
    const labels = (match) => match.list.map(({ l }) => l);
    const fuzzy = matchItems(items, "s", { filter: "fuzzy", limit: 2, contains });
    return {
      fuzzy: labels(fuzzy),
      scores: fuzzy.scores instanceof Map && fuzzy.scores.get("sveltekit") > fuzzy.scores.get("astro"),
      contains: labels(matchItems(items, "JS", { filter: "contains", contains })),
      containsScores: matchItems(items, "JS", { filter: "contains", contains }).scores,
      none: labels(matchItems(items, "zzz", { filter: null, contains })),
      empty: labels(matchItems(items, "", { filter: "fuzzy", limit: 3, contains })),
      query: matchItems(items, "rem", { filter: "fuzzy", contains }).query,
    };
  });
  assert.deepEqual(result, {
    fuzzy: ["SvelteKit", "Astro"],
    scores: true,
    contains: ["Next.js", "Nuxt.js"],
    containsScores: null,
    none: ["Next.js", "SvelteKit", "Nuxt.js", "Remix", "Astro"],
    empty: ["Next.js", "SvelteKit", "Nuxt.js"],
    query: "rem",
  });
});

primitiveTest("combobox_filter: typeaheadIndex finds the next label after a position, wrapping, case-insensitive", async (page) => {
  const result = await page.evaluate(async () => {
    const { typeaheadIndex } = await import("chadcn/primitives/combobox_filter");
    const items = [{ l: "Apple" }, { l: "Banana" }, { l: "avocado" }];
    return {
      fromStart: typeaheadIndex(items, "a"),
      afterFirst: typeaheadIndex(items, "A", 0),
      wraps: typeaheadIndex(items, "a", 2),
      prefix: typeaheadIndex(items, "ban"),
      missing: typeaheadIndex(items, "z"),
      none: typeaheadIndex([], "a"),
    };
  });
  assert.deepEqual(result, { fromStart: 0, afterFirst: 2, wraps: 0, prefix: 1, missing: -1, none: -1 });
});

primitiveTest("combobox_filter: the trigger typeahead starts after the selection, builds a buffer, cycles a repeated key and resets", async (page) => {
  const result = await page.evaluate(async () => {
    const { triggerTypeahead } = await import("chadcn/primitives/combobox_filter");
    const items = ["Apple", "Apricot", "Banana", "Avocado"].map((l) => ({ k: l.toLowerCase(), l }));
    const matches = [];
    const first = triggerTypeahead({ timeout: 10_000, onMatch: (item) => matches.push(item.k) });
    first.push("a", items, ["apple"]);
    first.push("a", items, ["apricot"]);
    first.push("p", items, ["avocado"]);
    first.release();
    const second = triggerTypeahead({ timeout: 10_000, onMatch: (item) => matches.push(item.k) });
    second.push("b", items, []);
    second.push("z", items, ["banana"]);
    second.push("a", items, ["banana"]);
    second.push("a", [], []);
    second.release();
    return matches;
  });
  // "a" after Apple -> Apricot; repeated "a" cycles -> Avocado; "ap" from there -> Apple. A fresh buffer: "b" -> Banana; "bz" has no
  // match (the buffer resets); "a" after Banana -> Avocado; an empty list matches nothing.
  assert.deepEqual(result, ["apricot", "avocado", "apple", "banana", "avocado"]);
});
