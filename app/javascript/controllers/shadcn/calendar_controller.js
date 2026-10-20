import { Controller } from "@hotwired/stimulus"
import { direction } from "shadcn/primitives/direction"
import * as grid from "shadcn/primitives/date_grid"

// shadcn Calendar (react-day-picker 10) on `Date` and `Intl` only. Spec: docs/shadcn-port/specs/calendar.md (Structure, Behavior).
//
// The server renders the root, the months container with its navigation, the footer, inline hidden inputs and one inert <template>
// of part prototypes that carry every class string. connect() clears the months, then builds them from clones of the prototypes and
// keeps their nodes like React's reconciliation does (month by display index, week by week number, day by date and display month),
// so focus stays on the clicked or moved-to button while attributes change.
//
// Known divergences: locales other than nil/en/en-US/es get Intl approximations and English labels (deviations/calendar.json).
export default class extends Controller {
  static targets = ["months", "nav", "previous", "next", "parts"]
  static values = { config: Object, month: String }

  // Intl.DateTimeFormat instances are slow to create and a render formats up to a hundred dates.
  static formats = new Map()

  // The five formatters a caller can replace with Intl.DateTimeFormat options (config.formatters keys).
  static formatters = { caption: "formatCaption", day: "formatDay", monthDropdown: "formatMonthDropdown", weekday: "formatWeekdayName", yearDropdown: "formatYearDropdown" }

  connect() {
    this.ready = false
    this.abort = new AbortController()
    this.clearMonths() // a Turbo snapshot may hold an old grid; the server-rendered nav stays
    this.setup()
    const options = { signal: this.abort.signal }
    this.element.addEventListener("click", (event) => this.onClick(event), options)
    this.element.addEventListener("focusin", (event) => this.onFocusIn(event), options)
    this.element.addEventListener("focusout", (event) => this.onFocusOut(event), options)
    this.element.addEventListener("keydown", (event) => this.onKeyDown(event), options)
    this.element.addEventListener("change", (event) => this.onChange(event), options)
    this.ready = true
    this.render()
    this.syncFields(false)
  }

  disconnect() {
    this.ready = false
    this.abort.abort()
  }

  configValueChanged() {
    if (!this.ready) return
    this.clearMonths()
    this.setup()
    this.render()
    this.syncFields(false)
  }

  monthValueChanged() {
    if (this.ready) this.render()
  }

  previous() {
    if (this.model?.previousMonth) this.goToMonth(this.model.previousMonth)
  }

  next() {
    if (this.model?.nextMonth) this.goToMonth(this.model.nextMonth)
  }

  // ---------------------------------------------------------------------------------------------------------------- setup

  setup() {
    const config = this.configValue
    this.cfg = config
    this.resolvedInputs = undefined
    this.today = config.today ? grid.parseISO(config.today) : grid.startOfDay(new Date())
    this.dir = direction(this.element, config.dir)
    this.mode = config.mode || null
    this.localeTag = config.locale || "en-US"
    const week = grid.weekInfo(this.localeTag)
    this.weekStartsOn = config.weekStartsOn ?? week.firstDay
    this.firstWeekContainsDate = config.firstWeekContainsDate ?? week.minimalDays ?? 1
    this.numberOfMonths = config.numberOfMonths || 1
    this.matchers = {
      disabled: config.disabled === undefined ? undefined : grid.reviveMatcher(config.disabled),
      hidden: config.hidden === undefined ? undefined : grid.reviveMatcher(config.hidden),
      custom: Object.entries(config.modifiers || {}).map(([name, value]) => [name, grid.reviveMatcher(value)])
    }
    this.dayClasses = config.dayClasses || {}
    this.modifierClasses = config.modifiersClassNames || {}
    this.labels = config.labels || {}
    this.dayViews = new WeakMap()
    this.selectViews = new WeakMap()
    this.monthViews = []
    this.lastFocused = null
    this.flagged = new WeakSet()
    this.selected = this.initialSelection()
    this.firstMonth = this.initialFirstMonth()
    this.focused = config.autoFocus ? "auto" : null
    this.label = this.resolveLabel()
    this.storePlaceholder()
  }

  // A selection written in the external input wins over `selected:` (spec calendar.md, DatePicker rules). Without `input:` the inline
  // `name:` inputs are the source on a reconnect (a Turbo snapshot keeps what the user chose); a missing input never overrides `selected:`.
  initialSelection() {
    const fromInput = this.cfg.input ? this.readInput() : this.readInline()
    this.selectionFromInput = Boolean(this.cfg.input) && fromInput !== undefined && this.hasSelection(fromInput)
    const selected = fromInput === undefined ? this.reviveSelection(this.cfg.selected) : fromInput
    return this.mode === "multiple" ? selected || [] : selected || null
  }

  reviveSelection(value) {
    if (value === undefined || value === null) return null
    if (this.mode === "single") return grid.parseISO(value)
    if (this.mode === "multiple") return value.map((iso) => grid.parseISO(iso)).filter(Boolean)
    if (this.mode === "range") return rangeOrNull(grid.parseISO(value.from), grid.parseISO(value.to))
    return null
  }

