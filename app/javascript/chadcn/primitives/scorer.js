// Fuzzy scorer shared by Command and Combobox. It replaces the filtering that cmdk (command-score) and Base UI do in the React
// originals, with no dependency: a query matches a text when its characters appear in order (a subsequence); the best alignment
// wins, with bonuses for a match at the start of the text, at a word boundary (after a space, "-", "_", "/", "." or at a lower ->
// UPPER camel-case step) and for consecutive characters, and a small penalty for gaps. Case and diacritics are folded
// ("cafe" finds "Café"), one character at a time so offsets keep pointing into the original string. Letters that have no
// Unicode decomposition fold through a small 1:1 table (ø ł đ ð ı); ß, æ, þ and the like stay as they are.
//
// Contract: a score of 0 means "does not match" (hide the item); anything above 0 matches and a higher score ranks first. An
// empty (or whitespace-only) query matches everything with the same score, so the original order is kept.
//
// Known divergences from cmdk's command-score: the numbers differ (only the order and the match/no-match decision are
// comparable); whitespace in the query is ignored instead of being matched as a separator.

/** Score every item gets for an empty query (all match, nothing outranks anything). @type {number} */
export const EMPTY_QUERY_SCORE = 1

const PREFIX_BONUS = 1.0
const BOUNDARY_BONUS = 0.9
const CONSECUTIVE_BONUS = 0.8
const GAP_PENALTY = 0.03
const LEADING_GAP_PENALTY = 0.01
const EXACT_BONUS = 10
const MIN_SCORE = 0.001
const SEPARATORS = new Set([" ", "-", "_", "/", ".", ":", ",", "(", ")", "[", "]", "\t", "\n"])

// Letters NFD does not decompose, mapped to one base letter (always one code point, so offsets stay aligned).
const NO_DECOMPOSITION = new Map([["ø", "o"], ["ł", "l"], ["đ", "d"], ["ð", "d"], ["ı", "i"]])

// Folded texts are reused across keystrokes (the same items are scored again on every key); callers never mutate the arrays.
const FOLD_CACHE_LIMIT = 20000
const FOLD_CACHE = new Map()

/**
 * Fold one string to lower case without diacritics, one entry per code point of the input (so `folded[i]` describes
 * `Array.from(text)[i]`).
 * @param {string} text
 * @returns {string[]}
 */
function foldChars(text) {
  const key = String(text ?? "")
  const cached = FOLD_CACHE.get(key)
  if (cached) return cached
  const folded = Array.from(key, (char) => {
    const base = char.normalize("NFD").replace(/\p{M}/gu, "")
    const lower = (base || char).toLowerCase()
    const first = Array.from(lower)[0] ?? char
    return NO_DECOMPOSITION.get(first) ?? first
  })
  if (FOLD_CACHE.size >= FOLD_CACHE_LIMIT) FOLD_CACHE.clear()
  FOLD_CACHE.set(key, folded)
  return folded
}

/**
 * Case- and diacritic-insensitive form of a string, for callers that need to compare or index folded text.
 * @param {string} text
 * @returns {string}
 * @example
 * fold("Café") // "cafe"
 */
export function fold(text) {
  return foldChars(text).join("")
}

/**
 * Whether the character at `index` starts a word of `chars` (the original characters).
 * @param {string[]} chars
 * @param {number} index
 * @returns {boolean}
 */
function boundaryAt(chars, index) {
  if (index === 0) return false
  const previous = chars[index - 1]
  if (SEPARATORS.has(previous)) return true
  const current = chars[index]
  return previous !== previous.toUpperCase() && current !== current.toLowerCase() && current === current.toUpperCase()
}

/**
 * Score one text against a query. Returns 0 when the query is not a subsequence of the text.
 * @param {string} query
 * @param {string} text
 * @returns {number} 0 (no match) or a positive score; higher is better.
 * @example
 * score("gh", "GitHub") > score("gh", "Light house") // true
 * score("zzz", "GitHub") // 0
 */
export function score(query, text) {
  const wanted = foldChars(query).filter((char) => !/\s/u.test(char))
  if (wanted.length === 0) return EMPTY_QUERY_SCORE
  const original = Array.from(String(text ?? ""))
  const haystack = foldChars(text)
  if (wanted.length > haystack.length) return 0

  // best[qi][ti]: best score matching wanted[0..qi] with wanted[qi] sitting at haystack[ti] (-Infinity when impossible).
  let previous = null
  for (let qi = 0; qi < wanted.length; qi += 1) {
    const current = new Array(haystack.length).fill(-Infinity)
    let bestEarlier = -Infinity // max over tj < ti - 1 of previous[tj] + GAP_PENALTY * tj
    for (let ti = 0; ti < haystack.length; ti += 1) {
      if (qi > 0 && ti >= 2 && previous[ti - 2] > -Infinity) bestEarlier = Math.max(bestEarlier, previous[ti - 2] + GAP_PENALTY * (ti - 2))
      if (haystack[ti] !== wanted[qi]) continue
      const bonus = ti === 0 ? PREFIX_BONUS : boundaryAt(original, ti) ? BOUNDARY_BONUS : 0
      if (qi === 0) {
        current[ti] = 1 + bonus - LEADING_GAP_PENALTY * ti
        continue
      }
      let from = -Infinity
      if (previous[ti - 1] > -Infinity) from = previous[ti - 1] + CONSECUTIVE_BONUS
      if (bestEarlier > -Infinity) from = Math.max(from, bestEarlier - GAP_PENALTY * (ti - 1))
      if (from > -Infinity) current[ti] = from + 1 + bonus
    }
    previous = current
  }

  let best = -Infinity
  for (const value of previous) if (value > best) best = value
  if (best === -Infinity) return 0
  // Shorter texts rank above longer ones with the same alignment; an exact match outranks everything.
  const compact = haystack.filter((char) => !/\s/u.test(char))
  const exact = compact.length === wanted.length && compact.every((char, i) => char === wanted[i])
  return Math.max(best, MIN_SCORE) + (exact ? EXACT_BONUS : 0) + 1 / (1 + haystack.length)
}

/**
 * Score an item by its text and optional keywords (keywords count slightly less than the text itself).
 * @param {string} query
 * @param {string} text
 * @param {string[]} [keywords]
 * @returns {number}
 */
export function scoreItem(query, text, keywords = []) {
  if (fold(query).trim() === "") return EMPTY_QUERY_SCORE
  let best = score(query, text)
  for (const keyword of keywords) best = Math.max(best, score(query, keyword) * 0.9)
  return best
}

/**
 * Rank items for a query: drops the ones that do not match and sorts by score (descending), keeping the original order for
 * equal scores.
 * @template T
 * @param {string} query
 * @param {T[]} items
 * @param {object} [options]
 * @param {(item: T) => string} [options.text] Text to match. Default: `String(item)`.
 * @param {(item: T) => string[]} [options.keywords] Extra strings that also match.
 * @returns {{ item: T, index: number, score: number }[]}
 * @example
 * rank("cal", ["Calendar", "Calculator", "Search"]).map((r) => r.item) // ["Calendar", "Calculator"]
 */
export function rank(query, items, { text = String, keywords = () => [] } = {}) {
  const ranked = []
  items.forEach((item, index) => {
    const value = scoreItem(query, text(item), keywords(item))
    if (value > 0) ranked.push({ item, index, score: value })
  })
  return ranked.sort((a, b) => b.score - a.score || a.index - b.index)
}
