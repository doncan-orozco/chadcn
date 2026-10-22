# Form controls

Inputs, buttons and the `Field` layout primitives. Interactive ones carry a Stimulus controller (`shadcn--checkbox`,
`shadcn--switch`, `shadcn--radio-group`, `shadcn--toggle`, `shadcn--toggle-group`, `shadcn--slider`, `shadcn--input-group`,
`shadcn--label`) and dispatch `shadcn--<name>:<event>` events. Conventions: [api-conventions.md](api-conventions.md).

| Component | Root kwargs (besides `**attrs`) | Parts (class and generated helper) | Events |
|---|---|---|---|
| `Button` | `variant:` (`default`, `destructive`, `outline`, `secondary`, `ghost`, `link`), `size:` (`default`, `xs`, `sm`, `lg`, `icon`, `icon-xs`, `icon-sm`, `icon-lg`), `as_child:`; `Button.variants(variant:, size:, class:)` | none | |
| `ButtonGroup` | `orientation:` (`horizontal`, `vertical`); `ButtonGroup.variants` | `Separator` (`orientation:`) `button_group.separator`, `Text` (`as_child:`) `button_group.text` | |
| `Calendar` | `mode:` (`single`, `multiple`, `range`, none = a plain grid), `selected:`, `default_month:`, `month:` (controlled), `today:`, `number_of_months:`, `caption_layout:` (`label`, `dropdown`, `dropdown-months`, `dropdown-years`), `show_outside_days:`, `fixed_weeks:`, `show_week_number:`, `week_starts_on:`, `locale:`, `dir:`, `disabled:`, `hidden:`, `modifiers:`, `modifiers_class_names:`, `class_names:`, `start_month:`, `end_month:`, `min:`, `max:`, `required:`, `exclude_disabled:`, `reset_on_select:`, `button_variant:`, `footer:`, `formatters:`, `name:`, `input:`, `label:`, `close_on_select:` | `DayButton` (`day:`, `modifiers:`) `calendar.day_button` | `select`, `month-change` |
| `Checkbox` | `checked:` (`true`, `false`, `"indeterminate"`), `default_checked:`, `disabled:`, `required:`, `name:`, `value:` (`"on"`), `form:` | none | `checked-change` |
| `Field` | `orientation:` (`vertical`, `horizontal`, `responsive`); `Field.variants` | `Set` `field.set`, `Legend` (`variant:` `legend`, `label`) `field.legend`, `Group` `field.group`, `Content` `field.content`, `Label` `field.label`, `Title` `field.title`, `Description` `field.description`, `Separator` `field.separator`, `Error` (`errors:`) `field.error` | |
| `Input` | `type:`, `default_value:` | none | |
| `InputGroup` | none | `Addon` (`align:` `inline-start`, `inline-end`, `block-start`, `block-end`) `input_group.addon`, `Button` (`type:`, `variant:`, `size:`, `as_child:`) `input_group.button`, `Text` `input_group.text`, `Input` `input_group.input`, `Textarea` `input_group.textarea` | |
| `Label` | `html_for:`, `as_child:` | none | |
| `NativeSelect` | `size:` (`default`, `sm`), `default_value:`, `value:` | `Option` `native_select.option`, `OptGroup` `native_select.opt_group` | |
| `RadioGroup` | `value:`, `default_value:`, `disabled:`, `required:`, `name:`, `form:`, `orientation:`, `dir:`, `loop:`, `as_child:` | `Item` (`value:`, `disabled:`...) `radio_group.item`, `Item::Indicator` `item.indicator` | `value-change` |
| `Switch` | `size:` (`default`, `sm`), `checked:`, `default_checked:`, `disabled:`, `required:`, `name:`, `value:`, `form:` | none | `checked-change` |
| `Textarea` | `default_value:`, `value:` | none | |
| `Toggle` | `variant:` (`default`, `outline`), `size:` (`default`, `sm`, `lg`), `pressed:`, `default_pressed:`, `disabled:`, `as_child:`; `Toggle.variants` | none | `pressed-change` |
| `ToggleGroup` | `type:` (`single` or `multiple`, required), `value:`, `default_value:`, `variant:`, `size:`, `spacing:`, `disabled:`, `roving_focus:`, `orientation:`, `dir:`, `loop:`, `as_child:` | `Item` (`value:`, `variant:`, `size:`...) `toggle_group.item` | `value-change` |
| `Slider` | `default_value:`, `value:` (arrays for ranges), `min:`, `max:`, `step:`, `orientation:`, `disabled:`, `inverted:`, `min_steps_between_thumbs:`, `preserve_thumb_order:`, `name:`, `form:`, `dir:`, `min_label:` ("Minimum"), `max_label:` ("Maximum"), `value_label:` ("Value %<index>d of %<count>d", a `Kernel.format` template for three or more thumbs) | none (track, range and thumbs are rendered from the values) | `value-change`, `value-commit` |

