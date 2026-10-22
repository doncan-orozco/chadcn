import { assert, primitiveTest } from "./primitives_support.mjs";

primitiveTest("scorer: an empty or blank query matches everything with the same score and rank keeps the original order", async (page) => {
  const result = await page.evaluate(async () => {
    const { score, scoreItem, rank, EMPTY_QUERY_SCORE } = await import("chadcn/primitives/scorer");
    const items = ["Banana", "Apple", "Cherry"];
    return {
      empty: score("", "Banana") === EMPTY_QUERY_SCORE,
      blank: scoreItem("   ", "Banana", ["x"]) === EMPTY_QUERY_SCORE,
      nullish: score(undefined, "Banana") === EMPTY_QUERY_SCORE,
      order: rank("", items).map((r) => r.item),
      indexes: rank("", items).map((r) => r.index),
    };
  });
  assert.deepEqual(result, { empty: true, blank: true, nullish: true, order: ["Banana", "Apple", "Cherry"], indexes: [0, 1, 2] });
});

primitiveTest("scorer: the query must be a subsequence of the text, otherwise the score is 0", async (page) => {
  const result = await page.evaluate(async () => {
    const { score } = await import("chadcn/primitives/scorer");
    return {
      subsequence: score("gthb", "GitHub") > 0,
      outOfOrder: score("hg", "GitHub"),
      missing: score("zzz", "GitHub"),
      longer: score("githubs", "GitHub"),
      emptyText: score("a", ""),
    };
  });
  assert.deepEqual(result, { subsequence: true, outOfOrder: 0, missing: 0, longer: 0, emptyText: 0 });
});

primitiveTest("scorer: ranking prefers an exact match, a prefix, a word boundary, consecutive characters, then shorter texts", async (page) => {
  const result = await page.evaluate(async () => {
    const { score, rank } = await import("chadcn/primitives/scorer");
    const order = (query, items) => rank(query, items).map((r) => r.item);
    return {
      exactFirst: order("calendar", ["Calendar Settings", "calendar", "Open calendar"]),
      prefixOverMiddle: order("cal", ["Local", "Calendar", "Scalable"]),
      boundary: order("gh", ["Sunghy", "Great Hall", "GitHub"]),
      camel: score("gh", "GitHub") > score("gh", "Sunghy"),
      consecutive: order("ab", ["xaxb", "xxab"]),
      boundaryOverConsecutive: order("ab", ["xxab", "a-x-b"]),
      shorter: order("app", ["Application settings", "App"]),
      separators: order("ds", ["Design system", "Dashes"]),
    };
  });
  assert.deepEqual(result, {
    exactFirst: ["calendar", "Calendar Settings", "Open calendar"],
    prefixOverMiddle: ["Calendar", "Local", "Scalable"],
    boundary: ["GitHub", "Great Hall", "Sunghy"],
    camel: true,
    consecutive: ["xxab", "xaxb"],
    boundaryOverConsecutive: ["a-x-b", "xxab"],
    shorter: ["App", "Application settings"],
    separators: ["Design system", "Dashes"],
  });
});

primitiveTest("scorer: ties keep the original order (stable)", async (page) => {
  const result = await page.evaluate(async () => {
    const { rank } = await import("chadcn/primitives/scorer");
    const items = [{ id: 1, t: "Item" }, { id: 2, t: "Item" }, { id: 3, t: "Item" }];
    return rank("it", items, { text: (item) => item.t }).map((r) => r.item.id);
  });
  assert.deepEqual(result, [1, 2, 3]);
});

primitiveTest("scorer: case and diacritics are folded in both directions and offsets stay aligned with the original", async (page) => {
  const result = await page.evaluate(async () => {
    const { score, fold, rank } = await import("chadcn/primitives/scorer");
    return {
      accentInText: score("cafe", "Café") > 0,
      accentInQuery: score("café", "Cafe") > 0,
      upper: score("CAFE", "cafe au lait") > 0,
      folded: fold("Crème Brûlée"),
      enye: score("nino", "Niño") > 0,
      ranked: rank("jose", ["Jose", "José", "Joseph"]).map((r) => r.item),
      boundaryAfterAccent: score("ab", "Ábaco") > score("ab", "Zábaco"),
    };
  });
  assert.deepEqual(result, {
    accentInText: true, accentInQuery: true, upper: true, folded: "creme brulee", enye: true,
    ranked: ["Jose", "José", "Joseph"], boundaryAfterAccent: true,
  });
});

primitiveTest("scorer: keywords also match but rank below the same text match; the query ignores whitespace", async (page) => {
  const result = await page.evaluate(async () => {
    const { scoreItem, rank } = await import("chadcn/primitives/scorer");
    const items = [{ t: "Settings", k: ["preferences"] }, { t: "Preferences", k: [] }];
    return {
      viaKeyword: scoreItem("prefs", "Settings", ["preferences"]) > 0,
      noKeyword: scoreItem("prefs", "Settings"),
      order: rank("pref", items, { text: (i) => i.t, keywords: (i) => i.k }).map((r) => r.item.t),
      spaces: scoreItem("g h", "GitHub") === scoreItem("gh", "GitHub"),
    };
  });
  assert.deepEqual(result, { viaKeyword: true, noKeyword: 0, order: ["Preferences", "Settings"], spaces: true });
});

primitiveTest("scorer: ranking a few thousand items is fast", async (page) => {
  const result = await page.evaluate(async () => {
    const { rank } = await import("chadcn/primitives/scorer");
    const items = Array.from({ length: 5000 }, (_, i) => `Command number ${i} for the palette`);
    const started = performance.now();
    const hits = rank("cmd pal", items).length;
    return { hits, ms: performance.now() - started };
  });
  assert.equal(result.hits, 5000);
  assert.ok(result.ms < 500, `took ${result.ms}ms`);
});

primitiveTest("scorer: the exact bonus ignores whitespace in the text, like in the query", async (page) => {
  const result = await page.evaluate(async () => {
    const { rank } = await import("chadcn/primitives/scorer");
    return rank("newyork", ["New York City", "New York"]).map((r) => r.item);
  });
  assert.deepEqual(result, ["New York", "New York City"]);
});

primitiveTest("scorer: letters without a decomposition fold to one base letter", async (page) => {
  const result = await page.evaluate(async () => {
    const { score, fold } = await import("chadcn/primitives/scorer");
    return { folded: fold("Øłđðı ßæþ"), found: score("lodz", "Łódź") > 0, oslo: score("osl", "Øsløy") > 0 };
  });
  assert.deepEqual(result, { folded: "olddi ßæþ", found: true, oslo: true });
});

primitiveTest("scorer: a long text does not overflow the call stack", async (page) => {
  const result = await page.evaluate(async () => {
    const { score } = await import("chadcn/primitives/scorer");
    return score("a", "a".repeat(200000)) > 0;
  });
  assert.equal(result, true);
});
