# InputGroup (`Components::V2::InputGroup`)

Oracle: `gems/chadcn/dev/port/oracle/src/input-group.tsx` (style `new-york-v4`, source_sha `e379899ac50d6cab`, `"use client"`), manifest `gems/chadcn/dev/port/oracle/manifest/input-group.json`, registry item `gems/chadcn/dev/port/oracle/registry/input-group.json` (`registryDependencies: button, input, textarea`). Tier `static`: no Radix primitive, no shared primitive. Exports `InputGroup`, `InputGroupAddon`, `InputGroupButton`, `InputGroupText`, `InputGroupInput`, `InputGroupTextarea`; data-slots `input-group`, `input-group-addon`, `input-group-control` (InputGroupButton keeps Button's `button` slot, InputGroupText has none). Two cva tables, neither exported: `inputGroupAddonVariants` (axis `align`) and `inputGroupButtonVariants` (axis `size`). The one client behaviour is InputGroupAddon's `onClick` (tsx lines 71-76), ported as the tiny Stimulus controller `chadcn--input-group` described under Behavior. Line numbers below are tsx lines. Class merges were checked with the catalog's `tailwind-merge` 2.6.1 + `class-variance-authority` 0.7.1 (`gems/chadcn/dev/react-shadcn-catalog/node_modules`).

## API

```ruby
Components::V2::InputGroup.new(class: nil, **attrs) { parts }
Components::V2::InputGroup::Addon.new(align: "inline-start", class: nil, **attrs) { content }
Components::V2::InputGroup::Button.new(type: "button", variant: "ghost", size: "xs", as_child: false, class: nil, **attrs) { content }
Components::V2::InputGroup::Text.new(class: nil, **attrs) { content }
Components::V2::InputGroup::Input.new(class: nil, **attrs)            # void, block ignored
Components::V2::InputGroup::Textarea.new(class: nil, **attrs) { optional initial text }
```

| part | kwarg | default (tsx) | accepted values |
|---|---|---|---|
| `InputGroup` | `class:` | `nil` (`className`, line 11) | merged last through `cn` (`class: "rounded-xl h-12"` drops `rounded-md` and `h-9`) |
| `InputGroup` | `**attrs` | (`...props`, `React.ComponentProps<"div">`) | any `div` attribute; `id`, `data: {}`, `aria: {}`, `role` (spread after `role="group"`, line 34, so a caller `role:` wins), `"data-disabled": "true"` (see Structure) |
| `InputGroup::Addon` | `align:` | `"inline-start"` (line 62 `align = "inline-start"`, cva `defaultVariants` line 54) | `inline-start`, `inline-end`, `block-start`, `block-end`; strings or symbols, underscores normalized to the oracle hyphen key (`:inline_end` == `"inline-end"`); `nil` = default; unknown value raises `ArgumentError` |
| `InputGroup::Addon` | `class:` / `**attrs` | `nil` / (`...props`, `div`) | `class` merged last through `cn` after the cva output (line 70); attrs spread after `role`, `data-slot`, `data-align` and `onClick` (line 77) so caller `role`, `data-slot`, `data-align` override the attribute (classes still follow `align:`) |
| `InputGroup::Button` | `type:` | `"button"` (line 102) | any button type (`"submit"`, `"reset"`); always rendered |
| `InputGroup::Button` | `variant:` | `"ghost"` (line 103) | every `Components::V2::Button` variant: `default`, `destructive`, `outline`, `secondary`, `ghost`, `link` (passed through to Button, line 112) |
| `InputGroup::Button` | `size:` | `"xs"` (line 104, cva `defaultVariants` line 94) | `xs`, `sm`, `icon-xs`, `icon-sm` (`:icon_xs` == `"icon-xs"`); Button's own sizes are NOT accepted (`Omit<..., "size">`, line 106); unknown raises `ArgumentError` |
| `InputGroup::Button` | `as_child:` / `class:` / `**attrs` | `false` / `nil` / (`...props` = remaining Button props) | `as_child:` forwarded to `Components::V2::Button` (Button supports `asChild`); `class` merged through `cn` after the input-group size classes; attrs (`disabled`, `aria-label`, `title`, `aria-invalid`, `data`, `id`...) forwarded to Button, spread last (line 114) so a caller `"data-size":` overrides the size attribute |
| `InputGroup::Text` | `class:` / `**attrs` | `nil` / (`...props`, `span`) | `class` merged last through `cn`; any span attribute |
| `InputGroup::Input` | `class:` / `**attrs` | `nil` / (`...props`, `input`) | everything `Components::V2::Input` accepts (`type:`, `placeholder`, `value`, `disabled`, `readonly`, `required`, `maxlength`, `autocomplete`, `aria: { invalid: true }`, `id`, `name`...); a caller `"data-slot":` overrides `input-group-control` (spread after, line 142) |
| `InputGroup::Textarea` | `class:` / `**attrs` | `nil` / (`...props`, `textarea`) | everything `Components::V2::Textarea` accepts (`default_value:`, `value:`, block, `rows`, `placeholder`, `readonly`...) |

- Ruby class names: `InputGroup::Button`, `InputGroup::Input`, `InputGroup::Textarea` shadow the top-level V2 components inside the namespace; the implementation must reference `Components::V2::Button` / `Input` / `Textarea` fully qualified.
- React prop mapping (api-mapping.md): `readOnly` -> `readonly:`, `maxLength` -> `maxlength:`, `autoComplete` -> `autocomplete:`, `htmlFor` (on caller labels) -> `for:`, `defaultValue` on InputGroupInput -> `value:` (Input spec), on InputGroupTextarea -> `default_value:` (Textarea spec).
- No `as:`. `as_child:` exists only on `InputGroup::Button` (inherited from Button); the other parts never use `Slot`.
- Events dispatched: none (no `on*Change` prop). Caller DOM handlers use `data: { action: ... }`; for the Addon see the click-replacement rule under Behavior.
- No class methods: neither cva table is exported (`export { ... }` lists only the six parts). The tables live as private constants copied key for key.
- `ref`: no equivalent.

## Structure

All parts are server-rendered; Stimulus sets nothing on the DOM (`data-controller` / `data-action` are ignored by the parity runner). No ids generated, no `aria-*` wiring, no sr-only text, no icons owned by the component.

```html
<div data-slot="input-group" role="group" class="{cn(root, className)}" ...attrs>
  <input data-slot="input-group-control" class="..." ...>          <!-- InputGroup::Input -->
  <div role="group" data-slot="input-group-addon" data-align="inline-start" class="..."
       data-controller="chadcn--input-group" data-action="click->chadcn--input-group#focusControl" ...attrs>
    <span class="...">text</span>                                    <!-- InputGroup::Text -->
    <button data-slot="button" data-variant="ghost" data-size="xs" type="button" class="...">...</button>  <!-- InputGroup::Button -->
  </div>
</div>
```

DOM order is exactly the caller's block order. The addon is visually placed by `order-first` / `order-last`, never moved in the DOM (examples put the input first and the addon after it; tab order follows DOM, scenario `behavior__tab-order`).

### `InputGroup` (lines 11-38)
- `div`, attributes `data-slot="input-group"`, `role="group"`, `class`, then `**attrs`.
- Classes, verbatim, `cn` arguments of lines 17-30 in order, then caller `class:`:
  1. `group/input-group relative flex w-full items-center rounded-md border border-input shadow-xs transition-[color,box-shadow] outline-none dark:bg-input/30`
  2. `h-9 min-w-0 has-[>textarea]:h-auto`
  3. `has-[>[data-align=inline-start]]:[&>input]:pl-2`
  4. `has-[>[data-align=inline-end]]:[&>input]:pr-2`
  5. `has-[>[data-align=block-start]]:h-auto has-[>[data-align=block-start]]:flex-col has-[>[data-align=block-start]]:[&>input]:pb-3`
  6. `has-[>[data-align=block-end]]:h-auto has-[>[data-align=block-end]]:flex-col has-[>[data-align=block-end]]:[&>input]:pt-3`
  7. `has-[[data-slot=input-group-control]:focus-visible]:border-ring has-[[data-slot=input-group-control]:focus-visible]:ring-[3px] has-[[data-slot=input-group-control]:focus-visible]:ring-ring/50`
  8. `has-[[data-slot][aria-invalid=true]]:border-destructive has-[[data-slot][aria-invalid=true]]:ring-destructive/20 dark:has-[[data-slot][aria-invalid=true]]:ring-destructive/40`
- States are pure CSS on descendants: focus ring when the control matches `:focus-visible` (keyboard tab and pointer click on a text input/textarea); destructive border when ANY descendant with a `data-slot` has `aria-invalid="true"` (the control, but also an addon Button, scenario `state__aria-invalid-on-addon-button`); height `auto` with a textarea child or a block addon; `[&>input]` padding only applies to direct `input` children.
- Disabled styling is opt-in: the addon's `group-data-[disabled=true]/input-group:opacity-50` reacts to `data-disabled="true"` on the root, which the caller sets (example `input-group-spinner`: `<InputGroup data-disabled>`; React stringifies a `true` data attribute to `data-disabled="true"`). In Ruby the caller passes `"data-disabled": "true"` (or `data: { disabled: "true" }`); a bare boolean `true` would render a valueless `data-disabled` in Phlex and NOT match `[data-disabled=true]`, so the root must render boolean-true `data-*` values as the string `"true"` (Base attribute rule; scenarios use the string form).

### `InputGroup::Addon` (lines 39-81)
- `div`, attributes `role="group"`, `data-slot="input-group-addon"`, `data-align="{align}"` (resolved oracle spelling, always present, default `inline-start`), `class`, the Stimulus wiring (Behavior), then `**attrs`.
- Classes `cn(inputGroupAddonVariants({ align }), className)`:
  - base: `flex h-auto cursor-text items-center justify-center gap-2 py-1.5 text-sm font-medium text-muted-foreground select-none group-data-[disabled=true]/input-group:opacity-50 [&>kbd]:rounded-[calc(var(--radius)-5px)] [&>svg:not([class*='size-'])]:size-4`
  - `inline-start`: `order-first pl-3 has-[>button]:ml-[-0.45rem] has-[>kbd]:ml-[-0.35rem]`
  - `inline-end`: `order-last pr-3 has-[>button]:mr-[-0.45rem] has-[>kbd]:mr-[-0.35rem]`
  - `block-start`: `order-first w-full justify-start px-3 pt-3 group-has-[>input]/input-group:pt-2.5 [.border-b]:pb-3`
  - `block-end`: `order-last w-full justify-start px-3 pb-3 group-has-[>input]/input-group:pb-2.5 [.border-t]:pt-3`
  - `compoundVariants`: none. tailwind-merge resolves `justify-center` vs `justify-start` (block aligns keep `justify-start`); the port must produce the same final string by running the same `cn`.

### `InputGroup::Button` (lines 83-117)
- Renders `Components::V2::Button.new(type:, variant:, "data-size": size, class: cn(input_group_button_variants(size), class), as_child:, **attrs)`. Button's own `size:` is NOT passed (React passes no `size` to `<Button>`), so Button computes its `default` size classes and `data-size="default"`, and the forwarded `data-size` (spread after Button's own, Button spec "caller data-size overrides") yields the DOM `data-size="xs|sm|icon-xs|icon-sm"`. DOM: `<button data-slot="button" data-variant="{variant}" data-size="{size}" type="{type}" class="...">`.
- Input-group classes (`cn` inside line 113):
  - base: `flex items-center gap-2 text-sm shadow-none`
  - `xs`: `h-6 gap-1 rounded-[calc(var(--radius)-5px)] px-2 has-[>svg]:px-2 [&>svg:not([class*='size-'])]:size-3.5`
  - `sm`: `h-8 gap-1.5 rounded-md px-2.5 has-[>svg]:px-2.5`
  - `icon-xs`: `size-6 rounded-[calc(var(--radius)-5px)] p-0 has-[>svg]:p-0`
  - `icon-sm`: `size-8 p-0 has-[>svg]:p-0`
