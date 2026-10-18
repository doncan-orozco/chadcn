# ButtonGroup (`Components::V2::ButtonGroup`, `ButtonGroup::Separator`, `ButtonGroup::Text`)

Oracle: `gems/phlex-shadcn/dev/port/oracle/src/button-group.tsx` (style `new-york-v4`, manifest `source_sha` a9ac862707ff8d78, tier `static`, `use_client: false`). Exports `ButtonGroup`, `ButtonGroupSeparator`, `ButtonGroupText`, `buttonGroupVariants`. Data-slots `button-group` and `button-group-separator` (ButtonGroupText has NO data-slot). Radix: `Slot` only (`import { Slot } from "radix-ui"`, radix-ui 1.7.0 -> `@radix-ui/react-slot` 1.4.0, `gems/phlex-shadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-slot/dist/index.mjs`, cited `slot.mjs:<line>`). The separator part renders shadcn `Separator` (`oracle/src/separator.tsx`) over `@radix-ui/react-separator` 1.1.16 (`react-separator/dist/index.mjs`, cited `sep.mjs:<line>`). cva semantics from `gems/phlex-shadcn/dev/react-shadcn-catalog/node_modules/class-variance-authority/dist/index.mjs` (cited `cva.mjs:<line>`). Registry examples fetched from `https://ui.shadcn.com/r/styles/new-york-v4/button-group-{demo,nested,size,separator,split,input,dropdown,select,popover,input-group,orientation}.json` (the full `button-group-*` list in the registry index).

## API

```ruby
Components::V2::ButtonGroup.new(orientation: nil, class: nil, **attrs) { ... }             # React ButtonGroup
Components::V2::ButtonGroup::Separator.new(orientation: "vertical", class: nil, **attrs)   # React ButtonGroupSeparator
Components::V2::ButtonGroup::Text.new(as_child: false, class: nil, **attrs) { ... }        # React ButtonGroupText
Components::V2::ButtonGroup.variants(orientation: nil)  # React buttonGroupVariants({ orientation }) -> class string
```

