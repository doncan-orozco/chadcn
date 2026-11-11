import { browserTest } from "./harness.mjs"
import { assert, host, settle } from "./support.mjs"
import { restore, snapshot } from "./turbo_support.mjs"

// InputGroupAddon onClick (spec dev/port/specs/input-group.md, Behavior): a click on the addon focuses the first input of the
// group unless it came from a button. The scenarios compare where focus lands after a pointer click; this file pins what they
// cannot see: a click on the addon's own padding, the keyboard-activated click of a button inside the addon, a synthetic click (assistive
// technology), the first <input> rule against a <textarea>, the listener gone after disconnect and a Turbo cache restore.
browserTest.component = "input-group"
const controller = "chadcn--input-group"
const addon = host(controller)
const active = (page) => page.evaluate(() => {
  const element = document.activeElement
  return element === document.body ? "body" : element.id || element.getAttribute("placeholder") || element.textContent.trim() || element.tagName
})

// Whether the topmost element at a viewport point is the one the selector matches.
const hits = (page, [x, y], selector) => page.evaluate(({ x, y, selector }) => document.elementFromPoint(x, y) === document.querySelector(selector), { x, y, selector })

browserTest("input-group: a click on the addon's own box (not its content) focuses the input", async ({ open }) => {
  const page = await open("behavior__addon-click-block-start")
  assert.equal(await active(page), "body")
  const box = await page.locator(addon).boundingBox()
  const point = [box.x + box.width - 2, box.y + 2]
  assert.equal(await hits(page, point, addon), true, "precondition: the point is on the addon's own box, not on its content")
  await page.mouse.click(...point)
  assert.equal(await active(page), "you@example.com")
})

browserTest("input-group: a synthetic click on the addon focuses the input", async ({ open }) => {
  const page = await open("behavior__addon-click-focuses-input")
  assert.equal(await active(page), "body", "precondition: nothing focused")
  await page.locator(addon).evaluate((element) => element.click())
  assert.equal(await active(page), "Search...")
})

browserTest("input-group: Enter and Space on a button inside the addon keep the focus on the button", async ({ open }) => {
  const page = await open("behavior__addon-click-on-button-skips")
  await page.evaluate((selector) => {
    window.__clicks = 0
    document.querySelector(`${selector} button`).addEventListener("click", () => window.__clicks++)
  }, addon)
  await page.focus(`${addon} button`)
  await page.keyboard.press("Enter")
  await page.keyboard.press("Space")
  assert.equal(await page.evaluate(() => window.__clicks), 2, "precondition: both keys clicked the button")
  assert.equal(await active(page), "Search")
})

browserTest("input-group: a click on the icon of a button inside the addon leaves the input unfocused", async ({ open }) => {
  const page = await open("behavior__addon-click-on-button-icon-skips")
  await page.locator(`${addon} button svg`).evaluate((svg) => svg.dispatchEvent(new MouseEvent("click", { bubbles: true })))
  assert.equal(await active(page), "body")
  // Control: the same synthetic click on the addon itself focuses the input.
  await page.locator(addon).evaluate((element) => element.dispatchEvent(new MouseEvent("click", { bubbles: true })))
  assert.equal(await active(page), "Search...")
})

browserTest("input-group: the first input of the group wins, a textarea is never focused", async ({ open }) => {
  const page = await open("behavior__addon-click-first-input")
  await page.locator(addon).evaluate((element) => element.click())
  assert.equal(await active(page), "ig-first")

  const textareaPage = await open("behavior__addon-click-textarea-no-focus")
  await textareaPage.locator(addon).evaluate((element) => element.click())
  assert.equal(await active(textareaPage), "body")
})

browserTest("input-group: a disconnected addon no longer focuses the input", async ({ open }) => {
  const page = await open("behavior__addon-click-focuses-input")
  await page.locator(addon).evaluate((element) => {
    window.__addon = element
    element.removeAttribute("data-controller")
  })
  await settle(page)
  await page.evaluate(() => window.__addon.click())
  assert.equal(await active(page), "body")
  // Control: connected again, the same click focuses it.
  await page.evaluate((name) => window.__addon.setAttribute("data-controller", name), controller)
  await settle(page)
  await page.evaluate(() => window.__addon.click())
  assert.equal(await active(page), "Search...")
})

browserTest("input-group: a Turbo snapshot restores an addon that focuses the input", async ({ open }) => {
  const page = await open("behavior__addon-click-focuses-input")
  const html = await snapshot(page, controller)
  await restore(page, controller, html)
  assert.equal(await page.locator(addon).count(), 1)
  assert.equal(await active(page), "body", "precondition: nothing focused")
  await page.locator(addon).evaluate((element) => element.click())
  assert.equal(await active(page), "Search...")
})
