// Radix typeahead as used by Menu (react-menu/dist/index.mjs:233-249, 822-833) and Select (react-select useTypeaheadSearch /
// findNextItem): the buffer appends each key, resets 1000 ms after the last key, and a repeated single letter ("aaa") cycles
// through the items starting with that letter.
//
// Known divergences: none.
import { wrapArray, textValue } from "shadcn/primitives/collection"

export const RESET_MS = 1000

// Menu flavour: match on strings.
export function nextMatch(values, search, currentMatch) {
  const isRepeated = search.length > 1 && Array.from(search).every((char) => char === search[0])
  const normalizedSearch = isRepeated ? search[0] : search
  const currentMatchIndex = currentMatch ? values.indexOf(currentMatch) : -1
  let wrappedValues = wrapArray(values, Math.max(currentMatchIndex, 0))
  if (normalizedSearch.length === 1) wrappedValues = wrappedValues.filter((v) => v !== currentMatch)
  const match = wrappedValues.find((value) => value.toLowerCase().startsWith(normalizedSearch.toLowerCase()))
  return match !== currentMatch ? match : undefined
}

// Select flavour: match on items (identity based, so equal labels stay distinct).
export function matchItem(items, search, currentItem, text = textValue) {
  const isRepeated = search.length > 1 && Array.from(search).every((char) => char === search[0])
  const normalizedSearch = isRepeated ? search[0] : search
  const currentIndex = currentItem ? items.indexOf(currentItem) : -1
  let wrapped = wrapArray(items, Math.max(currentIndex, 0))
  if (normalizedSearch.length === 1) wrapped = wrapped.filter((v) => v !== currentItem)
  const match = wrapped.find((item) => text(item).toLowerCase().startsWith(normalizedSearch.toLowerCase()))
  return match !== currentItem ? match : undefined
}

// A character key that feeds the buffer (Menu: no ctrl/alt/meta, `key.length === 1`).
export const isCharacterKey = (event) => !(event.ctrlKey || event.altKey || event.metaKey) && event.key.length === 1

// Buffer with the 1000 ms reset. `onSearch(search)` runs BEFORE the buffer is updated, like Radix.
export function typeahead({ onSearch, timeout = RESET_MS }) {
  let search = ""
  let timer = 0

  function update(value) {
    search = value
    clearTimeout(timer)
    if (value !== "") timer = setTimeout(() => update(""), timeout)
  }

  return {
    get search() { return search },
    push(key) {
      const next = search + key
      onSearch(next)
      update(next)
    },
    reset() { update("") },
    release() { clearTimeout(timer) },
  }
}
