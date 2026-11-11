// Mounts the content of an inert <template> the way React mounts a conditionally rendered subtree: the nodes only exist
// while mounted and every mount is a fresh clone (no state survives `unmount()`).
// Known divergences: none (not a Radix port: it stands in for React's conditional rendering of a subtree).
//
//   const mount = mountTemplate(templateEl, { into: document.body })   // portal to body
//   const mount = mountTemplate(templateEl, { into: "after" })         // in place, right after the <template>
//   const mount = mountTemplate(templateEl, { into: "replace" })       // in the template's place; unmount puts it back
//   const mount = mountTemplate(templateEl, { anchor: textNode })      // right after another node (detached template)
//   const mount = mountedTemplate(templateEl, serverNodes)             // nodes the server rendered already mounted
//   mount.nodes      // top-level elements inserted
//   mount.unmount()  // removes them; mount again to get a new copy
/**
 * Mounts a fresh clone of an inert <template>'s content.
 * @param {HTMLTemplateElement} templateEl
 * @param {object} [options]
 * @param {"after" | "replace" | Element} [options.into="after"] "after" inserts right after the template (or `anchor`);
 *   "replace" puts the clone in the template's place and `unmount()` puts the template back (an empty template stays);
 *   an element appends to it (portal).
 * @param {Node} [options.anchor] with `into: "after"`, the node to insert after instead of the template, so a template
 *   kept out of the document can mount at a marked place.
 * @returns {{ nodes: Element[], unmount: () => void }} `unmount()` is idempotent. Calling `mountTemplate` twice without
 *   unmounting inserts another copy.
 * @example
 * const mount = mountTemplate(tpl, { into: document.body })
 * mount.unmount()
 */
export function mountTemplate(templateEl, { into = "after", anchor = templateEl } = {}) {
  const fragment = templateEl.content.cloneNode(true)
  const inserted = [...fragment.childNodes]

  if (into === "after") anchor.after(fragment)
  else if (into === "replace") {
    if (inserted.length) templateEl.replaceWith(fragment)
  } else into.append(fragment)

  return mountedTemplate(templateEl, inserted, { into })
}

/**
 * Wraps nodes already in the document as a mount of `templateEl` (content the server rendered mounted, e.g. an open
 * disclosure), so they unmount the way `mountTemplate` would have unmounted its own copy.
 * @param {HTMLTemplateElement} templateEl
 * @param {Node[]} nodes the mounted nodes, text nodes included
 * @param {object} [options]
 * @param {"after" | "replace" | Element} [options.into="after"] with "replace", `unmount()` puts the template back where the
 *   first node was.
 * @returns {{ nodes: Element[], unmount: () => void }} `unmount()` is idempotent.
 * @example
 * const mount = mountedTemplate(tpl, [...content.childNodes])
 * mount.unmount() // content is empty again
 */
export function mountedTemplate(templateEl, nodes, { into = "after" } = {}) {
  const mounted = [...nodes]
  return {
    nodes: mounted.filter((node) => node.nodeType === Node.ELEMENT_NODE),
    unmount() {
      const first = mounted.find((node) => node.isConnected)
      if (into === "replace" && first) first.before(templateEl)
      mounted.forEach((node) => node.remove())
    },
  }
}
