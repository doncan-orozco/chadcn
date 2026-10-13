// Radix Collection (react-collection): ordered item registry. React keeps a registration map sorted by the DOM order of
// `[data-radix-collection-item]` nodes; the DOM itself is the registry here, so order is always current.
// Disabled items stay in the registry in Radix (consumers filter on `disabled` / `focusable`); the server marks them
// with `data-disabled` (or the native `disabled` property) and `items()` filters them out unless asked otherwise.
//
// Known divergences: items of a nested collection inside the container are included (React scopes per provider).

export const ITEM_ATTR = "data-radix-collection-item"
export const ITEM_SELECTOR = `[${ITEM_ATTR}]`

export const isDisabled = (el) => el.hasAttribute("data-disabled") || el.disabled === true

export function items(container, { includeDisabled = false } = {}) {
  const all = [...container.querySelectorAll(ITEM_SELECTOR)]
  return includeDisabled ? all : all.filter((el) => !isDisabled(el))
}

// Text used for typeahead: the `data-text-value` override (Radix `textValue`), else the trimmed text content.
export const textValue = (el) => (el.getAttribute("data-text-value") ?? el.textContent ?? "").trim()

export function wrapArray(array, startIndex) {
  return array.map((_, index) => array[(startIndex + index) % array.length])
}
