import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, eventLog, events, recordEvents, reconnect, settle } from "./support.mjs"

// chadcn--dialog against its parity pages (spec: dev/port/specs/dialog.md): pointer and keyboard open/close, trigger and content
// state attributes, the focus trap, the public events and which of them are cancelable, controlled mode, and a disconnect while
// open that takes the portaled nodes, the scroll lock and the aria-hidden siblings with it.

browserTest.component = "dialog"

const trigger = "[data-slot=dialog-trigger]"
const content = "[data-slot=dialog-content]"
const overlay = "[data-slot=dialog-overlay]"

const triggerState = (page) => page.locator(trigger).first().evaluate((el) => ({
  expanded: el.getAttribute("aria-expanded"), state: el.dataset.state, controls: el.getAttribute("aria-controls")
}))
const OPEN = { expanded: "true", state: "open", controls: "dialog-1" }
const CLOSED = { expanded: "false", state: "closed", controls: null }

browserTest("dialog: a trigger click mounts overlay and content in the body with data-state open and focuses the content", async ({ open }) => {
  const page = await open("open__via-trigger-click")
  assert.deepEqual(await triggerState(page), CLOSED)
  assert.equal(await page.locator(content).count(), 0, "closed: nothing mounted")
  await page.click(trigger)
  await settle(page)
  assert.deepEqual(await triggerState(page), OPEN)
  assert.deepEqual(await page.evaluate(({ content, overlay }) => ({
    parent: document.querySelector(content).parentElement.tagName,
    states: [document.querySelector(overlay).dataset.state, document.querySelector(content).dataset.state],
    role: document.querySelector(content).getAttribute("role"),
    focusInside: document.querySelector(content).contains(document.activeElement)
  }), { content, overlay }), { parent: "BODY", states: ["open", "open"], role: "dialog", focusInside: true })
})

browserTest("dialog: Enter on the focused trigger opens it, Escape closes it and returns the focus to the trigger", async ({ open }) => {
  const page = await open("open__via-trigger-click")
  await page.focus(trigger)
  await page.keyboard.press("Enter")
  await settle(page)
  assert.deepEqual(await triggerState(page), OPEN)
  await page.keyboard.press("Escape")
  await settle(page)
  assert.deepEqual(await triggerState(page), CLOSED)
  assert.equal(await page.locator(content).count(), 0)
  assert.equal(await page.evaluate((trigger) => document.activeElement === document.querySelector(trigger), trigger), true)
})

browserTest("dialog: Tab and Shift+Tab loop inside the modal content", async ({ open }) => {
  const page = await open("open__via-trigger-click")
  await page.click(trigger)
  await settle(page)
  const inside = () => page.evaluate((content) => document.querySelector(content).contains(document.activeElement), content)
  for (let i = 0; i < 5; i++) {
    await page.keyboard.press("Tab")
    assert.equal(await inside(), true, `Tab ${i + 1} stays inside`)
  }
  for (let i = 0; i < 5; i++) {
    await page.keyboard.press("Shift+Tab")
    assert.equal(await inside(), true, `Shift+Tab ${i + 1} stays inside`)
  }
})

browserTest("dialog: the close button and a primary click on the overlay close it", async ({ open }) => {
  const page = await open("open__via-trigger-click")
  await page.click(trigger)
  await settle(page)
  await page.click(`${content} > [data-slot=dialog-close]`)
  await settle(page)
  assert.deepEqual(await triggerState(page), CLOSED)
  await page.click(trigger)
  await settle(page)
  await page.mouse.click(5, 5)
  await settle(page)
  assert.deepEqual(await triggerState(page), CLOSED)
})

// Advisory of dev/port/REPORT.md: open-change was dispatched cancelable although Radix onOpenChange is a plain callback and the spec
// table says it is not cancelable. A listener calling preventDefault() must neither see a cancelable event nor change the outcome.
browserTest("dialog: open-change is not cancelable and preventDefault() does not keep it from opening or closing", async ({ open }) => {
  const page = await open("open__via-trigger-click")
  await recordEvents(page, "chadcn--dialog", { prevent: ["open-change"] })
  await page.click(trigger)
  await settle(page)
  assert.deepEqual(await triggerState(page), OPEN)
  await page.keyboard.press("Escape")
  await settle(page)
  assert.deepEqual(await triggerState(page), CLOSED)
  const changes = (await eventLog(page)).filter((entry) => entry.name === "open-change")
  assert.deepEqual(changes, [{ name: "open-change", open: true, cancelable: false }, { name: "open-change", open: false, cancelable: false }])
})

browserTest("dialog: escape-key-down stays cancelable and a prevented one keeps the dialog open", async ({ open }) => {
  const page = await open("open__via-trigger-click")
  await page.click(trigger)
  await settle(page)
  await recordEvents(page, "chadcn--dialog", { prevent: ["escape-key-down"] })
  await page.keyboard.press("Escape")
  await settle(page)
  assert.deepEqual(await triggerState(page), OPEN)
  assert.deepEqual((await eventLog(page)).map(({ name, cancelable }) => [name, cancelable]), [["escape-key-down", true]])
})

browserTest("dialog: a controlled dialog reports the request and leaves the DOM to the server", async ({ open }) => {
  const page = await open("controlled__open-true-stays-open")
  await recordEvents(page, "chadcn--dialog")
  await page.keyboard.press("Escape")
  await settle(page)
  assert.equal(await page.locator(content).count(), 1)
  assert.deepEqual(await events(page), ["escape-key-down", "open-change"])
})

browserTest("dialog: a disconnect while open removes the portaled nodes, the scroll lock and aria-hidden; a reconnect works once", async ({ open }) => {
  const page = await open("open__via-trigger-click")
  const errors = consoleErrors(page)
  await page.click(trigger)
  await settle(page)
  assert.deepEqual(await page.evaluate(() => ({
    hidden: document.querySelectorAll("body > [aria-hidden=true]").length > 0,
    scrollLocked: document.body.hasAttribute("data-scroll-locked")
  })), { hidden: true, scrollLocked: true }, "precondition: the open modal hides its siblings and locks the scroll")
  await page.evaluate(() => document.querySelector("[data-controller~='chadcn--dialog']").remove())
  await settle(page)
  assert.deepEqual(await page.evaluate(({ content, overlay }) => ({
    mounted: document.querySelectorAll(`${content}, ${overlay}`).length,
    hidden: document.querySelectorAll("body > [aria-hidden=true]").length,
    scrollLocked: document.body.hasAttribute("data-scroll-locked"),
    pointerEvents: document.body.style.pointerEvents
  }), { content, overlay }), { mounted: 0, hidden: 0, scrollLocked: false, pointerEvents: "" })

  const page2 = await open("open__via-trigger-click")
  await reconnect(page2, "chadcn--dialog")
  await recordEvents(page2, "chadcn--dialog")
  await page2.click(trigger)
  await settle(page2)
  assert.equal(await page2.locator(content).count(), 1, "one content after a reconnect")
  assert.deepEqual(await events(page2), ["open-change", "open-auto-focus"])
  assert.deepEqual(errors, [])
})
