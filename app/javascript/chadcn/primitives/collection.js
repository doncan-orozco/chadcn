// Radix Collection (react-collection): ordered item registry. React keeps a registration map sorted by the DOM order of
// `[data-radix-collection-item]` nodes; the DOM itself is the registry here, so order is always current.
// Disabled items stay in the registry in Radix (consumers filter on `disabled` / `focusable`); the server marks them
// with `data-disabled` (or the native `disabled` property) and `items()` filters them out unless asked otherwise.
//
// Known divergences: items of a nested collection inside the container are included (React scopes per provider).

/** Attribute that marks a collection item. @type {string} */
export const ITEM_ATTR = "data-radix-collection-item"
/** CSS selector matching every collection item. @type {string} */
export const ITEM_SELECTOR = `[${ITEM_ATTR}]`

/**
 * Whether an item is disabled (`data-disabled` attribute or the native `disabled` property).
 * @param {HTMLElement} el
 * @returns {boolean}
 */
export const isDisabled = (el) => el.hasAttribute("data-disabled") || el.disabled === true

/**
 * The items of a collection in DOM order.
 * @param {ParentNode} container
 * @param {object} [options]
 * @param {boolean} [options.includeDisabled=false] Keep disabled items.
 * @returns {HTMLElement[]}
 * @example
 * items(menuEl).map(textValue)
 */
export function items(container, { includeDisabled = false } = {}) {
  const all = [...container.querySelectorAll(ITEM_SELECTOR)]
  return includeDisabled ? all : all.filter((el) => !isDisabled(el))
}

/**
 * Text used for typeahead: the `data-text-value` override, else the trimmed text content.
 * @param {HTMLElement} el
 * @returns {string}
 */
export const textValue = (el) => (el.getAttribute("data-text-value") ?? el.textContent ?? "").trim()

/**
 * Rotates an array so it starts at `startIndex` (wrapping around).
 * @template T
 * @param {T[]} array
 * @param {number} startIndex
 * @returns {T[]}
 * @example
 * wrapArray([1, 2, 3, 4], 2) // [3, 4, 1, 2]
 */
export function wrapArray(array, startIndex) {
  return array.map((_, index) => array[(startIndex + index) % array.length])
}
