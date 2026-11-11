import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, host, reconnect, settle } from "./support.mjs"

// chadcn--sidebar against its parity pages (spec: dev/port/specs/sidebar.md): the trigger, the rail and the Ctrl/Cmd+B shortcut on
// desktop (data-state / data-collapsible, the cookie, the open-change event), controlled mode, the mobile Sheet the sidebar becomes
// under 768px (its body delegation of the toggle buttons), and a disconnect that puts the desktop structure back and leaves no
// window listener behind.

browserTest.component = "sidebar"

const sidebar = "[data-slot=sidebar][data-chadcn--sidebar-target=sidebar]"
const trigger = "[data-sidebar=trigger]"
const sheetContent = "[data-slot=sidebar][data-mobile=true]"

const desktopState = (page) => page.locator(sidebar).first().evaluate((el) => ({ state: el.dataset.state, collapsible: el.dataset.collapsible }))
const EXPANDED = { state: "expanded", collapsible: "" }
const COLLAPSED = { state: "collapsed", collapsible: "offcanvas" }

const recordOpen = (page) => page.evaluate(() => {
  window.__open = []
  for (const name of ["open-change", "open-mobile-change"]) {
    document.addEventListener(`chadcn--sidebar:${name}`, (event) => window.__open.push(`${name}:${event.detail.open}`))
  }
})
const opens = (page) => page.evaluate(() => window.__open)

// useIsMobile: the media query (max-width: 767px) and innerWidth < 768.
const goMobile = async (page) => {
  await page.setViewportSize({ width: 500, height: 720 })
  await settle(page)
}

browserTest("sidebar: the trigger collapses and expands the desktop sidebar, writes the cookie and dispatches open-change", async ({ open }) => {
  const page = await open("toggle__trigger-click-collapses-and-expands")
  await recordOpen(page)
  assert.deepEqual(await desktopState(page), EXPANDED)
  await page.click(trigger)
  assert.deepEqual(await desktopState(page), COLLAPSED)
  assert.match(await page.evaluate(() => document.cookie), /sidebar_state=false/)
  await page.click(trigger)
  assert.deepEqual(await desktopState(page), EXPANDED)
  assert.match(await page.evaluate(() => document.cookie), /sidebar_state=true/)
  assert.deepEqual(await opens(page), ["open-change:false", "open-change:true"])
})

browserTest("sidebar: Enter on the focused trigger, Ctrl+B and Meta+B toggle; plain B and Shift+Ctrl+B do not", async ({ open }) => {
  const page = await open("toggle__trigger-click-collapses-and-expands")
  await recordOpen(page)
  await page.focus(trigger)
  await page.keyboard.press("Enter")
  assert.deepEqual(await desktopState(page), COLLAPSED)
  await page.keyboard.press("Control+b")
  assert.deepEqual(await desktopState(page), EXPANDED)
  await page.keyboard.press("Meta+b")
  assert.deepEqual(await desktopState(page), COLLAPSED)
  await page.keyboard.press("b")
  await page.keyboard.press("Shift+Control+B")
  assert.deepEqual(await opens(page), ["open-change:false", "open-change:true", "open-change:false"])
})

browserTest("sidebar: a click on the rail toggles the sidebar", async ({ open }) => {
  const page = await open("toggle__rail-click")
  await page.locator("[data-sidebar=rail]").first().click({ force: true })
  assert.deepEqual(await desktopState(page), COLLAPSED)
})

browserTest("sidebar: a controlled sidebar dispatches open-change and keeps the server state", async ({ open }) => {
  const page = await open("controlled__open-true-stays-expanded")
  await recordOpen(page)
  await page.click(trigger)
  assert.equal((await desktopState(page)).state, "expanded")
  assert.deepEqual(await opens(page), ["open-change:false"])
})

browserTest("sidebar: on a mobile viewport Ctrl+B opens the Sheet with the sidebar content and Escape closes it", async ({ open }) => {
  const page = await open("mobile__trigger-inside-sidebar-closes")
  await goMobile(page)
  assert.equal(await page.locator(sidebar).count(), 0, "the desktop node is replaced by the Sheet host")
  await recordOpen(page)
  await page.keyboard.press("Control+b")
  await settle(page)
  assert.equal(await page.locator(`${sheetContent} [data-slot=sidebar-menu-button]`).count(), 1, "the block moved into the Sheet body")
  await page.keyboard.press("Escape")
  await settle(page)
  assert.equal(await page.locator(sheetContent).count(), 0)
  assert.deepEqual(await opens(page), ["open-mobile-change:true", "open-mobile-change:false"])
})

// Advisory of dev/port/REPORT.md: the mobile body delegation returned early on event.defaultPrevented; React SidebarTrigger calls
// onClick and then toggleSidebar() unconditionally (sidebar.tsx), as the desktop Stimulus action does.
browserTest("sidebar: a trigger inside the mobile Sheet closes it even when a caller prevented its click", async ({ open }) => {
  const page = await open("mobile__trigger-inside-sidebar-closes")
  await goMobile(page)
  await page.keyboard.press("Control+b")
  await settle(page)
  await recordOpen(page)
  await page.evaluate(({ sheetContent, trigger }) => {
    document.querySelector(`${sheetContent} ${trigger}`).addEventListener("click", (event) => event.preventDefault())
  }, { sheetContent, trigger })
  await page.click(`${sheetContent} ${trigger}`)
  await settle(page)
  assert.equal(await page.locator(sheetContent).count(), 0)
  assert.deepEqual(await opens(page), ["open-mobile-change:false"])
})

browserTest("sidebar: a disconnect on mobile puts the desktop node back; a reconnect leaves one shortcut listener", async ({ open }) => {
  const page = await open("toggle__trigger-click-collapses-and-expands")
  const errors = consoleErrors(page)
  await goMobile(page)
  await page.evaluate((selector) => document.querySelector(selector).setAttribute("data-controller", ""), host("chadcn--sidebar"))
  await settle(page)
  assert.equal(await page.locator(sidebar).count(), 1, "desktop node restored")
  assert.equal(await page.locator(`${sidebar} [data-slot=sidebar-inner] [data-slot=sidebar-content]`).count(), 1, "block back inside")

  const page2 = await open("toggle__trigger-click-collapses-and-expands")
  await reconnect(page2, "chadcn--sidebar")
  await recordOpen(page2)
  await page2.keyboard.press("Control+b")
  assert.deepEqual(await desktopState(page2), COLLAPSED)
  assert.deepEqual(await opens(page2), ["open-change:false"])
  assert.deepEqual(errors, [])
})
