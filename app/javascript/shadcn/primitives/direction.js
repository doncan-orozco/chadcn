// Radix useDirection (react-direction/dist/index.mjs:17-20): `localDir || globalDir || "ltr"`.
// The "global" value is the nearest DirectionProvider; on the server that provider is resolved while rendering
// (Phlex::Shadcn::Direction, spec direction.md) and written to the consumer's own `dir` attribute, so here the
// consumer element's `dir` attribute stands for it. NEVER reads html[dir] or an ancestor's dir.
//
// Known divergences: none.

const VALID = ["ltr", "rtl"]

const valid = (value) => (VALID.includes(value) ? value : null)

export function direction(el, localDir = null) {
  return valid(localDir) || valid(el?.getAttribute("dir")) || "ltr"
}