- That string becomes Button's `className`, merged by Button's `cn(buttonVariants({ variant, size: "default", className }))`. Reference final class for `variant: "ghost", size: "xs"` (tailwind-merge 2.6.1): `shrink-0 justify-center font-medium whitespace-nowrap transition-all outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 hover:bg-accent hover:text-accent-foreground dark:hover:bg-accent/50 py-2 flex items-center text-sm shadow-none h-6 gap-1 rounded-[calc(var(--radius)-5px)] px-2 has-[>svg]:px-2 [&>svg:not([class*='size-'])]:size-3.5`. Note `py-2` from Button's `default` size survives for `xs` and `sm` (px does not conflict with py) and is removed by `p-0` for the icon sizes; `icon-sm` keeps Button's `rounded-md`.

### `InputGroup::Text` (lines 119-129)
- `span`, NO `data-slot`, no role. Classes: `flex items-center gap-2 text-sm text-muted-foreground [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4`, then caller `class:`.

### `InputGroup::Input` (lines 131-145)
- Renders `Components::V2::Input.new("data-slot": "input-group-control", class: cn("flex-1 rounded-none border-0 bg-transparent shadow-none focus-visible:ring-0 dark:bg-transparent", class), **attrs)`. Input's own `data-slot="input"` is overridden by the forwarded attribute (Input spec: spread after), so the DOM carries `data-slot="input-group-control"`. Input's `type` is only rendered when given.
- Reference final class (no caller class): `h-9 w-full min-w-0 border-input px-3 py-1 text-base transition-[color,box-shadow] outline-none selection:bg-primary selection:text-primary-foreground file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground placeholder:text-muted-foreground disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 md:text-sm focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 flex-1 rounded-none border-0 bg-transparent shadow-none focus-visible:ring-0 dark:bg-transparent`.

