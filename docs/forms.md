# Forms

[chadcn](../README.md) docs, forms: `Chadcn::Form`, a form bound to a model, with shadcn's ids and ARIA contract and no react-hook-form.
The single controls (`Input`, `Select`, `Checkbox`...) are in [form controls](form-controls.md); this page is about binding them to
an object so that names, values, errors and ids are not written by hand.

## The three layers

shadcn's `form.tsx` is react-hook-form glue; what it really specifies is the ids and ARIA that one field derives for its label, control,
description and message. That contract is what is ported, in three layers that each replace the one below without touching the one above:

1. **A binding** (`Chadcn::Form::Binding`) answers the questions a field asks about one attribute: `name_for`, `id_for`, `value_for`,
   `errors_for`, `label_for`, `nested`, plus `action`, `http_method` and `csrf_token` for the root. `Chadcn::Form::Binding::Plain` (core)
   answers them for a Struct, a Hash or any object with readers; `Chadcn::Engine::FormBinding` (Rails only) answers them with a real
   `ActionView` form builder.
2. **`Chadcn::Form`** renders the only `<form>` (action, method, the `_method` hidden input, the CSRF hidden input) and yields itself.
3. **`Chadcn::Form::Field`** (`form.field(attribute: :email)`) asks the binding for name, id, value and errors, and offers the bound parts as
   helpers: `field.label`, `field.control`, `field.description`, `field.error` and the bound controls.

Core Phlex never names `Rails`; the binding is the only place that knows which world it is in.

## A form in plain Phlex

Give the form a `scope:` (the name prefix, so `user` gives `user[email]`), a `model:` (any object that answers the attribute readers)
and an `errors:` lookup (attribute => messages). `action:` and `method:` go to the `<form>`.

```ruby
user = Struct.new(:name, :email, :bio, :role, :country, :newsletter, :plan, :volume, :birthday, :website, keyword_init: true).new(
  name: "Ada", email: "ada@example", bio: "", role: "admin", country: "es", newsletter: true,
  plan: "pro", volume: 40, birthday: Date.new(1990, 3, 10), website: "example.com"
)
errors = { email: [ "is invalid" ] }

render Chadcn::Form.new(scope: :user, model: user, errors: errors, action: "/users/7", method: :patch, csrf_token: "token") do |form|
  form.field(attribute: :name) do |field|
    field.label
    field.input(required: true)
    field.error
  end

  form.field(attribute: :email) do |field|
    field.label
    field.input(type: "email")
    field.description { "We never share it." }
    field.error
  end

  form.field(attribute: :bio) do |field|
    field.label { "About you" }
    field.textarea(rows: 3)
    field.error
  end

  form.field(attribute: :role) do |field|
    field.label
    field.select do |select|
      select.trigger { select.value(placeholder: "Pick a role") }
      select.content do
        select.item(value: "admin") { "Admin" }
        select.item(value: "member") { "Member" }
      end
    end
  end

  form.field(attribute: :country) do |field|
    field.label
    field.native_select do |select|
      select.option(value: "es") { "Spain" }
      select.option(value: "mx") { "Mexico" }
    end
  end

  form.field(attribute: :newsletter, orientation: "horizontal") do |field|
    field.checkbox
    field.label { "Send me the newsletter" }
  end

  form.field(attribute: :plan) do |field|
    field.label
    field.radio_group(aria: { label: "Plan" }) do |group|
      group.item(value: "free", id: "plan-free")
      group.item(value: "pro", id: "plan-pro")
    end
  end

  form.field(attribute: :volume) do |field|
    field.label
    field.slider(max: 100, aria: { label: "Volume" })
  end

  form.field(attribute: :birthday) do |field|
    field.label
    field.date_picker(placeholder: "Birthday")
  end

  form.field(attribute: :website) do |field|
    field.label
    field.input_group do |group|
      group.addon { "https://" }
      group.input
    end
  end

  render Chadcn::Button.new(type: "submit") { "Save" }
end
```

Every `field.*` helper is the same as rendering its class (`field.input` is `render Chadcn::Form::Field::Input.new`), and the
attributes you pass win over the bound ones (`field.input(type: "email", required: true, class: "max-w-sm")`). A value a control cannot
express (an Array for a `select`, a String that is not a date for a `date_picker`) raises an `ArgumentError` that names the attribute.

