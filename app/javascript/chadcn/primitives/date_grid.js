// Calendar date math on native `Date` and `Intl` only (no date library). Replaces the slice of date-fns that react-day-picker 10
// (the library behind shadcn's Calendar) relies on. Spec: docs/shadcn-port/specs/calendar.md (Behavior > Date math).
//
// Every function is pure and DOM free; no function mutates its arguments. A "date" is a local calendar day: all comparisons are made
// on year/month/day (never on timestamps), so DST transitions cannot move a day. Weekdays are numbered like `Date#getDay`
// (0 = Sunday .. 6 = Saturday). Functions that need the week settings take `{ weekStartsOn, firstWeekContainsDate }`.
//
// Known divergences from date-fns: none for the en-US/es settings the Calendar spec pins; `weekInfo` is best effort where the
// browser has no `Intl.Locale#getWeekInfo` (Firefox: Sunday and one minimal day).

const MS_PER_DAY = 86400000

/**
 * Builds the local midnight of a calendar day. Unlike `new Date(y, m, d)`, years 0-99 are not mapped to 1900-1999. Month and day
 * overflow like the `Date` constructor (month 12 is January of the next year, day 0 the last day of the previous month).
 * @param {number} year
 * @param {number} month Zero based.
 * @param {number} day
 * @returns {Date}
 */
export function makeDate(year, month, day) {
  const date = new Date(2000, 0, 1)
  date.setFullYear(year, month, day)
  date.setHours(0, 0, 0, 0)
  return date
}

const pad = (number, width) => String(Math.abs(number)).padStart(width, "0")

/**
 * Parses `YYYY-MM-DD` as a LOCAL date (never `new Date("YYYY-MM-DD")`, which is UTC). Impossible days (`2026-02-30`) and other
 * shapes return null.
 * @param {unknown} value
 * @returns {Date | null}
 * @example
 * parseISO("2026-03-15") // local midnight of March 15th, 2026
 * parseISO("2026-02-30") // null
 */
export function parseISO(value) {
  const match = typeof value === "string" ? /^(\d{4})-(\d{2})-(\d{2})$/.exec(value.trim()) : null
  if (!match) return null
  const [year, month, day] = [Number(match[1]), Number(match[2]) - 1, Number(match[3])]
  const date = makeDate(year, month, day)
  return date.getFullYear() === year && date.getMonth() === month && date.getDate() === day ? date : null
}

/**
 * @param {Date} date
 * @returns {string} `YYYY-MM-DD` of the local day.
 */
export const toISO = (date) => `${pad(date.getFullYear(), 4)}-${pad(date.getMonth() + 1, 2)}-${pad(date.getDate(), 2)}`

/**
 * @param {Date} date
 * @returns {string} `YYYY-MM` of the local month.
 */
export const toMonthISO = (date) => `${pad(date.getFullYear(), 4)}-${pad(date.getMonth() + 1, 2)}`

/** @param {Date} date @returns {Date} */
export const startOfDay = (date) => makeDate(date.getFullYear(), date.getMonth(), date.getDate())

/** @param {Date} date @returns {Date} The first day of the month. */
export const startOfMonth = (date) => makeDate(date.getFullYear(), date.getMonth(), 1)

/** @param {Date} date @returns {Date} The last day of the month (at midnight). */
export const endOfMonth = (date) => makeDate(date.getFullYear(), date.getMonth() + 1, 0)

/** @param {Date} date @returns {Date} January 1st of the year. */
export const startOfYear = (date) => makeDate(date.getFullYear(), 0, 1)

/** @param {Date} date @returns {Date} December 31st of the year. */
export const endOfYear = (date) => makeDate(date.getFullYear(), 11, 31)

/** @param {number} year @param {number} month Zero based. @returns {number} */
export const daysInMonth = (year, month) => makeDate(year, month + 1, 0).getDate()

/**
 * @param {Date} date
 * @param {number} amount Days, may be negative.
 * @returns {Date}
 */
