import { browserTest } from "./harness.mjs"
import { assert, host, settle } from "./support.mjs"
import { restore, snapshot } from "./turbo_support.mjs"

// Radix Label (spec dev/port/specs/label.md, Behavior): a mousedown with detail > 1 on the label text is prevented so a double
// click does not select it; presses inside a nested control are left alone (a caller's own preventDefault is unobservable: the
// event stays prevented either way). The scenarios only compare the DOM; this file pins the prevented mousedown itself, the
// selection it saves, the nested-control exemption and a Turbo cache restore.
browserTest.component = "label"
const controller = "chadcn--label"
const label = host(controller)

// Records defaultPrevented of every mousedown after the controller's action ran (bubble listener on the document). Calling it
// again only empties the log.
const recordMousedowns = (page) => page.evaluate(() => {
  window.__mousedowns = []
  if (window.__recording) return
  window.__recording = true
  document.addEventListener("mousedown", (event) => window.__mousedowns.push({ detail: event.detail, prevented: event.defaultPrevented }))
})
const mousedowns = (page) => page.evaluate(() => window.__mousedowns)
// A point on the label's own text (left part, vertical middle), away from any nested control.
const textPoint = async (page, selector) => {
  const box = await page.locator(selector).first().boundingBox()
  return [box.x + 2, box.y + box.height / 2]
}

browserTest("label: a double click on the text prevents the second mousedown and selects nothing, a single one is left alone", async ({ open }) => {
  const page = await open("behavior__dblclick-text-prevented")
  await recordMousedowns(page)
  await page.mouse.dblclick(...await textPoint(page, label))
  assert.deepEqual(await mousedowns(page), [{ detail: 1, prevented: false }, { detail: 2, prevented: true }])
  assert.equal(await page.evaluate(() => window.getSelection().toString()), "")
  // Control: without the controller the same double click selects the text, so the empty selection above is the controller's.
  const bare = await open("behavior__dblclick-text-prevented")
  await bare.locator(label).evaluate((element) => element.removeAttribute("data-controller"))
  await settle(bare)
  await bare.mouse.dblclick(...await textPoint(bare, "[data-slot=label]"))
  assert.notEqual(await bare.evaluate(() => window.getSelection().toString()), "")
})

browserTest("label: a double click inside a nested input or button is not prevented", async ({ open }) => {
  for (const [scenario, inner] of [["behavior__dblclick-inside-input-not-prevented", "input"], ["behavior__dblclick-inside-button-not-prevented", "button"]]) {
    const page = await open(scenario)
    await recordMousedowns(page)
    await page.locator(`${label} ${inner}`).dblclick()
    assert.deepEqual((await mousedowns(page)).map((mousedown) => mousedown.prevented), [false, false], scenario)
    // Control: a double click on the label's own text in the same page is prevented.
    await recordMousedowns(page)
    await page.mouse.dblclick(...await textPoint(page, label))
    assert.deepEqual((await mousedowns(page)).map((mousedown) => mousedown.prevented), [false, true], `${scenario} (label text)`)
  }
})

browserTest("label: a Turbo snapshot restores a label that prevents the double-click selection", async ({ open }) => {
  const page = await open("behavior__dblclick-text-prevented")
  const html = await snapshot(page, controller)
  await restore(page, controller, html)
  await recordMousedowns(page)
  await page.mouse.dblclick(...await textPoint(page, label))
  assert.deepEqual((await mousedowns(page)).map((mousedown) => mousedown.prevented), [false, true])
})
