import { assert, primitiveTest } from "./primitives_support.mjs";

primitiveTest("ids: generateId mints unique ids with the default and a custom prefix", async (page) => {
  const ids = await page.evaluate(async () => {
    const { generateId } = await import("shadcn/primitives/ids");
    return [generateId(), generateId(), generateId("menu")];
  });
  assert.match(ids[0], /^radix-shadcn-\d+$/);
  assert.notEqual(ids[0], ids[1]);
  assert.match(ids[2], /^menu-\d+$/);
});

primitiveTest("ids: generateId never collides with an id already in the document", async (page) => {
  const result = await page.evaluate(async () => {
    const { generateId } = await import("shadcn/primitives/ids");
    const first = generateId("p");
    const n = Number(/^p-(\d+)$/.exec(first)[1]);
    const taken = document.createElement("div");
    taken.id = `p-${n + 1}`;
    document.body.append(taken);
    return { taken: taken.id, next: generateId("p") };
  });
  assert.notEqual(result.next, result.taken);
});

primitiveTest("ids: ensureId keeps a server-rendered id and assigns one only when missing", async (page) => {
  const result = await page.evaluate(async () => {
    const { ensureId } = await import("shadcn/primitives/ids");
    const withId = document.body.children[0];
    const without = document.body.children[1];
    return { kept: ensureId(withId), assigned: ensureId(without), again: ensureId(without), attr: without.id };
  });
  assert.equal(result.kept, "server");
  assert.match(result.assigned, /^radix-shadcn-\d+$/);
  assert.equal(result.again, result.assigned);
  assert.equal(result.attr, result.assigned);
}, { html: '<div id="server"></div><div></div>' });
