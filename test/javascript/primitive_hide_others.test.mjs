import { assert, primitiveTest } from "./primitives_support.mjs";

const html = `
  <header id="header">h</header>
  <main id="app"><nav id="nav">n</nav><section id="section"><div id="target">t</div><p id="sibling">s</p></section></main>
  <div id="live" aria-live="polite">l</div>
  <script id="script">/* inert */</script>
  <aside id="already" aria-hidden="true">a</aside>
  <aside id="falsy" aria-hidden="false">f</aside>`;

const snapshot = () => Object.fromEntries([...document.body.children, ...document.querySelectorAll("#nav, #sibling, #target, #section")]
  .map((el) => [el.id, [el.getAttribute("aria-hidden"), el.getAttribute("data-aria-hidden")]]));

primitiveTest("hide_others: hides every sibling along the path to body, never the target, its ancestors or live regions", async (page) => {
  const result = await page.evaluate(async (snap) => {
    const { hideOthers } = await import("shadcn/primitives/hide_others");
    const take = new Function(`return (${snap})()`);
    hideOthers(document.getElementById("target"));
    return take();
  }, snapshot.toString());
  assert.deepEqual(result.header, ["true", "true"]);
  assert.deepEqual(result.nav, ["true", "true"]);
  assert.deepEqual(result.sibling, ["true", "true"]);
  assert.deepEqual(result.target, [null, null]);
  assert.deepEqual(result.section, [null, null]);
  assert.deepEqual(result.app, [null, null]);
  assert.deepEqual(result.live, [null, null]);
  assert.deepEqual(result.script, [null, null]);
  assert.deepEqual(result.falsy, ["true", "true"]);
}, { html });

primitiveTest("hide_others: release() restores every attribute, leaves pre-hidden nodes alone and is ref-counted when nested", async (page) => {
  const result = await page.evaluate(async (snap) => {
    const { hideOthers } = await import("shadcn/primitives/hide_others");
    const take = new Function(`return (${snap})()`);
    const before = take();
    const outer = hideOthers(document.getElementById("target"));
    const inner = hideOthers(document.getElementById("sibling"));
    inner();
    const afterInner = take();
    outer();
    return { before, afterInner, after: take() };
  }, snapshot.toString());
  // The outer lock still hides the header after the inner one is gone.
  assert.deepEqual(result.afterInner.header, ["true", "true"]);
  assert.deepEqual(result.afterInner.nav, ["true", "true"]);
  // The pre-hidden node keeps its own aria-hidden through the inner release (the outer lock still marks it).
  assert.deepEqual(result.afterInner.already, ["true", "true"]);
  // A node that was already aria-hidden keeps its own value; "false" is restored by removal like Radix's aria-hidden package.
  assert.deepEqual(result.after.already, ["true", null]);
  assert.deepEqual(result.after.header, [null, null]);
  assert.deepEqual(result.after.nav, [null, null]);
  assert.deepEqual(result.after.sibling, [null, null]);
  assert.deepEqual(result.after.falsy, [null, null]);
  assert.deepEqual(result.before.already, ["true", null]);
}, { html });

primitiveTest("hide_others: accepts several targets and an explicit parent", async (page) => {
  const result = await page.evaluate(async () => {
    const { hideOthers } = await import("shadcn/primitives/hide_others");
    const release = hideOthers([document.getElementById("target"), null, document.getElementById("nav")], document.getElementById("app"));
    const hidden = [...document.querySelectorAll("[aria-hidden=true][data-aria-hidden]")].map((el) => el.id);
    release();
    return { hidden, left: document.querySelectorAll("[data-aria-hidden]").length };
  });
  assert.deepEqual(result.hidden, ["sibling"]);
  assert.equal(result.left, 0);
}, { html });

primitiveTest("hide_others: { marker: false } sets aria-hidden without the data-aria-hidden marker and releases cleanly", async (page) => {
  const result = await page.evaluate(async (snap) => {
    const { hideOthers } = await import("shadcn/primitives/hide_others");
    const take = new Function(`return (${snap})()`);
    const release = hideOthers(document.getElementById("target"), document.body, { marker: false });
    const hidden = take();
    release();
    return { hidden, released: take() };
  }, snapshot.toString());
  assert.deepEqual(result.hidden.header, ["true", null]);
  assert.deepEqual(result.hidden.sibling, ["true", null]);
  assert.deepEqual(result.released.header, [null, null]);
  assert.deepEqual(result.released.already, ["true", null]);
}, { html });

primitiveTest("hide_others: a { marker: false } call and a default-marker call on the same nodes compose and release in any order", async (page) => {
  const result = await page.evaluate(async (snap) => {
    const { hideOthers } = await import("shadcn/primitives/hide_others");
    const take = new Function(`return (${snap})()`);
    const target = document.getElementById("target");
    const releaseBare = hideOthers(target, document.body, { marker: false });
    const releaseMarked = hideOthers(target, document.body);
    const both = take();
    releaseBare();
    const afterBare = take();
    releaseMarked();
    return { both, afterBare, released: take() };
  }, snapshot.toString());
  assert.equal(result.both.sibling[0], "true");
  assert.equal(result.afterBare.sibling[0], "true", "still hidden by the marked call");
  assert.deepEqual(result.released.sibling, [null, null]);
  assert.deepEqual(result.released.header, [null, null]);
}, { html });
