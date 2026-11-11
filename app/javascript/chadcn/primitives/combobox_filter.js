// Matching of the Combobox (Base UI 1.9.0, spec dev/port/specs/combobox.md, Filtering): Base UI's default `contains` filter
// (filter:L9-33, an Intl.Collator substring match), the fuzzy filter of primitives/scorer.js, the selected-label bypass and the
// limit (root:L225-330), and the typeahead of the closed trigger (trigger:L92-107). Items are `{ k, l }` (form value, label), the
// shape the Phlex part serializes into the controller's `config`. Pure functions, no DOM, no Stimulus.
//
// Known divergences: none here (the fuzzy default filter is a recorded deviation of the spec, Third-party).
import { rank } from "chadcn/primitives/scorer"
import { typeahead } from "chadcn/primitives/typeahead"

/**
 * Base UI's default filter: whether `text` contains `query` for an Intl.Collator (search usage, base sensitivity, punctuation
 * ignored). An empty query matches everything.
 * @param {string} [locale] Collator locale (the page's when omitted).
 * @returns {(text: string, query: string) => boolean}
 * @example
 * collatorContains("en")("Next.js", "JS") // true
 */
export function collatorContains(locale) {
  const collator = new Intl.Collator(locale ?? undefined, { usage: "search", sensitivity: "base", ignorePunctuation: true })
  return (text, query) => {
    if (!query) return true
    for (let i = 0; i <= text.length - query.length; i += 1) {
      if (collator.compare(text.slice(i, i + query.length), query) === 0) return true
    }
    return false
  }
}

/**
 * The text that filters. In single mode an unedited query that equals the selected label (the input shows the selection) filters
 * nothing, so reopening shows the whole list.
 * @param {string} query The trimmed query.
 * @param {object} options
 * @param {string} options.selectedLabel Label of the single selection ("" when none).
 * @param {boolean} options.single
 * @param {boolean} options.queryEdited The user typed since the popup opened.
 * @param {(text: string, query: string) => boolean} options.contains
 * @returns {string}
 * @example
 * filterQuery("Apple", { selectedLabel: "Apple", single: true, queryEdited: false, contains }) // ""
 */
export function filterQuery(query, { selectedLabel, single, queryEdited, contains }) {
  const bypass = single && !queryEdited && query !== "" && selectedLabel.length === query.length && contains(selectedLabel, query)
  return bypass ? "" : query
}

/**
 * The items that match `query`. "fuzzy" ranks best match first and cuts to `limit` AFTER ranking; "contains" keeps source
 * order; `null` filters nothing. An empty query keeps every item in source order.
 * @template {{k: string, l: string}} T
 * @param {T[]} items
 * @param {string} query
 * @param {object} options
 * @param {"fuzzy"|"contains"|null} options.filter
 * @param {number} [options.limit=-1] Maximum matches, -1 for all.
 * @param {(text: string, query: string) => boolean} options.contains
 * @returns {{ query: string, list: T[], scores: Map<string, number>|null }} `scores`: fuzzy score per form value.
 * @example
 * matchItems([{ k: "a", l: "Apple" }], "ap", { filter: "contains", contains }).list // [{ k: "a", l: "Apple" }]
 */
export function matchItems(items, query, { filter, limit = -1, contains }) {
  let list = items
  let scores = null
  if (query !== "" && filter === "fuzzy") {
    const ranked = rank(query, list, { text: (item) => item.l })
    list = ranked.map(({ item }) => item)
    scores = new Map(ranked.map(({ item, score }) => [item.k, score]))
  } else if (query !== "" && filter !== null) {
    list = list.filter((item) => contains(item.l, query))
  }
  return { query, list: limit > -1 ? list.slice(0, limit) : list, scores }
}

/**
 * Index of the first item after `from` (wrapping around) whose label starts with `search`, case-insensitive; -1 for none.
 * @param {{l: string}[]} items
 * @param {string} search
 * @param {number} [from=-1]
 * @returns {number}
 * @example
 * typeaheadIndex([{ l: "Apple" }, { l: "Avocado" }], "a", 0) // 1
 */
export function typeaheadIndex(items, search, from = -1) {
  const needle = search.toLowerCase()
  for (let offset = 0; offset < items.length; offset += 1) {
    const index = (from + 1 + offset) % items.length
    if (items[index].l.toLowerCase().startsWith(needle)) return index
  }
  return -1
}

/**
 * The typeahead of a closed trigger (useTypeahead, trigger:L92-107): printable keys build a buffer that resets after `timeout`;
 * each key selects the next item whose label starts with the buffer, starting after the selection; a repeated key cycles.
 * @param {object} options
 * @param {number} options.timeout Milliseconds without a key before the buffer resets.
 * @param {(item: {k: string, l: string}) => void} options.onMatch Runs with the item to select.
 * @returns {{ push: (key: string, items: {k: string, l: string}[], selected: string[]) => void, release: () => void }}
 * @example
 * const search = triggerTypeahead({ timeout: 750, onMatch: (item) => select(item.k) })
 * search.push("a", items, ["banana"])
 */
export function triggerTypeahead({ timeout, onMatch }) {
  let items = []
  let from = -1
  let match = null
  let found = false
  const buffer = typeahead({
    timeout,
    onSearch: (search) => {
      const index = typeaheadIndex(items, search, from)
      if (index < 0) return
      match = index
      found = true
      onMatch(items[index])
    }
  })
  return {
    push(key, list, selected) {
      items = list
      if (!items.length) return
      if (buffer.search === "") {
        from = items.findIndex(({ k }) => selected.includes(k))
      } else if (buffer.search === key) {
        // A repeated key cycles: the buffer restarts from the current match.
        buffer.reset()
        from = match ?? from
      }
      found = false
      buffer.push(key)
      if (!found) buffer.reset()
    },
    release() {
      buffer.release()
      buffer.reset()
    }
  }
}
