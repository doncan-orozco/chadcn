import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, host, reconnect, settle } from "./support.mjs"

// Behavior of the resizable controller the parity runner cannot express: the public events, the imperative methods, the
// document-level listeners and the cursor sheet that a disconnect must release.

const GROUP = "[data-slot=resizable-panel-group]"
const HANDLE = "[data-slot=resizable-handle]"
const PANELS = "[data-slot=resizable-panel]"

const record = (page) => page.evaluate(() => {
  window.__resizable = []
  for (const name of ["layout-change", "layout-changed", "resize"]) {
    document.addEventListener(`chadcn--resizable:${name}`, (event) => window.__resizable.push({ name, detail: event.detail }))
  }
})
const recorded = (page) => page.evaluate(() => window.__resizable)
const grows = (page) => page.$$eval(PANELS, (panels) => panels.map((panel) => panel.style.flexGrow))
const controller = (page, expression) => page.evaluate(({ selector, expression }) => {
  const instance = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector(selector), "chadcn--resizable")
  return new Function("c", `return ${expression}`)(instance)
}, { selector: host("chadcn--resizable"), expression })

browserTest("resizable: connect writes the layout, the ARIA values of the handle and the initial layout", async ({ open }) => {
  const page = await open("default", "resizable")
  const handle = page.locator(HANDLE)

  assert.deepEqual(await grows(page), ["50", "50"])
  assert.equal(await handle.getAttribute("aria-valuenow"), "50")
  assert.equal(await handle.getAttribute("aria-valuemin"), "0")
  assert.equal(await handle.getAttribute("aria-valuemax"), "100")
  assert.equal(await handle.getAttribute("aria-controls"), await page.locator(PANELS).first().getAttribute("id"))
})

browserTest("resizable: arrow keys resize and dispatch layout-change and a user-interaction layout-changed", async ({ open }) => {
  const page = await open("default", "resizable")
  await record(page)
  await page.locator(HANDLE).focus()
  await page.keyboard.press("ArrowRight")
  await page.keyboard.press("ArrowRight")
  await settle(page)

  assert.deepEqual(await grows(page), ["60", "40"])
  assert.equal(await page.locator(HANDLE).getAttribute("aria-valuenow"), "60")
  const events = (await recorded(page)).filter((event) => event.name !== "resize")
  assert.deepEqual(events.map((event) => event.name), ["layout-change", "layout-changed", "layout-change", "layout-changed"])
  assert.equal(events.at(-1).detail.isUserInteraction, true)
  assert.deepEqual(Object.values(events.at(-1).detail.layout), [60, 40])
})

browserTest("resizable: a pointer drag moves the layout, keeps data-separator in step and commits one layout-changed", async ({ open }) => {
  const page = await open("default", "resizable")
  const errors = consoleErrors(page)
  await record(page)
  const box = await page.locator(HANDLE).boundingBox()
  const x = box.x + box.width / 2
  const y = box.y + box.height / 2

  await page.mouse.move(x, y)
  assert.equal(await page.locator(HANDLE).getAttribute("data-separator"), "hover")
  await page.mouse.down()
  assert.equal(await page.locator(HANDLE).getAttribute("data-separator"), "active")
  const tenth = (await page.locator(GROUP).boundingBox()).width / 10
  await page.mouse.move(x + tenth, y, { steps: 4 })
  await page.mouse.move(x + 2 * tenth, y, { steps: 4 })
  const during = (await recorded(page)).filter((event) => event.name === "layout-changed" && event.detail.isUserInteraction)
  assert.equal(during.length, 0)
  await page.mouse.up()
  await settle(page)

  const [first, second] = (await grows(page)).map(Number)
  assert.ok(Math.abs(first - 70) < 0.5 && Math.abs(first + second - 100) < 0.01, `layout after the drag: ${first}/${second}`)
  assert.equal(await page.locator(HANDLE).getAttribute("data-separator"), "inactive")
  const committed = (await recorded(page)).filter((event) => event.name === "layout-changed" && event.detail.isUserInteraction)
  assert.equal(committed.length, 1)
  assert.deepEqual(errors, [])
})

browserTest("resizable: the pointer cursor sheet and document listeners are released when the group disconnects", async ({ open }) => {
  const page = await open("default", "resizable")
  const box = await page.locator(HANDLE).boundingBox()
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2)
  assert.equal(await page.evaluate(() => document.adoptedStyleSheets[0]?.cssRules[0]?.cssText.includes("ew-resize")), true)

  await page.evaluate(() => document.querySelector("[data-slot=resizable-panel-group]").remove())
  await settle(page)
  assert.equal(await page.evaluate(() => document.adoptedStyleSheets.length), 0)
})

browserTest("resizable: a reconnected group starts again from its server props", async ({ open }) => {
  const page = await open("default", "resizable")
  const errors = consoleErrors(page)
  await page.locator(HANDLE).focus()
  await page.keyboard.press("ArrowRight")
  assert.deepEqual(await grows(page), ["55", "45"])

  await reconnect(page, "chadcn--resizable")
  await settle(page)
  assert.deepEqual(await grows(page), ["50", "50"])
  await page.locator(HANDLE).focus()
  await page.keyboard.press("ArrowLeft")
  assert.deepEqual(await grows(page), ["45", "55"])
  assert.deepEqual(errors, [])
})

browserTest("resizable: the controller exposes the imperative layout and panel methods", async ({ open }) => {
  const page = await open("collapsible__default-collapsed", "resizable")
  const ids = await page.$$eval(PANELS, (panels) => panels.map((panel) => panel.id))

  assert.equal(await controller(page, "c.isCollapsed(" + JSON.stringify(ids[0]) + ")"), true)
  await controller(page, "c.expand(" + JSON.stringify(ids[0]) + ")")
  assert.equal(await controller(page, "c.isCollapsed(" + JSON.stringify(ids[0]) + ")"), false)
  assert.equal(await controller(page, "c.getLayout()[" + JSON.stringify(ids[0]) + "]"), 20)
  await controller(page, "c.collapse(" + JSON.stringify(ids[0]) + ")")
  assert.deepEqual(await grows(page), ["0", "100"])
  assert.deepEqual(await controller(page, "c.setLayout({ " + JSON.stringify(ids[0]) + ": 30, " + JSON.stringify(ids[1]) + ": 70 })"), { [ids[0]]: 30, [ids[1]]: 70 })
  assert.deepEqual(await grows(page), ["30", "70"])
  assert.equal((await controller(page, "c.getSize(" + JSON.stringify(ids[1]) + ")")).asPercentage, 70)
})

browserTest("resizable: a panel dispatches resize with its size in percent and pixels", async ({ open }) => {
  const page = await open("default", "resizable")
  await page.evaluate(() => {
    window.__sizes = []
    document.addEventListener("chadcn--resizable:resize", (event) => window.__sizes.push({ target: event.target.id, ...event.detail }))
  })
  await page.locator(HANDLE).focus()
  await page.keyboard.press("ArrowRight")
  await settle(page)

  const first = await page.locator(PANELS).first().getAttribute("id")
  const last = (await page.evaluate(() => window.__sizes)).filter((detail) => detail.target === first).at(-1)
  assert.ok(Math.abs(last.size.asPercentage - 55) < 0.1, `size ${last.size.asPercentage}`)
  assert.ok(last.size.inPixels > 100)
  assert.ok(Math.abs(last.prevSize.asPercentage - 50) < 0.1, `prevSize ${last.prevSize.asPercentage}`)
})