  hasSelection(selected) {
    if (!selected) return false
    if (Array.isArray(selected)) return selected.length > 0
    return selected instanceof Date || Boolean(selected.from)
  }

  initialFirstMonth() {
    if (this.controlled) return null // derived from the month value on every render
    const { navStart, navEnd } = this.navigationBounds()
    const hint = this.selectionFromInput ? this.firstSelectedDate() : null
    return grid.initialMonth({
      defaultMonth: grid.parseISO(this.cfg.defaultMonth) || hint, today: this.today, numberOfMonths: this.numberOfMonths, navStart, navEnd
    })
  }

  firstSelectedDate() {
    if (this.selected instanceof Date) return this.selected
    return Array.isArray(this.selected) ? this.selected[0] : this.selected?.from
  }

  navigationBounds() {
    return grid.navMonths({
      startMonth: grid.parseISO(this.cfg.startMonth), endMonth: grid.parseISO(this.cfg.endMonth), today: this.today,
      yearDropdown: ["dropdown", "dropdown-years"].includes(this.cfg.captionLayout)
    })
  }

  get controlled() {
    return this.hasMonthValue && Boolean(grid.parseISO(this.monthValue))
  }

  clearMonths() {
    this.monthViews = []
    for (const child of [...this.monthsTarget.children]) if (!this.hasNavTarget || child !== this.navTarget) child.remove()
  }

  // --------------------------------------------------------------------------------------------------------------- model

  // react-day-picker useCalendar + createGetModifiers: the months to show and the built-in modifiers of every day.
  computeModel() {
    const { navStart, navEnd } = this.navigationBounds()
    const config = this.cfg
    const numberOfMonths = this.numberOfMonths
    // The month value may be removed after connect: the uncontrolled month then starts from the usual initial month.
    const first = this.controlled
      ? grid.initialMonth({ month: grid.parseISO(this.monthValue), today: this.today, numberOfMonths, navStart, navEnd })
      : (this.firstMonth ||= this.initialFirstMonth())
    const months = grid.buildMonths({
      first, numberOfMonths, navEnd, endMonth: grid.parseISO(config.endMonth), fixedWeeks: config.fixedWeeks,
      weekStartsOn: this.weekStartsOn, firstWeekContainsDate: this.firstWeekContainsDate
    })
    const days = months.flatMap((month) => month.weeks.flatMap((week) => week.days))
    const stepping = { numberOfMonths, pagedNavigation: config.pagedNavigation, disableNavigation: config.disableNavigation }
    const model = {
      months, days, navStart, navEnd, first, flags: new Map(), customNames: new Set(),
      previousMonth: grid.previousMonth({ first, navStart, ...stepping }),
      nextMonth: grid.nextMonth({ first, navEnd, ...stepping })
    }
    const startBound = navStart && grid.startOfMonth(navStart)
    const { disabled, hidden, custom } = this.matchers
    for (const day of days) {
      const flags = {
        focused: false,
        disabled: Boolean(disabled !== undefined && grid.dateMatches(day.date, disabled)),
        hidden: Boolean(hidden !== undefined && grid.dateMatches(day.date, hidden)) ||
          Boolean(startBound && grid.isBefore(day.date, startBound)) || Boolean(navEnd && grid.isAfter(day.date, navEnd)) ||
          (!config.showOutsideDays && day.outside),
        outside: day.outside,
        today: grid.isSameDay(day.date, this.today)
      }
      const customFlags = {}
      for (const [name, matcher] of custom) {
        customFlags[name] = matcher ? grid.dateMatches(day.date, matcher) : false
        if (customFlags[name]) model.customNames.add(name)
      }
      model.flags.set(day, { ...flags, custom: customFlags })
    }
    return model
  }

  // The modifiers of a day for the current render, in rdp's key order (CGM:70-90, DP:312-326).
  modifiersOf(day, model) {
    const { custom, ...flags } = model.flags.get(day)
    const modifiers = { ...flags }
    for (const name of model.customNames) modifiers[name] = custom[name] // custom modifiers override the built-in ones
    modifiers.focused = !modifiers.hidden && this.isFocused(day)
    modifiers.selected = this.isSelected(day.date) || modifiers.selected
    if (this.mode === "range" && this.selected) {
      const { from, to } = this.selected
      modifiers.range_start = Boolean(from && to && grid.isSameDay(day.date, from))
      modifiers.range_end = Boolean(from && to && grid.isSameDay(day.date, to))
      modifiers.range_middle = grid.rangeIncludes(this.selected, day.date, true)
    }
    return modifiers
  }

  isSelected(date) {
    if (this.mode === "single") return Boolean(this.selected) && grid.isSameDay(this.selected, date)
    if (this.mode === "multiple") return this.selected.some((selected) => grid.isSameDay(selected, date))
    if (this.mode === "range") return Boolean(this.selected) && grid.rangeIncludes(this.selected, date, false)
    return false
  }

  isFocused(day) {
    return Boolean(this.focused) && this.focused !== "auto" && sameDay(this.focused, day)
  }

