# Decision: Chadcn::Form is three layers, a Binding protocol, a Form root and a bound Field

Status: proposed by the spike (item #36); built by #37 (Form, Binding::Plain, Form::Field), #38 (bound controls), #39 (`chadcn--form` controller), #40 (Chadcn::Engine::FormBinding), #41 (nested `form.fields`), #42 (docs). "As built" is added by the item that deviates.
Proof: `dev/spikes/form/plain_binding_test.rb` and `dev/spikes/form/rails_binding_test.rb` (counts in the Gate output of #36). The prototype they exercise is `dev/spikes/form/binding.rb`.

## Decision

shadcn's `form.tsx` is react-hook-form glue: `Form` is `FormProvider`, `FormField` is a `Controller`, and the real contract is the ids
and ARIA that `useFormField` derives for one field. That contract is what is ported (spec: `dev/port/specs/form.md`); react-hook-form is not.
The port is three layers, each replaceable without touching the one above it:

1. **Binding protocol** (`Chadcn::Form::Binding`): the questions a field asks about one attribute. Nine messages; `Plain` answers all of them in the spike and the Rails side is proven call by call (table below):
   `name_for(attribute, multiple:)`, `id_for(attribute)`, `value_for(attribute)`, `errors_for(attribute)`, `label_for(attribute)`,
   `nested(attribute, object:, index:, errors:)` and, for the root only, `action`, `http_method`, `csrf_token`.
   A binding is plain Ruby; nothing outside it knows whether Rails is loaded.
2. **Form root** (`Chadcn::Form`): renders `<form>` (action, `method`, the `_method` hidden input, the CSRF hidden input from the
   binding) and yields itself. It owns one binding and hands a child binding to nested forms.
3. **Bound field** (`Chadcn::Form::Field`): `form.field(attribute: :email) { |f| ... }`. It asks the binding for name, id, value and errors, composes
   the existing `Chadcn::Field`, `Label`, `Input`... parts, and applies the `form.tsx` id/aria contract once, so every control gets it
   for free (`f.label`, `f.control`, `f.description`, `f.error`, plus one generated helper per nested part of `Form::Field`: `Form::Field::Label`, `Control`, `Description`, `Error` and one class per bound control such as `Form::Field::Input`).

Two bindings ship: `Binding::Plain` (core) and `Chadcn::Engine::FormBinding` (`lib/chadcn/engine/form_binding.rb`, loaded only with Rails). The engine binding builds its own `FormBuilder` from the view context (`view_context:`, `model:`, `scope:`, `url:`, `method:`, `namespace:`), so `Chadcn::Form` renders the only `<form>`; using it inside `form_with` is unsupported (nested forms). Core Phlex never names `Rails`.

## What the spike proved

Plain (`plain_binding_test.rb`, no Rails loaded):

| Case | Result |
|---|---|
| name | `user[email]`; `user[tags][]` with `multiple: true` |
| id | `user_email` (scope and attribute joined with `_`) |
| value | read from a Struct reader, from a Hash with symbol or string keys; `nil` without an object |
| errors | Hash keyed by symbol or string; absent attribute answers `[]` |
| label | humanized attribute (`first_name` -> `First name`); the Rails binding overrides it with I18n |
| action / method / token | carried as given |
| nested object | `user[address_attributes][street]`, id `user_address_attributes_street` |
| namespace | an optional `namespace:` prefixes the id (`signup_user_email`) and nested bindings carry it; the name is unchanged |
| nested collection | `user[addresses_attributes][1][city]`, id `user_addresses_attributes_1_city`, errors scoped to the row |

Rails (`rails_binding_test.rb`, `rails`, `action_view` and `active_model` required, an in-process `RouteSet`, no database, no controller):

| Case | Result |
|---|---|
| `field_name` / `field_id` | `user[email]`, `user[tags][]`, `user_email`: identical to the Plain binding, so the two are interchangeable |
| `polymorphic_path` | `/users` for a new record, `/users/7` for a persisted one |
| `_method` | hidden `_method=patch` input only for a persisted record |
| CSRF | hidden `authenticity_token` input from the view's `form_authenticity_token` |
| label | `Model.human_attribute_name(:email)` is overridable through `activemodel.attributes.user.email` |
| errors / value | `object.errors[:email]` and the reader on the model |
| `fields_for` | `user[addresses_attributes][0][street]`, id `user_addresses_attributes_0_street`; a hidden `..._attributes][0][id]` input for a persisted child only |
| namespace | `FormBuilder.new("user", object, view, { namespace: "signup" }).field_id(:email)` is `signup_user_email`: the `"#{namespace}_#{id}"` rule Plain copies |
| GET form | `form_with(method: :get)` renders no `authenticity_token` input |
| `fields_for` hidden id | the hidden `..._attributes][0][id]` input comes after the child's own inputs |
| direct builder | `FormBuilder.new("user", object, view, {})` answers `field_name` and `field_id` like the one `form_with` yields, so the binding can build it itself |

Findings that shape the build:

- The builder needs a real view context: url helpers, `protect_against_forgery?`, `form_authenticity_token`,
  `request_forgery_protection_token`. A Phlex component receives it as `view_context:` from the caller (`helpers` under phlex-rails, `self` in ERB); `phlex-rails` is not a dependency.
- `fields_for` emits the hidden `id` input after the child's inputs, not before; the order is irrelevant to Rails but #41's tests must not assert it.
- Attribute order differs between helpers (`hidden_field` emits `value` before `name`; the `_method` and token tags emit `name` first); tests must match tags with lookaheads, not exact strings.
- The two nested-model constants had to be pinned with `model_name` because the spike nests them in a test class; a host's models do not need it.

## Alternatives considered

- **phlex-rails `form_with` inside a Buffered helper**: ties core Phlex to Rails and to ActionView's output buffer, and the output
  is Rails' markup (no `data-slot`, no shadcn classes). Rejected for the core; the Rails binding uses only the builder's answers, not its tags.
- **A `FormBuilder` subclass with one helper per control**: every control reimplements name/id/value/errors inside ERB-shaped helpers,
  needs Rails to test anything and cannot be used from a plain Phlex view. Rejected.
- **Superform**: a fine library with its own field model, but a runtime dependency with its own component tree and namespace;
  the port must stay 1:1 with the shadcn parts and standalone. Rejected as a dependency; its idea (a field object that knows name, id, value, errors) is what layer 3 is.
- **An ERB shim** (`render Chadcn::Input` inside `form_with`): the ids and aria of `form.tsx` would be hand-wired per template. Rejected.

## Open risks

- **G1 cannot waive missing parts or slots.** `static_gate.rb` `check_parts` and `check_slots` ignore the deviation file, so the moment `lib/chadcn/form.rb` exists G1 reports 5x `G1_PART_MISSING` and 5x `G1_SLOT_MISSING`. The tokens are waived in `form.json`; parts and slots need either a deviation-aware gate (a `structure`-driven waiver in `.claude/scripts/shadcn/static_gate.rb`, outside this item) or a decision to keep Form out of G1. Needs a maintainer decision before #37 merges.
- **Ids diverge from Rails.** The control id is `user_email-form-item` (form.tsx:61, 113), not Rails' `user_email`: `fill_in "user_email"`, `label_tag` and host JS keyed on Rails ids break. Documented in #42.
- **Id uniqueness.** `id_for` is unique per scope, not per render; two forms with one scope collide unless `namespace:` is given.
- **`_attributes` naming.** Rails emits `user[address_attributes]` only when the model defines `address_attributes=`; otherwise `user[address]`. Plain always appends `_attributes`, so the two bindings are interchangeable only for nested-attribute models (#41 tests both).
- **Who renders `<form>`.** `Chadcn::Form` does; the engine binding builds its own builder (see Decision). `form_with` plus `Chadcn::Form` would nest two forms.

## Not blocked

One human decision is needed: how G1 treats Form's absent parts and slots (Open risks). `DEVIATIONS.md` must list `form.json` (G5 `G5_DEVIATION_UNREGISTERED`, outside this item's Owns). `dev/port/specs/form.md` carries the derived DX helpers section from `spec_helpers.rb` unedited; only `form.field` maps to a real part.
