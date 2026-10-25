import { browserTest } from "./harness.mjs"
import { assert, settle } from "./support.mjs"
import { afterSnapshotTicks, countIn, restore, snapshot } from "./turbo_support.mjs"

// Turbo page cache for the disclosure controllers: accordion, collapsible, tabs (stimulus R2/R3, radix-stimulus R10). The scroll area
// and the avatar have their own files, the helpers are shared in turbo_support.mjs.

browserTest("accordion: a closed item keeps its body in the snapshot and opens after the restore", async ({ open }) => {
  const page = await open("single__all-closed", "accordion")
  const html = await snapshot(page, "chadcn--accordion")
  assert.ok(await countIn(page, html, "template") >= 1, "the closed bodies are in the snapshot")

  await restore(page, "chadcn--accordion", html)
  const trigger = page.locator("[data-chadcn--accordion-target~=trigger]").first()
  await trigger.click()
  await settle(page)
  assert.equal(await trigger.getAttribute("aria-expanded"), "true")
  assert.ok(await page.locator("[data-chadcn--accordion-target~=content]").first().evaluate((el) => el.childElementCount) > 0, "content is mounted")
  assert.equal(await page.locator("[data-chadcn--accordion-target~=content] template").count(), 0)
})

browserTest("accordion: an open item keeps its content and state through the snapshot", async ({ open }) => {
  const page = await open("single__default-value-open", "accordion")
  const before = await page.locator("[data-chadcn--accordion-target~=item][data-state=open]").count()
  assert.ok(before > 0, "precondition: an item is open")
  const html = await snapshot(page, "chadcn--accordion")
  await restore(page, "chadcn--accordion", html)
  assert.equal(await page.locator("[data-chadcn--accordion-target~=item][data-state=open]").count(), before)
  assert.ok(await page.locator("[data-chadcn--accordion-target~=item][data-state=open] [data-chadcn--accordion-target~=content]").first().evaluate((el) => el.childElementCount) > 0)
})

browserTest("accordion: the live page still opens items after a snapshot that is not followed by a navigation", async ({ open }) => {
  const page = await open("single__all-closed", "accordion")
  await snapshot(page, "chadcn--accordion")
  await afterSnapshotTicks(page)
  const trigger = page.locator("[data-chadcn--accordion-target~=trigger]").first()
  await trigger.click()
  await settle(page)
  assert.equal(await trigger.getAttribute("aria-expanded"), "true")
  assert.ok(await page.locator("[data-chadcn--accordion-target~=content]").first().evaluate((el) => el.childElementCount) > 0)
})

browserTest("collapsible: a closed content keeps its body in the snapshot and opens after the restore", async ({ open }) => {
  const page = await open("closed__rest", "collapsible")
  const html = await snapshot(page, "chadcn--collapsible")
  assert.ok(await countIn(page, html, "template") >= 1, "the closed body is in the snapshot")

  await restore(page, "chadcn--collapsible", html)
  const trigger = page.locator("[data-chadcn--collapsible-target~=trigger]").first()
  await trigger.click()
  await settle(page)
  assert.equal(await trigger.getAttribute("aria-expanded"), "true")
  assert.ok(await page.locator("[data-chadcn--collapsible-target~=content]").first().evaluate((el) => el.childElementCount) > 0, "content is mounted")
})

browserTest("collapsible: an open content survives the snapshot and can be closed and reopened", async ({ open }) => {
  const page = await open("default-open__rest", "collapsible")
  const html = await snapshot(page, "chadcn--collapsible")
  await restore(page, "chadcn--collapsible", html)
  const content = page.locator("[data-chadcn--collapsible-target~=content]").first()
  assert.equal(await content.getAttribute("data-state"), "open")
  assert.ok(await content.evaluate((el) => el.childElementCount) > 0)
  const trigger = page.locator("[data-chadcn--collapsible-target~=trigger]").first()
  await trigger.click()
  await settle(page)
  await trigger.click()
  await settle(page)
  assert.ok(await content.evaluate((el) => el.childElementCount) > 0, "reopened content is mounted again")
})