  // react-day-picker calculateFocusTarget: the one day button that is in the tab order.
  focusTarget(model) {
    let target = null
    let priority = -1
    const focusable = (flags) => !flags.disabled && !flags.hidden && !flags.outside
    for (const day of model.days) {
      const { custom, ...flags } = model.flags.get(day)
      if (!focusable(flags)) continue
      if (custom.focused && priority < 3) [target, priority] = [day, 3]
      else if (this.lastFocused && sameDay(this.lastFocused, day) && priority < 2) [target, priority] = [day, 2]
      else if (this.isSelected(day.date) && priority < 1) [target, priority] = [day, 1]
      else if (flags.today && priority < 0) [target, priority] = [day, 0]
    }
    return target || model.days.find((day) => focusable(model.flags.get(day))) || null
  }

  // ------------------------------------------------------------------------------------------------------------- render

  // Re-entrant: the focus() calls at the end of a render fire events that change state, which renders once more.
  render() {
    if (!this.ready) return
    if (this.rendering) {
      this.dirty = true
      return
    }
    this.rendering = true
    try {
      do {
        this.dirty = false
        this.renderOnce()
      } while (this.dirty)
    } finally {
      this.rendering = false
    }
  }

  renderOnce() {
    const model = this.computeModel()
    this.model = model
    const target = this.focusTarget(model)
    // UF:22-30: auto focus starts on the target; a focused day that is no longer displayed falls back to it.
    if (this.focused === "auto" || (this.focused && !model.days.some((day) => sameDay(this.focused, day)))) this.focused = target ? toRef(target) : null
    const toFocus = []
    this.patching = true
    try {
      this.syncNav(model)
      this.syncMonths(model, target, toFocus)
    } finally {
      this.patching = false
    }
    for (const button of toFocus) button.focus()
  }

  syncNav(model) {
    if (!this.hasNavTarget) return
    for (const [button, month] of [[this.previousTarget, model.previousMonth], [this.nextTarget, model.nextMonth]]) {
      setAttr(button, "tabindex", month ? undefined : "-1")
      setAttr(button, "aria-disabled", month ? undefined : "true")
      setAttr(button.firstElementChild, "disabled", month ? undefined : "")
    }
  }

  syncMonths(model, target, toFocus) {
    model.months.forEach((month, index) => {
      const view = this.monthViews[index] || this.createMonthView(index)
      if (view.root.parentNode !== this.monthsTarget) this.monthsTarget.append(view.root)
      this.syncMonth(view, month, model, target, toFocus)
    })
    for (const view of this.monthViews.splice(model.months.length)) view.root.remove()
  }

  // ----------------------------------------------------------------------------------------------------- month (DP:264)

  createMonthView(index) {
    const view = { root: this.part("month"), index, rows: new Map() }
    const caption = this.part("caption")
    view.root.append(caption)
    if (this.cfg.captionLayout === "label") {
      view.label = this.part("caption_label")
      caption.append(view.label)
    } else {
      this.createDropdowns(view, caption)
    }
    view.table = this.part("month_grid")
    if (!this.cfg.hideWeekdays) view.table.append(this.createWeekdays())
    view.tbody = this.part("weeks")
    view.table.append(view.tbody)
    view.root.append(view.table)
    this.monthViews[index] = view
    return view
  }

  // DP:271-293: a month control and a year control (a native select, or a bare span when the layout has none), then a live region.
  createDropdowns(view, caption) {
    const layout = this.cfg.captionLayout
    const wrapper = this.part("dropdowns")
    view.month = ["dropdown", "dropdown-months"].includes(layout) ? this.createDropdown(view, "months") : { root: document.createElement("span") }
    view.year = ["dropdown", "dropdown-years"].includes(layout) ? this.createDropdown(view, "years") : { root: document.createElement("span") }
    wrapper.append(...(this.cfg.yearFirst ? [view.year.root, view.month.root] : [view.month.root, view.year.root]))
    view.status = this.part("status")
    wrapper.append(view.status)
    caption.append(wrapper)
  }

  createDropdown(view, kind) {
    const root = this.part(`${kind}_dropdown`)
    const select = root.querySelector("select")
    const label = root.querySelector("span[aria-hidden]")
    const text = document.createTextNode("")
    label.prepend(text)
    this.selectViews.set(select, { view, kind })
    return { root, select, text }
  }

  createWeekdays() {
    const head = this.part("weekdays")
    const row = head.querySelector("tr")
    if (this.cfg.showWeekNumber) row.append(this.part("week_number_header"))
    for (const date of grid.weekdays(this.today, this.weekStartsOn)) {
      const weekday = this.part("weekday")
      weekday.setAttribute("aria-label", this.weekdayLongText(date))
      weekday.textContent = this.format("weekday", date)
      row.append(weekday)
    }
    return head
  }

  syncMonth(view, month, model, target, toFocus) {
    const caption = this.format("caption", month.date)
    if (view.label) {
      setText(view.label, caption)
    } else {
      this.syncDropdowns(view, month.date, model)
      setText(view.status, caption)
    }
    setAttr(view.table, "aria-label", this.captionText(month.date))
    this.syncWeeks(view, month, model, target, toFocus)
  }

