// Mounts the content of an inert <template> the way React mounts a conditionally rendered subtree: the nodes only exist
// while mounted and every mount is a fresh clone (no state survives `unmount()`).
//
//   const mount = mountTemplate(templateEl, { into: document.body })   // portal to body
//   const mount = mountTemplate(templateEl, { into: "after" })         // in place, right after the <template>
//   mount.nodes      // top-level elements inserted
//   mount.unmount()  // removes them; mount again to get a new copy
export function mountTemplate(templateEl, { into = "after" } = {}) {
  const fragment = templateEl.content.cloneNode(true)
  const inserted = [...fragment.childNodes]

  if (into === "after") templateEl.after(fragment)
  else into.append(fragment)

  return {
    nodes: inserted.filter((node) => node.nodeType === Node.ELEMENT_NODE),
    unmount() {
      inserted.forEach((node) => node.remove())
    },
  }
}
