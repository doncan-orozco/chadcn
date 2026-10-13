// Port of react-remove-scroll(-bar) as Radix modals use it: while at least one lock is held, <body> carries
// `data-scroll-locked="<count>"` and a stylesheet hides its overflow and compensates the scrollbar width with
// margin-right, so the page does not shift. Ref-counted: the last release restores everything.
// Known divergences: no wheel/touch interception for scrollable shards (overflow: hidden makes it unnecessary here).
const ATTRIBUTE = "data-scroll-locked"
let count = 0
let styleEl = null

export function scrollLock() {
  count++
  apply()
  let released = false

  return function release() {
    if (released) return
    released = true
    count--
    if (count > 0) return apply()
    document.body.removeAttribute(ATTRIBUTE)
    styleEl?.remove()
    styleEl = null
  }
}

function apply() {
  document.body.setAttribute(ATTRIBUTE, String(count))
  if (!styleEl) {
    styleEl = document.createElement("style")
    document.head.append(styleEl)
  }
  // Measured before the first lock hides the scrollbar; later locks reuse the stylesheet.
  if (count === 1) styleEl.textContent = css(scrollbarWidth())
}

function scrollbarWidth() {
  return Math.max(0, window.innerWidth - document.documentElement.clientWidth)
}

function css(gap) {
  return `
body[${ATTRIBUTE}] {
  overflow: hidden !important;
  overscroll-behavior: contain;
  position: relative !important;
  padding-left: 0;
  padding-top: 0;
  padding-right: 0;
  margin-left: 0;
  margin-top: 0;
  margin-right: ${gap}px !important;
}
body[${ATTRIBUTE}] { --removed-body-scroll-bar-size: ${gap}px; }
`
}