export const addDays = (date, amount) => makeDate(date.getFullYear(), date.getMonth(), date.getDate() + amount)

/**
 * @param {Date} date
 * @param {number} amount Weeks, may be negative.
 * @returns {Date}
 */
export const addWeeks = (date, amount) => addDays(date, amount * 7)

/**
 * Adds months like date-fns: the day is clamped to the length of the target month (January 31st + 1 month is February 28th, or
 * 29th in a leap year). Native `setMonth` overflows into the next month and must not be used for this.
 * @param {Date} date
 * @param {number} amount Months, may be negative.
 * @returns {Date}
 * @example
 * addMonths(new Date(2024, 0, 31), 1) // February 29th, 2024
 */
export function addMonths(date, amount) {
  const first = makeDate(date.getFullYear(), date.getMonth() + amount, 1)
  return makeDate(first.getFullYear(), first.getMonth(), Math.min(date.getDate(), daysInMonth(first.getFullYear(), first.getMonth())))
}

/** @param {Date} date @param {number} amount Years, may be negative. @returns {Date} February 29th clamps to the 28th. */
export const addYears = (date, amount) => addMonths(date, amount * 12)

const dayNumber = (date) => {
  const utc = new Date(0)
  utc.setUTCFullYear(date.getFullYear(), date.getMonth(), date.getDate())
  return Math.round(utc.getTime() / MS_PER_DAY)
}

/** @param {Date} left @param {Date} right @returns {number} Calendar days from `right` to `left` (negative when left is earlier). */
export const differenceInCalendarDays = (left, right) => dayNumber(left) - dayNumber(right)

/** @param {Date} left @param {Date} right @returns {number} Calendar months from `right` to `left`, ignoring the day. */
export const differenceInCalendarMonths = (left, right) => (left.getFullYear() - right.getFullYear()) * 12 + left.getMonth() - right.getMonth()

/** @param {Date | null | undefined} left @param {Date | null | undefined} right @returns {boolean} */
export const isSameDay = (left, right) => Boolean(left && right) && differenceInCalendarDays(left, right) === 0

/** @param {Date | null | undefined} left @param {Date | null | undefined} right @returns {boolean} */
export const isSameMonth = (left, right) => Boolean(left && right) && differenceInCalendarMonths(left, right) === 0

/** @param {Date} left @param {Date} right @returns {boolean} Whether `left` is a later day than `right`. */
export const isAfter = (left, right) => differenceInCalendarDays(left, right) > 0

/** @param {Date} left @param {Date} right @returns {boolean} Whether `left` is an earlier day than `right`. */
export const isBefore = (left, right) => differenceInCalendarDays(left, right) < 0

/**
 * The closest previous (or same) day whose weekday is `weekStartsOn`.
 * @param {Date} date
 * @param {number} weekStartsOn 0..6, 0 = Sunday.
 * @returns {Date}
 */
export const startOfWeek = (date, weekStartsOn) => addDays(date, -((date.getDay() - weekStartsOn + 7) % 7))

/** @param {Date} date @param {number} weekStartsOn 0..6. @returns {Date} `startOfWeek` plus six days. */
export const endOfWeek = (date, weekStartsOn) => addDays(startOfWeek(date, weekStartsOn), 6)

// date-fns getWeekYear: the year Y whose first week (the week holding January `firstWeekContainsDate`) is the latest one that starts
// on or before the date.
function weekYear(date, { weekStartsOn, firstWeekContainsDate }) {
  const year = date.getFullYear()
  const firstWeekOfNextYear = startOfWeek(makeDate(year + 1, 0, firstWeekContainsDate), weekStartsOn)
  if (!isBefore(date, firstWeekOfNextYear)) return year + 1
  const firstWeekOfThisYear = startOfWeek(makeDate(year, 0, firstWeekContainsDate), weekStartsOn)
  return isBefore(date, firstWeekOfThisYear) ? year - 1 : year
}

