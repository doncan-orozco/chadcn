import { assert, frames, primitiveTest } from "./primitives_support.mjs";

const css = `
  @keyframes out { from { opacity: 1 } to { opacity: 0 } }
  .animated[data-state=closed] { animation: out 30ms }
  #el { width: 120px; height: 50px; overflow: hidden }
`;
const html = '<div id="el" class="animated" data-state="closed" hidden>content</div>';
const run = (page, body) => page.evaluate(new Function(`return (async () => { const { collapsibleContent } = await import("chadcn/primitives/collapsible_content"); const el = document.getElementById("el"); ${body} })()`));
const vars = `(() => ({ height: el.style.getPropertyValue("--radix-collapsible-content-height"), width: el.style.getPropertyValue("--radix-collapsible-content-width") }))()`;

primitiveTest("collapsible_content: setOpen(true) reveals the content and measures its size variables", async (page) => {
  const result = await run(page, `
    const content = collapsibleContent(el, { open: false });
    content.setOpen(true);
    return { state: el.dataset.state, hidden: el.hidden, vars: ${vars}, transition: el.style.transitionDuration, animation: el.style.animationName };`);
  assert.deepEqual(result, { state: "open", hidden: false, vars: { height: "50px", width: "120px" }, transition: "", animation: "" });
}, { html, css, motion: true });

primitiveTest("collapsible_content: without an exit animation setOpen(false) hides at once, clears the size variables and calls onExited", async (page) => {
  const result = await run(page, `
    el.className = "";
    el.hidden = false; el.dataset.state = "open";
    let exited = 0;
    const content = collapsibleContent(el, { open: true, onExited: () => exited++ });
    const open = ${vars};
    content.setOpen(false);
    return { open, state: el.dataset.state, hidden: el.hidden, vars: ${vars}, exited };`);
  assert.deepEqual(result.open, { height: "50px", width: "120px" });
  assert.deepEqual({ state: result.state, hidden: result.hidden, vars: result.vars, exited: result.exited }, { state: "closed", hidden: true, vars: { height: "", width: "" }, exited: 1 });
}, { html, css, motion: true });

primitiveTest("collapsible_content: with an exit animation the content stays visible until animationend, then hides and calls onExited", async (page) => {
  await run(page, `
    el.hidden = false; el.dataset.state = "open";
    window.__exited = new Promise((resolve) => { window.__content = collapsibleContent(el, { open: true, onExited: resolve }) });`);
  await frames(page); // the mount animation guard is lifted on the next frame
  const result = await run(page, `
    window.__content.setOpen(false);
    const during = { hidden: el.hidden, vars: ${vars} };
    await window.__exited;
    return { during, after: { hidden: el.hidden, state: el.dataset.state } };`);
  assert.deepEqual(result.during, { hidden: false, vars: { height: "50px", width: "120px" } });
  assert.deepEqual(result.after, { hidden: true, state: "closed" });
}, { html, css, motion: true });

primitiveTest("collapsible_content: an initially open content suspends transitions and animations until the next frame, then restores the originals", async (page) => {
  const before = await run(page, `
    el.hidden = false; el.dataset.state = "open";
    el.style.transitionDuration = "";
    window.__content = collapsibleContent(el, { open: true });
    return { transition: el.style.transitionDuration, animation: el.style.animationName };`);
  assert.deepEqual(before, { transition: "0s", animation: "none" });
  await frames(page);
  const after = await run(page, `
    window.__content.setOpen(false);
    window.__content.setOpen(true);
    return { transition: el.style.transitionDuration, animation: el.style.animationName };`);
  assert.deepEqual(after, { transition: "", animation: "" });
}, { html, css, motion: true });

primitiveTest("collapsible_content: release() cancels the pending exit; it is safe to repeat", async (page) => {
  await run(page, `
    el.hidden = false; el.dataset.state = "open";
    window.__exited = 0;
    window.__content = collapsibleContent(el, { open: true, onExited: () => window.__exited++ });`);
  await frames(page);
  const result = await run(page, `
    window.__content.setOpen(false);
    window.__content.release();
    window.__content.release();
    await new Promise((resolve) => el.addEventListener("animationend", resolve, { once: true }));
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    return { exited: window.__exited, hidden: el.hidden };`);
  assert.deepEqual(result, { exited: 0, hidden: false });
}, { html, css, motion: true });

primitiveTest("collapsible_content: release() before the first frame cancels the mount-animation guard frame", async (page) => {
  const result = await run(page, `
    el.hidden = false; el.dataset.state = "open";
    const content = collapsibleContent(el, { open: true });
    content.release();
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    content.setOpen(true);
    return { transition: el.style.transitionDuration, animation: el.style.animationName };`);
  // Documents incidental state (not a contract): the guard frame never ran, so the content is still treated as "mounted open" and keeps its animations suspended.
  assert.deepEqual(result, { transition: "0s", animation: "none" });
}, { html, css, motion: true });
