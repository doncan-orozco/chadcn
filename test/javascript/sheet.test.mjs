import { browserTest } from "./harness.mjs"
import { assert, eventLog, events, host, recordEvents, settle } from "./support.mjs"
import { restore, snapshot } from "./turbo_support.mjs"

// Sheet (spec dev/port/specs/sheet.md, Behavior): Radix Dialog under its own identifier. The scenarios compare the DOM and focus
// after clicks and keys with React; this file pins what they cannot see: the public events a caller receives and their order
// (open-change, open-auto-focus, escape-key-down, pointer-down-outside, interact-outside, close-auto-focus), a caller's
// preventDefault on each, the modal and non-modal outside rules, the controlled mode, what a disconnect releases, and a controller
// restored from a Turbo snapshot. The Turbo snapshot itself (no overlay, no lock, closed) is pinned in turbo_overlays.test.mjs.
browserTest.component = "sheet"
const controller = "chadcn--sheet"
const trigger = "[data-slot=sheet-trigger]"
const content = "[data-slot=sheet-content]"
const overlay = "[data-slot=sheet-overlay]"

const openSheet = async (page) => {
  await page.click(trigger)
  await page.waitForSelector(content)
  await settle(page)
}
// The focus scope returns focus (and dispatches close-auto-focus) a task after the content leaves: wait for the event when
// the test records events, never for the clock.
const untilClosed = async (page) => {
  await page.waitForSelector(content, { state: "detached" })
  await page.waitForFunction(() => window.__events.some((event) => event.name === "close-auto-focus"))
}
const focusedId = (page) => page.evaluate(() => document.activeElement?.id || document.activeElement?.dataset.slot || document.activeElement?.tagName)
const eventsNamed = async (page, name) => (await eventLog(page)).filter((event) => event.name === name)
const openChanges = async (page) => (await eventsNamed(page, "open-change")).map((event) => event.open)
const lockState = (page) => page.evaluate(() => ({
  scrollLocked: document.body.hasAttribute("data-scroll-locked"),
  pointerEvents: document.body.style.pointerEvents,
  // hideOthers marks the body children outside the content; icons inside the content carry their own aria-hidden.
  hidden: document.querySelectorAll("body > [aria-hidden=true]").length
}))

browserTest("sheet: opening reports open-change and open-auto-focus and focuses the first input; Escape closes back to the trigger", async ({ open }) => {
  const page = await open("closed__rest")
  await recordEvents(page, controller)
  await openSheet(page)
  assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "true")
  assert.equal(await page.locator(trigger).getAttribute("aria-controls"), await page.locator(content).getAttribute("id"))
  assert.equal(await focusedId(page), "sheet-demo-name")
  await page.keyboard.press("Escape")
  await untilClosed(page)
  assert.deepEqual(await events(page), ["open-change", "open-auto-focus", "escape-key-down", "open-change", "close-auto-focus"])
  assert.deepEqual(await openChanges(page), [true, false])
  assert.equal(await focusedId(page), "sheet-trigger")
  assert.equal(await page.locator(trigger).getAttribute("aria-controls"), null)
})

browserTest("sheet: a caller that prevents open-auto-focus keeps the focus out of the content", async ({ open }) => {
  const page = await open("closed__rest")
  await recordEvents(page, controller, { prevent: ["open-auto-focus"] })
  await openSheet(page)
  assert.equal(await page.evaluate((selector) => document.querySelector(selector).contains(document.activeElement), content), false)
})

browserTest("sheet: a caller that prevents escape-key-down keeps it open", async ({ open }) => {
  const page = await open("closed__rest")
  await recordEvents(page, controller, { prevent: ["escape-key-down"] })
  await openSheet(page)
  await page.keyboard.press("Escape")
  await settle(page)
  assert.equal(await page.locator(content).getAttribute("data-state"), "open")
  assert.deepEqual(await openChanges(page), [true])
})

browserTest("sheet: an overlay click reports pointer-down-outside then interact-outside, both cancelable, and closes", async ({ open }) => {
  const page = await open("closed__rest")
  await recordEvents(page, controller)
  await openSheet(page)
  await page.locator(overlay).click({ position: { x: 10, y: 10 }, force: true })
  await untilClosed(page)
  const outside = (await eventLog(page)).filter((event) => ["pointer-down-outside", "interact-outside"].includes(event.name))
  assert.deepEqual(outside.map((event) => [event.name, event.cancelable]), [["pointer-down-outside", true], ["interact-outside", true]])
  assert.deepEqual(await openChanges(page), [true, false])
  assert.equal(await focusedId(page), "sheet-trigger")
})

