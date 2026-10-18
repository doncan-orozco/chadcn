# NativeSelect (`Components::V2::NativeSelect`)

Oracle: `gems/phlex-shadcn/dev/port/oracle/src/native-select.tsx` (style `new-york-v4`, source_sha `4bdbce5575dce610`), manifest `gems/phlex-shadcn/dev/port/oracle/manifest/native-select.json`. Tier `static`: no Stimulus controller, no primitive, no Radix, no `"use client"`, no cva (`uses_cva: false`). Three exports: `NativeSelect`, `NativeSelectOption`, `NativeSelectOptGroup`. Five data-slots: `native-select-wrapper`, `native-select`, `native-select-icon` (all emitted by `NativeSelect`), `native-select-option`, `native-select-optgroup`. One icon: lucide `ChevronDownIcon` (lucide-react 0.577.0). Registry examples (ui.shadcn.com `r/styles/new-york-v4`): `native-select-demo`, `native-select-groups`, `native-select-disabled`, `native-select-invalid`. React DOM behaviour for `value`/`defaultValue` cited from `gems/phlex-shadcn/dev/react-shadcn-catalog/node_modules/react-dom/cjs/react-dom-client.development.js` (react-dom 19.3, `updateOptions` lines 1964-1987, select init lines 22313-22314), cited as `rdc:<line>`.

## API

```ruby
Components::V2::NativeSelect.new(size: "default", default_value: nil, value: nil, class: nil, **attrs) { options }
Components::V2::NativeSelect::Option.new(class: nil, **attrs) { label }
Components::V2::NativeSelect::OptGroup.new(class: nil, **attrs) { options }
```

Name rule: strip the root prefix (`NativeSelectOption` -> `NativeSelect::Option`, `NativeSelectOptGroup` -> `NativeSelect::OptGroup`).

### `Components::V2::NativeSelect` (tsx `NativeSelect`)