### `InputGroup::Textarea` (lines 147-161)
- Renders `Components::V2::Textarea.new("data-slot": "input-group-control", class: cn("flex-1 resize-none rounded-none border-0 bg-transparent py-3 shadow-none focus-visible:ring-0 dark:bg-transparent", class), **attrs, &block)`; DOM `data-slot="input-group-control"`.
- Reference final class: `flex field-sizing-content min-h-16 w-full border-input px-3 text-base transition-[color,box-shadow] outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 md:text-sm dark:aria-invalid:ring-destructive/40 flex-1 resize-none rounded-none border-0 bg-transparent py-3 shadow-none focus-visible:ring-0 dark:bg-transparent`.

## Behavior

InputGroupAddon's click handler (lines 71-76), the only behaviour in the file:

```js
onClick={(e) => {
  if ((e.target as HTMLElement).closest("button")) return
  e.currentTarget.parentElement?.querySelector("input")?.focus()
}}
```

Port: Stimulus controller `chadcn--input-group` (`gems/chadcn/app/javascript/controllers/chadcn/input_group_controller.js`), host = each Addon element, action `click->chadcn--input-group#focusControl`. No values, no targets, no timers, no primitives composed.

- `focusControl(event)`: return if `event.target.closest("button")` (any button ancestor of the click target, including an `InputGroup::Button` and its svg, scenarios `behavior__addon-click-on-button-skips`, `behavior__addon-click-on-button-icon-skips`); otherwise `this.element.parentElement?.querySelector("input")?.focus()`.
- It queries `input` only: in a textarea group clicking the addon does nothing (scenario `behavior__addon-click-textarea-no-focus`); it focuses the FIRST `input` descendant of the parent, at any depth, even when another input was clicked (scenario `behavior__addon-click-first-input`); `focus()` on a disabled input is a no-op (scenario `behavior__addon-click-disabled-input`). No `preventDefault`, no `stopPropagation`.
- The focused input matches `:focus-visible` (text inputs always do), so the root ring appears (scenario `behavior__addon-click-focuses-input`). A `<label for>` inside the addon focuses its input natively; the handler then focuses the first input (same element in the example).
- Replacement rule (React spread semantics): `{...props}` comes after `onClick` (line 77), so a caller `onClick` REPLACES the focus handler, including the merged `onClick` a Radix trigger injects when the Addon is the `asChild` child of `PopoverTrigger`/`TooltipTrigger` (example `input-group-button`). The port mirrors this: if the caller `data-action` (after any `render_as_child` merge) contains a click descriptor (explicit `click->...`, or a descriptor without `->`, whose default event on a `div` is `click`), the Addon omits its own `click->chadcn--input-group#focusControl`; otherwise caller descriptors come first and the component's last. `data-controller` tokens are unioned (caller first, then `chadcn--input-group`). Unit-tested by the builder (not expressible in a JSON scenario: the React side cannot carry a JS handler).
- Keyboard: none added; tab order is the DOM order of the controls and buttons.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::InputGroup` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render InputGroup::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::InputGroup::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `input_group.addon` | `InputGroup::Addon` | `InputGroupAddon` |
| `input_group.button` | `InputGroup::Button` | `InputGroupButton` |
| `input_group.text` | `InputGroup::Text` | `InputGroupText` |
| `input_group.input` | `InputGroup::Input` | `InputGroupInput` |
| `input_group.textarea` | `InputGroup::Textarea` | `InputGroupTextarea` |

Names that shadow a Phlex HTML element inside `InputGroup`'s OWN `view_template` (use `tag(:button)` there, never the bare method): `button`, `input`, `textarea`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Button` (InputGroup::Button), `Components::V2::Input` (InputGroup::Input), `Components::V2::Textarea` (InputGroup::Textarea): all planned (`gems/chadcn/dev/port/specs/{button,input,textarea}.md`). Relies on their documented rules: caller `data-slot` / `data-size` override, `cn` merge of caller `class`, `as_child:` on Button.
- `Components::V2::Base` for `cn`, attribute merge and `render_as_child`.
- Scenarios use lucide icons through `<icon:...>`: `search`, `info`, `copy`, `arrow-up`, `plus`, `check`, `star`, `mail`, `credit-card`, `corner-down-left`, `file-code`, `refresh-cw`, `loader-circle`, `loader`, `circle-help`, `ellipsis`, `chevron-down`, `link-2` (all present in the catalog's lucide-react).
- Registry examples (fetched from `https://ui.shadcn.com/r/styles/new-york-v4/input-group-*.json` on 2026-10-09: `demo`, `button`, `icon`, `text`, `textarea`, `spinner`, `tooltip`, `dropdown`, `label`, `button-group`, `custom`), each as `example__input-group-<slug>` plus a `__dark` twin. Scenario-level substitutions, identical on both harnesses, not component deviations (the coverage check only admits exports of input-group, button, input, textarea):
  - `Tooltip`/`TooltipTrigger`/`TooltipContent`, `DropdownMenu*`, `Popover*` wrappers dropped; the `InputGroupButton` / `InputGroupAddon` they wrapped is rendered directly. Their interactive behaviour belongs to those components' own scenarios.
  - Tabler icons -> lucide: `IconInfoCircle`->`info`, `IconPlus`->`plus`, `IconCheck`->`check`, `IconCopy`->`copy`, `IconStar`->`star`, `IconCornerDownLeft`->`corner-down-left`, `IconRefresh`->`refresh-cw`, `IconBrandJavascript`->`file-code`; lucide `HelpCircle`->`circle-help`, `MoreHorizontal`->`ellipsis`, `LoaderIcon`->`loader` (its `animate-spin` dropped, motion is off). `IconCheck className="size-3"` -> `[&_svg]:size-3` on the wrapping `_div`.
  - `Spinner` -> `<icon:loader-circle>` (Spinner's `role`/`aria-label`/`size-4 animate-spin` dropped; the addon's `[&>svg...]:size-4` sizes it).
  - `Separator orientation="vertical" className="h-4!"` -> `_div` with `bg-border shrink-0 h-4! w-px`.
  - `Label` -> `_label` with Label's text classes (as in the input scenarios); `ButtonGroup`/`ButtonGroupText` -> `_div role="group"` / `_label` / `_div` with the horizontal ButtonGroup classes and ButtonGroupText classes copied from their oracles.
  - `TextareaAutosize` (input-group-custom) -> `_textarea` with the example's own `data-slot="input-group-control"` and classes (no autosize).
  - `onClick` handlers (copy to clipboard, favourite toggle) and the `data-favorite` icon state dropped.

## Deviations

None. No `deviations/input-group.json` is written. The Addon click-replacement rule above reproduces React's spread semantics instead of declaring a difference.