  syncDropdowns(view, date, model) {
    if (view.month.select) {
      const options = Array.from({ length: 12 }, (_, value) => {
        const first = grid.makeDate(date.getFullYear(), value, 1)
        const disabled = Boolean((model.navStart && grid.isBefore(first, grid.startOfMonth(model.navStart))) ||
          (model.navEnd && grid.isAfter(first, grid.startOfMonth(model.navEnd))))
        return { value, label: this.format("monthDropdown", first), disabled }
      })
      this.syncDropdown(view.month, options, date.getMonth())
    } else {
      setText(view.month.root, this.format("monthDropdown", date))
    }
    if (view.year.select) {
      const years = model.navStart && model.navEnd ? model.navEnd.getFullYear() - model.navStart.getFullYear() + 1 : 0
      const options = Array.from({ length: years }, (_, offset) => {
        const value = model.navStart.getFullYear() + offset
        return { value, label: this.format("yearDropdown", grid.makeDate(value, 0, 1)), disabled: false }
      })
      this.syncDropdown(view.year, options, date.getFullYear())
    } else {
      setText(view.year.root, this.format("yearDropdown", date))
    }
  }

  // The select keeps its node (and focus): options are patched in place, the value is a DOM property (React never writes `selected`).
  syncDropdown(control, options, value) {
    const signature = options.map((option) => `${option.value}|${option.label}`).join(";")
    if (control.signature !== signature) {
      control.select.replaceChildren(...options.map((option) => Object.assign(document.createElement("option"), { value: String(option.value), textContent: option.label })))
      control.signature = signature
    }
    options.forEach((option, index) => { control.select.options[index].disabled = option.disabled })
    control.select.value = String(value)
    setAttr(control.root, "data-disabled", String(Boolean(this.cfg.disableNavigation)))
    control.text.data = options.find((option) => option.value === value)?.label ?? ""
  }

  // --------------------------------------------------------------------------------------------- weeks and days (DP:304)

  syncWeeks(view, month, model, target, toFocus) {
    const seen = new Set()
    month.weeks.forEach((week, position) => {
      let row = view.rows.get(week.weekNumber)
      if (!row) {
        row = { tr: this.part("week"), cells: new Map() }
        if (this.cfg.showWeekNumber) {
          row.number = this.part("week_number")
          row.tr.append(row.number)
        }
        view.rows.set(week.weekNumber, row)
      }
      seen.add(week.weekNumber)
      place(view.tbody, row.tr, position)
      if (row.number) {
        setAttr(row.number, "aria-label", `${this.labels.weekNumber} ${week.weekNumber}`)
        setText(row.number.firstElementChild, week.weekNumber < 10 ? `0${week.weekNumber}` : String(week.weekNumber))
      }
      this.syncDays(row, week, model, target, toFocus)
    })
    for (const [number, row] of view.rows) {
      if (seen.has(number)) continue
      row.tr.remove()
      view.rows.delete(number)
    }
  }

  syncDays(row, week, model, target, toFocus) {
    const seen = new Set()
    const offset = row.number ? 1 : 0
    week.days.forEach((day, position) => {
      let cell = row.cells.get(day.id)
      if (!cell) {
        cell = { td: this.part("day") }
        row.cells.set(day.id, cell)
      }
      seen.add(day.id)
      place(row.tr, cell.td, position + offset)
      this.syncDay(cell, day, this.modifiersOf(day, model), target, toFocus)
    })
    for (const [id, cell] of row.cells) {
      if (seen.has(id)) continue
      cell.td.remove()
      row.cells.delete(id)
    }
  }

  syncDay(cell, day, modifiers, target, toFocus) {
    const { td } = cell
    const interactive = Boolean(this.mode)
    const className = this.dayClassName(modifiers)
    if (td.className !== className) td.className = className
    setAttr(td, "aria-selected", modifiers.selected ? "true" : undefined)
    setAttr(td, "aria-label", !interactive && !modifiers.hidden ? this.dayLabel(day.date, modifiers, false) : undefined)
    setAttr(td, "data-day", day.iso)
    setAttr(td, "data-month", day.outside ? grid.toMonthISO(day.date) : undefined)
    setAttr(td, "data-selected", modifiers.selected ? "true" : undefined)
    setAttr(td, "data-disabled", modifiers.disabled ? "true" : undefined)
    setAttr(td, "data-hidden", modifiers.hidden ? "true" : undefined)
    setAttr(td, "data-outside", day.outside ? "true" : undefined)
    setAttr(td, "data-focused", modifiers.focused ? "true" : undefined)
    setAttr(td, "data-today", modifiers.today ? "true" : undefined)
    if (modifiers.hidden || !interactive) this.dropButton(cell)
    if (modifiers.hidden) return setContent(td, "")
    if (!interactive) return setContent(td, this.format("day", day.date))
    this.syncButton(cell, day, modifiers, target, toFocus)
  }

