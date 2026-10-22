# Calendar (shadcn new-york-v4, react-day-picker)

Oracle: `gems/chadcn/dev/port/oracle/src/calendar.tsx` (manifest `source_sha` 78ed2cc49dafc5bb), manifest `oracle/manifest/calendar.json`. Parts: `Calendar` (data-slot `calendar`), `CalendarDayButton` (renders shadcn `Button`, no own data-slot).
Behavior source: `gems/chadcn/dev/react-shadcn-catalog/node_modules/react-day-picker` **10.0.2** `dist/esm` (date library `date-fns` 4.1.0). Citations use these prefixes (file:line, original line numbers):
`DP` DayPicker.js, `UC` useCalendar.js, `UF` useFocus.js, `USI` selection/useSingle.js, `UMU` selection/useMulti.js, `URA` selection/useRange.js, `CFT` helpers/calculateFocusTarget.js, `GNF` helpers/getNextFocus.js, `GFD` helpers/getFocusableDate.js, `CGM` helpers/createGetModifiers.js, `GCN` helpers/getClassNamesForModifiers.js, `GDA` helpers/getDataAttributes.js, `GDC` helpers/getDefaultClassNames.js, `GD` helpers/getDates.js, `GM` helpers/getMonths.js, `GIM` helpers/getInitialMonth.js, `GNV` helpers/getNavMonth.js, `GNX` helpers/getNextMonth.js, `GPV` helpers/getPreviousMonth.js, `GDM` helpers/getDisplayMonths.js, `GMO` helpers/getMonthOptions.js, `GYO` helpers/getYearOptions.js, `GWD` helpers/getWeekdays.js, `GL` helpers/getLabels.js, `DMM` utils/dateMatchModifiers.js, `ATR` utils/addToRange.js, `RID` utils/rangeIncludesDate.js, `RCM` utils/rangeContainsModifiers.js, `TG` utils/typeguards.js, `CD` classes/CalendarDay.js, `DL` classes/DateLib.js, `NAV` components/Nav.js, `DD` components/Dropdown.js, `WDS` components/Weekdays.js, `LEN` locale/en-US.js, `LES` locale/es.js, `FWN` formatters/formatWeekNumber.js. The rendered oracle DOM quoted below was produced with `react-dom/server` from the catalog's own `src/components/ui/calendar.tsx` (identical to the oracle except the import path).
Examples: registry `calendar-demo`, `date-picker-demo`, `date-picker-with-range`, `date-picker-with-presets`, `calendar-hijri` (`/r/styles/new-york-v4/*.json`) and the docs examples `apps/v4/examples/radix/calendar-*.tsx`, `date-picker-*.tsx` (shadcn-ui/ui main; markup is style independent).
Tier: `third_party`. HARD CONSTRAINT: no react-day-picker, no date-fns, no other date library at runtime; native `Date` + `Intl` only.

## API

Every part: `class:` goes through `cn` last (caller wins), `**attrs` pass through (`data:` / `aria:` deep-merged), string and symbol option values are accepted (`mode: :range` == `mode: "range"`, `caption_layout: :dropdown_months` == `"dropdown-months"`, `button_variant: :outline`).

### `Chadcn::Calendar` (React `Calendar` -> `DayPicker`)

```ruby
Chadcn::Calendar.new(
  mode: nil,                    # nil | "single" | "multiple" | "range"   (rdp `mode`; nil = non-interactive grid)
  selected: nil,                # single: Date|ISO; multiple: Array; range: { from:, to: } (to optional)
  default_month: nil,           # Date|ISO; first displayed month (uncontrolled)
  month: nil,                   # Date|ISO; controlled displayed month (see Behavior "Controlled month")
  today: nil,                   # Date|ISO; nil = the browser's `new Date()` at connect (DL:60-69)
  number_of_months: 1,
  show_outside_days: true,      # shadcn default (tsx `showOutsideDays = true`)
  caption_layout: "label",      # shadcn default; "label" | "dropdown" | "dropdown-months" | "dropdown-years"
  button_variant: "ghost",      # shadcn default; any Chadcn::Button variant (default destructive outline secondary ghost link)
  locale: nil,                  # nil (rdp default enUS) | BCP 47 tag "es", "en", "en-US"...
  week_starts_on: nil,          # 0..6 (0 = Sunday); nil = from the locale
  fixed_weeks: false,
  show_week_number: false,
  disabled: nil,                # matcher(s), see below
  hidden: nil,                  # matcher(s)
  modifiers: nil,               # { name => matcher(s) }
  modifiers_class_names: nil,   # { name => "classes" }
  class_names: nil,             # { rdp UI key => "classes" } replaces shadcn's string for that key
  formatters: nil,              # { format_caption:|format_day:|format_month_dropdown:|format_weekday_name:|format_year_dropdown: => Intl.DateTimeFormat options Hash }
  components: nil,              # only nil / {} accepted (ArgumentError otherwise)
  start_month: nil, end_month: nil,   # Date|ISO
  min: nil, max: nil,           # Integer (multiple: count; range: nights)
  required: nil,                # true | false | nil (nil = prop absent: no data-required)
  exclude_disabled: false, reset_on_select: false,   # range only
  disable_navigation: false, hide_navigation: false, hide_weekdays: false, paged_navigation: false,
  auto_focus: false,
  footer: nil,                  # String
  dir: nil,                     # nil | "ltr" | "rtl"
  lang: nil,                    # nil = locale code (see Structure)
  name: nil,                    # renders hidden input(s) inside the root (inline form use)
  input: nil,                   # CSS selector of an EXTERNAL hidden input (String) or { from:, to: } selectors (range)
  label: nil,                   # CSS selector of an external element whose text shows the selection
  close_on_select: false,       # close the enclosing Popover after a completing selection
  class: nil, **attrs
) { }   # no block content (the grid is rendered by the controller); a block is ignored
```

Kwarg mapping to React props (mechanical, api-mapping.md): `mode`, `selected`, `defaultMonth`, `month`, `today`, `numberOfMonths`, `showOutsideDays`, `captionLayout`, `buttonVariant`, `locale`, `weekStartsOn`, `fixedWeeks`, `showWeekNumber`, `disabled`, `hidden`, `modifiers`, `modifiersClassNames`, `classNames`, `formatters`, `components`, `startMonth`, `endMonth`, `min`, `max`, `required`, `excludeDisabled`, `resetOnSelect`, `disableNavigation`, `hideNavigation`, `hideWeekdays`, `pagedNavigation`, `autoFocus`, `footer`, `dir`, `lang`, `className`. `id`, `title`, `role`, `aria-label`, `aria-labelledby`, `style`, `data-*` reach the root through `**attrs` (rdp forwards exactly these, DP:257 + GDA:19-23; Ruby forwards every attr, R6). `name:`, `input:`, `label:`, `close_on_select:` are port-only (DatePicker composition, no React counterpart, unit-tested only).