browserTest("sheet: a caller that prevents pointer-down-outside keeps it open after an overlay click", async ({ open }) => {
  const page = await open("closed__rest")
  await recordEvents(page, controller, { prevent: ["pointer-down-outside"] })
  await openSheet(page)
  await page.locator(overlay).click({ position: { x: 10, y: 10 }, force: true })
  await settle(page)
  assert.equal(await page.locator(content).getAttribute("data-state"), "open")
  assert.deepEqual(await openChanges(page), [true])
})

browserTest("sheet: a caller that prevents close-auto-focus keeps the focus off the trigger", async ({ open }) => {
  const page = await open("closed__rest")
  await recordEvents(page, controller, { prevent: ["close-auto-focus"] })
  await openSheet(page)
  await page.click(`${content} [data-slot=sheet-close]`)
  await untilClosed(page)
  assert.notEqual(await focusedId(page), "sheet-trigger")
})

browserTest("sheet: modal locks scroll, disables outside pointer events and hides the page; modal false does none of it", async ({ open }) => {
  const page = await open("closed__rest")
  const before = await lockState(page)
  await openSheet(page)
  const modalLock = await lockState(page)
  assert.equal(modalLock.scrollLocked, true)
  assert.equal(modalLock.pointerEvents, "none")
  assert.ok(modalLock.hidden > before.hidden)

  const nonModalPage = await open("modal-false__open")
  const nonModalBefore = await lockState(nonModalPage)
  await openSheet(nonModalPage)
  assert.equal(await nonModalPage.locator(overlay).count(), 0)
  assert.deepEqual(await lockState(nonModalPage), nonModalBefore)
})

browserTest("sheet: modal false closes on an outside click and the trigger click toggles it closed once", async ({ open }) => {
  const page = await open("modal-false__open")
  await recordEvents(page, controller)
  await openSheet(page)
  await page.mouse.click(1, 1)
  await untilClosed(page)
  assert.ok((await events(page)).includes("interact-outside"))
  assert.deepEqual(await openChanges(page), [true, false])

  await openSheet(page)
  await page.click(trigger)
  await untilClosed(page)
  assert.deepEqual(await openChanges(page), [true, false, true, false])
})

browserTest("sheet: controlled open reports the close request and stays open", async ({ open }) => {
  const page = await open("controlled__open-true-stays-open")
  await recordEvents(page, controller)
  await page.waitForSelector(content)
  await page.keyboard.press("Escape")
  await settle(page)
  assert.equal(await page.locator(content).getAttribute("data-state"), "open")
  assert.deepEqual(await openChanges(page), [false])
})

browserTest("sheet: disconnect while open removes the portaled nodes and releases the lock, pointer events and aria-hidden", async ({ open }) => {
  const page = await open("closed__rest")
  const before = await lockState(page)
  await openSheet(page)
  assert.equal((await lockState(page)).scrollLocked, true, "precondition: locked while open")
  await page.locator(host(controller)).evaluate((element) => element.removeAttribute("data-controller"))
  await settle(page)
  assert.equal(await page.locator(content).count(), 0)
  assert.equal(await page.locator(overlay).count(), 0)
  const after = await lockState(page)
  assert.equal(after.scrollLocked, false)
  assert.notEqual(after.pointerEvents, "none")
  assert.equal(after.hidden, before.hidden)
})

browserTest("sheet: a controller restored from a Turbo snapshot opens, focuses the first input and closes on the overlay", async ({ open }) => {
  const page = await open("closed__rest")
  await openSheet(page)
  const html = await snapshot(page, controller)
  await restore(page, controller, html)
  assert.equal(await page.locator(content).count(), 0, "precondition: the snapshot is closed")
  await recordEvents(page, controller)
  await openSheet(page)
  assert.equal(await focusedId(page), "sheet-demo-name")
  await page.locator(overlay).click({ position: { x: 10, y: 10 }, force: true })
  await untilClosed(page)
  assert.deepEqual(await openChanges(page), [true, false])
})
