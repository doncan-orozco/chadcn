# Field (`Chadcn::Field`)

Oracle: `dev/port/oracle/src/field.tsx` (style `new-york-v4`, manifest `source_sha` `4a4d17fcb933513f`, cited as `field.tsx:<line>`), manifest `dev/port/oracle/manifest/field.json`. Tier `static`: `"use client"` only because of `useMemo` in `FieldError` (field.tsx:3, 194); no Radix primitive of its own (manifest `radix_primitives: []`), no icons, no hooks beyond `useMemo`, no Stimulus controller of its own. Ten exports, ten parts: `Field`, `FieldLabel`, `FieldDescription`, `FieldError`, `FieldGroup`, `FieldLegend`, `FieldSeparator`, `FieldSet`, `FieldContent`, `FieldTitle`. Data-slots: `field`, `field-label` (on BOTH `FieldLabel` and `FieldTitle`), `field-description`, `field-error`, `field-group`, `field-legend`, `field-separator`, `field-separator-content`, `field-set`, `field-content`. One cva table, `fieldVariants` (field.tsx:57-79). Registry dependencies: `label`, `separator` (both specced). Registry examples (fetched from `https://ui.shadcn.com/r/styles/new-york-v4/<name>.json`): `field-demo`, `field-input`, `field-textarea`, `field-fieldset`, `field-radio`, `field-checkbox`, `field-switch`, `field-slider`, `field-select`, `field-choice-card`, `field-group`, `field-responsive`.

## API

Name rule (strip the `Field` prefix): `FieldSet` -> `Field::Set`, `FieldLegend` -> `Field::Legend`, `FieldGroup` -> `Field::Group`, `FieldContent` -> `Field::Content`, `FieldLabel` -> `Field::Label`, `FieldTitle` -> `Field::Title`, `FieldDescription` -> `Field::Description`, `FieldSeparator` -> `Field::Separator`, `FieldError` -> `Field::Error`.

```ruby
Chadcn::Field.new(orientation: "vertical", class: nil, **attrs) { ... }
Chadcn::Field::Set.new(class: nil, **attrs) { ... }
Chadcn::Field::Legend.new(variant: "legend", class: nil, **attrs) { ... }
Chadcn::Field::Group.new(class: nil, **attrs) { ... }
Chadcn::Field::Content.new(class: nil, **attrs) { ... }
Chadcn::Field::Label.new(html_for: nil, as_child: false, class: nil, **attrs) { ... }
Chadcn::Field::Title.new(class: nil, **attrs) { ... }
Chadcn::Field::Description.new(class: nil, **attrs) { ... }
Chadcn::Field::Separator.new(class: nil, **attrs) { optional children }
Chadcn::Field::Error.new(errors: nil, class: nil, **attrs) { optional children }

Chadcn::Field.variants(orientation: "vertical", class: nil) # => class string of fieldVariants
```

| part (tsx function) | Ruby class | kwargs (default) | source |
|---|---|---|---|
| `Field` | `Chadcn::Field` | `orientation:` (`"vertical"`), `class:`, `**attrs` | field.tsx:81-95, default `orientation = "vertical"` (83) and cva `defaultVariants` (76-78) |
| `FieldSet` | `Field::Set` | `class:`, `**attrs` (any `fieldset` attr: `disabled`, `name`, `form`) | field.tsx:10-22 |
| `FieldLegend` | `Field::Legend` | `variant:` (`"legend"`; `"legend"` \| `"label"`), `class:`, `**attrs` | field.tsx:24-42, default `variant = "legend"` (26) |
| `FieldGroup` | `Field::Group` | `class:`, `**attrs` | field.tsx:44-55 |
| `FieldContent` | `Field::Content` | `class:`, `**attrs` | field.tsx:97-108 |
| `FieldLabel` | `Field::Label` | everything `Chadcn::Label` accepts: `html_for:` (nil), `as_child:` (false), `class:`, `**attrs` | field.tsx:110-126, `React.ComponentProps<typeof Label>` |
| `FieldTitle` | `Field::Title` | `class:`, `**attrs` | field.tsx:128-139 |
| `FieldDescription` | `Field::Description` | `class:`, `**attrs` | field.tsx:141-154 |
| `FieldSeparator` | `Field::Separator` | `class:`, `**attrs`, block = children | field.tsx:156-184 |
| `FieldError` | `Field::Error` | `errors:` (nil), `class:`, `**attrs`, block = children | field.tsx:186-235 |