`checked:`, `value:` and `pressed:` are the controlled forms: the component renders that state and only dispatches the event; the
`default_*` keywords start uncontrolled. The checkbox, switch and radio group render the hidden `<input>` Radix adds when `name:` is
given, so they submit with a normal form.

## Example: a field with a native input, both forms

```ruby
# explicit classes
render Chadcn::Field::Group.new do
  render Chadcn::Field.new do
    render Chadcn::Field::Label.new(html_for: "email") { "Email" }
    render Chadcn::Input.new(id: "email", type: "email", placeholder: "m@example.com", required: true)
    render Chadcn::Field::Description.new { "We never share it." }
  end
  render Chadcn::Field.new(orientation: "horizontal") do
    render Chadcn::Checkbox.new(id: "terms", name: "terms")
    render Chadcn::Field::Label.new(html_for: "terms", class: "font-normal") { "Accept the terms" }
  end
end

# generated helpers (Field::Group is a part of Field, so the group is rendered from a Field root or by its class)
render Chadcn::Field.new do |field|
  field.label(html_for: "email") { "Email" }
  render Chadcn::Input.new(id: "email", type: "email", placeholder: "m@example.com", required: true)
  field.description { "We never share it." }
  field.error(errors: [ "is invalid" ])
end
```

`Field::Error.new(errors:)` renders one message or a list, mirroring shadcn's `FieldError`: each entry has a `message` key (symbol or
string) or a `#message` method, blank messages are dropped, and a block replaces `errors:` with custom content.

## Example: a calendar and a date picker

`Calendar` is shadcn's `Calendar` (react-day-picker) written with native `Date` and `Intl` only: no date library is shipped. Dates are
`Date`, `Time` or `"YYYY-MM-DD"` strings and are always read as local dates. The server renders the shell and the navigation; the
`shadcn--calendar` controller builds the months in the browser. It dispatches `shadcn--calendar:select` (`detail: { selected, date,
modifiers }`) and `shadcn--calendar:month-change` (`detail: { month }`), both bubbling.

```ruby
render Chadcn::Calendar.new(mode: :single, selected: Date.new(2026, 3, 15), class: "rounded-md border shadow-sm")

# a range over two months, weeks starting on Monday, weekends and the days before March 2026 disabled
render Chadcn::Calendar.new(
  mode: :range, number_of_months: 2, week_starts_on: 1, selected: { from: Date.new(2026, 3, 10), to: Date.new(2026, 3, 14) },
  disabled: [ { day_of_week: [ 0, 6 ] }, { before: Date.new(2026, 3, 1) } ]
)

# month and year dropdowns between two months, Spanish text, custom modifier
render Chadcn::Calendar.new(
  mode: :single, caption_layout: :dropdown, locale: :es, start_month: Date.new(2020, 1, 1), end_month: Date.new(2030, 12, 1),
  modifiers: { booked: [ Date.new(2026, 3, 16), Date.new(2026, 3, 17) ] }, modifiers_class_names: { booked: "line-through" }
)
```

There is no `DatePicker` component (shadcn has none either: its date pickers are examples). The composition is a `Popover`, a `Button`
trigger and a `Calendar`. Keep the form field OUTSIDE `Popover::Content`: the content is an inert `<template>` that is mounted into
`body` on open and removed on close, so anything inside it is not in the form. `input:` is the source of truth: the calendar reads the
input's value every time it opens and writes `YYYY-MM-DD` back (then dispatches bubbling `input` and `change`); `label:` is an element
whose text shows the formatted selection (its first text is the placeholder, and it gets `data-empty="true|false"` for styling);
`close_on_select: true` closes the popover once the selection is complete.

