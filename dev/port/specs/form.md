# Form (`Chadcn::Form`)

Oracle: `dev/port/oracle/src/form.tsx` (style `new-york-v4`, manifest `source_sha` `dfa22e6614b807df`, cited as `form.tsx:<line>`), manifest `dev/port/oracle/manifest/form.json`. Tier `third_party` (react-hook-form): there is no oracle DOM to compare, so the component is gated by Minitest and the browser tests of `chadcn--form`, not by G2 (`dev/port/deviations/form.json`). Decision, spike and alternatives: `dev/decisions/form.md`. Registry dependency: `label` (and, through the port, `field`, `input`).

Eight exports in the tsx: `useFormField`, `Form`, `FormItem`, `FormLabel`, `FormControl`, `FormDescription`, `FormMessage`, `FormField`. Only the ids/ARIA/data contract below is ported 1:1; the react-hook-form plumbing is replaced by a Binding.

## API

Built by #37 (root, Plain binding, bound Field), #38 (controls), #39 (client validity), #40 (Rails binding), #41 (nested).

```ruby
Chadcn::Form.new(binding: nil, scope: nil, model: nil, errors: {}, action: nil, method: "post", csrf_token: nil, class: nil, **attrs) { |form| ... }
Chadcn::Form::Binding                                  # protocol (module): name_for id_for value_for errors_for label_for nested action http_method csrf_token
Chadcn::Form::Binding::Plain.new(scope:, object: nil, errors: {}, action: nil, http_method: "post", csrf_token: nil)
Chadcn::Form::Binding::Rails.new(builder:)             # engine only; wraps an ActionView FormBuilder from form_with
Chadcn::Form::Field.new(attribute, binding:, orientation: "vertical", class: nil, **attrs) { |field| ... }

form.field(:email) { |field| ... }                     # => Chadcn::Form::Field bound to the form's binding
form.fields(:addresses) { |address| ... }              # #41: nested object / collection, one nested Form per row
```

| Ruby | React (tsx) | notes | source |
|---|---|---|---|
| `Chadcn::Form` | `Form` (`FormProvider`) | renders `<form>`; `binding:` or `scope:`/`model:`/`errors:` build a Plain binding; `**attrs` forwarded (`class:` merged) | form.tsx:19 |
| `Form#field(attribute, **kwargs)` | `FormField` (`Controller`) | yields a bound `Form::Field`; no render prop | form.tsx:32-44 |
| `Form::Field` | `FormItem` + `FormFieldContext` | root of one field, a `Chadcn::Field` (`data-slot="field"`); `form-item` slot dropped (deviation) | form.tsx:76-88 |
| `field.label` | `FormLabel` | `Chadcn::Field::Label`, `for` = form item id, `data-error` | form.tsx:90-105 |
| `field.control` / bound controls (`field.input`, `field.textarea`, ...) | `FormControl` | the control gets id, `name`, `value`, `aria-describedby`, `aria-invalid`; no `form-control` slot | form.tsx:107-123 |
| `field.description` | `FormDescription` | `Chadcn::Field::Description` with the description id | form.tsx:125-136 |
| `field.error` | `FormMessage` | `Chadcn::Field::Error` with the message id; renders nothing without error and without block | form.tsx:138-155 |
| `field.form_item_id` etc. | `useFormField()` | readers on the field | form.tsx:50-68 |

## Id / aria contract (the 1:1 core)

Per field the form generates `base`, one id unique per rendered field. React uses `React.useId()` (form.tsx:77); the port derives it from the binding (`binding.id_for(attribute)`, Rails and Plain agree: `user_email`), so it is stable across renders and unique per scope.

| Value | Rule | source |
|---|---|---|
| `form_item_id` | `"#{base}-form-item"`; the control's `id` and the label's `for` | form.tsx:61, 101, 113 |
| `form_description_id` | `"#{base}-form-item-description"`; the description's `id` | form.tsx:62, 131 |
| `form_message_id` | `"#{base}-form-item-message"`; the error's `id` | form.tsx:63, 149 |
| control `aria-describedby` | no error: `form_description_id`; with an error: `"#{form_description_id} #{form_message_id}"` (always lists the description id, even when no description is rendered, like React) | form.tsx:114-118 |
| control `aria-invalid` | `"true"` with an error, `"false"` without (React writes the boolean as a string) | form.tsx:119 |
| label `data-error` | `"true"` / `"false"`; the class `data-[error=true]:text-destructive` keys off it | form.tsx:99-100 |
| error content | the error message(s) when there is an error, else the block; no body: renders nothing | form.tsx:140-145 |
| `name` / `value` | from the binding (`name_for`, `value_for`); no counterpart in the tsx (react-hook-form's `Controller` spreads them) | form.tsx:32-44 |

Deliberate difference from the Field port: `Field` writes `data-invalid` on the root; the bound field writes both `data-invalid` (Field's class `data-[invalid=true]:text-destructive`) and the label's `data-error`.

## Behavior

`chadcn--form` (#39): mirrors HTML5 validity (`checkValidity`, `validationMessage`) into the same `aria-invalid`, `aria-describedby`, `data-error` and message element on `input`/`change`/`invalid`, so a client-side error and a server-side error render the same markup. Server errors win on first paint; client validity takes over after the first edit. Without the controller everything above is still correct (server render only).

## Out of scope

Validation schemas (`zod`, `@hookform/resolvers`), `Controller` render props, `useFormState`, field arrays of react-hook-form. Nested attributes (#41) replace field arrays.

Note on the derived section below: it is generated mechanically from the eight tsx exports and assumes one class per export. The port deliberately does not do that (`dev/port/deviations/form.json`): only `Form` and `Form::Field` are classes; `item`, `label`, `control`, `description` and `message` are helpers of the bound `Form::Field` (`field.label`, `field.control`, `field.description`, `field.error`), which compose the existing `Chadcn::Field` parts. #37 must not create `Form::Item`/`Form::Label`/`Form::Control`/`Form::Description`/`Form::Message`.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Form` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Form::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Form::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `form.item` | `Form::Item` | `FormItem` |
| `form.label` | `Form::Label` | `FormLabel` |
| `form.control` | `Form::Control` | `FormControl` |
| `form.description` | `Form::Description` | `FormDescription` |
| `form.message` | `Form::Message` | `FormMessage` |
| `form.field` | `Form::Field` | `FormField` |

Names that shadow a Phlex HTML element inside `Form`'s OWN `view_template` (use `tag(:label)` there, never the bare method): `label`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->
