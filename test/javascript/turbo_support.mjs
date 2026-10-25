// Shared by the Turbo page-cache tests (turbo_disclosure, turbo_scroll_area, turbo_avatar). Not a *.test.mjs file, so the runner
// does not execute it. Turbo takes its snapshot one timer tick after turbo:before-cache, so the markup must be restorable by then;
// the restore is simulated by re-inserting the host as it is in that snapshot, which connects a new controller (the same approach
// as turbo_overlays.test.mjs). turbo_visit.test.mjs drives the real thing.
import { host, settle } from "./support.mjs"

// The markup of the controller host one timer tick after the event, i.e. what Turbo would snapshot.
export const snapshot = (page, controller) => page.evaluate(async (selector) => {
  document.dispatchEvent(new Event("turbo:before-cache"))
  await new Promise((resolve) => setTimeout(resolve))
  return document.querySelector(selector).outerHTML
}, host(controller))

export const restore = async (page, controller, html) => {
  await page.evaluate(({ selector, html }) => {
    const live = document.querySelector(selector)
    live.insertAdjacentHTML("afterend", html)
    live.remove()
  }, { selector: host(controller), html })
  await settle(page)
}

// Counts matches in the snapshot markup without connecting anything (<template> content is not queried, as in the DOM).
export const countIn = (page, html, selector) => page.evaluate(({ html, selector }) => {
  const root = document.createElement("div")
  root.innerHTML = html
  return root.querySelectorAll(selector).length
}, { html, selector })

// Turbo keeps the page for a visit to #hash: after the snapshot the live page must work again without a restore.
export const afterSnapshotTicks = (page) => page.evaluate(async () => { for (let tick = 0; tick < 4; tick++) await new Promise((resolve) => setTimeout(resolve)) })