- `orientation:` accepts `"vertical"`, `:vertical`, `"horizontal"`, `:horizontal`, `"responsive"`, `:responsive` (shadcn-port R4); the string form is what lands in `data-orientation`. `nil` behaves like the default (JSON scenarios cannot express `undefined`). An unknown value is not rejected: like cva, it adds no variant classes and is written to `data-orientation` as given (no scenario, TS forbids it).
- `variant:` on `Field::Legend` accepts `"legend"`/`:legend`/`"label"`/`:label`; the string lands in `data-variant`. The size classes key off `data-variant` (`data-[variant=legend]:text-base`, `data-[variant=label]:text-sm`), not off Ruby, so there is no variant table for Legend.
- `class:` is merged through `cn` (tailwind_merge) after the part's classes; caller wins conflicts (R6). For `Field` the tsx does `cn(fieldVariants({ orientation }), className)` (field.tsx:91): one merge of `BASE + ORIENTATION[orientation] + class`. `Field.variants` mirrors `fieldVariants` (not exported by the tsx; provided per the `Component.variants` rule in api-mapping.md).
- `**attrs`: any attribute of the element (`id`, `title`, `role`, `style`, `aria: {}` / `"aria-*":`, `data: {}`), deep-merged. Data-attributes callers are expected to set and that the classes key off: `Field` `data-invalid="true"` (`data-[invalid=true]:text-destructive`) and `data-disabled="true"` (`group-data-[disabled=true]/field:opacity-50` on `FieldLabel`/`FieldTitle`); `FieldGroup` `data-slot="checkbox-group"` (`data-[slot=checkbox-group]:gap-3`, and the parent `FieldSet`'s `has-[>[data-slot=checkbox-group]]:gap-3`) and `data-variant="outline"` (`group-data-[variant=outline]/field-group:-mb-2` on `FieldSeparator`).
- `Field::Label` is a thin wrapper that renders `Chadcn::Label` (field.tsx:115-125): it passes `data-slot="field-label"`, `class: cn(FIELD_LABEL_CLASSES, class)` and every other kwarg/attr through unchanged, so `html_for:`, `for:`, `as_child:` (false | tag symbol | Chadcn component instance, Radix Slot via Label) behave exactly as in `dev/port/specs/label.md`. Inside the `Field` namespace the constants `Label` and `Separator` resolve to `Field::Label`/`Field::Separator`; the implementation must reference `Chadcn::Label` and `Chadcn::Separator` fully qualified.
- `Field::Error` `errors:` = React `errors?: Array<{ message?: string } | undefined>` (field.tsx:189-192). Each entry may be `nil`, a Hash with `:message` or `"message"` (the harness passes JSON string keys), or any object responding to `#message` (JS `error?.message` duck typing; e.g. `ActiveModel::Error`). Content algorithm, field.tsx:194-219, reproduced exactly:
  1. If children are given (the block's captured output is non-empty; React `if (children)` treats `""` as absent), the content is the children; `errors` is ignored.
  2. Else if `errors` is nil or empty: no content.
  3. Else dedupe by message preserving first-occurrence order (`new Map(errors.map(e => [e?.message, e])).values()`; `nil` entries and entries without a message share one key, `nil`/undefined).
  4. Exactly one unique entry: the content is its message as a bare text node (no `ul`); if that message is nil/empty, no content.
  5. Two or more: `<ul class="ml-4 flex list-disc flex-col gap-1">` with one `<li>` per unique entry whose message is truthy (entries without a message produce nothing).
  6. No content: the part renders NOTHING (no element, field.tsx:221-223).
- `Field::Separator` children: block. Present (non-empty capture) -> `data-content="true"` and the content span; absent -> `data-content="false"` and no span (`!!children`, field.tsx:166, 174).
- No `as_child:` except on `Field::Label` (no other part uses Slot). No events dispatched (no `on*` props). `ref` has no equivalent. `FieldLabel` in the `field-checkbox` example receives `defaultChecked`; React DOM never writes `defaultChecked` as an attribute on a `<label>`, so the port does not accept/forward it and the scenario omits it.

## Structure

Every part is server-rendered; nothing is set client-side except what `Chadcn::Label` itself wires (its `chadcn--label` controller/action, ignored by the parity runner). No ids generated, no `aria-*` added, no `data-state`. In every part the tsx writes its own attributes BEFORE `{...props}`, so a caller attr with the same name wins: `role`, `data-slot`, `data-orientation` (Field), `data-variant` (Legend), `data-content` (Separator). `className` is always destructured, so `class:` never replaces the base, it is merged. Scenarios `field__role-override`, `field__data-orientation-attr-override`, `field-legend__data-variant-override`, `field-separator__data-content-override`, `field-label__data-slot-override`.

```html
<fieldset data-slot="field-set" class="flex flex-col gap-6 has-[>[data-slot=checkbox-group]]:gap-3 has-[>[data-slot=radio-group]]:gap-3">
  <legend data-slot="field-legend" data-variant="legend" class="mb-3 font-medium data-[variant=legend]:text-base data-[variant=label]:text-sm">...</legend>
  <p data-slot="field-description" class="...">...</p>
  <div data-slot="field-group" class="group/field-group @container/field-group flex w-full flex-col gap-7 data-[slot=checkbox-group]:gap-3 [&>[data-slot=field-group]]:gap-4">
    <div role="group" data-slot="field" data-orientation="vertical" class="group/field flex w-full gap-3 data-[invalid=true]:text-destructive flex-col [&>*]:w-full [&>.sr-only]:w-auto">
      <label data-slot="field-label" for="email" class="(Label base merged with FieldLabel classes, see below)">Email</label>
      <input id="email">
      <p data-slot="field-description" class="...">...</p>
      <div role="alert" data-slot="field-error" class="text-sm font-normal text-destructive">...</div>
    </div>
    <div data-slot="field-separator" data-content="true" class="relative -my-2 h-5 text-sm group-data-[variant=outline]/field-group:-mb-2">
      <div data-orientation="horizontal" role="none" data-slot="separator" class="shrink-0 bg-border data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-px absolute inset-0 top-1/2"></div>
      <span class="relative mx-auto block w-fit bg-background px-2 text-muted-foreground" data-slot="field-separator-content">Or continue with</span>
    </div>
  </div>
</fieldset>
```

Per part (classes verbatim from the tsx, in source order):

| part | tag | data-slot | other attrs (server) | classes |
|---|---|---|---|---|
| `FieldSet` | `fieldset` | `field-set` | none | `flex flex-col gap-6` + `has-[>[data-slot=checkbox-group]]:gap-3 has-[>[data-slot=radio-group]]:gap-3` (field.tsx:15-16) |
| `FieldLegend` | `legend` | `field-legend` | `data-variant` = variant (field.tsx:32) | `mb-3 font-medium` + `data-[variant=legend]:text-base` + `data-[variant=label]:text-sm` (field.tsx:34-37) |
| `FieldGroup` | `div` | `field-group` | none | `group/field-group @container/field-group flex w-full flex-col gap-7 data-[slot=checkbox-group]:gap-3 [&>[data-slot=field-group]]:gap-4` (field.tsx:49) |
| `Field` | `div` | `field` | `role="group"`, `data-orientation` = orientation (field.tsx:88-90) | `fieldVariants` (below) |
| `FieldContent` | `div` | `field-content` | none | `group/field-content flex flex-1 flex-col gap-1.5 leading-snug` (field.tsx:102) |
| `FieldLabel` | `label` (via `Chadcn::Label`; the `as_child` element when given) | `field-label` (overrides Label's `label`) | `for` from `html_for:`/`for:`; Label's own attrs | FieldLabel classes (field.tsx:118-120) merged into Label's base (below) |
| `FieldTitle` | `div` | `field-label` (sic, same slot as FieldLabel, field.tsx:131) | none | `flex w-fit items-center gap-2 text-sm leading-snug font-medium group-data-[disabled=true]/field:opacity-50` (field.tsx:133) |
| `FieldDescription` | `p` | `field-description` | none | `text-sm leading-normal font-normal text-muted-foreground group-has-[[data-orientation=horizontal]]/field:text-balance` + `last:mt-0 nth-last-2:-mt-1 [[data-variant=legend]+&]:-mt-1.5` + `[&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary` (field.tsx:146-148) |
| `FieldSeparator` | `div` | `field-separator` | `data-content` = `"true"`/`"false"` (field.tsx:166) | `relative -my-2 h-5 text-sm group-data-[variant=outline]/field-group:-mb-2` (field.tsx:168) |
| (separator line) | `Chadcn::Separator.new(class: "absolute inset-0 top-1/2")`, first child of FieldSeparator, always rendered (field.tsx:173) | `separator` | Separator defaults: `data-orientation="horizontal"`, `role="none"` | Separator base + `absolute inset-0 top-1/2` |
| (separator content) | `span`, second child, only with children (field.tsx:174-181) | `field-separator-content` | attribute order in tsx: `class` then `data-slot` | `relative mx-auto block w-fit bg-background px-2 text-muted-foreground` |
| `FieldError` | `div`, or nothing (field.tsx:221-233) | `field-error` | `role="alert"` (field.tsx:227) | `text-sm font-normal text-destructive` (field.tsx:229) |
| (error list) | `ul` > `li`, only with 2+ unique errors (field.tsx:212-217) | none | none | `ml-4 flex list-disc flex-col gap-1` on the `ul`; `li` unstyled |

`fieldVariants` (manifest `cva.fieldVariants`, field.tsx:57-79):

- base: `group/field flex w-full gap-3 data-[invalid=true]:text-destructive`
- `orientation.vertical`: `flex-col [&>*]:w-full [&>.sr-only]:w-auto`
- `orientation.horizontal`: `flex-row items-center` `[&>[data-slot=field-label]]:flex-auto` `has-[>[data-slot=field-content]]:items-start has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px`
- `orientation.responsive`: `flex-col @md/field-group:flex-row @md/field-group:items-center [&>*]:w-full @md/field-group:[&>*]:w-auto [&>.sr-only]:w-auto` `@md/field-group:[&>[data-slot=field-label]]:flex-auto` `@md/field-group:has-[>[data-slot=field-content]]:items-start @md/field-group:has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px`
- defaultVariants `{ orientation: "vertical" }`; compoundVariants none. (The manifest token list also contains a stray `vertical`, an extraction artifact of the key name, not a class.)

Rendered class strings (tailwind-merge 2.6.1 from `dev/react-shadcn-catalog/node_modules`, computed for this spec; the port must reach them by merging through `cn`, never by hand-deduplicating):
- `Field` vertical: `group/field flex w-full gap-3 data-[invalid=true]:text-destructive flex-col [&>*]:w-full [&>.sr-only]:w-auto`; horizontal and responsive: base + the variant tokens unchanged (no conflicts).
- `FieldLabel` = `cn(LABEL_BASE, cn(FIELD_LABEL, class))` (FieldLabel merges its own `className` first, field.tsx:117-121, then Label merges the result after its base, label.tsx). With no `class:` the result is `items-center text-sm font-medium select-none group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed peer-disabled:opacity-50 group/field-label peer/field-label flex w-fit gap-2 leading-snug group-data-[disabled=true]/field:opacity-50 has-[>[data-slot=field]]:w-full has-[>[data-slot=field]]:flex-col has-[>[data-slot=field]]:rounded-md has-[>[data-slot=field]]:border [&>*]:data-[slot=field]:p-4 has-data-[state=checked]:border-primary has-data-[state=checked]:bg-primary/5 dark:has-data-[state=checked]:bg-primary/10` (Label's `flex`, `gap-2`, `leading-none` are replaced by FieldLabel's; `class: "font-normal"` additionally drops Label's `font-medium`, scenario `field-label__class-merge-font-normal`). Implementation: `render Chadcn::Label.new(**attrs, data: { slot: "field-label" }.merge(caller data), class: cn(FIELD_LABEL, class))`.
- `FieldSeparator` line: `shrink-0 bg-border data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-px absolute inset-0 top-1/2`.

DOM order: caller order for every part's children; parts never reorder, wrap or inject children, except `FieldSeparator` (Separator line first, then the optional span with the children) and `FieldError` (children, the bare message text, or the `ul`).

Composition semantics pinned by scenarios (all pure CSS, no JS):
- `[&>*]:w-full` / `[&>.sr-only]:w-auto` (vertical, responsive below md): `field__vertical__sr-only-label`.
- Horizontal: `[&>[data-slot=field-label]]:flex-auto` (`field__horizontal__label-flex-auto-then-control`); with a direct `FieldContent` child the row aligns `items-start` and a direct `[role=checkbox]`/`[role=radio]` child gets `mt-px` (`field__horizontal__with-content-checkbox`, `...-radio`), not without one (`field__horizontal__without-content-no-mt`).
- Responsive: the `@md/field-group` container query (28rem) of the nearest `FieldGroup` switches to a row (`field__orientation-responsive__wide`, `__narrow`, `__resize` with `viewport` steps, `example__field-responsive__narrow`); outside a FieldGroup it never switches (`field__orientation-responsive__outside-field-group`).
- `FieldLabel` wrapping a `Field` becomes a bordered card (`has-[>[data-slot=field]]:*`, `[&>*]:data-[slot=field]:p-4`) and turns primary when a descendant has `data-state="checked"` (`field-label__choice-card-checked`, dark twin for `dark:has-data-[state=checked]:bg-primary/10`, `field-label__choice-card-unchecked`).
- `FieldDescription`: `last:mt-0` (`field-description__last-child`), `nth-last-2:-mt-1` (`__nth-last-2`), `[[data-variant=legend]+&]:-mt-1.5` only after a `legend`-variant FieldLegend (`__after-legend` vs `__after-legend-label-variant`), `group-has-[[data-orientation=horizontal]]/field:text-balance` applies when the enclosing `group/field` element contains a horizontal-orientation descendant (`__group-has-horizontal-descendant` vs `__no-horizontal-descendant`), direct-child links only (`__with-link` with hover step, `__nested-link-not-direct-child`).
- States: `data-invalid="true"` on Field (`field__state-invalid`, dark twin, horizontal variant), `data-disabled="true"` dims FieldLabel and FieldTitle (`field__state-disabled`, dark twin; `"false"` does not, `field__state-disabled-false`), Label's `peer-disabled:*` still applies (`field-label__peer-disabled`). Native label activation: `field-label__click-focuses-control`, `field-label__click-activates-checkbox-fixture`; keyboard focus moves to the control (`field__focus-control__tab`), the label itself is not focusable.
- `FieldSet` gap shrinks to `gap-3` with a direct `[data-slot=checkbox-group]` or `[data-slot=radio-group]` child (`field-set__has-checkbox-group`, `field-set__has-radio-group`); a native `disabled` fieldset disables its controls (`field-set__disabled-attr`).
- `FieldGroup`: nested group gets `gap-4` (`field-group__nested`); `data-variant="outline"` pulls the separator up (`field-group__variant-outline-separator`).
- Dark mode: the only explicit `dark:` token is FieldLabel's; all other differences come from theme tokens (`--destructive`, `--muted-foreground`, `--primary`, `--border`, `--background`), covered by `__dark` twins (every `orientation` option has one).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Field` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Field::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Field::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `field.label` | `Field::Label` | `FieldLabel` |
| `field.description` | `Field::Description` | `FieldDescription` |
| `field.error` | `Field::Error` | `FieldError` |
| `field.group` | `Field::Group` | `FieldGroup` |
| `field.legend` | `Field::Legend` | `FieldLegend` |
| `field.separator` | `Field::Separator` | `FieldSeparator` |
| `field.set` | `Field::Set` | `FieldSet` |
| `field.content` | `Field::Content` | `FieldContent` |
| `field.title` | `Field::Title` | `FieldTitle` |

Names that shadow a Phlex HTML element inside `Field`'s OWN `view_template` (use `tag(:label)` there, never the bare method): `label`, `legend`, `title`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Chadcn::Label` (`Field::Label` renders it; spec `dev/port/specs/label.md`).
- `Chadcn::Separator` (`Field::Separator` renders `Separator.new(class: "absolute inset-0 top-1/2")` with its defaults `orientation: "horizontal"`, `decorative: true`; spec `dev/port/specs/separator.md`).
- No icons (`icons: []`). No primitives, no Stimulus controller of its own.

Example substitutions (scenario-level, identical on both harnesses, not component deviations): the coverage check only admits Field, Label and Separator exports, so the examples' other components are raw fixtures that keep the attributes Field's selectors read:
- `Input` -> `_input type="text"` (id, placeholder, required kept); `Textarea` -> `_textarea` (example classes kept); `Button` -> `_button type=...`; `form` -> `_form`.
- `Checkbox` -> `_button type="button" role="checkbox" aria-checked data-state id className="size-4 shrink-0 border"` (Radix Checkbox is a `button[role=checkbox][data-state]`, which is what `[role=checkbox]` and `has-data-[state=checked]` match). `RadioGroup` -> `_div role="radiogroup" data-slot="radio-group" className="grid gap-3"`; `RadioGroupItem` -> `_button role="radio" aria-checked data-state value id`; `Switch` -> `_button role="switch" aria-checked="false" data-state="unchecked"`.
- `Select`/`SelectTrigger`/`SelectItem` -> native `_select` with `_option`s; `Slider` (controlled `[200, 800]`) -> `_input type="range"` with the example's `aria-label` and classes, and the description renders the static values 200 / 800.
- `FieldLabel defaultChecked` (field-checkbox) is dropped (React writes nothing for it on a label).
Full compositions with the real Input/Checkbox/RadioGroup/Switch/Select/Slider/Textarea/Button belong to cross-component scenarios once those are DONE.

## Deviations

None for Field. `Field::Label` inherits Label's single API-only deviation (caller `mousedown` data-action is not suppressed for targets inside button/input/select/textarea; recorded in `dev/port/deviations/label.json`); it is not observable in any Field scenario and needs no `deviations/field.json`.