Value formats (Ruby and the scenario harness, where `"$date:YYYY-MM-DD"` arrives as the ISO string and `"$locale:es"` as `"es"`):
- Dates: `Date`, `Time`/`DateTime` (`to_date`), or an ISO `"YYYY-MM-DD"` String. Month kwargs (`default_month`, `month`, `start_month`, `end_month`) are normalized to the first of the month. In JS every ISO string is parsed as a LOCAL date `new Date(y, m - 1, d)` (never `new Date("YYYY-MM-DD")`, which is UTC); the React harness does the same (Harness.tsx `reviveValue`).
- `selected`: single -> one date; multiple -> Array of dates; range -> Hash `{ from:, to: }` (String or Symbol keys; `to` optional). A value whose shape does not match `mode` raises `ArgumentError`.
- Matchers (`disabled`, `hidden`, each `modifiers` value), same precedence as DMM:13-59 / TG:8-64: `true`/`false`; a date; an Array of dates; a range `{ from:, to: }` (either side optional, inverted ranges are swapped, RID:13-32); `{ day_of_week: Integer | Array }` (also `"dayOfWeek"`); an interval `{ before:, after: }` (closed when `before` > `after`: strictly between; otherwise open: strictly before `before` OR strictly after `after`); `{ after: }` (strictly after); `{ before: }` (strictly before); or an Array mixing any of these. Keys accepted as snake_case or camelCase, String or Symbol. Ruby normalizes to JSON (ISO strings, camelCase keys) for the controller. Procs/lambdas raise `ArgumentError` (functions are not portable).
- `class_names` keys are rdp UI keys (GDC, UI.js): `root months month nav button_previous button_next month_caption dropdowns dropdown dropdown_root caption_label months_dropdown years_dropdown chevron month_grid weekdays weekday weeks week week_number week_number_header day day_button footer` and modifier keys `today outside disabled hidden focused selected range_start range_middle range_end`. A given key REPLACES the shadcn+rdp string for that key (`classNames={{ ..., ...classNames }}` spread last in the tsx; rdp merges `{ ...getDefaultClassNames(), ...props.classNames }`, DP:113), so the `rdp-*` class is gone unless the caller includes it.
- `formatters`: each value is an `Intl.DateTimeFormat` options Hash (plus optional `locale:`), applied as `date.toLocaleString(locale || <calendar locale>, options)`; it replaces the corresponding default formatter. Deviation (functions are not portable); unit-tested only.
- `button_variant` is validated against `Chadcn::Button::VARIANTS`; `caption_layout`, `mode`, `dir` against their lists (`ArgumentError` on unknown values).
- `week_starts_on`: Integer 0..6 or its String.

Events (dispatched by `shadcn--calendar` on the root, `bubbles: true`, not cancelable):

| Event | rdp origin | detail |
|---|---|---|
| `shadcn--calendar:select` | `onSelect` (USI:19-35 every click; UMU:20-48 except the two early returns at `min` / `required`; URA:18-53 every click) | `{ selected, date, modifiers }`: `selected` = single `"YYYY-MM-DD"` or `null`; multiple Array of ISO (may be `[]`); range `{ from, to }` (ISO or `null`) or `null`; `date` = clicked day ISO; `modifiers` = the clicked day's boolean modifiers |
| `shadcn--calendar:month-change` | `onMonthChange` (UC:75-90, only when `goToMonth` runs and navigation is enabled) | `{ month: "YYYY-MM-01" }` |

Not ported (no DOM effect, React-only, or not data): `ref`, every other `on*` callback (`onDayClick`, `onDayFocus`, `onDayBlur`, `onDayKeyDown`, `onDayMouseEnter/Leave`, `onNextClick`, `onPrevClick`), `components` (render overrides), function matchers, function formatters/labels, `labels`, `styles`, `modifiersStyles`, `timeZone`, `noonSafe`, `dateLib`, `numerals`, `ISOWeek`, `broadcastCalendar`, `firstWeekContainsDate`, `useAdditionalWeekYearTokens`, `useAdditionalDayOfYearTokens`, `navLayout`, `reverseMonths`, `reverseYears`, `animate`, `nonce`, `initialFocus` (removed in rdp 9+, a no-op in 10). Listed in `deviations/calendar.json`.

### `Chadcn::Calendar::DayButton` (React `CalendarDayButton`)

```ruby
Chadcn::Calendar::DayButton.new(day:, modifiers: {}, class: nil, **attrs) { "15" }
```

- `day:` a date (Date / ISO) or a Hash `{ date: }` (String or Symbol key), mirroring rdp's `CalendarDay` (`day.date` is the only field read, calendar.tsx `day.date.toLocaleDateString()`).
- `modifiers:` Hash (String/Symbol keys; snake_case as in rdp: `selected`, `range_start`, `range_end`, `range_middle`, `focused`, `today`, `outside`, `disabled`, `hidden`).
- Renders `Chadcn::Button.new(variant: "ghost", size: "icon", ...)` (`data-slot="button" data-variant="ghost" data-size="icon"`) with `class: cn(<calendar.tsx CalendarDayButton string>, "rdp-day", class)`, so the final class list is Button's `cn(buttonVariants({ variant: "ghost", size: "icon", className }))`: oracle output (verified) = `shrink-0 items-center justify-center rounded-md text-sm whitespace-nowrap transition-all outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 hover:bg-accent hover:text-accent-foreground dark:hover:bg-accent/50 flex aspect-square size-auto w-full min-w-(--cell-size) flex-col gap-1 leading-none font-normal group-data-[focused=true]/day:relative ... [&>span]:text-xs [&>span]:opacity-70 rdp-day` (+ `rdp-day_button` inside the calendar).
- Data attributes, exactly the tsx expressions:
  - `data-day` = `day.date.toLocaleDateString()` (browser default locale; `3/15/2026` in en-US). Server-rendered standalone: the Ruby side cannot know the browser locale, so it renders the en-US form `M/D/YYYY` (deviation; inside the Calendar the controller uses the real `toLocaleDateString()`).
  - `data-selected-single` = JS `modifiers.selected && !range_start && !range_end && !range_middle`: absent when `selected` is absent/nil, `"false"` when `selected` is `false`, otherwise `"true"`/`"false"` from the range flags.
  - `data-range-start`, `data-range-end`, `data-range-middle` = the flag as `"true"`/`"false"` when the key is present, absent when the key is absent.
  - No `type` attribute standalone (React `Button` sets none); inside the Calendar the controller adds `type="button"` etc. (Structure).
