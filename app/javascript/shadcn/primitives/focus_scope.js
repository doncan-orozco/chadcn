// Port of @radix-ui/react-focus-scope.
// Known divergences: release() removes this scope from the stack and resumes the previous one synchronously; Radix does
// both inside the deferred (setTimeout 0) return-focus task, so a parent trap resumes one task earlier. No observable
// effect when the released content is removed or focus returns into the parent.
const stack = []

const AUTOFOCUS_ON_MOUNT = "focusScope.autoFocusOnMount"
const AUTOFOCUS_ON_UNMOUNT = "focusScope.autoFocusOnUnmount"
const EVENT_OPTIONS = { bubbles: false, cancelable: true }

/**
 * Traps and/or loops focus inside a container and restores focus on release.
 *
 * On mount focus moves to the first tabbable non-link descendant (or the container); on release it returns to the element that
 * was focused before. Nested scopes pause the previous one (stack). The container gets a temporary `tabindex="-1"`
 * unless it already has a tabindex; it is removed on release.
 * @param {HTMLElement} container
 * @param {object} [options]
 * @param {boolean} [options.trapped=false] Focus cannot leave the container (modal). Tab is also blocked at the edges
 *   even without `loop` (focus does not wrap, it stays put).
 * @param {boolean} [options.loop=false] Tab at the edges wraps.
 * @param {(event: CustomEvent) => void} [options.onMountAutoFocus] Cancelable; `preventDefault()` keeps focus where it
 *   is. Not dispatched when focus is already inside the container at mount.
 * @param {(event: CustomEvent) => void} [options.onUnmountAutoFocus] Cancelable; runs on the next task after release.
 * @returns {() => void} release: removes the listeners and the observer, restores the tabindex and schedules the return
 *   focus. Call it once (not idempotent: a second call schedules the return focus again).
 * @example
 * const release = focusScope(contentEl, { trapped: true, loop: true })
 */
export function focusScope(container, { trapped = false, loop = false, onMountAutoFocus, onUnmountAutoFocus } = {}) {
  const scope = {
    paused: false,
    pause() { this.paused = true },
    resume() { this.paused = false },
  }
  let lastFocused = null
  const hadTabindex = container.hasAttribute("tabindex")
  if (!hadTabindex) container.tabIndex = -1

  const disposers = []
  const listen = (target, type, handler, options) => {
    target.addEventListener(type, handler, options)
    disposers.push(() => target.removeEventListener(type, handler, options))
  }

  if (trapped) {
    const onFocusIn = (event) => {
      if (scope.paused) return
      if (container.contains(event.target)) lastFocused = event.target
      else focus(lastFocused, { select: true })
    }
    const onFocusOut = (event) => {
      if (scope.paused || event.relatedTarget === null) return
      if (!container.contains(event.relatedTarget)) focus(lastFocused, { select: true })
    }
    // Focus is lost to <body> when the focused element is removed: bring it back to the container.
    const onMutations = (mutations) => {
      if (document.activeElement !== document.body) return
      if (mutations.some((m) => m.removedNodes.length > 0)) focus(container)
    }
    listen(document, "focusin", onFocusIn)
    listen(document, "focusout", onFocusOut)
    const observer = new MutationObserver(onMutations)
    observer.observe(container, { childList: true, subtree: true })
    disposers.push(() => observer.disconnect())
  }

  if (loop || trapped) {
    listen(container, "keydown", (event) => {
      if (scope.paused) return
      const isTab = event.key === "Tab" && !event.altKey && !event.ctrlKey && !event.metaKey
      const focused = document.activeElement
      if (!isTab || !focused) return
      const [first, last] = tabbableEdges(container)
      if (!(first && last)) {
        if (focused === container) event.preventDefault()
      } else if (!event.shiftKey && focused === last) {
        event.preventDefault()
        if (loop) focus(first, { select: true })
      } else if (event.shiftKey && focused === first) {
        event.preventDefault()
        if (loop) focus(last, { select: true })
      }
    })
  }

  const previouslyFocused = document.activeElement
  stack.at(-1)?.pause()
  stack.push(scope)

  if (!container.contains(previouslyFocused)) {
    const mountEvent = new CustomEvent(AUTOFOCUS_ON_MOUNT, EVENT_OPTIONS)
    if (onMountAutoFocus) container.addEventListener(AUTOFOCUS_ON_MOUNT, onMountAutoFocus)
    container.dispatchEvent(mountEvent)
    if (!mountEvent.defaultPrevented) {
      focusFirst(removeLinks(tabbableCandidates(container)), { select: true })
      if (document.activeElement === previouslyFocused) focus(container)
    }
    if (onMountAutoFocus) container.removeEventListener(AUTOFOCUS_ON_MOUNT, onMountAutoFocus)
  }

  return function release() {
    disposers.forEach((dispose) => dispose())
    if (!hadTabindex) container.removeAttribute("tabindex")
    // Radix defers the return focus so a dismissing click can finish first.
    setTimeout(() => {
      const unmountEvent = new CustomEvent(AUTOFOCUS_ON_UNMOUNT, EVENT_OPTIONS)
      if (onUnmountAutoFocus) container.addEventListener(AUTOFOCUS_ON_UNMOUNT, onUnmountAutoFocus)
      container.dispatchEvent(unmountEvent)
      if (!unmountEvent.defaultPrevented) focus(previouslyFocused ?? document.body, { select: true })
      if (onUnmountAutoFocus) container.removeEventListener(AUTOFOCUS_ON_UNMOUNT, onUnmountAutoFocus)
    }, 0)
    const at = stack.indexOf(scope)
    if (at !== -1) stack.splice(at, 1)
    stack.at(-1)?.resume()
  }
}

function focusFirst(candidates, { select = false } = {}) {
  const previouslyFocused = document.activeElement
  for (const candidate of candidates) {
    focus(candidate, { select })
    if (document.activeElement !== previouslyFocused) return
  }
}

function tabbableEdges(container) {
  const candidates = tabbableCandidates(container)
  return [findVisible(candidates, container), findVisible(candidates.reverse(), container)]
}

// Elements that can receive focus by Tab, in DOM order. Visibility is checked separately (findVisible) because
// getComputedStyle is too expensive for every node during the walk.
function tabbableCandidates(container) {
  const nodes = []
  const walker = document.createTreeWalker(container, NodeFilter.SHOW_ELEMENT, {
    acceptNode: (node) => {
      const isHiddenInput = node.tagName === "INPUT" && node.type === "hidden"
      if (node.disabled || node.hidden || isHiddenInput) return NodeFilter.FILTER_SKIP
      return node.tabIndex >= 0 ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_SKIP
    },
  })
  while (walker.nextNode()) nodes.push(walker.currentNode)
  return nodes
}

function findVisible(elements, container) {
  return elements.find((element) => !isHidden(element, { upTo: container }))
}

function isHidden(node, { upTo }) {
  if (getComputedStyle(node).visibility === "hidden") return true
  while (node) {
    if (upTo !== undefined && node === upTo) return false
    if (getComputedStyle(node).display === "none") return true
    node = node.parentElement
  }
  return false
}

function removeLinks(items) {
  return items.filter((item) => item.tagName !== "A")
}

function focus(element, { select = false } = {}) {
  if (!element?.focus) return
  const previouslyFocused = document.activeElement
  element.focus({ preventScroll: true })
  if (element !== previouslyFocused && element instanceof HTMLInputElement && select) element.select()
}
