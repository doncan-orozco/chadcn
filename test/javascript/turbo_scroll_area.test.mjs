import { browserTest } from "./harness.mjs"
import { assert, host, settle } from "./support.mjs"
import { afterSnapshotTicks, countIn, restore, snapshot } from "./turbo_support.mjs"

// Turbo page cache for the scroll area: the scrollbar mounts on hover, so the snapshot must hold none and a hovered pointer must
// bring it back (stimulus R2/R3, radix-stimulus R10).
const SCROLLBAR = "[data-slot=scroll-area-scrollbar]"

browserTest("scroll-area: the snapshot has no mounted scrollbar and the restore does not duplicate them", async ({ open }) => {
  const page = await open("default__hover", "scroll-area")
  await page.locator(host("chadcn--scroll-area")).first().hover()
  await page.waitForSelector(SCROLLBAR)
  assert.equal(await page.locator(SCROLLBAR).count(), 1, "precondition: one scrollbar while hovered")

  const html = await snapshot(page, "chadcn--scroll-area")
  assert.equal(await countIn(page, html, SCROLLBAR), 0, "no mounted scrollbar in the snapshot")

  await restore(page, "chadcn--scroll-area", html)
  assert.equal(await page.locator(SCROLLBAR).count(), 0)
  await page.mouse.move(0, 0)
  await page.locator(host("chadcn--scroll-area")).first().hover()
  await page.waitForSelector(SCROLLBAR)
  await settle(page)
  assert.equal(await page.locator(SCROLLBAR).count(), 1, "exactly one scrollbar after the restore")
})

browserTest("scroll-area: the live page shows its scrollbar again after a snapshot that is not followed by a navigation", async ({ open }) => {
  const page = await open("default__hover", "scroll-area")
  await snapshot(page, "chadcn--scroll-area")
  await afterSnapshotTicks(page)
  await page.locator(host("chadcn--scroll-area")).first().hover()
  await page.waitForSelector(SCROLLBAR)
  assert.equal(await page.locator(SCROLLBAR).count(), 1)
})

browserTest("scroll-area: a hovered root keeps its scrollbar through a snapshot that is not followed by a navigation", async ({ open }) => {
  const page = await open("default__hover", "scroll-area")
  await page.locator(host("chadcn--scroll-area")).first().hover()
  await page.waitForSelector(SCROLLBAR)
  await snapshot(page, "chadcn--scroll-area")
  await afterSnapshotTicks(page)
  await page.waitForSelector(SCROLLBAR) // no pointer move: the new controller learns about the pointer that is already inside
  await settle(page)
  assert.equal(await page.locator(SCROLLBAR).count(), 1)
})

browserTest("scroll-area: a hovered root keeps its scrollbar through a second before-cache inside the restore window", async ({ open }) => {
  const page = await open("default__hover", "scroll-area")
  await page.locator(host("chadcn--scroll-area")).first().hover()
  await page.waitForSelector(SCROLLBAR)
  const atSecondSnapshot = await page.evaluate(async (scrollbar) => {
    const nextTick = () => new Promise((resolve) => setTimeout(resolve))
    document.dispatchEvent(new Event("turbo:before-cache"))
    await nextTick() // the first snapshot; the restore is one tick away
    document.dispatchEvent(new Event("turbo:before-cache")) // the records are gone: only the carried hover state re-arms
    await nextTick()
    return document.querySelectorAll(scrollbar).length
  }, SCROLLBAR)
  assert.equal(atSecondSnapshot, 0, "the second snapshot holds no scrollbar")
  await afterSnapshotTicks(page)
  await page.waitForSelector(SCROLLBAR, { timeout: 2000 }) // no pointer move: red without the carry
  await settle(page)
  assert.equal(await page.locator(SCROLLBAR).count(), 1)
})