```ruby
date = Date.new(2026, 3, 10) # the model's value, nil when empty
# date-fns "PPP", the text the controller writes into the label: March 10th, 2026
ordinal = date && ((11..13).cover?(date.day % 100) ? "th" : { 1 => "st", 2 => "nd", 3 => "rd" }.fetch(date.day % 10, "th"))

form(action: "/events", method: "post") do
  input(type: "hidden", id: "event_date", name: "event[date]", value: date&.iso8601)
  render Chadcn::Popover.new do
    render Chadcn::Popover::Trigger.new(as_child: Chadcn::Button.new(variant: "outline", class: "w-[240px] justify-start text-left font-normal has-[[data-empty=true]]:text-muted-foreground")) do
      render Chadcn::Icon.new("calendar")
      span(id: "event_date_label", data: { shadcn__calendar_placeholder: "Pick a date", empty: date.nil?.to_s }) { date ? date.strftime("%B #{date.day}#{ordinal}, %Y") : "Pick a date" }
    end
    render Chadcn::Popover::Content.new(class: "w-auto p-0", align: "start") do
      render Chadcn::Calendar.new(mode: :single, selected: date, input: "#event_date", label: "#event_date_label", close_on_select: true)
    end
  end
end
```

The calendar only connects when the popover opens, so the server renders the label in its final state: the text, `data-empty`, and the
placeholder in `data-shadcn--calendar-placeholder` (the controller falls back to it when the selection is cleared; without the attribute
the label's first text becomes the placeholder, which is wrong when the label already shows a date). Format the text like the controller
does (`March 10th, 2026` for English; other locales use `Intl` `dateStyle: "long"`), or the label changes the first time it is used.
An `input:` or `label:` selector that matches nothing logs an error and is ignored; `input: { from:, to: }` is only valid for `mode: :range`.
An `input:` value that does not fully parse (in any mode) logs a warning and is read as no selection.

A range picker takes one selector per input (`input: { from: "#stay_from", to: "#stay_to" }`) or a single input holding
`YYYY-MM-DD/YYYY-MM-DD`; a multiple picker holds `YYYY-MM-DD,YYYY-MM-DD`. A calendar that is not inside a popover can submit by itself
with `name:`: it renders hidden inputs (`name`, `name[]` or `name[from]` and `name[to]`) that the controller keeps in sync. A multiple
calendar starts its `name[]` list with one blank value (like Rails' check box collections) so an empty selection still submits the key;
call `compact_blank` on the array.

```ruby
form(action: "/stays", method: "post") do
  render Chadcn::Calendar.new(mode: :range, name: "stay", selected: { from: Date.new(2026, 3, 10) }, number_of_months: 2)
  render Chadcn::Button.new(type: "submit") { "Book" }
end
```

## Example: radio group and toggle group

```ruby
render Chadcn::RadioGroup.new(default_value: "comfortable", name: "density") do |group|
  %w[default comfortable compact].each do |value|
    div(class: "flex items-center gap-3") do
      group.item(value: value, id: "r-#{value}") { |item| item.indicator }
      render Chadcn::Label.new(html_for: "r-#{value}") { value.capitalize }
    end
  end
end

render Chadcn::ToggleGroup.new(type: "multiple", variant: "outline", default_value: %w[bold]) do |group|
  group.item(value: "bold", aria: { label: "Toggle bold" }) { render Chadcn::Icon.new("bold") }
  group.item(value: "italic", aria: { label: "Toggle italic" }) { render Chadcn::Icon.new("italic") }
end
```

## Example: buttons

```ruby
render Chadcn::Button.new { "Default" }
render Chadcn::Button.new(variant: :outline, size: :sm) { "Small outline" }
render Chadcn::Button.new(variant: "destructive", disabled: true) { "Delete" }
render Chadcn::Button.new(size: "icon", aria: { label: "Settings" }) { render Chadcn::Icon.new("settings") }
render Chadcn::Button.new(as_child: :a, href: "/docs", variant: "link") { "Documentation" }

# the class string alone (React buttonVariants)
a(href: "/more", class: Chadcn::Button.variants(variant: "outline", size: "sm")) { "Read more" }
```

## Notes

- `Calendar` text is exact for the default locale and `es`; other `locale:` tags use `Intl` names with English labels (see its
  deviations). Functions cannot cross from Ruby, so `formatters:` take `Intl.DateTimeFormat` option hashes, matchers are data, and `month:`
  is moved by setting the `data-shadcn--calendar-month-value` attribute. `Calendar::DayButton` is the shadcn `CalendarDayButton`; the
  calendar clones one for every day.
- `Slider` dispatches `value-change` while dragging and `value-commit` when the pointer is released or a key is pressed, as Radix.
- `ToggleGroup.new(type:)` is required (React has no default); `variant:` and `size:` on the group cascade to its items, an item may
  override them.
- `InputGroup::Input` and `InputGroup::Textarea` are the plain `Input` / `Textarea` restyled for the group; `InputGroup::Button`
  defaults to `variant: "ghost", size: "xs"`.
- `Label` renders `<label data-slot="label">`; `html_for:` is React's `htmlFor` (`for:` is accepted too).
