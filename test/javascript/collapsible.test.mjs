import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, reconnect, settle } from "./support.mjs"
import { restore, snapshot } from "./turbo_support.mjs"

// chadcn--collapsible against its parity pages (spec: dev/port/specs/collapsible.md): pointer and keyboard, root, trigger and
// content state, the open-change event, controlled mode, as_child content, disconnect cleanup and a Turbo cache restore of a state
// the user chose. The core Turbo snapshot cases (closed body kept, exit animation finished) live in turbo_disclosure.test.mjs.

browserTest.component = "collapsible"

const root = "[data-slot=collapsible]"
const triggers = "[data-slot=collapsible-trigger]"
const content = "[data-slot=collapsible-content]"

// Every open-change the root dispatches, in order.
const recordOpenChanges = (page) => page.evaluate(() => {
  window.__changes = []
  document.addEventListener("chadcn--collapsible:open-change", (event) => window.__changes.push({ open: event.detail.open, cancelable: event.cancelable }))
})
const openChanges = (page) => page.evaluate(() => window.__changes)

// The state as a reader of the DOM sees it: root, every trigger and the content.
const state = (page) => page.evaluate(({ root, triggers, content }) => {
  const host = document.querySelector(root)
  const region = host.querySelector(content)
  return {
    root: host.dataset.state,
    triggers: [...host.querySelectorAll(triggers)].map((el) => ({
      state: el.dataset.state, expanded: el.getAttribute("aria-expanded"), controls: el.hasAttribute("aria-controls") ? el.getAttribute("aria-controls") === region?.id : null
    })),
    content: region && { state: region.dataset.state, hidden: region.hidden, body: region.textContent.trim() }
  }
}, { root, triggers, content })

const openState = (count = 1, body = "Hidden content") => ({
  root: "open",
  triggers: Array.from({ length: count }, () => ({ state: "open", expanded: "true", controls: true })),
  content: { state: "open", hidden: false, body }
})
const closedState = (count = 1) => ({
  root: "closed",
  triggers: Array.from({ length: count }, () => ({ state: "closed", expanded: "false", controls: null })),
  content: { state: "closed", hidden: true, body: "" }
})

browserTest("collapsible: a click opens the content, mounts its body and dispatches a non-cancelable open-change", async ({ open }) => {
  const page = await open("closed__rest")
  await recordOpenChanges(page)
  assert.deepEqual(await state(page), closedState())

  await page.click(triggers)
  await settle(page)
  assert.deepEqual(await state(page), openState())
  assert.equal(await page.locator(`${content} template`).count(), 0, "the body template is taken over")

  await page.click(triggers)
  await settle(page)
  assert.deepEqual(await state(page), closedState(), "closing unmounts the body and hides the content")
  assert.deepEqual(await openChanges(page), [{ open: true, cancelable: false }, { open: false, cancelable: false }])
})

browserTest("collapsible: Enter and Space on the focused trigger toggle the content", async ({ open }) => {
  const page = await open("closed__rest")
  await page.focus(triggers)
  await page.keyboard.press("Enter")
  await settle(page)
  assert.deepEqual(await state(page), openState())
  await page.keyboard.press("Space")
  await settle(page)
  assert.deepEqual(await state(page), closedState())
})

browserTest("collapsible: every trigger of a root reflects and drives the shared state", async ({ open }) => {
  const page = await open("multiple-triggers__shared-state")
  await page.getByRole("button", { name: "Open details" }).click()
  await settle(page)
  assert.deepEqual(await state(page), openState(2, "Details"))
  await page.getByRole("button", { name: "Close details" }).click()
  await settle(page)
  assert.deepEqual(await state(page), closedState(2))
})

browserTest("collapsible: a controlled collapsible only dispatches open-change and leaves the DOM to the server", async ({ open }) => {
  const page = await open("controlled-open__rest")
  await recordOpenChanges(page)
  const before = await state(page)
  assert.equal(before.root, "open", "precondition: rendered open")
  await page.click(triggers)
  await settle(page)
  assert.deepEqual(await state(page), before)
  assert.deepEqual(await openChanges(page), [{ open: false, cancelable: false }])
})

browserTest("collapsible: a click the caller prevented does not toggle", async ({ open }) => {
  const page = await open("closed__rest")
  await recordOpenChanges(page)
  await page.evaluate(() => document.addEventListener("click", (event) => event.preventDefault(), { capture: true }))
  await page.click(triggers)
  await settle(page)
  assert.deepEqual(await state(page), closedState())
  assert.deepEqual(await openChanges(page), [])
})

browserTest("collapsible: an as_child content is absent while closed and inserted on open", async ({ open }) => {
  const page = await open("as-child__content__closed-then-open")
  assert.equal(await page.locator(content).count(), 0, "no content element while closed")
  await page.click(triggers)
  await settle(page)
  assert.equal(await page.locator(`${content}[data-state=open]`).count(), 1)
  assert.equal(await page.locator(content).isVisible(), true)
  await page.click(triggers)
  await settle(page)
  assert.equal(await page.locator(content).count(), 0, "closing removes the slotted element again")
})

// NO_MOTION is `*{animation:none!important}` (specificity 0,0,0): a more specific !important rule wins, so the exit animation runs.
const holdExit = (page) => page.addStyleTag({
  content: `@keyframes chadcn-test-hold{to{opacity:.5}} ${content}[data-state=closed]{animation:chadcn-test-hold 60s!important}`
})

// disconnect() must release the content's exit listener: an animation that ends after the controller is gone must not touch the DOM.
browserTest("collapsible: an exit animation that ends after disconnect leaves the content alone", async ({ open }) => {
  const page = await open("default-open__rest")
  await holdExit(page)
  await page.click(triggers)
  const exiting = page.locator(content)
  assert.ok(await exiting.evaluate((el) => el.dataset.state === "closed" && !el.hidden && el.textContent.trim() !== ""), "precondition: exit running")

  await page.evaluate(async (root) => {
    document.querySelector(root).setAttribute("data-controller", "")
    await new Promise((resolve) => setTimeout(resolve))
  }, root)
  await exiting.evaluate((el) => el.dispatchEvent(new AnimationEvent("animationend", { animationName: "chadcn-test-hold" })))
  await settle(page)
  assert.deepEqual(await exiting.evaluate((el) => ({ hidden: el.hidden, body: el.textContent.trim() })), { hidden: false, body: "Hidden content" })
})

browserTest("collapsible: an open content moved in the DOM still closes and reopens with its body", async ({ open }) => {
  const page = await open("default-open__rest")
  const errors = consoleErrors(page)
  await reconnect(page, "chadcn--collapsible")
  await page.click(triggers)
  await settle(page)
  assert.deepEqual(await state(page), closedState())
  await page.click(triggers)
  await settle(page)
  assert.deepEqual(await state(page), openState())
  assert.deepEqual(errors, [])
})

browserTest("collapsible: a content the user opened survives a Turbo cache snapshot and restore", async ({ open }) => {
  const page = await open("closed__rest")
  await page.click(triggers)
  await settle(page)
  const html = await snapshot(page, "chadcn--collapsible")
  await restore(page, "chadcn--collapsible", html)
  assert.deepEqual(await state(page), openState())

  await recordOpenChanges(page)
  await page.click(triggers)
  await settle(page)
  assert.deepEqual(await state(page), closedState())
  assert.deepEqual(await openChanges(page), [{ open: false, cancelable: false }], "the restored controller knows it is open")
})
