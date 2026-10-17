import { assert, primitiveTest, tick } from "./primitives_support.mjs";

const html = `
  <button id="before">before</button>
  <div id="scope"><button id="one">1</button><button id="two">2</button></div>
  <div id="inner"><button id="innerOne">i</button></div>
  <button id="after">after</button>
  <div id="empty"></div>`;
const active = (page) => page.evaluate(() => document.activeElement.id);
const start = async (page, options = "{}", selector = "scope") => {
  await page.focus("#before");
  await page.evaluate(async ([options, selector]) => {
    const { focusScope } = await import("shadcn/primitives/focus_scope");
    window.__log = [];
    const opts = new Function("log", `return (${options})`)(window.__log);
    (window.__releases ??= {})[selector] = focusScope(document.getElementById(selector), opts);
  }, [options, selector]);
};
const release = (page, selector = "scope") => page.evaluate((selector) => window.__releases[selector](), selector);

primitiveTest("focus_scope: on mount the first tabbable child takes focus and the container gets a temporary tabindex", async (page) => {
  await start(page);
  assert.equal(await active(page), "one");
  assert.equal(await page.getAttribute("#scope", "tabindex"), "-1");
  await release(page);
  assert.equal(await page.getAttribute("#scope", "tabindex"), null);
}, { html });

primitiveTest("focus_scope: an empty scope focuses the container; a pre-existing tabindex is kept on release", async (page) => {
  await page.evaluate(() => document.getElementById("empty").setAttribute("tabindex", "0"));
  await start(page, "{}", "empty");
  assert.equal(await active(page), "empty");
  await release(page, "empty");
  assert.equal(await page.getAttribute("#empty", "tabindex"), "0");
}, { html });

primitiveTest("focus_scope: onMountAutoFocus is cancelable and keeps focus where it is when prevented", async (page) => {
  await start(page, "{ onMountAutoFocus: (e) => { log.push('mount:' + e.cancelable); e.preventDefault() } }");
  assert.equal(await active(page), "before");
  assert.deepEqual(await page.evaluate(() => window.__log), ["mount:true"]);
}, { html });

primitiveTest("focus_scope: release() returns focus to the previously focused element on the next task", async (page) => {
  await start(page);
  const sync = await page.evaluate(() => { window.__releases.scope(); return document.activeElement.id });
  assert.equal(sync, "one", "return focus is deferred, like Radix");
  await tick(page);
  assert.equal(await active(page), "before");
}, { html });

primitiveTest("focus_scope: onUnmountAutoFocus is cancelable and prevents the focus return", async (page) => {
  await start(page, "{ onUnmountAutoFocus: (e) => { log.push('unmount:' + e.cancelable); e.preventDefault() } }");
  await release(page);
  await tick(page);
  assert.equal(await active(page), "one");
  assert.deepEqual(await page.evaluate(() => window.__log), ["unmount:true"]);
}, { html });

primitiveTest("focus_scope: trapped pulls focus back from outside; release() removes the trap", async (page) => {
  await start(page, "{ trapped: true }");
  await page.focus("#two");
  await page.evaluate(() => document.getElementById("after").focus());
  assert.equal(await active(page), "two");
  await release(page);
  await tick(page);
  await page.evaluate(() => document.getElementById("after").focus());
  assert.equal(await active(page), "after");
}, { html });

primitiveTest("focus_scope: loop wraps Tab and Shift+Tab at the edges, and stops after release", async (page) => {
  await start(page, "{ loop: true }");
  await page.focus("#two");
  await page.keyboard.press("Tab");
  assert.equal(await active(page), "one");
  await page.keyboard.press("Shift+Tab");
  assert.equal(await active(page), "two");
  await release(page);
  await tick(page);
  await page.focus("#two");
  await page.keyboard.press("Tab");
  assert.equal(await active(page), "innerOne", "native tab order resumes");
}, { html });

primitiveTest("focus_scope: a trapped scope without loop keeps Tab inside at the last element", async (page) => {
  await start(page, "{ trapped: true }");
  await page.focus("#two");
  await page.keyboard.press("Tab");
  assert.equal(await active(page), "two");
}, { html });

primitiveTest("focus_scope: nested scopes pause the outer one and resume it on release", async (page) => {
  await start(page, "{ trapped: true }");
  await page.evaluate(async () => {
    const { focusScope } = await import("shadcn/primitives/focus_scope");
    window.__focusins = [];
    document.addEventListener("focusin", (event) => window.__focusins.push(event.target.id));
    window.__releases.inner = focusScope(document.getElementById("inner"), { trapped: true });
  });
  assert.equal(await active(page), "innerOne");
  assert.deepEqual(await page.evaluate(() => window.__focusins), ["innerOne"], "the paused outer trap did not fight the inner scope's focus");
  // Only the inner trap acts: it pulls focus back into the inner scope.
  await page.evaluate(() => document.getElementById("one").focus());
  assert.equal(await active(page), "innerOne");
  await release(page, "inner");
  await tick(page);
  assert.equal(await active(page), "one", "focus returns to where it was before the inner scope");
  await page.evaluate(() => document.getElementById("after").focus());
  assert.equal(await active(page), "one", "the outer trap is active again");
}, { html });

primitiveTest("focus_scope: the MutationObserver is disconnected on release (a removed focused element does not pull focus back)", async (page) => {
  await page.evaluate(() => document.getElementById("scope").setAttribute("tabindex", "0"));
  await start(page, "{ trapped: true }");
  await release(page);
  await tick(page);
  await page.focus("#one");
  await page.evaluate(() => document.getElementById("one").remove());
  await tick(page);
  assert.notEqual(await active(page), "scope");
}, { html });

primitiveTest("focus_scope: releasing nested scopes outer-first leaves the inner trap active", async (page) => {
  await start(page, "{ trapped: true }");
  await page.evaluate(async () => {
    const { focusScope } = await import("shadcn/primitives/focus_scope");
    window.__releases.inner = focusScope(document.getElementById("inner"), { trapped: true });
  });
  await release(page, "scope");
  await tick(page);
  await page.evaluate(() => document.getElementById("after").focus());
  assert.equal(await active(page), "innerOne", "the inner trap still pulls focus back");
}, { html });

primitiveTest("focus_scope: onMountAutoFocus is not dispatched when focus is already inside the container at mount", async (page) => {
  await page.focus("#one");
  await page.evaluate(async () => {
    const { focusScope } = await import("shadcn/primitives/focus_scope");
    window.__log = [];
    window.__release = focusScope(document.getElementById("scope"), { onMountAutoFocus: () => window.__log.push("mount") });
  });
  assert.deepEqual(await page.evaluate(() => window.__log), []);
  assert.equal(await active(page), "one");
}, { html });
