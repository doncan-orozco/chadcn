import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, host, settle } from "./support.mjs"
import { restore, snapshot } from "./turbo_support.mjs"

// chadcn--accordion against its parity pages (spec: dev/port/specs/accordion.md): pointer and keyboard, item state attributes,
// the value-change event, controlled mode, disconnect cleanup and a Turbo cache restore of a state the user chose. The core Turbo
// snapshot cases (closed body kept, exit animation finished) live in turbo_disclosure.test.mjs.

browserTest.component = "accordion"

const trigger = (page, name) => page.getByRole("button", { name })
const item = (page, name) => page.locator("[data-slot=accordion-item]").filter({ has: trigger(page, name) })
const content = (page, name) => item(page, name).locator("[data-slot=accordion-content]")
const focused = (page) => page.evaluate(() => document.activeElement?.textContent.trim())

// Every value-change the root dispatches, in order (detail.value).
const recordValues = (page) => page.evaluate(() => {
  window.__values = []
  document.addEventListener("chadcn--accordion:value-change", (event) => window.__values.push(event.detail.value))
})
const values = (page) => page.evaluate(() => window.__values)

// The state of one item as a reader of the DOM sees it: every part's data-state, the trigger's ARIA and the mounted body.
const itemState = (page, name) => item(page, name).evaluate((el) => {
  const button = el.querySelector("[data-slot=accordion-trigger]")
  const region = el.querySelector("[data-slot=accordion-content]")
  return {
    item: el.dataset.state,
    header: button.parentElement.dataset.state,
    trigger: button.dataset.state,
    content: region.dataset.state,
    expanded: button.getAttribute("aria-expanded"),
    controls: button.getAttribute("aria-controls") === region.id,
    hidden: region.hidden,
    body: region.textContent.trim() !== ""
  }
})

const OPEN = { item: "open", header: "open", trigger: "open", content: "open", expanded: "true", controls: true, hidden: false, body: true }
const CLOSED = { item: "closed", header: "closed", trigger: "closed", content: "closed", expanded: "false", controls: false, hidden: true, body: false }

browserTest("accordion: a click opens the item, mounts its body and dispatches value-change", async ({ open }) => {
  const page = await open("single__all-closed")
  await recordValues(page)
  assert.deepEqual(await itemState(page, "Is it accessible?"), CLOSED)

  await trigger(page, "Is it accessible?").click()
  await settle(page)
  assert.deepEqual(await itemState(page, "Is it accessible?"), OPEN)
  assert.equal(await content(page, "Is it accessible?").textContent(), "Yes. It adheres to the WAI-ARIA design pattern.")
  assert.equal(await content(page, "Is it accessible?").locator("template").count(), 0, "the body template is taken over")
  assert.deepEqual(await values(page), ["item-1"])
})

browserTest("accordion: single opens one item at a time and unmounts the body of the one it closes", async ({ open }) => {
  const page = await open("single__all-closed")
  await recordValues(page)
  await trigger(page, "Is it accessible?").click()
  await trigger(page, "Is it styled?").click()
  await settle(page)
  assert.deepEqual(await itemState(page, "Is it accessible?"), CLOSED)
  assert.deepEqual(await itemState(page, "Is it styled?"), OPEN)
  assert.deepEqual(await values(page), ["item-1", "item-2"])
})

browserTest("accordion: a non-collapsible single accordion locks its open item", async ({ open }) => {
  const page = await open("single__all-closed")
  await recordValues(page)
  await trigger(page, "Is it accessible?").click()
  await settle(page)
  assert.equal(await trigger(page, "Is it accessible?").getAttribute("aria-disabled"), "true")
  // aria-disabled only announces the lock; the button still receives the click (Playwright would wait for it to be enabled).
  await trigger(page, "Is it accessible?").click({ force: true })
  await settle(page)
  assert.deepEqual(await itemState(page, "Is it accessible?"), OPEN)
  assert.deepEqual(await values(page), ["item-1"], "no value-change for a click that changes nothing")
})

browserTest("accordion: a collapsible single accordion closes its open item and reports an empty value", async ({ open }) => {
  const page = await open("single__collapsible__default-value-open")
  await recordValues(page)
  const [name] = await page.locator("[data-slot=accordion-item][data-state=open] [data-slot=accordion-trigger]").allTextContents()
  assert.equal(await trigger(page, name.trim()).getAttribute("aria-disabled"), null, "collapsible never locks the open item")
  await trigger(page, name.trim()).click()
  await settle(page)
  assert.deepEqual(await itemState(page, name.trim()), CLOSED)
  assert.deepEqual(await values(page), [""])
})

browserTest("accordion: multiple keeps several items open and reports the open values as an array", async ({ open }) => {
  const page = await open("multiple__click-open-two-then-close")
  await recordValues(page)
  await trigger(page, "Is it accessible?").click()
  await trigger(page, "Is it styled?").click()
  await settle(page)
  assert.deepEqual(await itemState(page, "Is it accessible?"), OPEN)
  assert.deepEqual(await itemState(page, "Is it styled?"), OPEN)
  assert.equal(await trigger(page, "Is it accessible?").getAttribute("aria-disabled"), null, "multiple never locks an item")

  await trigger(page, "Is it accessible?").click()
  await settle(page)
  assert.deepEqual(await itemState(page, "Is it accessible?"), CLOSED)
  assert.deepEqual(await values(page), [["item-1"], ["item-1", "item-2"], ["item-2"]])
})

