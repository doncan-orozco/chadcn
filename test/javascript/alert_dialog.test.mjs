import { browserTest } from "./harness.mjs"
import { assert, eventLog, events, host, recordEvents, settle } from "./support.mjs"
import { restore, snapshot } from "./turbo_support.mjs"

// AlertDialog (spec dev/port/specs/alert-dialog.md, Behavior): the dialog behavior plus three differences (ad:58-63) applied on the
// events the dialog controller dispatches. The scenarios compare the DOM and focus after clicks and keys with React; this file pins
// what they cannot see: the public events a caller receives (open-change, escape-key-down, open-auto-focus, close-auto-focus) and the
// outside events it never receives, a caller's preventDefault on each, the controlled mode, the window listeners and portaled nodes
// released on disconnect, and the Cancel auto focus of a controller restored from a Turbo snapshot. The Turbo snapshot itself
// (no overlay, no lock, closed) is pinned for every dialog in turbo_overlays.test.mjs.
browserTest.component = "alert-dialog"
const controller = "chadcn--alert-dialog"
const prefix = controller
const trigger = "[data-slot=alert-dialog-trigger]"
const content = "[data-slot=alert-dialog-content]"
const overlay = "[data-slot=alert-dialog-overlay]"
const cancel = "[data-slot=alert-dialog-cancel]"
const action = "[data-slot=alert-dialog-action]"

const openDialog = async (page) => {
  await page.click(trigger)
  await page.waitForSelector(content)
  await settle(page)
}
// The focus scope returns focus (and dispatches close-auto-focus) a task after the content leaves: wait for the event when
// the test records events, never for the clock.
const closed = async (page) => {
  await page.waitForSelector(content, { state: "detached" })
  await page.waitForFunction(() => !window.__events || window.__events.some((event) => event.name === "close-auto-focus"))
}
const focused = (page) => page.evaluate(() => document.activeElement?.dataset.slot ?? document.activeElement?.tagName)
const named = async (page, name) => (await eventLog(page)).filter((event) => event.name === name)

browserTest("alert-dialog: opening reports open-change, keeps the trigger in sync and focuses Cancel", async ({ open }) => {
  const page = await open("closed__rest")
  await recordEvents(page, prefix)
  await openDialog(page)
  assert.deepEqual((await named(page, "open-change")).map((e) => e.open), [true])
  assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "true")
  assert.equal(await page.locator(trigger).getAttribute("data-state"), "open")
  assert.equal(await page.locator(content).getAttribute("role"), "alertdialog")
  assert.equal(await focused(page), "alert-dialog-cancel")
  // The caller sees open-auto-focus as cancelable; the alert prevents it after the caller (bubble listener on window).
  const [autoFocus] = await named(page, "open-auto-focus")
  assert.equal(autoFocus.cancelable, true)
})

browserTest("alert-dialog: a caller that prevents open-auto-focus keeps the focus off Cancel", async ({ open }) => {
  const page = await open("closed__rest")
  await recordEvents(page, prefix, { prevent: ["open-auto-focus"] })
  await openDialog(page)
  assert.notEqual(await focused(page), "alert-dialog-cancel")
  assert.equal(await page.locator(content).getAttribute("data-state"), "open")
})

browserTest("alert-dialog: an outside press never closes and the caller never receives pointer-down-outside or interact-outside", async ({ open }) => {
  const page = await open("closed__rest")
  await recordEvents(page, prefix)
  await openDialog(page)
  await page.locator(overlay).click({ position: { x: 10, y: 10 }, force: true })
  await page.locator(overlay).click({ position: { x: 10, y: 10 }, button: "right", force: true })
  await settle(page)
  assert.equal(await page.locator(content).getAttribute("data-state"), "open")
  const names = await events(page)
  assert.ok(!names.includes("pointer-down-outside"), names.join(","))
  assert.ok(!names.includes("interact-outside"), names.join(","))
  // Control: Escape still reaches the caller and closes.
  await page.keyboard.press("Escape")
  await closed(page)
  assert.equal((await named(page, "escape-key-down")).length, 1)
  assert.deepEqual((await named(page, "open-change")).map((e) => e.open), [true, false])
})

