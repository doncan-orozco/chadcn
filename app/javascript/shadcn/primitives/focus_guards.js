// Port of @radix-ui/react-focus-guards: two focusable, invisible sentinels at both edges of <body> keep Tab events
// inside the document while a modal focus scope is open. Ref-counted: the guards are removed with the last release.
// Known divergences: none.
let count = 0

export function focusGuards() {
  const edges = document.querySelectorAll("[data-radix-focus-guard]")
  document.body.insertAdjacentElement("afterbegin", edges[0] ?? createGuard())
  document.body.insertAdjacentElement("beforeend", edges[1] ?? createGuard())
  count++

  return function release() {
    if (count === 1) document.querySelectorAll("[data-radix-focus-guard]").forEach((node) => node.remove())
    count--
  }
}

function createGuard() {
  const span = document.createElement("span")
  span.setAttribute("data-radix-focus-guard", "")
  span.tabIndex = 0
  span.style.outline = "none"
  span.style.opacity = "0"
  span.style.position = "fixed"
  span.style.pointerEvents = "none"
  return span
}