/**
 * The locale week number (date-fns `getWeek`): the week holding January `firstWeekContainsDate` is week 1.
 * @param {Date} date
 * @param {{ weekStartsOn: number, firstWeekContainsDate: number }} settings
 * @returns {number}
 * @example
 * getWeek(new Date(2026, 11, 27), { weekStartsOn: 0, firstWeekContainsDate: 1 }) // 1 (Dec 27 2026 starts the week of Jan 1 2027)
 */
export function getWeek(date, settings) {
  const firstWeek = startOfWeek(makeDate(weekYear(date, settings), 0, settings.firstWeekContainsDate), settings.weekStartsOn)
  return Math.round(differenceInCalendarDays(startOfWeek(date, settings.weekStartsOn), firstWeek) / 7) + 1
}

/**
 * Week settings of a BCP 47 tag from `Intl.Locale` (`getWeekInfo()`, or the older `weekInfo` property). `firstDay` is converted from
 * Intl's 1..7 (Monday..Sunday) to 0..6 (Sunday..Saturday). Where the browser reports nothing (Firefox) or the tag is invalid the
 * answer is Sunday and `minimalDays: null` (the caller then uses 1, like date-fns en-US).
 * @param {string | null | undefined} tag
 * @returns {{ firstDay: number, minimalDays: number | null }}
 * @example
 * weekInfo("de") // { firstDay: 1, minimalDays: 4 } in a browser that reports week info
 */
export function weekInfo(tag) {
  try {
    const locale = new Intl.Locale(tag || "en-US")
    const info = typeof locale.getWeekInfo === "function" ? locale.getWeekInfo() : locale.weekInfo
    if (!info || !Number.isInteger(info.firstDay)) return { firstDay: 0, minimalDays: null }
    return { firstDay: info.firstDay % 7, minimalDays: Number.isInteger(info.minimalDays) ? info.minimalDays : null }
  } catch {
    return { firstDay: 0, minimalDays: null }
  }
}

/**
 * English ordinal suffix of a day number from `Intl.PluralRules("en-US", { type: "ordinal" })`.
 * @param {number} number
 * @returns {string} `st`, `nd`, `rd` or `th`.
 * @example
 * ordinalSuffix(22) // "nd"
 */
export function ordinalSuffix(number) {
  return { one: "st", two: "nd", few: "rd" }[new Intl.PluralRules("en-US", { type: "ordinal" }).select(number)] || "th"
}

/**
 * Navigation bounds (react-day-picker `getNavMonths`). A year dropdown without explicit bounds gets January of (today - 100 years)
 * and December of today's year.
 * @param {{ startMonth?: Date | null, endMonth?: Date | null, today: Date, yearDropdown?: boolean }} options
 * @returns {{ navStart: Date | null, navEnd: Date | null }} `navStart` is the first day of the first month, `navEnd` the last day of the last.
 */
export function navMonths({ startMonth, endMonth, today, yearDropdown = false }) {
  let start = startMonth ? startOfMonth(startMonth) : null
  let end = endMonth ? endOfMonth(endMonth) : null
  if (!start && yearDropdown) start = startOfYear(addYears(today, -100))
  if (!end && yearDropdown) end = endOfYear(today)
  return { navStart: start, navEnd: end }
}

/**
 * First displayed month (react-day-picker `getInitialMonth`): `month`, else `defaultMonth`, else today; pulled back so the last
 * displayed month is `navEnd`, pushed forward to `navStart`; always the first of a month.
 * @param {{ month?: Date | null, defaultMonth?: Date | null, today: Date, numberOfMonths: number, navStart: Date | null, navEnd: Date | null }} options
 * @returns {Date}
 */
export function initialMonth({ month, defaultMonth, today, numberOfMonths, navStart, navEnd }) {
  let first = month || defaultMonth || today
  if (navEnd && differenceInCalendarMonths(navEnd, first) < numberOfMonths - 1) first = addMonths(navEnd, -(numberOfMonths - 1))
  if (navStart && differenceInCalendarMonths(first, navStart) < 0) first = navStart
  return startOfMonth(first)
}

