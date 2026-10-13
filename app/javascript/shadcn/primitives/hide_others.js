// Port of the `aria-hidden` package (hideOthers) used by Radix modal content: every sibling along the path from the
// targets up to <body> gets aria-hidden="true" (and the data-aria-hidden marker); ref-counted so nested modals compose
// and a node that was already aria-hidden is left alone on release. Known divergences: none.
const counters = new WeakMap()
const markers = new WeakMap()
const uncontrolled = new WeakMap()

export function hideOthers(targets, parent = document.body) {
  const list = (Array.isArray(targets) ? targets : [targets]).filter(Boolean)
  list.push(...parent.querySelectorAll("[aria-live], script"))

  const keep = new Set()
  const stop = new Set(list)
  const addWithAncestors = (el) => {
    if (!el || keep.has(el)) return
    keep.add(el)
    addWithAncestors(el.parentNode)
  }
  list.forEach(addWithAncestors)

  const hidden = []
  const walk = (node) => {
    if (!node || stop.has(node)) return
    for (const child of node.children) {
      if (keep.has(child)) {
        walk(child)
        continue
      }
      const current = child.getAttribute("aria-hidden")
      const alreadyHidden = current !== null && current !== "false"
      const counter = (counters.get(child) || 0) + 1
      const marker = (markers.get(child) || 0) + 1
      counters.set(child, counter)
      markers.set(child, marker)
      hidden.push(child)
      if (counter === 1 && alreadyHidden) uncontrolled.set(child, true)
      if (marker === 1) child.setAttribute("data-aria-hidden", "true")
      if (!alreadyHidden) child.setAttribute("aria-hidden", "true")
    }
  }
  walk(parent)

  return function release() {
    hidden.forEach((child) => {
      const counter = counters.get(child) - 1
      const marker = markers.get(child) - 1
      counters.set(child, counter)
      markers.set(child, marker)
      if (!counter) {
        if (!uncontrolled.has(child)) child.removeAttribute("aria-hidden")
        uncontrolled.delete(child)
      }
      if (!marker) child.removeAttribute("data-aria-hidden")
    })
  }
}
