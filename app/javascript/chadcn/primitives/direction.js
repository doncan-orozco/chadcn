// Radix useDirection (react-direction/dist/index.mjs:17-20): `localDir || globalDir || "ltr"`.
// The "global" value is the nearest DirectionProvider; on the server that provider is resolved while rendering
// (Chadcn::Direction, spec direction.md) and written to the consumer's own `dir` attribute, so here the
// consumer element's `dir` attribute stands for it. NEVER reads html[dir] or an ancestor's dir.
//
// Known divergences: none.

const VALID = ["ltr", "rtl"]

const valid = (value) => (VALID.includes(value) ? value : null)

/**
 * Resolves the text direction of a consumer element like Radix `useDirection`: the local value, else the element's own `dir`
 * attribute, else "ltr". Never reads html[dir] or an ancestor.
 * @param {Element | null | undefined} el The consumer element.
 * @param {"ltr" | "rtl" | null} [localDir=null] An explicit local override.
 * @returns {"ltr" | "rtl"}
 * @example
 * direction(el)          // "rtl" when el has dir="rtl"
 * direction(el, "ltr")   // "ltr"
 */
export function direction(el, localDir = null) {
  return valid(localDir) || valid(el?.getAttribute("dir")) || "ltr"
}