/**
 * Month shown by the "previous" button, or null when there is none (navigation disabled or `navStart` reached).
 * @param {{ first: Date, navStart: Date | null, numberOfMonths: number, pagedNavigation?: boolean, disableNavigation?: boolean }} options
 * @returns {Date | null}
 */
export function previousMonth({ first, navStart, numberOfMonths, pagedNavigation = false, disableNavigation = false }) {
  if (disableNavigation) return null
  const month = startOfMonth(first)
  if (navStart && differenceInCalendarMonths(month, navStart) <= 0) return null
  return addMonths(month, -(pagedNavigation ? numberOfMonths : 1))
}

/**
 * Month shown by the "next" button, or null when there is none (navigation disabled or fewer than `numberOfMonths` months left).
 * @param {{ first: Date, navEnd: Date | null, numberOfMonths: number, pagedNavigation?: boolean, disableNavigation?: boolean }} options
 * @returns {Date | null}
 */
export function nextMonth({ first, navEnd, numberOfMonths, pagedNavigation = false, disableNavigation = false }) {
  if (disableNavigation) return null
  if (navEnd && differenceInCalendarMonths(navEnd, first) < numberOfMonths) return null
  return addMonths(startOfMonth(first), pagedNavigation ? numberOfMonths : 1)
}

/**
 * The months to display and their weeks (react-day-picker `getDisplayMonths` + `getDates` + `getMonths`).
 *
 * Each month holds the days between the start of its first week and the end of its last week; weeks are grouped by the locale week
 * number (not by 7-day chunks); with `fixedWeeks` every month is padded to 42 days. A day is outside when it is not in its display
 * month; the same date shown in two months is two different days (`id` differs).
 * @param {{ first: Date, numberOfMonths: number, navEnd: Date | null, endMonth?: Date | null, fixedWeeks?: boolean,
 *           weekStartsOn: number, firstWeekContainsDate: number }} options `endMonth` clamps the grid to the end of its last week.
 * @returns {Array<{ date: Date, id: string, weeks: Array<{ weekNumber: number, days: Array<{ date: Date, iso: string, month: Date, monthId: string, outside: boolean, id: string }> }> }>}
 */
export function buildMonths({ first, numberOfMonths, navEnd, endMonth = null, fixedWeeks = false, weekStartsOn, firstWeekContainsDate }) {
  const settings = { weekStartsOn, firstWeekContainsDate }
  const displayMonths = []
  for (let index = 0; index < numberOfMonths; index += 1) {
    const month = addMonths(first, index)
    if (navEnd && isAfter(month, navEnd)) break
    displayMonths.push(month)
  }
  const gridStart = startOfWeek(displayMonths[0], weekStartsOn)
  const lastWeekEnd = endOfWeek(endOfMonth(displayMonths.at(-1)), weekStartsOn)
  const constraint = endMonth ? endOfWeek(endOfMonth(endMonth), weekStartsOn) : null
  const gridEnd = constraint && isAfter(lastWeekEnd, constraint) ? constraint : lastWeekEnd
  const dates = Array.from({ length: differenceInCalendarDays(gridEnd, gridStart) + 1 }, (_, offset) => addDays(gridStart, offset))
  const padded = 42 * displayMonths.length
  while (fixedWeeks && dates.length < padded) dates.push(addDays(dates.at(-1), 1))

  return displayMonths.map((month) => {
    const firstDate = startOfWeek(month, weekStartsOn)
    const lastDate = endOfWeek(endOfMonth(month), weekStartsOn)
    const monthDates = dates.filter((date) => !isBefore(date, firstDate) && !isAfter(date, lastDate))
    if (fixedWeeks && monthDates.length < 42) {
      const limit = addDays(lastDate, 42 - monthDates.length)
      monthDates.push(...dates.filter((date) => isAfter(date, lastDate) && !isAfter(date, limit)))
    }
    const monthId = toMonthISO(month)
    const weeks = []
    for (const date of monthDates) {
      const weekNumber = getWeek(date, settings)
      const day = { date, iso: toISO(date), month, monthId, outside: !isSameMonth(date, month), id: `${toISO(date)}_${monthId}` }
      const week = weeks.find((candidate) => candidate.weekNumber === weekNumber)
      if (week) week.days.push(day)
      else weeks.push({ weekNumber, days: [day] })
    }
    return { date: month, id: monthId, weeks }
  })
}

