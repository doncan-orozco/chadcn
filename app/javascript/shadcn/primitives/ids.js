// Radix useId (react-id/dist/index.mjs): `deterministicId || generated`. Server-rendered ids always win; a generated id is
// only minted for elements that arrive without one, and never collides with an id already in the document.
//
// Known divergences: generated ids read `radix-shadcn-<n>` instead of React's `radix-:r1:`; ids are not compared by value
// (the parity runner compares them structurally through aria relations).

let count = 0

/**
 * Mints an element id that does not exist in the document yet.
 * @param {string} [prefix="radix-shadcn"]
 * @returns {string}
 * @example
 * generateId("menu") // "menu-<n>"
 */
export function generateId(prefix = "radix-shadcn") {
  let id
  do { id = `${prefix}-${count++}` } while (document.getElementById(id))
  return id
}

/**
 * Returns the element's id, assigning a generated one when it has none (server-rendered ids win).
 * @param {Element} el
 * @param {string} [prefix]
 * @returns {string}
 */
export function ensureId(el, prefix) {
  if (!el.id) el.id = generateId(prefix)
  return el.id
}