  // Class string of a day cell: the day class, then one string per true modifier in rdp's order (not tailwind-merged, GCN:14-30).
  dayClassName(modifiers) {
    const classes = [this.dayClasses.day]
    for (const [name, active] of Object.entries(modifiers)) {
      if (active !== true) continue
      const classNames = this.modifierClasses[name] || this.dayClasses[name]
      if (classNames) classes.push(classNames)
    }
    return classes.join(" ")
  }

  dropButton(cell) {
    if (!cell.button) return
    this.dayViews.delete(cell.button)
    cell.button = null
    cell.td.replaceChildren()
  }

  syncButton(cell, day, modifiers, target, toFocus) {
    if (!cell.button) {
      cell.button = this.part("day_button")
      this.dayViews.set(cell.button, cell)
      cell.td.replaceChildren(cell.button)
    }
    const { button } = cell
    cell.day = day
    cell.modifiers = modifiers
    const range = this.mode === "range" && this.selected
    setAttr(button, "data-day", day.date.toLocaleDateString())
    setAttr(button, "data-selected-single", modifiers.selected ? String(!modifiers.range_start && !modifiers.range_end && !modifiers.range_middle) : undefined)
    setAttr(button, "data-range-start", range ? String(modifiers.range_start) : undefined)
    setAttr(button, "data-range-end", range ? String(modifiers.range_end) : undefined)
    setAttr(button, "data-range-middle", range ? String(modifiers.range_middle) : undefined)
    setAttr(button, "disabled", !modifiers.focused && modifiers.disabled ? "" : undefined)
    setAttr(button, "aria-disabled", modifiers.focused && modifiers.disabled ? "true" : undefined)
    setAttr(button, "tabindex", target && sameDay(target, day) ? "0" : "-1")
    setAttr(button, "aria-label", this.dayLabel(day.date, modifiers, true))
    setText(button, this.format("day", day.date))
    // The tsx effect: a button whose `focused` modifier turned true takes DOM focus.
    if (modifiers.focused && !this.flagged.has(button)) toFocus.push(button)
    if (modifiers.focused) this.flagged.add(button)
    else this.flagged.delete(button)
  }

  part(name) {
    const node = this.partsTarget.content.querySelector(`[data-shadcn--calendar-part="${name}"]`).cloneNode(true)
    node.removeAttribute("data-shadcn--calendar-part")
    return node
  }

  // ------------------------------------------------------------------------------------------------------------- events

  onClick(event) {
    const cell = this.dayViews.get(event.target.closest("button"))
    if (!cell) return
    event.preventDefault()
    event.stopPropagation()
    this.focused = toRef(cell.day)
    if (!cell.modifiers.disabled) this.select(cell.day.date, cell.modifiers)
    this.render()
  }

  onFocusIn(event) {
    const cell = this.dayViews.get(event.target)
    if (this.patching || !cell || this.isFocused(cell.day)) return
    this.focused = toRef(cell.day)
    this.render()
  }

  onFocusOut(event) {
    if (this.patching || !this.dayViews.has(event.target)) return
    this.lastFocused = this.focused
    this.focused = null
    this.render()
  }

  onKeyDown(event) {
    if (!this.dayViews.has(event.target)) return
    const rtl = this.dir === "rtl"
    const horizontal = event.shiftKey ? "month" : "day"
    const moves = {
      ArrowLeft: [horizontal, rtl ? "after" : "before"],
      ArrowRight: [horizontal, rtl ? "before" : "after"],
      ArrowDown: [event.shiftKey ? "year" : "week", "after"],
      ArrowUp: [event.shiftKey ? "year" : "week", "before"],
      PageUp: [event.shiftKey ? "year" : "month", "before"],
      PageDown: [event.shiftKey ? "year" : "month", "after"],
      Home: ["startOfWeek", "before"],
      End: ["endOfWeek", "after"]
    }
    if (!Object.hasOwn(moves, event.key)) return
    event.preventDefault()
    event.stopPropagation()
    this.moveFocus(...moves[event.key])
  }

  // DP:205-214: the dropdown of month `index` was changed; the first displayed month moves so that month shows the chosen value.
  onChange(event) {
    const dropdown = this.selectViews.get(event.target)
    if (!dropdown) return
    const shown = this.model.months[dropdown.view.index].date
    const value = Number(event.target.value)
    const date = dropdown.kind === "months" ? grid.makeDate(shown.getFullYear(), value, 1) : grid.makeDate(value, shown.getMonth(), 1)
    this.changeMonth(grid.addMonths(date, -dropdown.view.index))
    this.render() // a refused move (controlled month, disabled navigation) puts the select back to the displayed value
  }

  // ------------------------------------------------------------------------------------------------- navigation, focus

  // UC:75-90: clamp to the navigation bounds, move (unless controlled), notify.
  changeMonth(date) {
    if (this.cfg.disableNavigation) return
    const { navStart, navEnd } = this.model
    let month = grid.startOfMonth(date)
    if (navStart && grid.isBefore(month, grid.startOfMonth(navStart))) month = grid.startOfMonth(navStart)
    if (navEnd && grid.isAfter(month, grid.startOfMonth(navEnd))) month = grid.startOfMonth(navEnd)
    if (!this.controlled) this.firstMonth = month
    this.dispatch("month-change", { detail: { month: grid.toISO(month) }, cancelable: false })
  }