/**
 * The seven days of the week of `reference`, starting on `weekStartsOn` (react-day-picker `getWeekdays`).
 * @param {Date} reference
 * @param {number} weekStartsOn
 * @returns {Date[]}
 */
export function weekdays(reference, weekStartsOn) {
  const start = startOfWeek(reference, weekStartsOn)
  return Array.from({ length: 7 }, (_, offset) => addDays(start, offset))
}

/**
 * Whether `date` is inside a range (react-day-picker `rangeIncludesDate`). An inverted range is swapped; a range with only one side
 * matches that day (unless `excludeEnds`).
 * @param {{ from?: Date | null, to?: Date | null }} range
 * @param {Date} date
 * @param {boolean} [excludeEnds=false] Match only days strictly between the ends.
 * @returns {boolean}
 */
export function rangeIncludes(range, date, excludeEnds = false) {
  let { from, to } = range
  if (from && to) {
    if (differenceInCalendarDays(to, from) < 0) [from, to] = [to, from]
    const margin = excludeEnds ? 1 : 0
    return differenceInCalendarDays(date, from) >= margin && differenceInCalendarDays(to, date) >= margin
  }
  if (!excludeEnds && to) return isSameDay(to, date)
  if (!excludeEnds && from) return isSameDay(from, date)
  return false
}

const isDate = (value) => value instanceof Date
const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value) && !isDate(value)

/**
 * Turns the JSON matcher form the server emits into matchers: every string is an ISO date (parsed as a local date), objects keep the
 * keys `from`, `to`, `before`, `after` and `dayOfWeek` (a key that is present with a null value stays present, because react-day-picker
 * decides the matcher type with `in`), booleans pass through.
 * @param {unknown} json
 * @returns {unknown} A matcher accepted by {@link dateMatches}; unparsable dates become invalid matchers that never match.
 */
export function reviveMatcher(json) {
  if (typeof json === "string") return parseISO(json) || false
  if (Array.isArray(json)) return json.map(reviveMatcher)
  if (!isObject(json)) return json
  return Object.fromEntries(Object.entries(json).map(([key, value]) => [key, key === "dayOfWeek" ? value : reviveMatcher(value)]))
}

/**
 * Whether a date satisfies a matcher (react-day-picker `dateMatchModifiers`, same precedence): a boolean; a date; an array of dates;
 * a range (`from` key); `{ dayOfWeek }`; an interval (`before` and `after`: closed, strictly between, when `before` is later than
 * `after`, otherwise open: strictly before `before` or strictly after `after`); `{ after }`; `{ before }`; or an array of any of these.
 * @param {Date} date
 * @param {unknown} matchers
 * @returns {boolean}
 */
export function dateMatches(date, matchers) {
  return (Array.isArray(matchers) ? matchers : [matchers]).some((matcher) => {
    if (typeof matcher === "boolean") return matcher
    if (isDate(matcher)) return isSameDay(date, matcher)
    if (Array.isArray(matcher)) return matcher.every(isDate) && matcher.some((candidate) => isSameDay(date, candidate))
    if (!isObject(matcher)) return false
    if ("from" in matcher) return rangeIncludes(matcher, date, false)
    if ("dayOfWeek" in matcher) return [].concat(matcher.dayOfWeek).includes(date.getDay())
    if ("before" in matcher && "after" in matcher) {
      if (!isDate(matcher.before) || !isDate(matcher.after)) return false
      const before = differenceInCalendarDays(matcher.before, date) > 0
      const after = differenceInCalendarDays(matcher.after, date) < 0
      return isAfter(matcher.before, matcher.after) ? after && before : before || after
    }
    if ("after" in matcher) return isDate(matcher.after) && differenceInCalendarDays(date, matcher.after) > 0
    if ("before" in matcher) return isDate(matcher.before) && differenceInCalendarDays(matcher.before, date) > 0
    return false
  })
}