- `modifiers: { focused: true }` focuses the button on mount in React (tsx `useEffect`); the standalone Ruby render cannot (deviation); inside the Calendar the controller does it.
- `**attrs` (e.g. `aria-label`, `tabindex`, `disabled`) pass through to the button.

### DatePicker (documented composition, NOT a class)

The oracle has no date picker component (registry: only `calendar.json`; shadcn's date pickers are examples). The port documents this composition and a unit test renders it:

```ruby
input(type: "hidden", id: "event_date", name: "event[date]", value: @event.date&.iso8601)   # OUTSIDE the popover
render Chadcn::Popover.new do
  render Chadcn::Popover::Trigger.new(as_child: Chadcn::Button.new(variant: "outline", class: "w-[240px] justify-start text-left font-normal")) do
    render Chadcn::Icon.new("calendar")
    span(id: "event_date_label") { @event.date ? l(@event.date, format: :long) : "Pick a date" }
  end
  render Chadcn::Popover::Content.new(class: "w-auto p-0", align: "start") do
    render Chadcn::Calendar.new(mode: :single, input: "#event_date", label: "#event_date_label", close_on_select: true)
  end
end
```

Rules:
- The form input lives OUTSIDE `Popover::Content`: the content is an inert `<template>` that is mounted into `body` on open and removed on close (specs/popover.md), so anything inside it is not in the form and does not survive a close.
- `input:` is the source of truth. On every `connect()` (each popover open mounts a fresh copy) the controller parses the external input's value (single `YYYY-MM-DD`; multiple comma-separated `YYYY-MM-DD,YYYY-MM-DD`; range `YYYY-MM-DD/YYYY-MM-DD`, from-only `YYYY-MM-DD/`, or `input: { from: sel, to: sel }` with one ISO per input) and uses it instead of `selected:`; an empty or unparsable value means no selection. Port-only rule: when the input yields a selection and neither `month:` nor `default_month:` is given, the first displayed month is the month of the (first / `from`) selected date (the docs examples pass `defaultMonth={date}` for the same effect).
- After each `select` the controller writes the new value in that format into the input(s) and dispatches bubbling `input` and `change` events on each written input.
- `label:` element: its initial text is kept as the placeholder (stored once in `data-shadcn--calendar-placeholder` on that element); after each `select` the text becomes the formatted selection or, when cleared, the placeholder; the element gets `data-empty="true|false"` so callers can style the empty state (e.g. `has-[[data-empty=true]]:text-muted-foreground` on the button). Formats (the examples' date-fns formats re-expressed with Intl): single = `PPP` (en / en-US: `March 15th, 2026` built like the PPPP rule below without the weekday; other locales `Intl.DateTimeFormat(locale, { dateStyle: "long" })`); multiple = those joined with `", "`; range = `LLL dd, y - LLL dd, y` via `Intl.DateTimeFormat(locale, { month: "short", day: "2-digit", year: "numeric" })` (en: `Jan 20, 2022 - Feb 09, 2022`), from-only = the `from` part alone.
- `close_on_select: true`: after a select whose result is complete (single: a date; range: `from` and `to` present and different; multiple: never) the controller closes the enclosing popover the way a React `onSelect={() => setOpen(false)}` does: it finds the closest `[data-slot=popover-content]`, the element with `aria-controls="<that content id>"` (the open Popover trigger, which hosts `shadcn--popover`), and calls that controller's `request(false)` through `this.application.getControllerForElementAndIdentifier`. Focus then returns to the trigger through the popover's own close-auto-focus. Outside a popover the flag does nothing.
- `name:` (inline use, also combinable with `input:`): the server renders hidden inputs inside the root, after the months container: single `<input type="hidden" name="<name>" value="ISO|">`; multiple one `<input type="hidden" name="<name>[]" value="">` followed by one `name="<name>[]"` per date; range `name="<name>[from]"` and `name="<name>[to]"` (empty when nil). The controller keeps them in sync.

## Structure

Server vs Stimulus:
- The SERVER renders: the root `div` with all its attributes; inside it the months container `div` (empty until connect) whose FIRST child is the server-rendered `nav` (prev/next buttons with chevrons, aria-labels, disabled state computed in Ruby from the initial month and `start_month`/`end_month`/`caption_layout`/`today`), the `footer` div when given, the hidden inputs for `name:`, and one inert `<template data-shadcn--calendar-target="parts">` holding prototype elements for every other part with their FINAL class strings computed in Ruby (`cn` + `class_names` overrides + `Chadcn::Icon` chevrons + a `Calendar::DayButton` prototype + the modifier class strings incl. `modifiers_class_names`). Every Tailwind token therefore lives in Ruby (G1); the controller never contains class strings. Labels (en/es tables, below) also live in Ruby and reach the controller as a JSON value.
- The CONTROLLER `shadcn--calendar` (connect) computes everything date-dependent with `Date` + `Intl` and builds the month(s) after the `nav` by cloning the prototypes: captions/dropdowns, grid, weekday names, week numbers, day cells and buttons, all aria/data attributes, tabindex; it re-syncs the nav (its attributes may differ from the server guess when `today:` is nil). Output is fully deterministic given `today` and the month.
- Why the nav is server-rendered: inside a `Popover::Content` the popover's focus scope focuses the first tabbable synchronously right after mounting the template, before Stimulus connects the calendar; React's FocusScope finds the rendered prev button ("Go to the Previous Month"). With the nav already in the markup both pick the same element.
- Patch, do not rebuild: like React's reconciliation (keys: month `displayIndex` DP:266, week `weekNumber` DP:307, day `${isoDate}_${displayMonthId}` DP:332), the controller keeps the `nav`, its buttons, each month's caption span, dropdown `select`s and status span as the SAME nodes for the life of the calendar (text/attributes updated in place: focus stays on a nav button or select after a click/change; the `aria-live` caption announces), and keeps day `td`/`button` nodes while the displayed months are unchanged (selection/focus changes only update attributes; focus stays on the clicked button). Only when the displayed months change are the weeks rebuilt. On connect the months container is cleared first (a Turbo snapshot may contain an old grid; the server nav is kept).

Rendered DOM (oracle, `mode="single"`, en-US, today 2026-03-15, March 2026; `...` = repeated cells):

```html
<div data-slot="calendar" class="w-fit rdp-root group/calendar bg-background p-3 [--cell-size:--spacing(8)] [[data-slot=card-content]_&]:bg-transparent [[data-slot=popover-content]_&]:bg-transparent rtl:**:[.rdp-button\_next>svg]:rotate-180 rtl:**:[.rdp-button\_previous>svg]:rotate-180" lang="en-US" data-mode="single">
  <div class="relative flex flex-col gap-4 md:flex-row rdp-months">
    <nav class="absolute inset-x-0 top-0 flex w-full items-center justify-between gap-1 rdp-nav" aria-label="Navigation bar">
      <button type="button" class="<buttonVariants(variant) + size-(--cell-size) p-0 select-none aria-disabled:opacity-50 rdp-button_previous>" aria-label="Go to the Previous Month">
        <svg ... class="lucide lucide-chevron-left size-4 rdp-chevron" aria-hidden="true">...</svg></button>
      <button type="button" class="<... rdp-button_next>" aria-label="Go to the Next Month">
        <svg ... class="lucide lucide-chevron-right size-4 rdp-chevron" aria-hidden="true">...</svg></button>
    </nav>
    <div class="flex w-full flex-col gap-4 rdp-month">
      <div class="flex h-(--cell-size) w-full items-center justify-center px-(--cell-size) rdp-month_caption">
        <span class="font-medium select-none text-sm rdp-caption_label" role="status" aria-live="polite">March 2026</span>
      </div>
      <table role="grid" aria-multiselectable="false" aria-label="March 2026" class="w-full border-collapse rdp-month_grid">
        <thead aria-hidden="true"><tr class="flex rdp-weekdays">
          <th aria-label="Sunday" class="flex-1 rounded-md text-[0.8rem] font-normal text-muted-foreground select-none rdp-weekday" scope="col">Su</th> ...
        </tr></thead>
        <tbody class="rdp-weeks">
          <tr class="mt-2 flex w-full rdp-week">
            <td class="group/day relative aspect-square h-full w-full p-0 text-center select-none [&:last-child[data-selected=true]_button]:rounded-r-md [&:first-child[data-selected=true]_button]:rounded-l-md rdp-day" role="gridcell" data-day="2026-03-01">
              <button data-slot="button" data-variant="ghost" data-size="icon" class="<DayButton classes> rdp-day rdp-day_button" data-day="3/1/2026" type="button" tabindex="-1" aria-label="Sunday, March 1st, 2026">1</button>
            </td> ...
```

Root (`components.Root` override in the tsx, DP:257, GDA:10-25):
- `div`, `data-slot="calendar"`, `class` = `cn("w-fit rdp-root" (class_names[:root] replaces it), "group/calendar bg-background p-3 [--cell-size:--spacing(8)] [[data-slot=card-content]_&]:bg-transparent [[data-slot=popover-content]_&]:bg-transparent", "rtl:**:[.rdp-button\_next>svg]:rotate-180", "rtl:**:[.rdp-button\_previous>svg]:rotate-180", class)` (rdp joins `classNames.root` before `props.className`, DP:216, then the Root override runs `cn` over the whole string, so a caller `w-full`/`p-0` beats `w-fit`/`p-3`).
- `lang` = `lang:` || locale code: nil -> `"en-US"` (rdp `defaultLocale` is enUS, DP:87, DL:591), `"en"` -> `"en-US"` (the harness maps `$locale:en` to rdp `enUS`), `"es"` -> `"es"`, any other tag -> the tag as given (date-fns locale codes are BCP 47 tags).
- `dir` only when given. `id`, `title`, `role`, `aria-label`, `aria-labelledby`, `style`, `data-*` and any other attr from `**attrs`.
- `data-mode` = mode when set; `data-required` = `"true"`/`"false"` only when `required:` is not nil (`"required" in props`); `data-multiple-months="true"` when `number_of_months > 1`; `data-week-numbers="true"` when `show_week_number`. Plus Stimulus wiring (`data-controller="shadcn--calendar"`, `data-shadcn--calendar-*-value`, ignored by the runner).

Months / nav (DP:258-259, NAV:23-27):
- `div.rdp-months` class `relative flex flex-col gap-4 md:flex-row rdp-months`.
- `nav` (absent with `hide_navigation`), class `absolute inset-x-0 top-0 flex w-full items-center justify-between gap-1 rdp-nav`, `aria-label` = labelNav (`Navigation bar` / `Barra de navegación`, LEN:51, LES:30).
- Prev / next `button` (plain buttons, NOT shadcn Button, no data-slot): `type="button"`, class `cn(Button.variants(variant: button_variant), "size-(--cell-size) p-0 select-none aria-disabled:opacity-50", "rdp-button_previous" | "rdp-button_next")` (size `default` tokens `h-9 px-4 py-2` are removed by the merge, `has-[>svg]:px-3` stays); when the target month does not exist: `tabindex="-1"` and `aria-disabled="true"` (absent otherwise, NAV:24-26); `aria-label` = labelPrevious / labelNext. Child: lucide `chevron-left` / `chevron-right` (always left for prev and right for next, NAV:25-27; RTL flips them only through the `rtl:**:[...]:rotate-180` root classes) with class `size-4 rdp-chevron` (`cn("size-4", classNames.chevron)`), default width/height 24, `aria-hidden="true"`, and `disabled=""` ON THE SVG when its button is disabled (the tsx Chevron spreads rdp's `disabled` prop onto the lucide svg; reproduce).

Month (DP:264-302, one per displayed month, in order):
- `div` class `flex w-full flex-col gap-4 rdp-month`.
- Caption `div` class `flex h-(--cell-size) w-full items-center justify-center px-(--cell-size) rdp-month_caption`.
  - `caption_layout: "label"`: `span` class `font-medium select-none text-sm rdp-caption_label`, `role="status"`, `aria-live="polite"`, text = caption.
  - dropdown layouts (DP:271-293): `div` class `flex h-(--cell-size) w-full items-center justify-center gap-1.5 text-sm font-medium rdp-dropdowns` containing, in month-first order (en/es; year-first locales swap, DP:277-279, DL:537-543):
    - month control: `dropdown` and `dropdown-months` -> dropdown (below) with select class `absolute inset-0 bg-popover opacity-0 rdp-dropdown rdp-months_dropdown`, `aria-label` labelMonthDropdown (`Choose the Month` / `Elegir el mes`), options = the 12 months of the displayed year (GMO:16-31) `value` 0..11, label = `date.toLocaleString("default", { month: "short" })` (shadcn `formatMonthDropdown`; browser default locale, so `Mar` even with `locale: "es"`), `disabled` when the month is before `start_month` or after `end_month`; value = displayed month. Otherwise a bare `<span>` with that same short month text.
    - year control: `dropdown` and `dropdown-years` -> dropdown with select class `... rdp-dropdown rdp-years_dropdown`, `aria-label` labelYearDropdown (`Choose the Year` / `Elegir el año`), options = each year from navStart to navEnd (GYO:15-33; label `yyyy`, never disabled); value = displayed year. Otherwise a bare `<span>` with the 4-digit year.
    - Dropdown markup (DD:15-19): `span` class `relative rounded-md border border-input shadow-xs has-focus:border-ring has-focus:ring-[3px] has-focus:ring-ring/50 rdp-dropdown_root` with `data-disabled="true|false"` (= `disable_navigation`), containing the `select` (`disabled=""` with `disable_navigation`; its `value` is a DOM property, React never writes `selected` attributes on the client) and a `span` `aria-hidden="true"` class `font-medium select-none flex h-8 items-center gap-1 rounded-md pr-1 pl-2 text-sm [&>svg]:size-3.5 [&>svg]:text-muted-foreground rdp-caption_label` with the selected option's label text followed by lucide `chevron-down` with class `size-4 rdp-chevron`, `width="18" height="18"`.
    - Then a visually hidden `span role="status" aria-live="polite"` with inline style `border:0;clip:rect(0 0 0 0);height:1px;margin:-1px;overflow:hidden;padding:0;position:absolute;width:1px;white-space:nowrap;word-wrap:normal` and the caption text (DP:282-293).
  - Default nav months (GNV:8-29): with a year dropdown (`dropdown`, `dropdown-years`) and no `start_month` -> January of (today - 100 years); no `end_month` -> December 31 of today's year (so next is disabled at December of the current year).
- Grid `table` class `w-full border-collapse rdp-month_grid`, `role="grid"`, `aria-multiselectable="true"` for multiple/range else `"false"` (React stringifies the boolean, DP:301), `aria-label` = labelGrid (= caption text).
  - `thead aria-hidden="true"` > `tr` class `flex rdp-weekdays` (absent with `hide_weekdays`, WDS:9-10): optional week-number header `th` class `w-(--cell-size) select-none rdp-week_number_header`, `aria-label` labelWeekNumberHeader (`Week Number` / `Número de semana`), `scope="col"`, empty text; then 7 `th` class `flex-1 rounded-md text-[0.8rem] font-normal text-muted-foreground select-none rdp-weekday`, `aria-label` = long weekday name, `scope="col"`, text = 2-letter weekday (GWD:11-24: the week of `today` starting at weekStartsOn).
  - `tbody` class `rdp-weeks` > one `tr` class `mt-2 flex w-full rdp-week` per week (days grouped by week number like GM:42-53, not by 7-day chunks).
  - Week number cell (shadcn `WeekNumber` override): a `td` (not rdp's `th`) with, in React order, `week="[object Object]"` (the override spreads rdp's `week` object prop onto the `td`; React stringifies it; reproduce the attribute literally), `aria-label` = labelWeekNumber (`Week 10` / `Semana 10`, unpadded), class `text-[0.8rem] text-muted-foreground select-none rdp-week_number`, `scope="row"`, `role="rowheader"`; child `div` class `flex size-(--cell-size) items-center justify-center text-center` with the zero-padded number (`09`, `10`; FWN:13-18).
  - Day cell `td` (DP:332): `class` = `classNames.day` + one class string per TRUE modifier in this order: `focused`, `disabled`, `hidden`, `outside`, `today`, custom modifiers (in `modifiers:` key order), `selected`, `range_start`, `range_end`, `range_middle` (GCN:14-30, modifier object order CGM:70-90 + DP:314-325), each string being `modifiers_class_names[name]` if given, else `class_names[name]`, else the shadcn+rdp default; joined with a space and NOT tailwind-merged (duplicates and `rounded-md` + `rounded-l-md` coexist). Defaults: day `group/day relative aspect-square h-full w-full p-0 text-center select-none [&:last-child[data-selected=true]_button]:rounded-r-md` + (`show_week_number` ? `[&:nth-child(2)[data-selected=true]_button]:rounded-l-md` : `[&:first-child[data-selected=true]_button]:rounded-l-md`) + `rdp-day`; focused `rdp-focused`; disabled `text-muted-foreground opacity-50 rdp-disabled`; hidden `invisible rdp-hidden`; outside `text-muted-foreground aria-selected:text-muted-foreground rdp-outside`; today `rounded-md bg-accent text-accent-foreground data-[selected=true]:rounded-none rdp-today`; selected `rdp-selected`; range_start `rounded-l-md bg-accent rdp-range_start`; range_middle `rounded-none rdp-range_middle`; range_end `rounded-r-md bg-accent rdp-range_end`.
    Attributes: `role="gridcell"`; `aria-selected="true"` and `data-selected="true"` when selected (absent otherwise); `aria-label` = labelGridcell ONLY in non-interactive mode (no `mode`) and not hidden; `data-day` = ISO `YYYY-MM-DD`; `data-month` = `YYYY-MM` only for outside days; `data-disabled`, `data-hidden`, `data-outside`, `data-focused`, `data-today` = `"true"` when set, absent otherwise.
    Content: hidden -> nothing; non-interactive -> the day number text; interactive -> the day button.
  - Day button (interactive only): the `Calendar::DayButton` markup with class `cn(<CalendarDayButton string>, "rdp-day", class_names[:day_button] || "rdp-day_button")` through Button, attributes in addition to the DayButton data attrs: `type="button"`; `disabled=""` when disabled and not focused; `aria-disabled="true"` when disabled and focused; `tabindex="0"` on the focus target else `"-1"`; `aria-label` = labelDayButton. Range flags exist (`"true"`/`"false"`) only while the selected value is a range object with `from` (DP:319-325): in range mode with no selection they are absent; `data-selected-single` follows the DayButton rule (so a from-only range gives `data-selected-single="true"` on `from`). Text = day number (`d`).
- Footer: `div` class `rdp-footer` (`class_names[:footer]` replaces), `role="status"`, `aria-live="polite"`, text = `footer` (DP:341), after the months container.

Text and labels (Intl mapping; date-fns pattern -> exact Intl reproduction for the locales nil/`en`/`en-US` and `es`):

| Item | rdp source | en / en-US | es | other tags (deviation) |
|---|---|---|---|---|
| caption, grid label | `formatCaption`/`labelGrid` -> `DL.formatMonthYear` `LLLL y` (DL:549-568, LEN:27-35 `LLLL yyyy`) | `${Intl month:"long"} ${year}` = `March 2026` | same rule = `marzo 2026` (NOT Intl month+year, which gives `marzo de 2026`) | month-first: same rule; year-first locales (DL:571-589): `Intl.DateTimeFormat(tag, { month: "long", year: "numeric" })` |
| weekday header | `cccccc` | `Intl weekday:"short"` first 2 chars (`Su Mo Tu We Th Fr Sa`) | same rule (`lu ma mi ju vi sá do`, = date-fns es `short`) | `Intl weekday:"short"` unsliced |
| weekday aria-label | `cccc` | `Intl weekday:"long"` | same | same |
| day number | `d` | `String(getDate())` | same | same (latn digits) |
| day button / gridcell label | `PPPP` + prefix/suffix (LEN:7-21, 37-50; LES:7-15, 22-29) | `${weekday long}, ${month long} ${day}${ordinal}, ${year}` (date-fns en-US full `EEEE, MMMM do, y`; ordinal from `Intl.PluralRules("en-US", { type: "ordinal" })`: one `st`, two `nd`, few `rd`, other `th`) -> `Sunday, March 1st, 2026`; prefix `Today, ` when today; suffix `, selected` when selected (button only) | `Intl.DateTimeFormat("es", { dateStyle: "full" })` (= `EEEE, d 'de' MMMM 'de' y`) -> `domingo, 1 de marzo de 2026`; prefix `Hoy, `; suffix `, seleccionado` | `Intl dateStyle:"full"` + English prefix/suffix |
| month dropdown option / label | shadcn `formatMonthDropdown` | `date.toLocaleString("default", { month: "short" })` literally | same (browser locale) | same |
| year option / span | `yyyy` | 4-digit year | same | same |
| week number text / label | FWN:13-18 / `Week N` | `0N` for N < 10 / `Week N` | same / `Semana N` | English label |
| nav, prev, next, dropdowns, week-number header labels | LEN:22-26, 51-52 / LES:16-20, 30-31 | `Navigation bar`, `Go to the Previous Month`, `Go to the Next Month`, `Choose the Month`, `Choose the Year`, `Week Number` | `Barra de navegación`, `Ir al mes anterior`, `Ir al mes siguiente`, `Elegir el mes`, `Elegir el año`, `Número de semana` | English |

Locale tag resolution: `es` and `es-*` use the es column; nil, `en`, `en-US` the en column; everything else "other". Week settings: `week_starts_on:` wins; else nil/en/en-US -> 0 (date-fns en-US), es -> 1 (date-fns es.js:26); other tags -> `new Intl.Locale(tag).getWeekInfo?.() ?? .weekInfo` `firstDay % 7` (fallback 0 where the browser lacks weekInfo, e.g. Firefox). `firstWeekContainsDate` (week numbering only): en/en-US 1, es **1** (date-fns es.js:27; NOT CLDR's 4, verified: es January 2027 starts with `Semana 1`), other tags `weekInfo.minimalDays` when the browser reports it (Chromium no longer does) else 1.

## Behavior

Composes: no Radix primitive (rdp is not Radix). Shared primitives: none required (no layer, no positioning; the DatePicker composition reuses Popover's controller). Native `Date` + `Intl` only; all date math is local-time calendar arithmetic (`setDate`, `setMonth` with day clamping).

Date math the controller must reproduce (date-fns semantics):
- `addMonths(d, n)` / `addYears` clamp the day to the target month's length (Jan 31 + 1 month = Feb 28/29); native `setMonth` overflows and must not be used unguarded.
- `startOfWeek(d)` = the closest previous (or same) day whose weekday is weekStartsOn; `endOfWeek` = startOfWeek + 6.
- `getWeek(d)` (locale week numbering, used for week numbers and week grouping): week-year = the year Y such that `startOfWeekYear(Y) <= d`, where `startOfWeekYear(Y) = startOfWeek(Jan firstWeekContainsDate of Y)`; week = `round((startOfWeek(d) - startOfWeekYear) / 7 days) + 1` (en-US: the week containing Jan 1 is week 1, so Dec 27 2026 - Jan 2 2027 is week `01`).

Grid model (UC:21-110, GDM:11-22, GD:13-57, GM:16-64):
- Initial first month (GIM:12-25): `month || default_month || today`; if `end_month` is set and fewer than `number_of_months - 1` months remain to it, shift back so the last displayed month is `end_month`; if before `start_month`, use `start_month`; then the 1st of the month.
- Displayed months: `number_of_months` consecutive months from the first, stopping after navEnd (GDM:14-19).
- Days: from `startOfWeek(first month)` to `endOfWeek(endOfMonth(last month))`, clamped to `endOfWeek(endOfMonth(end_month))` when `end_month` is set (GD:18-38); per month the days between that month's first week start and last week end (GM:19-32); with `fixed_weeks` every month is padded with the following days up to 42 (GM:33-41, GD:46-55), so February 2026 (exactly 4 weeks) shows 6 rows.
- Outside day = not in its display month (CD:13). Hidden = `hidden` matcher, before navStart (1st of start month), after navEnd (end of end month), or outside when `show_outside_days` is false (CGM:31-40). Today = same day as `today` (CGM:41). Disabled = `disabled` matcher (CGM:34). Custom modifiers per `modifiers` (CGM:51-66) and they override the built-in flag of the same name (CGM:86-90).
- Selected (DP:317-326): single = same day; multiple = any same day; range = within `[from, to]` inclusive (RID with `excludeEnds=false`; from-only or to-only match that day). Range flags: `range_start` = from && to && day == from; `range_end` = from && to && day == to; `range_middle` = strictly inside (RID `excludeEnds=true`), so a same-day range is start AND end, not middle.
- Interactive = `mode` present (DP:143). Non-interactive grids render text cells and gridcell labels, have no day buttons, no keyboard, no selection.

Navigation (DP:144-155, NAV:13-22, GNX:18-34, GPV:19-35, UC:75-90):
- previous month = first month - 1 (or - `number_of_months` with `paged_navigation`), undefined when `disable_navigation` or the first month is not after navStart; next month = first + 1 (or + n paged), undefined when `disable_navigation` or `differenceInCalendarMonths(navEnd, first) < number_of_months`.
- Clicking a nav button with no target does nothing (no event); otherwise `goToMonth(target)`: clamps to [navStart, navEnd] months, sets the first month (unless controlled) and dispatches `month-change`. Focus stays on the clicked nav button (same node). `disable_navigation` blocks every `goToMonth` (UC:76-78).
- Dropdowns (DP:205-214): month change -> `goToMonth(setMonth(startOfMonth(this month's date), value) - displayIndex months)`; year change -> same with `setYear`; so changing the second month's dropdown keeps that month at the chosen value. A `select` keeps focus (same node). Option lists and values are recomputed after every month change.
- Controlled month (`month:`): exactly like React's `useControlledValue` without `onMonthChange` (UC:25-27): nav clicks, dropdown changes and keyboard moves dispatch `month-change` but the displayed month does not move. The caller moves it by setting the `month` Stimulus value (`data-shadcn--calendar-month-value`, ISO) on the root, which re-renders.

Focus model (UF:18-61, CFT:37-70, DP:156-198):
- State: `focused` (day or none) and `lastFocused`. Focus target (the only day button with `tabindex="0"`): among focusable days (not disabled, not hidden, not outside; CFT:18-22), priority lastFocused > first selected > today; if none, the first focusable day of the displayed months; if no focusable day exists, no button has tabindex 0.
- A day button `focus` event -> focused = that day (`data-focused="true"` + `rdp-focused` on its td, which activates the button's `group-data-[focused=true]/day:` ring). `blur` -> lastFocused = the CURRENT focused state, focused = none (UF:31-34). Update the state before calling `.focus()` on the next button: during a keyboard move the old button's blur then records the NEW day as lastFocused (React runs the blur handler of the re-rendered tree), so tabindex 0 follows the keyboard; after a first programmatic/mouse focus with no earlier blur, tabindex 0 stays on the selected/today day until the next blur (rdp behavior, keep it). Day identity includes the display month (CD:26-29): the outside copy of April 1 in the March grid is a different day than April 1 in the April grid.
- Mouse click on a day: `preventDefault` + `stopPropagation`, focused = that day (DP:156-165), then select unless disabled. The browser's own click focus also lands on it.
- `auto_focus`: focused starts as the focus target and that button is focused on connect (UF:22; scenario `mode-single__auto-focus`).
- When the focused day is no longer displayed (e.g. controlled month refused a move), focused becomes the current focus target and that button is focused (UF:23-30).
- Whenever focused changes to a rendered day, its button receives DOM focus (tsx `useEffect`), so keyboard moves and auto focus move real focus.

Keyboard (on day buttons only, `keydown`, DP:174-198; every listed key `preventDefault` + `stopPropagation`; Enter/Space are the native button click):

| Key | Move (GFD:17-44) |
|---|---|
| ArrowLeft / ArrowRight | -1 / +1 day; reversed when `dir: "rtl"` (only the `dir` kwarg counts, not the document direction) |
| Shift+ArrowLeft / Shift+ArrowRight | -1 / +1 month (same rtl swap) |
| ArrowUp / ArrowDown | -1 / +1 week |
| Shift+ArrowUp / Shift+ArrowDown | -1 / +1 year |
| PageUp / PageDown | -1 / +1 month |
| Shift+PageUp / Shift+PageDown | -1 / +1 year |
| Home / End | startOfWeek / endOfWeek of the focused day |
| Enter / Space | click -> select |
| Tab | native DOM order: prev, next, then per month its month/year selects (dropdown layouts) and, in the month holding it, the single focus-target day; then out |

Move algorithm (UF:35-49, GNF:21-37, UC:91-97): compute the candidate from the focused day; clamp it to navStart (moving before) or navEnd (moving after); while it matches `disabled` or `hidden` repeat the same move from it (max 365 attempts, then no move); with `disable_navigation` the candidate must already be displayed (same day AND display month) else nothing happens; if it is not displayed, `goToMonth(candidate)` (fires `month-change`); then focused = the candidate, which gets DOM focus. Months are clamped by `addMonths` (Jan 31 PageDown -> Feb 28).

Selection (only when the clicked day is not disabled; dispatch `select` with the new value; uncontrolled: the grid updates):
- single (USI:19-35): new = clicked day; if not `required` and it equals the current selection -> none.
- multiple (UMU:20-48): clicking a selected day removes it, except: count == `min` -> nothing (no event); `required` and only one selected -> nothing (no event). Clicking an unselected day: count == `max` -> selection becomes just that day; else append.
- range (URA:18-53, ATR:15-92): with `reset_on_select` and (complete range or no `from`): same-day single-day range click without `required` -> none, else `{ from: day }`. Otherwise addToRange: empty -> `{ from: day, to: (min > 0 ? nil : day) }`; from-only: same day -> `min == 0` ? `{from, to: day}` : `required` ? `{from}` : none; before from -> `{ from: day, to: from }`; after -> `{ from, to: day }`; complete: day == from == to -> `required` ? unchanged : none; day == from -> `{ from, to: (min > 0 ? nil : day) }`; day == to -> `{ from: day, to: (min > 0 ? nil : day) }`; before from -> `{ from: day, to }`; after from -> `{ from, to: day }`. Then if from and to: nights `> max` (max > 0) or `< min` (min > 1) -> `{ from: day }`. Then with `exclude_disabled` and a complete range that contains a disabled day (RCM:17-71) -> `{ from: day }`.
- Selection does not change the displayed month (clicking an outside day selects it and stays). `select` is dispatched once per accepted click; the inline `name:` inputs, the external `input:`/`label:` and `close_on_select` follow (API).

Pointer/hover: no JS hover behavior; hover styles are CSS (`hover:bg-accent`, `dark:hover:text-accent-foreground` on day buttons, button variant hover on nav). Disabled day buttons are native `disabled` (no click, no focus).

Live region: the caption span (label layout) or the hidden status span (dropdown layouts) is `role="status" aria-live="polite"` and its text changes in place on month change.

No timers, no scroll lock, no Presence, no positioning, no animation (`animate` is not ported).

Turbo/cleanup: `disconnect()` removes listeners; on connect the months container is rebuilt from scratch (keeping the server nav). A `month` value change or `today`/config value change re-renders.

## Third-party

React side: `react-day-picker` 10.0.2 (`DayPicker` with shadcn `classNames`, `formatters.formatMonthDropdown`, `components` Root/Chevron/DayButton/WeekNumber) on `date-fns` 4.1.0 and `@date-fns/tz` (unused without `timeZone`).
Port: NO third-party JavaScript (maintainer constraint): the `shadcn--calendar` Stimulus controller re-implements the rdp model above with `Date` and `Intl` (`DateTimeFormat`, `PluralRules`, `Locale#getWeekInfo`). It renders rdp's DOM exactly, including rdp's default class names (`rdp-root`, `rdp-months`, `rdp-month`, `rdp-nav`, `rdp-button_previous`, `rdp-button_next`, `rdp-chevron`, `rdp-month_caption`, `rdp-caption_label`, `rdp-dropdowns`, `rdp-dropdown_root`, `rdp-dropdown`, `rdp-months_dropdown`, `rdp-years_dropdown`, `rdp-month_grid`, `rdp-weekdays`, `rdp-weekday`, `rdp-week_number_header`, `rdp-weeks`, `rdp-week`, `rdp-week_number`, `rdp-day`, `rdp-day_button`, `rdp-focused`, `rdp-disabled`, `rdp-hidden`, `rdp-outside`, `rdp-today`, `rdp-selected`, `rdp-range_start`, `rdp-range_middle`, `rdp-range_end`, `rdp-footer`; GDC:11-30), because shadcn appends them to its own strings and the RTL classes target `.rdp-button_next` / `.rdp-button_previous`. No rdp stylesheet is loaded on either side (shadcn does not import `react-day-picker/style.css`), so the `rdp-*` classes carry no CSS.
Mapping rdp component -> port element: Root -> root `div` (server); Months -> `div.rdp-months` (server, empty); Nav/PreviousMonthButton/NextMonthButton/Chevron -> server `nav` + buttons + `Chadcn::Icon` (`chevron-left`/`chevron-right`, `chevron-down` in dropdowns with width/height 18); Month, MonthCaption, CaptionLabel, DropdownNav, Dropdown/MonthsDropdown/YearsDropdown/Select/Option, MonthGrid, Weekdays/Weekday, WeekNumberHeader, Weeks/Week, WeekNumber (shadcn `td` override), Day, DayButton (shadcn `CalendarDayButton` = `Calendar::DayButton` prototype), Footer -> cloned prototypes. rdp's own `Chevron` svg (polygons) never appears (shadcn overrides it with lucide).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Calendar` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Calendar::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Calendar::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `calendar.day_button` | `Calendar::DayButton` | `CalendarDayButton` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Chadcn::Button` (`Calendar::DayButton` renders it with `variant: "ghost", size: "icon"`) and `Chadcn::Button.variants(variant:)` for the nav button class (`buttonVariants({ variant: buttonVariant })`).
- `Chadcn::Icon` (`chevron-left`, `chevron-right`, `chevron-down`; lucide 0.577.0 like the catalog).
- `Chadcn::Popover` (+ `Trigger`, `Content`) only in the DatePicker composition and its scenarios; `close_on_select` talks to the existing `shadcn--popover` controller (no change to it).
- Scenarios also compose `Card`/`CardContent`/`CardFooter`, `Select*`, `Field*`, `InputGroup*` (docs examples; file-level `composes`).

## Deviations

Recorded in `gems/chadcn/dev/port/deviations/calendar.json`. Summary:
1. Structure: the root holds, besides `div.rdp-months`, an inert `<template data-shadcn--calendar-target="parts">` (prototypes) and, with `name:`, hidden inputs; Stimulus attributes on the root. None has a data-slot, classes on a box, or text, so the compared DOM is unchanged.
2. Rendering split: the server renders the root, months container and nav; the controller renders the rest in `connect()`. Before connect (no JS) only the shell and nav exist.
3. Locales: exact text/labels only for nil/`en`/`en-US` and `es`. Other tags use Intl approximations (dateStyle `full` for the day label, unsliced short weekday names, English labels for nav/dropdowns/week numbers/today/selected, `firstWeekContainsDate` from `weekInfo.minimalDays` or 1) where rdp 10 uses date-fns patterns and its own per-locale label translations.
4. API: function-valued props are not portable: `formatters` take Intl.DateTimeFormat option Hashes; `components` must be empty; matchers are data only; every `on*` callback except `onSelect`/`onMonthChange` (events) is dropped; `selected` is always the initial value (React semantics when no `onSelect` is passed); `month` is controlled through the Stimulus value; plus the not-ported list in API.
5. `Calendar::DayButton` rendered standalone (outside the calendar) writes `data-day` in the en-US `M/D/YYYY` form and does not focus itself for `modifiers: { focused: true }`.
6. Port-only API for forms (`name:`, `input:`, `label:`, `close_on_select:`) and the DatePicker composition (no oracle component).

Scenario notes: every Calendar scenario pins `today` (`$date:2026-03-15`) and a month (`defaultMonth`/`month`, or a pinned `today` for the initial-month cases); `CalendarDayButton` scenarios have no date dependency. Day targets use the td's ISO `data-day` (`td[data-day="2026-03-20"] button`). Native `<select>` changes are driven by `focus` + `type` (Chromium select typeahead fires `change`; arrow keys open the macOS popup instead). Docs examples are written as their closest data-only equivalent: `calendar-custom-days` without its `components.DayButton` price spans and `formatMonthDropdown` override; `calendar-range` with `disabled={[{after: today}, {before: 1900-01-01}]}` for its function matcher; `calendar-rtl` with `dir="rtl"` and the default locale (arSA/he are outside the exact locale set); `calendar-presets`/`date-picker-*` without their state handlers (so `month` stays controlled and the popovers stay uncontrolled); `initialFocus` omitted (no-op in rdp 10); the `calendar-time` clock icon without its `text-muted-foreground` class (string icons take no class). `calendar-hijri` is not a scenario: it renders its own copy of the component around `react-day-picker/persian` (Jalali calendar via date-fns-jalali), not `Calendar`.
