# Form controls

Inputs, buttons and the `Field` layout primitives. Interactive ones carry a Stimulus controller (`shadcn--checkbox`,
`shadcn--switch`, `shadcn--radio-group`, `shadcn--toggle`, `shadcn--toggle-group`, `shadcn--slider`, `shadcn--input-group`,
`shadcn--label`) and dispatch `shadcn--<name>:<event>` events. Conventions: [api-conventions.md](api-conventions.md).

| Component | Root kwargs (besides `**attrs`) | Parts (class and generated helper) | Events |
|---|---|---|---|
| `Button` | `variant:` (`default`, `destructive`, `outline`, `secondary`, `ghost`, `link`), `size:` (`default`, `xs`, `sm`, `lg`, `icon`, `icon-xs`, `icon-sm`, `icon-lg`), `as_child:`; `Button.variants(variant:, size:, class:)` | none | |
| `ButtonGroup` | `orientation:` (`horizontal`, `vertical`); `ButtonGroup.variants` | `Separator` (`orientation:`) `button_group.separator`, `Text` (`as_child:`) `button_group.text` | |
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
render Phlex::Shadcn::Field::Group.new do
  render Phlex::Shadcn::Field.new do
    render Phlex::Shadcn::Field::Label.new(html_for: "email") { "Email" }
    render Phlex::Shadcn::Input.new(id: "email", type: "email", placeholder: "m@example.com", required: true)
    render Phlex::Shadcn::Field::Description.new { "We never share it." }
  end
  render Phlex::Shadcn::Field.new(orientation: "horizontal") do
    render Phlex::Shadcn::Checkbox.new(id: "terms", name: "terms")
    render Phlex::Shadcn::Field::Label.new(html_for: "terms", class: "font-normal") { "Accept the terms" }
  end
end

# generated helpers (Field::Group is a part of Field, so the group is rendered from a Field root or by its class)
render Phlex::Shadcn::Field.new do |field|
  field.label(html_for: "email") { "Email" }
  render Phlex::Shadcn::Input.new(id: "email", type: "email", placeholder: "m@example.com", required: true)
  field.description { "We never share it." }
  field.error(errors: [ "is invalid" ])
end
```

`Field::Error.new(errors:)` renders one message or a list, mirroring shadcn's `FieldError`: each entry has a `message` key (symbol or
string) or a `#message` method, blank messages are dropped, and a block replaces `errors:` with custom content.

## Example: radio group and toggle group

```ruby
render Phlex::Shadcn::RadioGroup.new(default_value: "comfortable", name: "density") do |group|
  %w[default comfortable compact].each do |value|
    div(class: "flex items-center gap-3") do
      group.item(value: value, id: "r-#{value}") { |item| item.indicator }
      render Phlex::Shadcn::Label.new(html_for: "r-#{value}") { value.capitalize }
    end
  end
end

render Phlex::Shadcn::ToggleGroup.new(type: "multiple", variant: "outline", default_value: %w[bold]) do |group|
  group.item(value: "bold", aria: { label: "Toggle bold" }) { render Phlex::Shadcn::Icon.new("bold") }
  group.item(value: "italic", aria: { label: "Toggle italic" }) { render Phlex::Shadcn::Icon.new("italic") }
end
```

## Example: buttons

```ruby
render Phlex::Shadcn::Button.new { "Default" }
render Phlex::Shadcn::Button.new(variant: :outline, size: :sm) { "Small outline" }
render Phlex::Shadcn::Button.new(variant: "destructive", disabled: true) { "Delete" }
render Phlex::Shadcn::Button.new(size: "icon", aria: { label: "Settings" }) { render Phlex::Shadcn::Icon.new("settings") }
render Phlex::Shadcn::Button.new(as_child: :a, href: "/docs", variant: "link") { "Documentation" }

# the class string alone (React buttonVariants)
a(href: "/more", class: Phlex::Shadcn::Button.variants(variant: "outline", size: "sm")) { "Read more" }
```

## Notes

- `Slider` dispatches `value-change` while dragging and `value-commit` when the pointer is released or a key is pressed, as Radix.
- `ToggleGroup.new(type:)` is required (React has no default); `variant:` and `size:` on the group cascade to its items, an item may
  override them.
- `InputGroup::Input` and `InputGroup::Textarea` are the plain `Input` / `Textarea` restyled for the group; `InputGroup::Button`
  defaults to `variant: "ghost", size: "xs"`.
- `Label` renders `<label data-slot="label">`; `html_for:` is React's `htmlFor` (`for:` is accepted too).