const rangesOverlap = (left, right) =>
  rangeIncludes(left, right.from) || rangeIncludes(left, right.to) || rangeIncludes(right, left.from) || rangeIncludes(right, left.to)

/**
 * Whether a complete range contains a day matched by the matchers (react-day-picker `rangeContainsModifiers`, used by
 * `excludeDisabled`).
 * @param {{ from: Date, to: Date }} range
 * @param {unknown} matchers
 * @returns {boolean}
 */
export function rangeContainsMatch(range, matchers) {
  return (Array.isArray(matchers) ? matchers : [matchers]).some((matcher) => {
    if (typeof matcher === "boolean") return matcher
    if (isDate(matcher)) return rangeIncludes(range, matcher)
    if (Array.isArray(matcher)) return matcher.every(isDate) && matcher.some((candidate) => rangeIncludes(range, candidate))
    if (!isObject(matcher)) return false
    if ("from" in matcher) return Boolean(matcher.from && matcher.to) && rangesOverlap(range, { from: matcher.from, to: matcher.to })
    if ("dayOfWeek" in matcher) {
      const days = [].concat(matcher.dayOfWeek)
      const total = Math.min(differenceInCalendarDays(range.to, range.from), 6)
      return Array.from({ length: total + 1 }, (_, offset) => addDays(range.from, offset)).some((date) => days.includes(date.getDay()))
    }
    if ("before" in matcher && "after" in matcher && isDate(matcher.before) && isDate(matcher.after) && isAfter(matcher.before, matcher.after)) {
      return rangesOverlap(range, { from: addDays(matcher.after, 1), to: addDays(matcher.before, -1) })
    }
    if ("before" in matcher || "after" in matcher) return dateMatches(range.from, matcher) || dateMatches(range.to, matcher)
    return false
  })
}

/**
 * The range after clicking `date` (react-day-picker `addToRange`). Returns null for "no selection".
 * @param {Date} date The clicked day.
 * @param {{ from?: Date | null, to?: Date | null } | null} range The current selection.
 * @param {{ min?: number, max?: number, required?: boolean }} [limits] `min`/`max` are nights.
 * @returns {{ from: Date, to: Date | undefined } | null}
 */
export function addToRange(date, range, { min = 0, max = 0, required = false } = {}) {
  const { from, to } = range || {}
  let next = null
  if (!from && !to) {
    next = { from: date, to: min > 0 ? undefined : date }
  } else if (!from) {
    next = null // a range with only `to` is not a range for react-day-picker: nothing is added
  } else if (!to) {
    if (isSameDay(from, date)) next = min === 0 ? { from, to: date } : required ? { from, to: undefined } : null
    else if (isBefore(date, from)) next = { from: date, to: from }
    else next = { from, to: date }
  } else if (isSameDay(from, date) && isSameDay(to, date)) {
    next = required ? { from, to } : null
  } else if (isSameDay(from, date)) {
    next = { from, to: min > 0 ? undefined : date }
  } else if (isSameDay(to, date)) {
    next = { from: date, to: min > 0 ? undefined : date }
  } else if (isBefore(date, from)) {
    next = { from: date, to }
  } else {
    next = { from, to: date }
  }
  if (next?.from && next?.to) {
    const nights = differenceInCalendarDays(next.to, next.from)
    if ((max > 0 && nights > max) || (min > 1 && nights < min)) next = { from: date, to: undefined }
  }
  return next
}