  goToMonth(date) {
    this.changeMonth(date)
    this.render()
  }

  moveFocus(moveBy, moveDir) {
    if (!this.focused) return
    const next = this.nextFocus(moveBy, moveDir, this.focused.date)
    if (!next) return
    const displayed = this.model.days.some((day) => sameDay(next, day))
    if (this.cfg.disableNavigation && !displayed) return
    if (!displayed) this.changeMonth(next.date)
    this.focused = next
    this.render()
  }

  // GNF:21-37: the candidate day; while it is disabled or hidden the same move is repeated from it (at most 365 times).
  nextFocus(moveBy, moveDir, from, attempt = 0) {
    if (attempt > 365) return null
    const date = this.focusableDate(moveBy, moveDir, from)
    const { disabled, hidden } = this.matchers
    const blocked = Boolean(disabled !== undefined && grid.dateMatches(date, disabled)) || Boolean(hidden !== undefined && grid.dateMatches(date, hidden))
    if (blocked) return this.nextFocus(moveBy, moveDir, date, attempt + 1)
    return toRef({ date, iso: grid.toISO(date), monthId: grid.toMonthISO(date) })
  }

  // GFD:17-44
  focusableDate(moveBy, moveDir, from) {
    const amount = moveDir === "after" ? 1 : -1
    const moves = {
      day: () => grid.addDays(from, amount),
      week: () => grid.addWeeks(from, amount),
      month: () => grid.addMonths(from, amount),
      year: () => grid.addYears(from, amount),
      startOfWeek: () => grid.startOfWeek(from, this.weekStartsOn),
      endOfWeek: () => grid.endOfWeek(from, this.weekStartsOn)
    }
    const date = moves[moveBy]()
    const { navStart, navEnd } = this.model
    if (moveDir === "before" && navStart && grid.isBefore(date, navStart)) return navStart
    if (moveDir === "after" && navEnd && grid.isAfter(date, navEnd)) return navEnd
    return date
  }

  // ------------------------------------------------------------------------------------------------------- selection

  select(date, modifiers) {
    const next = this.nextSelection(date)
    if (next === undefined) return
    this.selected = next
    this.dispatch("select", { detail: { selected: this.serialize(), date: grid.toISO(date), modifiers: booleans(modifiers) }, cancelable: false })
    this.syncFields(true)
    this.closeOnSelect()
  }

  // The new selection after a click, or undefined when nothing happens (USI:19-35, UMU:20-48, URA:18-53).
  nextSelection(date) {
    const { required, min, max } = this.cfg
    if (this.mode === "single") return !required && this.selected && grid.isSameDay(date, this.selected) ? null : date
    if (this.mode === "multiple") {
      const current = this.selected
      if (current.some((selected) => grid.isSameDay(selected, date))) {
        if (current.length === min) return undefined
        if (required && current.length === 1) return undefined
        return current.filter((selected) => !grid.isSameDay(selected, date))
      }
      return current.length === max ? [date] : [...current, date]
    }
    return this.nextRange(date, { min, max, required })
  }

  nextRange(date, limits) {
    const current = this.selected
    const complete = Boolean(current?.from && current?.to)
    let range
    if (this.cfg.resetOnSelect && (complete || !current?.from)) {
      const single = complete && grid.isSameDay(current.from, current.to) && grid.isSameDay(date, current.from)
      range = !limits.required && single ? null : { from: date, to: undefined }
    } else {
      range = grid.addToRange(date, current, limits)
    }
    const { disabled } = this.matchers
    if (this.cfg.excludeDisabled && disabled !== undefined && range?.from && range.to && grid.rangeContainsMatch({ from: range.from, to: range.to }, disabled)) {
      range = { from: date, to: undefined }
    }
    return range
  }

  serialize() {
    const selected = this.selected
    if (this.mode === "single") return selected ? grid.toISO(selected) : null
    if (this.mode === "multiple") return selected.map(grid.toISO)
    if (!selected) return null
    return { from: selected.from ? grid.toISO(selected.from) : null, to: selected.to ? grid.toISO(selected.to) : null }
  }

  // ------------------------------------------------------------------------- forms, label, popover (DatePicker rules)

  // `input:` text <-> selection: single `YYYY-MM-DD`, multiple `a,b`, range `from/to`, or one ISO per `{ from, to }` input.
  inputs() {
    const input = this.cfg.input
    if (!input) return null
    if (this.resolvedInputs === undefined) this.resolvedInputs = this.resolveInputs(input)
    return this.resolvedInputs
  }

  resolveInputs(input) {
    const selectors = typeof input === "string" ? [input] : [input.from, input.to]
    const found = selectors.map((selector) => document.querySelector(selector))
    const missing = selectors.filter((_, index) => !found[index])
    if (missing.length) {
      console.error(`shadcn--calendar: input ${missing.map((selector) => `"${selector}"`).join(", ")} matches no element; the selection is not read from or written to it`, this.element)
      return null
    }
    return typeof input === "string" ? { value: found[0] } : { from: found[0], to: found[1] }
  }