| part | kwarg | default (tsx) | accepted values |
|---|---|---|---|
| `ButtonGroup` | `orientation:` | `nil` (destructured with NO default; cva `defaultVariants.orientation = "horizontal"` supplies the classes) | `"horizontal"`, `"vertical"`, `:horizontal`, `:vertical`, `nil` |
| `ButtonGroup` | `class:` | `nil` (`className`) | merged through `cn` after `variants(orientation:)` |
| `ButtonGroup` | `**attrs` | `...props` (`React.ComponentProps<"div">`) | `id`, `title`, `role`, `aria: {}`, `data: {}`, `aria-*`, `data-*`, `style` |
| `ButtonGroup::Separator` | `orientation:` | `"vertical"` (tsx `orientation = "vertical"`, overriding Separator's `"horizontal"`) | `"vertical"`, `"horizontal"`, symbols |
| `ButtonGroup::Separator` | `class:` | `nil` | merged (see Structure) |
| `ButtonGroup::Separator` | `**attrs` | `...props` (`React.ComponentProps<typeof Separator>`) | everything `Components::V2::Separator` accepts: `decorative:` (default `true`, from separator.tsx), `as_child:`, `id`, `data: {}`, `aria: {}`... forwarded unchanged to `Components::V2::Separator` |
| `ButtonGroup::Text` | `as_child:` | `false` (`asChild = false`) | `false` \| tag symbol (`:label`, `:span`) \| a V2 component instance (e.g. a `Components::V2::Label` instance) |
| `ButtonGroup::Text` | `class:` | `nil` | merged through `cn` after the base string |
| `ButtonGroup::Text` | `**attrs` | `...props` (`React.ComponentProps<"div">`) | every HTML attribute |

- `variants(orientation:)` reproduces cva exactly (cva.mjs:23-27): `nil` -> default `"horizontal"` classes; `"horizontal"`/`"vertical"` (string or symbol, normalized with `to_s`) -> that entry; any other string -> no orientation classes at all (cva returns `variants[variant][key]` = undefined, it does NOT fall back to the default). Scenario `orientation-invalid-no-variant-classes`. JS `null` (cva.mjs:25) has no Ruby equivalent distinct from `nil`; not part of the API.
- `orientation:` on `ButtonGroup` is NOT normalized for the attribute: `data-orientation` renders the value given (`data-orientation={orientation}`), and is ABSENT when `orientation:` is `nil` (React omits `undefined` attributes). The port must not render `data-orientation="horizontal"` by default (scenario `defaults` vs `orientation-horizontal`).
- Blocks: `ButtonGroup` and `ButtonGroup::Text` yield children; an empty block renders an empty element (`children-empty`). `ButtonGroup::Separator` renders no children.
- Events: none dispatched. `ref`: no equivalent. No Stimulus controller (`shadcn--button-group` does not exist).

## Structure

Everything is server-rendered; Stimulus sets nothing.

```html
<!-- ButtonGroup, orientation: nil -->
<div role="group" data-slot="button-group" class="{variants(orientation: nil) + class}" ...attrs>children</div>
<!-- ButtonGroup, orientation: "vertical" -->
<div role="group" data-slot="button-group" data-orientation="vertical" class="..." ...attrs>children</div>

<!-- ButtonGroup::Separator (defaults) -->
<div data-orientation="vertical" role="none" data-slot="button-group-separator"
     class="shrink-0 data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:w-px relative m-0! self-stretch bg-input data-[orientation=vertical]:h-auto"></div>

<!-- ButtonGroup::Text -->
<div class="flex items-center gap-2 rounded-md border bg-muted px-4 text-sm font-medium shadow-xs [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4" ...attrs>children</div>
```

Part `ButtonGroup` (`data-slot="button-group"`):
- Tag `div`, `role="group"`, `data-slot="button-group"`, `data-orientation` only when `orientation:` is given. JSX order is `role`, `data-slot`, `data-orientation`, `className`, then `{...props}`, so caller attrs WIN over `role` (`role-override`: `role: "toolbar"`), `data-slot` (`data-slot-override`) and `data-orientation` (`data-orientation-override`: `data: { orientation: "vertical" }` with `orientation: nil` renders `data-orientation="vertical"` but keeps the horizontal classes). `class` is not overridable that way (it is destructured into `cn`).
- Class = `cn(buttonGroupVariants({ orientation }), className)`. cva joins base then the orientation entry (cva.mjs:54); verbatim tokens:
  - base: `flex w-fit items-stretch has-[>[data-slot=button-group]]:gap-2 [&>*]:focus-visible:relative [&>*]:focus-visible:z-10 has-[select[aria-hidden=true]:last-child]:[&>[data-slot=select-trigger]:last-of-type]:rounded-r-md [&>[data-slot=select-trigger]:not([class*='w-'])]:w-fit [&>input]:flex-1`
  - `horizontal`: `[&>*:not(:first-child)]:rounded-l-none [&>*:not(:first-child)]:border-l-0 [&>*:not(:last-child)]:rounded-r-none`
  - `vertical`: `flex-col [&>*:not(:first-child)]:rounded-t-none [&>*:not(:first-child)]:border-t-0 [&>*:not(:last-child)]:rounded-b-none`
  - No `compoundVariants`. The manifest token `horizontal` is the variant key, not a class.
- Caller `class` goes through `cn` last: `class: "w-full"` drops `w-fit` (`class-merge__w-full`); `class: "[--radius:9999rem]"` is kept and re-rounds every child via `--radius` (`class-merge__radius-var`, `example__button-group-input-group`).
- What the classes do (pure CSS, no JS), each with a scenario:
  - children lose inner radii and inner borders along the axis: first child keeps its leading radius, last child its trailing radius, middle children are square; `children-single` keeps all radii (it is both first and last), `children-two`, `children-five-sm`, `orientation-vertical`.
  - nested groups: `has-[>[data-slot=button-group]]:gap-2` adds a gap only when a DIRECT child is a `button-group`; the inner groups are themselves children, so the outer `[&>*]` rounding rules apply to the inner group elements (which have no border/radius of their own) (`nested-groups`, `nested-vertical-in-horizontal`, `nested-mixed-children`).
  - `[&>*]:focus-visible:relative [&>*]:focus-visible:z-10`: the keyboard-focused child is lifted so its ring is not covered by the next sibling (`focus-visible__tab-second`, `focus-visible__vertical-tab-second`, `input-focus-visible__click`).
  - `[&>input]:flex-1`: a direct `<input>` child grows (`input-flex-1`, inside a 360px wrapper; the group is `w-fit` so growth only shows when the input has its own `w-full`).
  - `[&>[data-slot=select-trigger]:not([class*='w-'])]:w-fit`: a direct select trigger without any `w-` substring in its class gets `w-fit` (`select-trigger-without-w-class`; `select-trigger-with-w-class` shows the trigger's own `w-fit` disabling the rule).
  - `has-[select[aria-hidden=true]:last-child]:[&>[data-slot=select-trigger]:last-of-type]:rounded-r-md`: when the group's last child is Radix Select's hidden native `<select aria-hidden="true">`, the last select trigger gets its right radius back even though it is not `:last-child` (`select-trigger-last-with-hidden-select` vs `select-trigger-last-without-hidden-select`).
- Not focusable itself; no `tabindex`, no ids, no `aria-orientation` (shadcn does not set it).

Part `ButtonGroupSeparator` (`data-slot="button-group-separator"`):
- Renders `Components::V2::Separator` (spec `gems/phlex-shadcn/dev/port/specs/separator.md`) with `data: { slot: "button-group-separator" }`, `orientation:` (default `"vertical"`), the merged class, then `**attrs`. tsx JSX order: `data-slot`, `orientation`, `className`, `{...props}`, so a caller `data-slot` wins (`separator-data-slot-override`), and `decorative:`/`as_child:`/`id` reach Separator unchanged (`separator-decorative-false`, `separator-as-child-span`, `separator-forwarded-attrs`).
- Separator then renders (sep.mjs:17-27; separator.tsx): tag `div`, `data-orientation` (normalized: `"vertical"` or `"horizontal"`), `role="none"` when decorative (default `true`), or `role="separator"` + `aria-orientation="vertical"` (vertical only) when `decorative: false`; `data-slot` = `"button-group-separator"` (separator.tsx writes `data-slot="separator"` before `{...props}`, so the button-group value wins).
- Class: ButtonGroupSeparator computes `cn("relative m-0! self-stretch bg-input data-[orientation=vertical]:h-auto", className)` and Separator computes `cn("shrink-0 bg-border data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-px", that)`. tailwind-merge resolves `bg-input` over `bg-border` and `data-[orientation=vertical]:h-auto` over `data-[orientation=vertical]:h-full`, giving the string in the Structure block. The port passes its own `cn(...)` result as `class:` to `Components::V2::Separator`, which merges it after its base: same resolved set. `class: "bg-primary w-0.5"` replaces `bg-input` and keeps `data-[orientation=vertical]:w-px` (different variant group) (`separator-class-merge`).
- Sizing: `self-stretch` + `h-auto` make it as tall as the row in a horizontal group; `w-px`. In a vertical group pass `orientation: "horizontal"` (`h-px w-full`) (`separator-horizontal-in-vertical-group`). Outside a group (`separator-standalone`) it stretches in its flex parent. The group's `[&>*:not(...)]` rules apply to it as a child (no visible effect: it has no border/radius).

Part `ButtonGroupText` (no data-slot):
- Tag `div` (`const Comp = asChild ? Slot.Root : "div"`), no `data-slot`, no role, no aria. The port must NOT invent a `data-slot` (the manifest lists none for this part).
- Class verbatim: `flex items-center gap-2 rounded-md border bg-muted px-4 text-sm font-medium shadow-xs [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4`, then caller `class` through `cn` (`text-class-merge`: `px-2` replaces `px-4`, `bg-primary` replaces `bg-muted`).
- `[&_svg:not([class*='size-'])]:size-4` sizes any descendant lucide SVG without a `size-*` class (`text-with-icon`, `text-icon-sized-not-overridden`).
- `as_child:` = Radix Slot (slot.mjs:81-104 `mergeProps`), implemented by `Components::V2::Base#render_as_child`: the child element replaces the `div`; `class` is a plain join, Text classes first then the child's (no tailwind-merge; `text-as-child-classname-join`), `style` slot-then-child, `aria-describedby` concatenated, all other child props win. `as_child: :label` renders `<label class="..." for=...>` (`text-as-child-label`, the docs pattern `ButtonGroupText asChild > Label htmlFor`).
- Inside a group it is a child like any other, so it loses inner radii/borders (`text-default`, `text-vertical-group`).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Phlex::Shadcn::ButtonGroup` MUST `yield self` from `view_template`; `Phlex::Shadcn::Base` generates one helper per nested part (`const_added`), each exactly `render ButtonGroup::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Phlex::Shadcn::ButtonGroup::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `button_group.separator` | `ButtonGroup::Separator` | `ButtonGroupSeparator` |
| `button_group.text` | `ButtonGroup::Text` | `ButtonGroupText` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Separator` (registry dependency, rendered by `ButtonGroup::Separator`).
- `Components::V2::Base` for `cn`, attribute merge and `render_as_child`.
- No icons, no sr-only text, no Stimulus, no primitives (`icons: []`, `text_literals: []`).
- Scenario substitutions (identical raw markup on both harnesses, not component deviations). The manifest's `registry_dependencies` is `["separator"]` (derived from imports), although the registry item lists `["button", "separator"]`; `scenario_coverage.rb` therefore rejects `Button`, `Input`, `Select*`, `DropdownMenu*`, `Popover*`, `InputGroup*` and `Tooltip*` nodes here. Group children are written as raw elements that carry the oracle class strings and attributes of those parts:
  - `Button variant=... size=...` -> `_button data-slot="button"` with `buttonVariants` base + variant + size tokens from `manifest/button.json` (gap/radius duplicates resolved as tailwind-merge does).
  - `Input` -> `_input data-slot="input"` with the three input.tsx class strings.
  - `SelectTrigger` (closed) -> `_button type=button role=combobox aria-expanded=false aria-autocomplete=none dir=ltr data-state=closed data-slot=select-trigger data-size=default` with the select.tsx trigger classes and a `<icon:chevron-down>` child (the oracle icon carries `size-4 opacity-50`; the string icon form cannot carry a class). The hidden native select is a raw `_select aria-hidden=true` with Radix's visually-hidden style.
  - `DropdownMenuTrigger asChild > Button` / `PopoverTrigger asChild > Button` (closed) -> the `_button` above plus `type=button aria-haspopup=menu|dialog aria-expanded=false data-state=closed` (ids omitted). Closed content renders nothing.
  - `InputGroup` / `InputGroupInput` / `InputGroupAddon align=inline-end` / `TooltipTrigger asChild > InputGroupButton size=icon-xs` -> raw `_div`/`_input`/`_button` with their input-group.tsx classes resolved.
  - `button-group-split` uses `IconPlus` from `@tabler/icons-react`; the scenario uses lucide `<icon:plus>`.
  - Real compositions (V2 `Button`, `Input`, `Select`, `DropdownMenu`, `Popover`, `InputGroup` inside `ButtonGroup`) belong to cross-component scenarios once those are DONE.

## Deviations

None. No `deviations/button-group.json` is written.
