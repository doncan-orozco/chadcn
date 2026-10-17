// Port of @radix-ui/react-portal: the element lives in `container` (default: body) while portaled and goes back
// to its original position on release.
// Known divergences: implemented as a DOM move with a comment placeholder instead of a React portal (no re-render semantics).
/**
 * Moves an element into `container` and leaves a placeholder where it was.
 * @param {HTMLElement} el
 * @param {Element} [container=document.body]
 * @returns {() => void} release: puts the element back at its original position. It is a no-op when the placeholder
 *   no longer has a parent (the element then stays in the container); safe to call twice.
 * @example
 * const release = portal(contentEl)
 */
export function portal(el, container = document.body) {
  const placeholder = document.createComment("portal")
  el.before(placeholder)
  container.append(el)

  return function release() {
    placeholder.replaceWith(el)
  }
}