| Helper | Renders | Notes |
|---|---|---|
| `field.label` | `Field::Label`, `for` the control id, `data-error` | the text is the binding's label unless you give a block |
| `field.control { \|attrs\| ... }` | nothing itself | yields the bound attributes, see the escape hatch below |
| `field.description` | `Field::Description` with the description id | |
| `field.error` | `Field::Error` with the message id | see "Errors" |
| `field.input`, `field.textarea` | `Input`, `Textarea` | `name`, `id`, `value`, `aria` |
| `field.select` | `Select` | the *trigger* carries the id and `aria`; the value is its `default_value` |
| `field.native_select` | `NativeSelect` | `multiple: true` accepts an Array and names the control `user[tags][]` |
| `field.checkbox`, `field.switch` | `Checkbox`, `Switch` | a hidden `unchecked_value:` input (default `"0"`, `nil` renders none) comes first |
| `field.radio_group` | `RadioGroup` | `id` and `aria` on the group; items keep their own ids; the group is not labelable, so pass `aria: { label: }` or `aria: { labelledby: }` |
| `field.slider` | `Slider` | a number is one thumb, an Array one thumb each; pass `aria: { label: }` |
| `field.date_picker` | `Popover` + `Calendar` | `placeholder:`, `calendar: { ... }`; a hidden input with an ISO date is submitted |
| `field.input_group` | `InputGroup` | `group.input` and `group.textarea` are bound |

The bound controls are uncontrolled: the value becomes the `default_value:` or `default_checked:`, never `value:` or `checked:`
(passing those makes the control controlled, and is yours to own). The hidden inputs of the checkbox, switch and date picker are
disabled together with their control.

## The id and ARIA contract

A field with the attribute `email` in the scope `user` renders:

```html
<form data-slot="form" data-controller="chadcn--form" action="/users" method="post">
  <div role="group" data-slot="field" data-invalid="true">             <!-- data-invalid only with an error -->
    <label data-slot="field-label" data-error="true" for="user_email-form-item">
    <input name="user[email]" id="user_email-form-item" aria-invalid="true"
           aria-describedby="user_email-form-item-description user_email-form-item-message">
    <p data-slot="field-description" id="user_email-form-item-description">
    <div role="alert" data-slot="field-error" id="user_email-form-item-message">
```

- The control id is `"#{binding id}-form-item"`, the description `...-description`, the message `...-message`, as in `form.tsx`. The binding
  id (`user_email`) is Rails' `field_id` for the engine binding and the same rule for `Plain`.
- **The control id is therefore not Rails' `user_email`.** `fill_in "user_email"` in a system test, `label_tag` and host JavaScript keyed on
  the Rails id do not find it; target `user_email-form-item` (or the label text, or the `name`). This is by design: it is what shadcn
  renders.
- `aria-invalid` is `"true"` or `"false"`; `aria-describedby` lists the description id and, only while there is an error, the message id.
- Ids are unique per scope, not per render. Two forms with the same scope on one page collide, so give each a `namespace:`
  (`Chadcn::Form.new(scope: :user, namespace: "signup")` gives `signup_user_email-form-item`; names do not change).
- `Chadcn::Form::Field` adds `data-invalid` to its root and `data-error` to its label so the shadcn classes
  (`data-[invalid=true]:text-destructive`, `data-[error=true]:text-destructive`) turn them red.

### `field.control`: your own control

`field.control` renders nothing; it yields the bound attributes (`name`, `id`, `value`, `aria`) merged with what you pass, which then
win. Use it for any element that has no bound part:

```ruby
product = Struct.new(:price).new(12)

render Chadcn::Form.new(scope: :product, model: product, action: "/products") do |form|
  form.field(attribute: :price) do |field|
    field.label
    field.control(data: { role: "price" }) do |attrs|
      render Chadcn::Input.new(**attrs, type: "number", min: 0, step: "0.01")
    end
    field.error
  end
end
```

## Form attributes: `method:`, GET forms and CSRF

- `Chadcn::Form.new(method:)` takes `get`, `post` (the default), `put`, `patch` or `delete`. A browser submits only `get` and `post`, so
  `put`, `patch` and `delete` render `method="post"` and a hidden `_method` input, as Rails does. Anything else raises `ArgumentError`.
- The form's keyword is `method:`; a binding answers the same question with `http_method` (lowercase, `"patch"`). With a `binding:` the form uses
  the binding's `action`, `http_method` and `csrf_token`, and any other kwarg (`method:`, `action:`, `scope:`...) raises `ArgumentError`.
- `csrf_token:` renders a hidden `authenticity_token` input, **never on a `get` form** (Rails does the same). With the engine binding the token
  comes from the view; nothing to pass.
- Any other attribute (`class:`, `id:`, `data:`, `novalidate: true`, `enctype:`) goes to the `<form>`; `class:` and `data:` merge.

## Errors

`errors_for(attribute)` answers an Array of messages. In `Plain` the `errors:` lookup is a Hash (symbol or string keys) or anything that
answers `[]`, such as `ActiveModel::Errors`. `field.error` maps them to `Chadcn::Field::Error`, one `{ message: }` each (several messages
render a list), inside the message element of the field:

```ruby
login = Struct.new(:email, :password).new("a@b.co")

render Chadcn::Form.new(scope: :login, model: login, errors: { email: [ "is invalid", "is taken" ] }, action: "/login") do |form|
  form.field(attribute: :email) do |field|
    field.label
    field.input(type: "email")
    field.error # a list of two messages
  end
  form.field(attribute: :password) do |field|
    field.label
    field.input(type: "password")
    field.error { "At least 12 characters." } # no errors: the block, rendered as is
  end
end
```

`field.error` has three cases: with errors it renders their messages (a block is ignored, the error wins); without errors and with a block it
renders the block; with neither it renders an empty hidden `role="alert"` element with the message id, so the id that
`aria-describedby` will list already exists when the browser validates.

## What the `chadcn--form` controller does

`Chadcn::Form` always renders `data-controller="chadcn--form"`. It mirrors the browser's HTML5 constraint validation (`required`, `type="email"`,
`pattern`, `min`...) into the same markup a server error produces, so a client error and a server error look and read the same:

- on `invalid` (the browser blocked a submit) it marks the form as attempted (`data-chadcn-form-attempted`) and, for the invalid control, sets
  the field's `data-invalid`, the label's `data-error`, the control's `aria-invalid="true"`, links the message id in `aria-describedby` and writes
  the browser's `validationMessage` in the message element;
- on `input`, `change` and the synthetic `click` of the hidden input of `Checkbox`, `Switch` and `RadioGroup` it re-evaluates once the form was
  attempted, when the field already shows an error (a server error hands over at the first edit of that control) or on `change`; a valid control
  clears all of it;
- `form.reset()` clears the mirrored state and the server-rendered errors, unless a later `reset` listener calls `preventDefault()`;
- a `novalidate` form is not re-validated on `input` or `change`; controls outside the form (`form="..."`) are not reached; a multi-control
  field (radios, an input group with two inputs) aggregates, each control keeping its own `aria-invalid`.

It declares no targets and no values and keeps all state in the DOM, so a Turbo cache restore keeps it. It never touches a message you wrote
(`field.error { ... }` renders without `data-chadcn-form-message`, the attribute that marks the elements the controller manages). Without
JavaScript everything above is still correct as a server render; no validation message is invented in Ruby. Strings come from the browser,
so they are in the user's locale.

## Nested objects and collections

`form.fields(attribute: :address)` binds an associated object and `form.fields(attribute: :addresses)` each element of a collection. The
fields are named like Rails nested attributes:

```ruby
address = Struct.new(:street, :city)
account = Struct.new(:name, :address, :addresses).new("Acme", address.new("1 Main St"), [ address.new("2 Elm St", "Leon"), address.new("", "Cadiz") ])
errors = { "addresses[1].street": [ "can't be blank" ] }

render Chadcn::Form.new(scope: :account, model: account, errors: errors, action: "/accounts", namespace: "billing") do |form|
  form.fields(attribute: :address) do |address| # account[address_attributes][street]
    address.field(attribute: :street) { |field| field.label; field.input; field.error }
  end

  form.fields(attribute: :addresses) do |address| # account[addresses_attributes][0][street], [1], ...
    address.field(attribute: :street) { |field| field.label; field.input; field.error }
    address.field(attribute: :city) { |field| field.label; field.input }
  end
end
```

- An enumerable (not a `Hash` or `Struct`) yields once per element with its row; `nil` or a single object yields once; an empty collection yields
  nothing. `index:` picks one row of a collection (an `Integer`) or, for a single object, becomes the row in the name
  (`form.fields(attribute: :address, index: "NEW_RECORD")`, the template row of a JavaScript "add" button). A block is required.
- Scopes nest: `address.fields(attribute: :phones) { |phone| ... }`. The `namespace:` is carried into every row.
- Inside a row block, `form.field` (the root) is bound to the **row**, like `address.field`; use the yielded scope to stay readable.
- Calling `form.fields` twice for the same association on one parent restarts the numbering at `0` for the second call: render a
  collection with one call, or give `index:`.
- `Binding::Plain` finds the errors of a row in the parent `errors:` under Rails' `index_errors` keys: `"addresses[0].street"` for a
  collection row and `"address.street"` for a single object. An explicit `errors:` on a nested binding of your own wins.
- After the block, the hidden inputs the nested binding asks for are rendered (`Binding#hidden_fields`): none for `Plain`; with the engine
  binding the `id` of a persisted child (`autocomplete="off"`), as `fields_for` does. A row block that renders its own `id` input gets a duplicate.

## In Rails

`Chadcn::Engine::FormBinding` is the binding for a host that runs Rails. It builds its own `ActionView::Helpers::FormBuilder` from the view
context and **never wraps `form_with`**: `Chadcn::Form` renders the only `<form>`, so putting it inside `form_with` nests two forms.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :addresses
  accepts_nested_attributes_for :addresses

  validates :name, :email, presence: true
