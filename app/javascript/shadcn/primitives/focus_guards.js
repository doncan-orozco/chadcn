// Port of @radix-ui/react-focus-guards: two focusable, invisible sentinels at both edges of <body> keep Tab events
// inside the document while a modal focus scope is open. Ref-counted: the guards are removed with the last release.
// Known divergences: none (release is single-use, like upstream).
let count = 0

/**
 * Inserts two focusable sentinels at both edges of <body> (ref-counted) so Tab stays inside the document while a modal is open.
 * @returns {() => void} release: removes the guards when the last holder releases. Single-use: call it once per `focusGuards()`;
 *   a second call decrements the shared counter again and can remove guards another modal still needs.
 * @example
 * const release = focusGuards()
 * release()
 */
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