| kwarg | default (tsx) | accepted values |
|---|---|---|
| `size:` | `"default"` (destructured `size = "default"`, typed `"sm" \| "default"`) | `"default"`, `:default`, `"sm"`, `:sm`. Rendered verbatim as `data-size="{size}"` on the `<select>` (string form of the symbol). It is NOT the native HTML `size` attribute: the tsx type is `Omit<ComponentProps<"select">, "size">`, so the listbox-rows attribute cannot be passed (same in Ruby: `size:` is always consumed as the data-size). |
| `default_value:` | `nil` (React `defaultValue` via `...props`) | String (or an Array of strings when `multiple: true`). The matching `NativeSelect::Option` (by its `value` attribute, string compare) renders `selected=""`. Mirrors React: `defaultValue` runs `updateOptions(node, multiple, defaultValue, true)` (rdc:22314) which sets `option.defaultSelected = true` (rdc:1973, rdc:1980), i.e. the `selected` content attribute. Single mode stops at the first match (rdc:1979-1981). No match -> nothing marked (browser shows the first option, the same as React's fallback which only sets the property, rdc:1983-1985). |
| `value:` | `nil` (React `value` via `...props`) | Same values as `default_value:`. React controlled `value` sets only the `selected` PROPERTY (rdc:22313, `setDefaultSelected = false`), never the attribute. The server cannot set a property, so the port renders `selected=""` on the matching option exactly as for `default_value:`: identical selected option and visual, one extra attribute. Declared deviation (see Deviations). If both are given, `value:` wins (React warns and uses `value`, rdc:2006-2012 / 22312-22314). |
| `class:` | `nil` (`className`) | Merged through `cn` (tailwind_merge) as the LAST argument of the `<select>` classes, so the caller wins conflicts (`class: "rounded-full"` drops `rounded-md`). It applies to the `<select>`, NOT to the wrapper `div` (tsx passes `className` to `cn` of the select only). |
| `**attrs` | (`...props`, `ComponentProps<"select">`) | Every HTML attribute of a `select`, applied to the `<select>` (never to the wrapper): `id`, `name`, `disabled`, `required`, `multiple`, `autocomplete`, `form`, `tabindex`, `title`, `dir`, `data: {}`, `aria: {}` / `"aria-*":` (deep-merged; `aria: { invalid: true }` or `"aria-invalid": "true"` renders `aria-invalid="true"`). |

- Block = the select's children (`Option`s, `OptGroup`s), rendered inside `<select>`.
- Boolean attributes render like React: `disabled: true` -> `disabled=""`, `required: true` -> `required=""`, `multiple: true` -> `multiple=""`; `false`/`nil` omit them.
- The wrapper `div` and the icon take no caller input at all (tsx hard-codes their className and attributes; there is no `wrapperClassName`).
- No `as_child:` (no `Slot` in the source), no `as:`, no events dispatched (callers listen to native `change`/`input` via `data: { action: "change->foo#bar" }`), no `ref` equivalent, no class method (no `nativeSelectVariants` export).

### `Components::V2::NativeSelect::Option` (tsx `NativeSelectOption`)

| kwarg | default | accepted values |
|---|---|---|
| `class:` | `nil` | merged last through `cn` after `bg-[Canvas] text-[CanvasText]` |
| `**attrs` | (`...props`, `ComponentProps<"option">`) | `value`, `disabled`, `selected`, `label`, `id`, `data:`, `aria:` ... passed to `<option>` |

Block = option text. `selected` is computed from the parent's `default_value:`/`value:` (see above) unless the caller passes `selected:` explicitly (caller attr wins, React spread semantics; note React itself warns against `selected` on `<option>` and prefers `defaultValue`). The parent-to-option link must be render-scoped (e.g. a value the parent exposes while yielding its block, such as Phlex `context` or a fiber-local stack), never a client-side DOM rewrite.

### `Components::V2::NativeSelect::OptGroup` (tsx `NativeSelectOptGroup`)

| kwarg | default | accepted values |
|---|---|---|
| `class:` | `nil` | merged last through `cn` after `bg-[Canvas] text-[CanvasText]` |
| `**attrs` | (`...props`, `ComponentProps<"optgroup">`) | `label` (the group heading), `disabled`, `id`, `data:`, `aria:` |

Block = the group's `Option`s.

## Structure

Fully server-rendered; nothing is set client-side; no ids generated (only a caller `id:` for `<label for>`), no sr-only text, no `data-state`.

```html
<div class="group/native-select relative w-fit has-[select:disabled]:opacity-50" data-slot="native-select-wrapper">
  <select data-slot="native-select" data-size="{size}" class="{cn(base, focus, invalid, className)}" ...attrs>
    {block}
  </select>
  <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-chevron-down pointer-events-none absolute top-1/2 right-3.5 size-4 -translate-y-1/2 text-muted-foreground opacity-50 select-none" aria-hidden="true" data-slot="native-select-icon"><path d="m6 9 6 6 6-6"></path></svg>
</div>
```

Per part, in DOM order:

1. `native-select-wrapper` (`div`, tsx lines 11-14): class literal, not passed through `cn`, not mergeable: `group/native-select relative w-fit has-[select:disabled]:opacity-50`. Attributes: `class`, `data-slot` only. No caller attributes ever land here.
2. `native-select` (`select`, tsx lines 15-25): attribute order `data-slot="native-select"`, `data-size="{size}"`, `class`, then `...props`. Because the spread comes last, a caller `data-slot` or `data-size` in `**attrs` overrides the computed value (React spread semantics; scenario `attrs__data-size-override`). Classes, verbatim, the four `cn` arguments in order:
   1. `h-9 w-full min-w-0 appearance-none rounded-md border border-input bg-transparent px-3 py-2 pr-9 text-sm shadow-xs transition-[color,box-shadow] outline-none selection:bg-primary selection:text-primary-foreground placeholder:text-muted-foreground disabled:pointer-events-none disabled:cursor-not-allowed data-[size=sm]:h-8 data-[size=sm]:py-1 dark:bg-input/30 dark:hover:bg-input/50`
   2. `focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50`
   3. `aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40`
   4. caller `class:`
   Note `px-3` and `pr-9` coexist in the React output (tailwind-merge keeps `pr-9` after `px-3` because a later `pr` refines, it does not conflict backwards); the port must keep both, which `cn` does identically.
3. `native-select-icon` (`svg`, tsx lines 26-30): `render Components::V2::Icon.new(name: "chevron-down", class: "pointer-events-none absolute top-1/2 right-3.5 size-4 -translate-y-1/2 text-muted-foreground opacity-50 select-none", aria: { hidden: "true" }, data: { slot: "native-select-icon" })`. lucide 0.577.0 builds the class as `mergeClasses("lucide", "lucide-chevron-down", "lucide-chevron-down", className)` (createLucideIcon.js, Icon.js:32, duplicates removed), so the class starts `lucide lucide-chevron-down`. `aria-hidden="true"` is passed explicitly by the tsx (lucide would add it anyway, Icon.js:33). It is a sibling AFTER the `<select>`, positioned over its right padding (`pr-9`).
4. `native-select-option` (`option`, tsx lines 35-46): `data-slot="native-select-option"`, `class="{cn('bg-[Canvas] text-[CanvasText]', className)}"`, then `...props` (caller `data-slot` overrides). `selected=""` when it matches the parent `default_value:`/`value:`.
5. `native-select-optgroup` (`optgroup`, tsx lines 48-59): `data-slot="native-select-optgroup"`, `class="{cn('bg-[Canvas] text-[CanvasText]', className)}"`, then `...props`.

States, all pure CSS (pinned by scenarios):
- `data-size="sm"`: `data-[size=sm]:h-8 data-[size=sm]:py-1` (32px tall vs 36px).
- `focus-visible` (keyboard tab): `border-ring`, 3px `ring-ring/50`.
- `disabled`: the wrapper's `has-[select:disabled]:opacity-50` dims select AND icon together; the select gets `pointer-events-none cursor-not-allowed` and is skipped by tab. Disabled `OptGroup`/`Option` are native (greyed by the UA in the popup; the closed select is unaffected).
- `aria-invalid="true"`: `border-destructive`; ring colour `ring-destructive/20` (dark `/40`) visible only combined with focus-visible (`ring-[3px]`).
- Hover: the only hover token is `dark:hover:bg-input/50`, so hover is a no-op in light mode and changes the background in dark mode.
- Dark: `dark:bg-input/30`, `dark:hover:bg-input/50`, `dark:aria-invalid:ring-destructive/40`. Options/optgroups use the system colours `Canvas`/`CanvasText`, which follow `color-scheme` (relevant for the native popup only).
- `multiple`: the UA renders a listbox, but the `h-9` height is unchanged (rows clipped); identical on both sides.
- Known difference (accepted divergence, not covered by parity): a server-rendered `select[multiple]` with selected options starts scrolled to the first selected option, while React-inserted starts at scrollTop 0; scenario `multiple` therefore selects the first option (`todo`, no placeholder option) so both start at 0.
- `::selection`, `::placeholder`: tokens copied verbatim; no visible effect on a closed select.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Phlex::Shadcn::NativeSelect` MUST `yield self` from `view_template`; `Phlex::Shadcn::Base` generates one helper per nested part (`const_added`), each exactly `render NativeSelect::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Phlex::Shadcn::NativeSelect::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `native_select.opt_group` | `NativeSelect::OptGroup` | `NativeSelectOptGroup` |
| `native_select.option` | `NativeSelect::Option` | `NativeSelectOption` |

Names that shadow a Phlex HTML element inside `NativeSelect`'s OWN `view_template` (use `tag(:option)` there, never the bare method): `option`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Icon` (infra `_icons`): `Icon.new(name: "chevron-down", ...)` for `native-select-icon`, lucide 0.577.0 markup; must pass `data:`/`aria:` through.
- `Components::V2::Base` (`cn`, `merge_attrs`).
- No other V2 component (manifest `registry_dependencies: []`). Scenarios use raw `_label`, `_form`, `_button`, `_div` for layout and focus siblings.

## Deviations

One, API/attribute only, written to `gems/phlex-shadcn/dev/port/deviations/native-select.json`:
- Controlled `value:`: React sets only the `selected` property of the matching option (rdc:22313, `updateOptions(..., false)`), the Phlex server render can only express it as the `selected=""` attribute. The selected option, the closed select's text and `select.value` are identical; the DOM differs by that one attribute, only in scenario `controlled__value`. Uncontrolled `default_value:` has no deviation (React writes `defaultSelected`, i.e. the same attribute, rdc:1980).

```json
{ "reason": "React controlled value on <select> sets only option.selected (property, react-dom updateOptions with setDefaultSelected=false); a server render can only express it as the selected attribute, so value: renders selected=\"\" on the matching NativeSelect::Option. Selected option, displayed text and select.value are identical.", "allow_tokens": [], "allow_missing_tokens": [], "api": ["NativeSelect: value: renders selected=\"\" on the matching option (React sets only the selected property)"], "attributes": ["option[selected] when NativeSelect value: is used (scenario controlled__value)"] }
```
