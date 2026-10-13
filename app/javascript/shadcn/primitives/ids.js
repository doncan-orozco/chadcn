// Radix useId (react-id/dist/index.mjs): `deterministicId || generated`. Server-rendered ids always win; a generated id is
// only minted for elements that arrive without one, and never collides with an id already in the document.
//
// Known divergences: generated ids read `radix-v2-<n>` instead of React's `radix-:r1:`; ids are not compared by value
// (the parity runner compares them structurally through aria relations).

let count = 0

export function generateId(prefix = "radix-v2") {
  let id
  do { id = `${prefix}-${count++}` } while (document.getElementById(id))
  return id
}

export function ensureId(el, prefix) {
  if (!el.id) el.id = generateId(prefix)
  return el.id
}