browserTest("alert-dialog: a caller that prevents escape-key-down keeps it open", async ({ open }) => {
  const page = await open("closed__rest")
  await recordEvents(page, prefix, { prevent: ["escape-key-down"] })
  await openDialog(page)
  await page.keyboard.press("Escape")
  await settle(page)
  assert.equal(await page.locator(content).getAttribute("data-state"), "open")
  assert.deepEqual((await named(page, "open-change")).map((e) => e.open), [true])
})

for (const [name, button] of [["Cancel", cancel], ["Action", action]]) {
  browserTest(`alert-dialog: ${name} closes, reports open-change and close-auto-focus and returns focus to the trigger`, async ({ open }) => {
    const page = await open("closed__rest")
    await recordEvents(page, prefix)
    await openDialog(page)
    await page.focus(button)
    await page.keyboard.press("Enter")
    await closed(page)
    assert.deepEqual((await named(page, "open-change")).map((e) => e.open), [true, false])
    assert.equal((await named(page, "close-auto-focus")).length, 1)
    assert.equal(await focused(page), "alert-dialog-trigger")
    assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "false")
  })
}

browserTest("alert-dialog: a caller that prevents close-auto-focus keeps the focus off the trigger", async ({ open }) => {
  const page = await open("closed__rest")
  await recordEvents(page, prefix, { prevent: ["close-auto-focus"] })
  await openDialog(page)
  await page.click(cancel)
  await closed(page)
  assert.notEqual(await focused(page), "alert-dialog-trigger")
})

browserTest("alert-dialog: controlled open reports the close request and stays open", async ({ open }) => {
  const page = await open("controlled__open-true-stays-open")
  await recordEvents(page, prefix)
  await page.waitForSelector(content)
  await page.keyboard.press("Escape")
  await page.click(cancel)
  await settle(page)
  assert.equal(await page.locator(content).getAttribute("data-state"), "open")
  assert.deepEqual((await named(page, "open-change")).map((e) => e.open), [false, false])
})

browserTest("alert-dialog: disconnect while open removes the portaled nodes, the scroll lock, aria-hidden and the window listeners", async ({ open }) => {
  const page = await open("closed__rest")
  const hiddenBefore = await page.evaluate(() => document.querySelectorAll("[aria-hidden=true]").length)
  await openDialog(page)
  // The outside event a dialog would forward from the host: the alert's window listener prevents it while connected. The host is
  // found by its id value, which stays when data-controller goes.
  const outsidePrevented = () => page.evaluate(() => {
    const event = new CustomEvent("chadcn--alert-dialog:pointer-down-outside", { bubbles: true, cancelable: true })
    document.querySelector("[data-chadcn--alert-dialog-id-value]").dispatchEvent(event)
    return event.defaultPrevented
  })
  assert.equal(await outsidePrevented(), true, "precondition: the window listener is armed")
  assert.equal(await page.evaluate(() => document.body.hasAttribute("data-scroll-locked")), true)

  await page.locator(host(controller)).evaluate((el) => el.removeAttribute("data-controller"))
  await settle(page)
  assert.equal(await page.locator(content).count(), 0)
  assert.equal(await page.locator(overlay).count(), 0)
  assert.equal(await page.evaluate(() => document.body.hasAttribute("data-scroll-locked")), false)
  assert.notEqual(await page.evaluate(() => document.body.style.pointerEvents), "none")
  assert.equal(await page.evaluate(() => document.querySelectorAll("[aria-hidden=true]").length), hiddenBefore)
  assert.equal(await outsidePrevented(), false)
})

browserTest("alert-dialog: a controller restored from a Turbo snapshot focuses Cancel and ignores outside presses", async ({ open }) => {
  const page = await open("closed__rest")
  await openDialog(page)
  const html = await snapshot(page, controller)
  await restore(page, controller, html)
  assert.equal(await page.locator(content).count(), 0, "precondition: the snapshot is closed")
  await openDialog(page)
  assert.equal(await focused(page), "alert-dialog-cancel")
  await page.locator(overlay).click({ position: { x: 10, y: 10 }, force: true })
  await settle(page)
  assert.equal(await page.locator(content).getAttribute("data-state"), "open")
})