browserTest("accordion: a controlled accordion only dispatches value-change and leaves the DOM to the server", async ({ open }) => {
  const page = await open("controlled-single__click-other-no-change")
  await recordValues(page)
  await trigger(page, "Is it accessible?").click()
  await settle(page)
  assert.deepEqual(await itemState(page, "Is it accessible?"), CLOSED)
  assert.deepEqual(await itemState(page, "Is it styled?"), OPEN)
  assert.deepEqual(await values(page), ["item-1"])
})

browserTest("accordion: a click the caller prevented does not toggle", async ({ open }) => {
  const page = await open("single__all-closed")
  await recordValues(page)
  await page.evaluate(() => document.addEventListener("click", (event) => event.preventDefault(), { capture: true }))
  await trigger(page, "Is it accessible?").click()
  await settle(page)
  assert.deepEqual(await itemState(page, "Is it accessible?"), CLOSED)
  assert.deepEqual(await values(page), [])
})

browserTest("accordion: Enter and Space on a focused trigger toggle its item", async ({ open }) => {
  const page = await open("single__collapsible__click-close")
  await trigger(page, "Is it styled?").focus()
  await page.keyboard.press("Enter")
  await settle(page)
  assert.deepEqual(await itemState(page, "Is it styled?"), OPEN)
  await page.keyboard.press("Space")
  await settle(page)
  assert.deepEqual(await itemState(page, "Is it styled?"), CLOSED)
})

browserTest("accordion: ArrowDown and ArrowUp move focus between triggers and wrap; Home and End jump", async ({ open }) => {
  const page = await open("single__all-closed")
  await trigger(page, "Is it accessible?").focus()
  await page.keyboard.press("ArrowDown")
  assert.equal(await focused(page), "Is it styled?")
  await page.keyboard.press("ArrowUp")
  await page.keyboard.press("ArrowUp")
  assert.equal(await focused(page), "Is it animated?", "ArrowUp wraps to the last trigger")
  await page.keyboard.press("ArrowDown")
  assert.equal(await focused(page), "Is it accessible?", "ArrowDown wraps to the first trigger")
  await page.keyboard.press("End")
  assert.equal(await focused(page), "Is it animated?")
  await page.keyboard.press("Home")
  assert.equal(await focused(page), "Is it accessible?")
  assert.deepEqual(await itemState(page, "Is it accessible?"), CLOSED, "moving focus opens nothing")
})

browserTest("accordion: a vertical accordion ignores ArrowLeft and ArrowRight", async ({ open }) => {
  const page = await open("single__all-closed")
  await trigger(page, "Is it styled?").focus()
  await page.keyboard.press("ArrowRight")
  await page.keyboard.press("ArrowLeft")
  assert.equal(await focused(page), "Is it styled?")
})

browserTest("accordion: a horizontal RTL accordion moves forward on ArrowLeft and ignores ArrowDown", async ({ open }) => {
  const page = await open("orientation-horizontal__rtl__keyboard")
  await trigger(page, "Is it accessible?").focus()
  await page.keyboard.press("ArrowLeft")
  assert.equal(await focused(page), "Is it styled?")
  await page.keyboard.press("ArrowRight")
  assert.equal(await focused(page), "Is it accessible?")
  await page.keyboard.press("ArrowDown")
  assert.equal(await focused(page), "Is it accessible?")
})

browserTest("accordion: arrow keys skip a disabled trigger", async ({ open }) => {
  const page = await open("disabled-item__rest")
  assert.equal(await trigger(page, "Is it accessible?").isDisabled(), true, "precondition: the first item is disabled")
  await trigger(page, "Is it styled?").focus()
  await page.keyboard.press("ArrowUp")
  assert.equal(await focused(page), "Is it animated?")
  await page.keyboard.press("ArrowDown")
  assert.equal(await focused(page), "Is it styled?")
})

// The keydown listener lives on the root element: removing the root disconnects the controller and must take the listener with it (a
// leaked listener still handles, and prevents, an arrow key dispatched inside the detached root); the reinserted root reconnects with
// exactly one listener (two would move focus two triggers per press).
browserTest("accordion: disconnect removes the keyboard listener and a reconnect adds exactly one", async ({ open }) => {
  const page = await open("single__all-closed")
  const errors = consoleErrors(page)
  const handledWhileDetached = await page.evaluate(async () => {
    const root = document.querySelector("[data-slot=accordion]")
    const parent = root.parentNode
    root.remove()
    await new Promise((resolve) => setTimeout(resolve))
    const event = new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true, cancelable: true })
    root.querySelector("[data-slot=accordion-trigger]").dispatchEvent(event)
    parent.append(root)
    await new Promise((resolve) => setTimeout(resolve))
    return event.defaultPrevented
  })
  assert.equal(handledWhileDetached, false, "no listener left after disconnect")

  await trigger(page, "Is it accessible?").focus()
  await page.keyboard.press("ArrowDown")
  assert.equal(await focused(page), "Is it styled?", "one step per press after the reconnect")
  assert.deepEqual(errors, [])
})

browserTest("accordion: the items a user opened survive a Turbo cache snapshot and restore", async ({ open }) => {
  const page = await open("multiple__click-open-two-then-close")
  await trigger(page, "Is it styled?").click()
  await settle(page)
  const html = await snapshot(page, "chadcn--accordion")
  await restore(page, "chadcn--accordion", html)
  assert.deepEqual(await itemState(page, "Is it styled?"), OPEN)
  assert.deepEqual(await itemState(page, "Is it accessible?"), CLOSED)

  await recordValues(page)
  await trigger(page, "Is it accessible?").click()
  await settle(page)
  assert.deepEqual(await itemState(page, "Is it accessible?"), OPEN)
  assert.deepEqual(await values(page), [["item-2", "item-1"]], "the restored controller knows the item opened before the snapshot")
  assert.equal(await page.locator(host("chadcn--accordion")).count(), 1)
})
