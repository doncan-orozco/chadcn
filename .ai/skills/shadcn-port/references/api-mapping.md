# API mapping: React shadcn -> Phlex

One table, applied mechanically by the builder AND by the harness (`ShadcnParity::TreeRenderer` converts the JSON scenario tree with exactly these rules, so a wrong rule fails the gate).

| React | Phlex | Notes |
|---|---|---|
| `<Button variant="outline" size="sm">` | `render Chadcn::Button.new(variant: "outline", size: "sm") { "Click" }` | Strings and symbols both accepted (R4). |
| `className="x"` | `class: "x"` | Merged last via `cn` (tailwind_merge): caller wins. |
| `children` | block | Text, other components, `plain`/`raw` inside the block. |
| camelCase prop `defaultValue` | `default_value:` | `ariaLabel` is passed as `aria: { label: }` or `"aria-label":`; both accepted. |
| `data-foo="x"`, `aria-*`, `role`, `id`, `type`, `disabled`... | same keys through `**attrs` | `data: {}` / `aria: {}` hashes deep-merged with component defaults; `Base#merge_attrs` maps React DOM props (`tab_index:`, `read_only:`, `max_length:`, `html_for:`...) to their HTML names and renders boolean aria/data values as `"true"`/`"false"` like React. |
| `asChild` | `as_child:` | `false` (default) \| a tag symbol (`as_child: :a`, the part renders that tag with its own classes, `data-slot` and attrs) \| a V2 component **instance** (`as_child: Chadcn::Button.new(variant: "outline")`, Radix `Slot` semantics via `Chadcn::Base#render_as_child`). |
| `disabled` boolean | `disabled: true` | Renders attribute exactly like React (`disabled=""`). |
| `open` / `onOpenChange` | `open:` (initial/controlled) + event `chadcn--dialog:open-change` with `detail: { open }` | Controlled mode = the server renders the next state; client mode = Stimulus value. |
| `defaultOpen` | `default_open:` | |
| `value` / `defaultValue` / `onValueChange` | `value:` / `default_value:` / event `chadcn--<name>:value-change` (`detail: { value }`) | |
| `checked` / `onCheckedChange` | `checked:` / event `chadcn--<name>:checked-change` | `checked: "indeterminate"` supported where Radix supports it. |
| `onClick` etc. | plain DOM events; use `data: { action: "click->foo#bar" }` | No JS callbacks in Ruby. |
| `ref` | `data: { <controller>_target: ... }` or no equivalent | Not part of the API. List in the spec if React callers rely on it. |
| Compound exports `Dialog`, `DialogTrigger`, `DialogContent`... | `Chadcn::Dialog`, `Dialog::Trigger`, `Dialog::Content`... | Rule: strip the root name prefix. Exceptions (`buttonVariants`, `useSidebar`) map to class methods: `Chadcn::Button.variants(variant:, size:)` returns the class string. |
| `cva` variants | class-level table + `Component.variants(**opts)` | Keys identical to React (`"icon-sm"`). |
| `cn(...)` | `cn(...)` from `Chadcn::Base` | Same semantic (clsx + tailwind-merge). |
| lucide icons (`<XIcon />`) | `render Chadcn::Icon.new(name: "x")` rendering the exact lucide SVG (`class`, `size-4`, `aria-hidden`) | Icon set must be the same lucide version as the catalog. |
| `useIsMobile()` and other hooks | Stimulus value/helper in the owning controller | Document in the spec. |

## Example: Button

```tsx
<Button variant="outline" size="sm" className="shrink-0" onClick={...}>Save</Button>
```
```ruby
render Chadcn::Button.new(variant: "outline", size: "sm", class: "shrink-0", data: { action: "click->foo#save" }) { "Save" }
```
Must emit `<button data-slot="button" class="...tokens identical to React...">Save</button>`.

## Example: Dialog (compound)

```tsx
<Dialog>
  <DialogTrigger asChild><Button variant="outline">Open</Button></DialogTrigger>
  <DialogContent><DialogHeader><DialogTitle>Hi</DialogTitle></DialogHeader></DialogContent>
</Dialog>
```
```ruby
render Chadcn::Dialog.new do
  render Chadcn::Dialog::Trigger.new(as_child: Chadcn::Button.new(variant: "outline")) { "Open" }
  render Chadcn::Dialog::Content.new do
    render Chadcn::Dialog::Header.new { render Chadcn::Dialog::Title.new { "Hi" } }
  end
end
```