end

# app/controllers/users_controller.rb
class UsersController < ApplicationController
  def edit = render Views::Users::Edit.new(user: User.find(params[:id]))

  def update
    user = User.find(params[:id])
    if user.update(params.expect(user: [ :name, :email, :bio, :role, :newsletter, { addresses_attributes: [ %i[id street city] ] } ]))
      redirect_to user
    else
      render Views::Users::Edit.new(user:), status: :unprocessable_entity
    end
  end
end

# app/views/users/edit.rb
class Views::Users::Edit < Views::Base
  def initialize(user:)
    @user = user
  end

  def view_template
    form_binding = Chadcn::Engine::FormBinding.new(view_context: helpers, model: @user)

    render Chadcn::Form.new(binding: form_binding) do |form|
      form.field(attribute: :name) do |field|
        field.label
        field.input(required: field.form_binding.required?(:name))
        field.error
      end

      form.field(attribute: :email) do |field|
        field.label
        field.input(type: "email", required: field.form_binding.required?(:email))
        field.description { "We never share it." }
        field.error
      end

      form.field(attribute: :newsletter, orientation: "horizontal") do |field|
        field.checkbox
        field.label
      end

      form.fields(attribute: :addresses) do |address|
        address.field(attribute: :street) { |field| field.label; field.input; field.error }
      end

      render Chadcn::Button.new(type: "submit") { "Save" }
    end
  end
end
```

`view_context:` is the object that answers the url helpers and the CSRF methods: `helpers` in a `phlex-rails` component, `self` in an ERB
template. `model:`, `scope:`, `url:`, `method:` and `namespace:` are the other keywords (`scope:` defaults to the model's `param_key`,
`url:` to `polymorphic_path(model)`, `method:` to `patch` for a persisted model and `post` otherwise). Pass the binding to the form
explicitly, as above: core has no global hook that fills it in.

What Rails still computes, and where it differs from `form_with`:

| | `form_with` | `Chadcn::Form` + `FormBinding` |
|---|---|---|
| `name` of a control | `field_name`: `user[email]`, `user[tags][]` | the same, from the same builder |
| `id` of a control | `user_email` | `user_email-form-item` (the label, the description and the message follow); the builder id is the base |
| action | `polymorphic_path(model)` | the same; `url:` overrides |
| verb | `patch` when persisted, hidden `_method` | the same; `method:` overrides |
| CSRF | hidden `authenticity_token` from the view | the same; none when forgery protection is off or the form is a `get` |
| errors | `field_with_errors` wrapper around the tag | `model.errors[attribute]` into `field.error`, `aria-invalid`, `data-invalid` and `data-error`; no wrapper |
| label text | `helpers.label.<scope>.<attribute>`, then `human_attribute_name` | the same translations |
| `required` | not set | `binding.required?(attribute)` (a plain presence validator, in the model's create/update context; `if:`/`unless:` never count); you pass it on |
| value | the reader of the model | the same, as the uncontrolled default (`value_for` calls the reader: never pass request input as the attribute) |
| nested attributes | `fields_for`, `user[addresses_attributes][0][street]`, hidden `id` | `form.fields`, the same names and hidden `id`; `_attributes` only when the model defines `addresses_attributes=` |
| submit button | `f.submit`, with i18n text | `render Chadcn::Button.new(type: "submit")`: the text is yours |

The engine binding does not re-read `*_before_type_cast`, so an integer attribute that was invalid after a failed save re-renders from the
cast value. In tests, `Chadcn::Engine::FormBinding` over a minimal `ActionView::Base` with url helpers and the forgery methods is enough
(`test/engine/form_test.rb` in the repository is the reference).

## Your own binding

Any object that includes `Chadcn::Form::Binding` and answers the nine messages works with `Chadcn::Form` unchanged: a presenter, a
form object, a hash from JSON. The defaults raise `NotImplementedError`, except `hidden_fields`, which defaults to none.

```ruby
require "chadcn"

class SearchBinding
  include Chadcn::Form::Binding

  def initialize(params) = @params = params
  def name_for(attribute, multiple: false) = "q[#{attribute}]#{'[]' if multiple}"
  def id_for(attribute) = "q_#{attribute}"
  def value_for(attribute) = @params[attribute]
  def errors_for(_attribute) = []
  def label_for(attribute) = attribute.to_s.capitalize
  def nested(_attribute, object:, index: nil, errors: nil) = raise(NotImplementedError)
  def action = "/search"
  def http_method = "get"
  def csrf_token = nil
end

Class.new(Phlex::HTML) do
  def view_template
    render Chadcn::Form.new(binding: SearchBinding.new(term: "phlex")) do |form|
      form.field(attribute: :term) { |field| field.label; field.input(type: "search") }
    end
  end
end.new.call
```