  // The inline `name:` inputs as a selection, or undefined when the calendar has none.
  readInline() {
    const field = (kind) => this.element.querySelector(`input[data-shadcn--calendar-field="${kind}"]`)
    if (this.mode === "single") return field("single") ? grid.parseISO(field("single").value) : undefined
    if (this.mode === "range") return field("from") ? rangeOrNull(grid.parseISO(field("from").value), grid.parseISO(field("to")?.value)) : undefined
    if (this.mode !== "multiple" || !field("blank")) return undefined
    return [...this.element.querySelectorAll('input[data-shadcn--calendar-field="item"]')].map((item) => grid.parseISO(item.value)).filter(Boolean)
  }

  readInput() {
    const inputs = this.inputs()
    if (!inputs) return undefined
    if (inputs.value) {
      const text = inputs.value.value.trim()
      if (this.mode === "single") return this.parsedInput(text, grid.parseISO(text))
      if (this.mode === "multiple") {
        const parts = text.split(",").map((part) => part.trim()).filter(Boolean)
        const dates = parts.map((part) => grid.parseISO(part))
        return this.parsedInput(text, dates.filter(Boolean), dates.every(Boolean))
      }
      const parts = text.split("/").map((part) => part.trim())
      return this.parsedRange(text, parts[0], parts[1], parts.length <= 2)
    }
    if (this.mode !== "range") return undefined
    const [from, to] = [inputs.from.value.trim(), inputs.to.value.trim()]
    return this.parsedRange(from || to ? `${from}/${to}` : "", from, to)
  }

  // A range is valid only when each side that is present parses (and, in the one-input form, there are at most two parts).
  parsedRange(text, from, to, shaped = true) {
    const [start, end] = [grid.parseISO(from), grid.parseISO(to)]
    return this.parsedInput(text, rangeOrNull(start, end), Boolean(shaped && (!from || start) && (!to || end)))
  }

  // A non-empty value that does not fully parse is read as no selection, loudly, the same in every mode.
  parsedInput(text, result, valid = Boolean(result)) {
    if (!text || valid) return result
    console.warn(`shadcn--calendar: input value "${text}" is not a valid ${this.mode} date value; it is read as no selection`, this.element)
    return this.mode === "multiple" ? [] : null
  }

  // The inline `name:` inputs and the label always follow the selection; `notify` (after a click) also writes the external inputs.
  syncFields(notify) {
    this.syncInlineFields()
    if (notify) this.writeInputs()
    this.syncLabel(notify)
  }

  syncInlineFields() {
    const field = (kind) => this.element.querySelector(`input[data-shadcn--calendar-field="${kind}"]`)
    const serialized = this.serialize()
    if (this.mode === "multiple") {
      const blank = field("blank")
      if (!blank) return
      this.element.querySelectorAll('input[data-shadcn--calendar-field="item"]').forEach((item) => item.remove())
      serialized.reduce((anchor, iso) => {
        const item = Object.assign(blank.cloneNode(), { value: iso })
        item.setAttribute("data-shadcn--calendar-field", "item")
        anchor.after(item)
        return item
      }, blank)
    } else if (this.mode === "range") {
      const [from, to] = [field("from"), field("to")]
      if (from) from.value = serialized?.from || ""
      if (to) to.value = serialized?.to || ""
    } else if (field("single")) {
      field("single").value = serialized || ""
    }
  }