browserTest("tabs: an inactive panel keeps its body in the snapshot and shows it after the restore", async ({ open }) => {
  const page = await open("default", "tabs")
  const html = await snapshot(page, "chadcn--tabs")
  assert.ok(await countIn(page, html, "template") >= 1, "the inactive bodies are in the snapshot")

  await restore(page, "chadcn--tabs", html)
  const triggers = page.locator("[role=tab]")
  assert.ok(await triggers.count() > 1, "precondition: two tabs")
  await triggers.nth(1).click()
  await settle(page)
  assert.equal(await triggers.nth(1).getAttribute("aria-selected"), "true")
  const panel = page.locator("[role=tabpanel][data-state=active]")
  assert.equal(await panel.count(), 1)
  assert.ok(await panel.evaluate((el) => el.childElementCount > 0 || el.textContent.trim() !== ""), "the activated panel has its body")
})

// NO_MOTION is `*{animation:none!important}` (specificity 0,0,0): a more specific !important rule on the exit state wins, so the
// exit animation really runs and the controller is snapshotted mid-exit.
const holdExit = (page, selector) =>
  page.addStyleTag({ content: `@keyframes shadcn-test-hold{to{opacity:.5}} ${selector}{animation:shadcn-test-hold 60s!important}` })

// Every matching element in the snapshot is hidden and holds nothing but its body template.
const allRestored = (page, html, selector) => page.evaluate(({ html, selector }) => {
  const root = document.createElement("div")
  root.innerHTML = html
  const found = [...root.querySelectorAll(selector)]
  return found.length > 0 && found.every((el) => el.hidden && el.children.length === 1 && el.firstElementChild.tagName === "TEMPLATE")
}, { html, selector })

browserTest("accordion: an item snapshotted mid exit animation is closed, hidden and keeps its body", async ({ open }) => {
  const page = await open("single__collapsible__default-value-open", "accordion")
  const closed = "[data-chadcn--accordion-target~=content][data-state=closed]"
  await holdExit(page, closed)
  const handle = await page.locator("[data-chadcn--accordion-target~=item][data-state=open] [data-chadcn--accordion-target~=content]").first().elementHandle()
  await page.locator("[data-chadcn--accordion-target~=item][data-state=open] [data-chadcn--accordion-target~=trigger]").first().click()
  assert.ok(await handle.evaluate((el) => el.dataset.state === "closed" && !el.hidden && el.childElementCount > 0), "precondition: exit running")
  const html = await snapshot(page, "chadcn--accordion")
  assert.ok(await allRestored(page, html, closed))
  await afterSnapshotTicks(page)
  assert.equal(await handle.evaluate((el) => el.hidden), true, "the live page does not keep the exiting content visible")
})

browserTest("collapsible: a content snapshotted mid exit animation is closed, hidden and keeps its body", async ({ open }) => {
  const page = await open("default-open__rest", "collapsible")
  const closed = "[data-chadcn--collapsible-target~=content][data-state=closed]"
  await holdExit(page, closed)
  const content = page.locator("[data-chadcn--collapsible-target~=content]").first()
  await page.locator("[data-chadcn--collapsible-target~=trigger]").first().click()
  assert.ok(await content.evaluate((el) => !el.hidden && el.childElementCount > 0), "precondition: exit running")
  const html = await snapshot(page, "chadcn--collapsible")
  assert.ok(await allRestored(page, html, closed))
  await afterSnapshotTicks(page)
  assert.equal(await content.evaluate((el) => el.hidden), true)
})

browserTest("tabs: a panel snapshotted mid exit animation is inactive, hidden and keeps its body", async ({ open }) => {
  const page = await open("default", "tabs")
  const inactive = "[role=tabpanel][data-state=inactive]"
  await holdExit(page, inactive)
  const leaving = await page.locator("[role=tabpanel][data-state=active]").first().elementHandle()
  await page.locator("[role=tab]").nth(1).click()
  assert.ok(await leaving.evaluate((el) => el.dataset.state === "inactive" && !el.hidden), "precondition: exit running")
  const html = await snapshot(page, "chadcn--tabs")
  assert.ok(await allRestored(page, html, inactive))
  await afterSnapshotTicks(page)
  assert.equal(await leaving.evaluate((el) => el.hidden), true)
})