## `as_child` = Radix Slot merge (implemented once in `Chadcn::Base`)

`render_as_child(child, **slot_attrs, &block)` merges the parent part's computed attributes (`slot_attrs`: aria, `data-state`, `data-action`, `id`...) into the child's attributes with exactly Radix `mergeProps` semantics: **child props win** (so the child's `data-slot="button"` is kept), `class` is a PLAIN join, slot first then child, `[slot, child].compact_blank.join(" ")`, with NO tailwind-merge and no conflict resolution (Radix `mergeProps` does exactly `[slotPropValue, childPropValue].filter(Boolean).join(" ")`; resolving conflicts would drop a class that the React DOM keeps, so the class sets would differ), `data-action` descriptors are concatenated with the child's first then the slot's (Radix calls the child's handler, then the slot's), `style` is merged slot-then-child (child wins), `aria-describedby` ids are concatenated child first, then slot, deduplicated and space-joined, `nil` when empty (react-slot 1.4.0 `concatAriaDescribedby`; only when the child has the prop, otherwise the slot's value passes through), Stimulus `data-controller` tokens are UNIONED (slot first, so a nested trigger keeps both controllers), everything else child-over-slot. This is DIFFERENT from `merge_attrs`, which is for a component's own default classes plus the caller's `class:` and does go through `cn`. Verified against `@radix-ui/react-slot/dist/index.mjs` `mergeProps`. Then it renders the child with the block. `as_child: :tag` is the degenerate case (no child component): same merge against a bare element. Parts never implement this themselves.

The scenario `tree` uses `"asChild": true` with one child node; the Phlex harness converts that child into the instance passed to `as_child:`, React renders real `asChild`, and the DOM is compared.

## Result of each rule must be observable

For each row above the scenario set contains at least one scenario that exercises it. If a rule cannot be mapped 1:1, it is a **deviation**: write `deviations/<name>.json` (`{ "reason": "...", "allow_tokens": [], "allow_missing_tokens": [], "api": ["..."] }`) and list it in DEVIATIONS.md. Undeclared differences fail the gates.

## Parts that render no element

Radix `Root`/`Sub`/`Provider`/`Portal` parts (Dialog, AlertDialog, DropdownMenu, ContextMenu, Popover, Tooltip, HoverCard, Select, Menubar.Menu, every Portal) render nothing: shadcn's `data-slot` on them never reaches the DOM. Their Ruby class exists (same API, same nesting) but emits **no element and no `data-slot`**; it only yields its block (and computes ids / controller wiring for its children). The manifest lists such slots under `non_rendered_slots`; G1 does not require them and G2 fails if they are rendered. If a controller needs a host and the Trigger cannot be it (Dialog), the port may add one `display: contents` element without `data-slot`/classes, recorded in `deviations/<name>.json`. Content that Radix leaves unmounted (closed overlays, unloaded avatar images, hidden scrollbars...) is shipped in an inert `<template>` at its JSX position and mounted/unmounted ONLY through the shared `template_mount` primitive; builders must not hand-roll cloning/portalling. See radix-dom-contract.md "Verified corrections".

## DX helpers (yielded root)

Beside the 1:1 nested classes the root offers generated helpers: `render Chadcn::Table.new do |table| table.header { table.row { table.head { ... } } } end`. Rules: the root `yield self`s; the helper name is the snake_cased part name with the root prefix stripped once (`TableHead` -> `head`; an export without the prefix keeps its name: `ScrollBar` -> `scroll_bar`); `root.helper(**attrs, &block)` is exactly `render Root::Part.new(**attrs), &block`; helpers are generated by `Chadcn::Base` (`const_added` on nested `Chadcn::Base` subclasses), never hand-written; both forms may be mixed in a view; scenarios and tests use the explicit classes, and `parity_run.mjs --dx helpers` renders the same scenarios through the helpers (gate G2b). `.claude/scripts/shadcn/spec_helpers.rb` derives each component's helper list from the oracle and writes it into the spec.


Raw elements (`_input`, `_select`, `_textarea`...) in scenario trees take React DOM props: `className`/`htmlFor`/camelCase DOM props map to real attribute names, and `defaultValue`/`value` become the `value` attribute (input), the text content (textarea) or `selected` on the matching `<option>` (select); `defaultChecked`/`checked` become `checked`.