  writeInputs() {
    const inputs = this.inputs()
    if (!inputs) return
    const serialized = this.serialize()
    let writes = []
    if (inputs.value) {
      let text = serialized || ""
      if (this.mode === "multiple") text = serialized.join(",")
      else if (this.mode === "range") text = serialized ? `${serialized.from || ""}/${serialized.to || ""}` : ""
      writes = [[inputs.value, text]]
    } else if (this.mode === "range") {
      writes = [[inputs.from, serialized?.from || ""], [inputs.to, serialized?.to || ""]]
    }
    for (const [input, value] of writes) {
      if (!input) continue
      input.value = value
      input.dispatchEvent(new Event("input", { bubbles: true }))
      input.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  // The label element, resolved once per setup; a selector that matches nothing is reported and ignored.
  resolveLabel() {
    if (!this.cfg.label) return null
    const label = document.querySelector(this.cfg.label)
    if (!label) console.error(`shadcn--calendar: label "${this.cfg.label}" matches no element; the selection text is not shown`, this.element)
    return label
  }

  // The placeholder is declared by the server (`data-shadcn--calendar-placeholder`: the calendar connects only when the popover opens, so
  // the label's own text may already be a date). Without the attribute the element's first text becomes the placeholder, stored once.
  storePlaceholder() {
    const label = this.label
    if (label && !label.hasAttribute("data-shadcn--calendar-placeholder")) label.setAttribute("data-shadcn--calendar-placeholder", label.textContent)
  }

  // `data-empty` always follows the selection; the text changes only after a click (the server rendered the initial text).
  syncLabel(notify) {
    const label = this.label
    if (!label) return
    const text = this.selectionText()
    label.setAttribute("data-empty", String(!text))
    if (notify) label.textContent = text || label.getAttribute("data-shadcn--calendar-placeholder")
  }

  selectionText() {
    if (!this.hasSelection(this.selected)) return null
    if (this.mode === "single") return this.longText(this.selected)
    if (this.mode === "multiple") return this.selected.map((date) => this.longText(date)).join(", ")
    const short = this.intl(this.localeTag, { month: "short", day: "2-digit", year: "numeric" })
    return [this.selected.from, this.selected.to].filter(Boolean).map((date) => short.format(date)).join(" - ")
  }

  // Closes the enclosing Popover the way `onSelect={() => setOpen(false)}` does, once the selection is complete.
  closeOnSelect() {
    if (!this.cfg.closeOnSelect) return
    const selected = this.selected
    const complete = this.mode === "single" ? Boolean(selected) : this.mode === "range" && Boolean(selected?.from && selected.to && !grid.isSameDay(selected.from, selected.to))
    const content = complete ? this.element.closest("[data-slot=popover-content]") : null
    if (!content?.id) return
    const trigger = document.querySelector(`[aria-controls="${CSS.escape(content.id)}"]`)
    if (trigger) this.application.getControllerForElementAndIdentifier(trigger, "shadcn--popover")?.request(false)
  }

  // ----------------------------------------------------------------------------------------------------------- text

  intl(locale, options) {
    const key = `${locale}|${JSON.stringify(options)}`
    const formats = this.constructor.formats
    if (!formats.has(key)) formats.set(key, new Intl.DateTimeFormat(locale, options))
    return formats.get(key)
  }

  // A caller formatter is an Intl.DateTimeFormat options hash (functions cannot cross from Ruby); it replaces the default.
  format(kind, date) {
    const custom = this.cfg.formatters?.[this.constructor.formatters[kind]]
    if (!custom) return this[`${kind}Text`](date)
    const { locale, ...options } = custom
    return date.toLocaleString(locale || this.localeTag, options)
  }

  // DL:549-568: `LLLL y`, or Intl month + year for the year-first locales.
  captionText(date) {
    if (this.cfg.yearFirst) return this.intl(this.localeTag, { month: "long", year: "numeric" }).format(date)
    return `${this.intl(this.localeTag, { month: "long" }).format(date)} ${date.getFullYear()}`
  }

  // `cccccc` (the first two letters for en and es, whose date-fns names are two letters).
  weekdayText(date) {
    const text = this.intl(this.localeTag, { weekday: "short" }).format(date)
    return ["en", "es"].includes(this.cfg.localeKind) ? text.slice(0, 2) : text
  }

  weekdayLongText(date) {
    return this.intl(this.localeTag, { weekday: "long" }).format(date)
  }

  dayText(date) {
    return String(date.getDate())
  }

  // shadcn formatMonthDropdown: the BROWSER locale, whatever the calendar locale is.
  monthDropdownText(date) {
    return date.toLocaleString("default", { month: "short" })
  }

  yearDropdownText(date) {
    return String(date.getFullYear()).padStart(4, "0")
  }

  // date-fns `PPP` (en: March 15th, 2026; other locales Intl dateStyle long).
  longText(date) {
    if (this.cfg.localeKind !== "en") return this.intl(this.localeTag, { dateStyle: "long" }).format(date)
    return `${this.intl(this.localeTag, { month: "long" }).format(date)} ${date.getDate()}${grid.ordinalSuffix(date.getDate())}, ${date.getFullYear()}`
  }

  // date-fns `PPPP` with rdp's prefix and suffix (LEN:7-21, LES:7-15).
  dayLabel(date, modifiers, button) {
    let label = this.cfg.localeKind === "en" ? `${this.weekdayLongText(date)}, ${this.longText(date)}` : this.intl(this.localeTag, { dateStyle: "full" }).format(date)
    if (modifiers.today) label = `${this.labels.today}, ${label}`
    if (button && modifiers.selected) label = `${label}, ${this.labels.selected}`
    return label
  }
}

const sameDay = (left, right) => left.iso === right.iso && left.monthId === right.monthId

const toRef = (day) => ({ date: day.date, iso: day.iso, monthId: day.monthId })

const booleans = (modifiers) => Object.fromEntries(Object.entries(modifiers).filter(([, value]) => typeof value === "boolean"))

// A range without any end is "no selection" (react-day-picker keeps `undefined`).
const rangeOrNull = (from, to) => (from || to ? { from: from || undefined, to: to || undefined } : null)

function setAttr(element, name, value) {
  if (value === undefined || value === null) {
    if (element.hasAttribute(name)) element.removeAttribute(name)
  } else if (element.getAttribute(name) !== value) {
    element.setAttribute(name, value)
  }
}

function setText(element, text) {
  if (element.textContent !== text) element.textContent = text
}

// A cell whose content is plain text (non-interactive grid): keeps a single text node.
function setContent(element, text) {
  if (text === "") element.replaceChildren()
  else setText(element, text)
}

// Puts `node` at `index` among the children of `parent` without touching it when it is already there (a moved node loses focus).
function place(parent, node, index) {
  if (parent.children[index] !== node) parent.insertBefore(node, parent.children[index] || null)
}
