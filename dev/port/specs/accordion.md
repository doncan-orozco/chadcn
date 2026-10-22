# Accordion

Oracle: `gems/chadcn/dev/port/oracle/src/accordion.tsx` (manifest `source_sha` 99de242681eb4312, tier `radix_stateful`), wrapping `AccordionPrimitive.Root/Item/Header/Trigger/Content` from `radix-ui` 1.7.0 -> `@radix-ui/react-accordion` 1.2.21, built on `@radix-ui/react-collapsible` 1.1.21, `react-presence` 1.1.11, `react-collection` 1.1.16, `react-direction` 1.1.5, `react-id` 1.1.4, `react-use-controllable-state`. Sources read from `gems/chadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/<pkg>/dist/index.mjs`, cited as `accordion.mjs:<line>`, `collapsible.mjs:<line>`, `presence.mjs:<line>`, `collection.mjs:<line>`, `controllable.mjs:<line>`. Icons: lucide-react 0.577.0. Registry examples: `accordion-demo` only (the new-york-v4 registry has no other `accordion-*` item).

## API

Four exports, four Ruby classes (`Accordion`, `AccordionItem` -> `Accordion::Item`, `AccordionTrigger` -> `Accordion::Trigger`, `AccordionContent` -> `Accordion::Content`). The Radix `Header` is not exported by shadcn; it is rendered internally by `Accordion::Trigger` (no Ruby class for callers). No cva tables (manifest `cva: {}`).

```ruby
Components::V2::Accordion.new(
  type: "single",          # "single" | "multiple" (strings or symbols). Radix renders the single impl for anything but "multiple" (accordion.mjs:44), so omitting type behaves as "single"
  value: nil,              # controlled. single: String ("" = none open); multiple: Array of Strings. nil = uncontrolled (controllable.mjs:20 `isControlled = prop !== undefined`)
  default_value: nil,      # uncontrolled initial. single: String, default "" (accordion.mjs:65); multiple: Array, default [] (accordion.mjs:91)
  collapsible: false,      # single only (accordion.mjs:60); multiple is always collapsible (accordion.mjs:110). Ignored for multiple
  disabled: false,         # disables every item (accordion.mjs:221) and removes the keyboard handler (accordion.mjs:204)
  dir: nil,                # "ltr" | "rtl"; only affects ArrowLeft/ArrowRight in horizontal orientation (accordion.mjs:127-128, 159-181). NOT rendered as an attribute
  orientation: "vertical", # "vertical" | "horizontal" (accordion.mjs:121), rendered as data-orientation on every part
  as_child: false,         # Radix Slot on Root (Primitive.div)
  class: nil,              # merged through cn onto the root div (shadcn passes no base classes for Root)
  **attrs                  # id, aria: {}, data: {}, aria-label... pass through to the root div
) { items }

Components::V2::Accordion::Item.new(
  value:,                  # required String (Radix: `open = value && valueContext.value.includes(value)`, accordion.mjs:220)
  disabled: false,         # item-level disable, OR-ed with the root's (accordion.mjs:221)
  as_child: false,         # Radix Slot on the Collapsible Root div
  class: nil,              # cn("border-b last:border-b-0", class)
  **attrs                  # onto the item div
) { trigger + content }

Components::V2::Accordion::Trigger.new(
  class: nil,              # cn(<trigger classes>, class) onto the BUTTON (not the h3)
  **attrs                  # onto the button (id, aria-*, data-*, data: { action: }); `disabled:` is NOT a Trigger kwarg in Radix (the item/root decide)
) { label }                # block = label; the ChevronDown icon is always appended after it

Components::V2::Accordion::Content.new(
  force_mount: false,      # Radix CollapsibleContent `forceMount` (collapsible.mjs:82-84), passed through by shadcn's {...props}
  class: nil,              # IMPORTANT: goes to the INNER div: cn("pt-0 pb-4", class) (accordion.tsx AccordionContent); the region div's classes are fixed
  style: nil,              # caller style appended after the two accordion CSS vars (accordion.mjs:310-314)
  **attrs                  # onto the region div (id, aria-*, data-*)
) { body }
```

- Strings and symbols are accepted for `type`, `orientation`, `dir` (shadcn-port R4). `value`/`default_value` are item values (Strings) and are compared as strings.
- Events: `shadcn--accordion:value-change`, dispatched from the root element, `detail: { value }` where `value` is a String for single (`""` after collapsing) and an Array for multiple. Not cancelable (Radix `onValueChange` is not preventable). Uncontrolled: dispatched after the DOM is updated (useUncontrolledState effect, controllable.mjs:62-66). Controlled: dispatched instead of updating, only when the computed value differs from `value:` (controllable.mjs:38-43). Single non-collapsible: clicking the open item calls `onItemClose` which does nothing (`collapsible && setValue("")`, accordion.mjs:75), so no event.
- Consumer click handlers on the Trigger (`data: { action: "click->x#y" }`) run first; Radix skips the toggle if the consumer called `preventDefault()` (`composeEventHandlers(props.onClick, context.onOpenToggle)`, collapsible.mjs:73). The controller must check `event.defaultPrevented`.
- `as_child:` on `Accordion` and `Accordion::Item` uses `Components::V2::Base#render_as_child` (tag symbol or instance); the block is the slotted element's content. Not offered on Trigger and Content: see Deviations.
- `ref`, `onKeyDown` on Root and per-item `onOpenChange` have no Ruby equivalent (Radix Item overrides `onOpenChange`, accordion.mjs:239).

## Structure

DOM (uncontrolled, single, item-1 open, item-2 closed; ids shown as `T1/C1/T2/C2`, React `useId` values, normalized by the runner):

```html
<div data-slot="accordion" class="w-full" data-orientation="vertical" data-controller="shadcn--accordion">
  <div data-state="open" data-orientation="vertical" data-slot="accordion-item" class="border-b last:border-b-0">
    <h3 data-orientation="vertical" data-state="open" class="flex">
      <button type="button" aria-controls="C1" aria-expanded="true" data-state="open" data-orientation="vertical"
              id="T1" data-slot="accordion-trigger" class="<trigger classes>" data-radix-collection-item="">
        Is it accessible?
        <svg ... class="lucide lucide-chevron-down pointer-events-none size-4 shrink-0 translate-y-0.5 text-muted-foreground transition-transform duration-200" aria-hidden="true"><path d="m6 9 6 6 6-6"></path></svg>
      </button>
    </h3>
    <div data-state="open" id="C1" role="region" aria-labelledby="T1" data-orientation="vertical"
         data-slot="accordion-content" class="overflow-hidden text-sm data-[state=closed]:animate-accordion-up data-[state=open]:animate-accordion-down"
         style="--radix-accordion-content-height: var(--radix-collapsible-content-height); --radix-accordion-content-width: var(--radix-collapsible-content-width); transition-duration: 0s; animation-name: none; --radix-collapsible-content-height: 52px; --radix-collapsible-content-width: 900px;">
      <div class="pt-0 pb-4">Yes. It adheres to the WAI-ARIA design pattern.</div>
    </div>
  </div>
  <div data-state="closed" data-orientation="vertical" data-slot="accordion-item" class="border-b last:border-b-0">
    <h3 data-orientation="vertical" data-state="closed" class="flex">
      <button type="button" aria-expanded="false" data-state="closed" data-orientation="vertical" id="T2" ...>Is it styled? <svg .../></button>
    </h3>
    <div data-state="closed" id="C2" hidden="" role="region" aria-labelledby="T2" data-orientation="vertical" data-slot="accordion-content" class="..."
         style="--radix-accordion-content-height: var(--radix-collapsible-content-height); --radix-accordion-content-width: var(--radix-collapsible-content-width);"></div>
  </div>
</div>
```

Part `Accordion` (Root, `data-slot="accordion"`; accordion.mjs:191-206, accordion.tsx `Accordion`):
- tag `div` (or the `as_child` element). Attributes: caller attrs, `data-slot="accordion"`, `data-orientation="vertical|horizontal"` (always). No classes from shadcn (only caller `class:`). Radix renders NO `role`, NO `dir`, NO `data-disabled`, NO `aria-orientation` on the root (`type`, `value`, `defaultValue`, `collapsible`, `disabled`, `dir`, `orientation` are destructured away, accordion.mjs:41, 55-61, 117-123). Collection.Slot adds no attribute (collection.mjs:29-34).
- Controller host: `data-controller="shadcn--accordion"` on this element (Stimulus wiring, not compared). Values: `type`, `value` (JSON), `controlled` (Boolean), `collapsible`, `disabled`, `orientation`, `dir`.

Part `Accordion::Item` (`AccordionItem`, `data-slot="accordion-item"`; accordion.mjs:213-251 -> collapsible.mjs:19-55):
- tag `div`. Attributes: `data-state="open|closed"`, `data-disabled=""` only when the item or root is disabled (collapsible.mjs:47), `data-orientation`, caller attrs, `data-slot="accordion-item"`.
- Classes verbatim: `border-b last:border-b-0`, then caller `class:` through `cn`.

Header (no data-slot, no Ruby class; rendered by `Accordion::Trigger`; accordion.mjs:253-270):
- tag `h3`, `data-orientation`, `data-state="open|closed"`, `data-disabled=""` when disabled, `class="flex"` verbatim (accordion.tsx `<AccordionPrimitive.Header className="flex">`). Caller attrs never reach it.

Part `Accordion::Trigger` (`AccordionTrigger`, `data-slot="accordion-trigger"`; accordion.mjs:272-292 -> collapsible.mjs:57-77, collection.mjs:37-51):
- tag `button`, `type="button"`, `aria-controls="<content id>"` ONLY while open (collapsible.mjs:66, `context.open ? context.contentId : undefined`; this corrects the radix-dom-contract checklist, which implies it is always present), `aria-expanded="true|false"` (always), `data-state="open|closed"`, `data-disabled=""` + `disabled=""` when disabled, `aria-disabled="true"` only when the item is open AND the accordion is not collapsible (single without `collapsible`, accordion.mjs:283; multiple never), `data-orientation`, `id="<trigger id>"`, caller attrs (they win: spread after, accordion.mjs:287), `data-slot="accordion-trigger"`, `data-radix-collection-item=""` (collection.mjs:50).
- Classes verbatim: `flex flex-1 items-start justify-between gap-4 rounded-md py-4 text-left text-sm font-medium transition-all outline-none hover:underline focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 [&[data-state=open]>svg]:rotate-180`, then caller `class:` through `cn`.
- Children: the block, then `Icon(name: "chevron-down", class: "pointer-events-none size-4 shrink-0 translate-y-0.5 text-muted-foreground transition-transform duration-200")`, rendering lucide 0.577.0 `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-chevron-down pointer-events-none size-4 shrink-0 translate-y-0.5 text-muted-foreground transition-transform duration-200" aria-hidden="true"><path d="m6 9 6 6 6-6"></path></svg>`. Note `[&[data-state=open]>svg]:rotate-180` also rotates a caller svg placed directly in the trigger (scenario `trigger__icon-and-text__open`).

Part `Accordion::Content` (`AccordionContent`, `data-slot="accordion-content"`; accordion.mjs:294-318 -> collapsible.mjs:79-140):
- tag `div`, `data-state="open|closed"`, `data-disabled=""` when disabled, `id="<content id>"`, `hidden=""` while not open/present (collapsible.mjs:129), `role="region"`, `aria-labelledby="<trigger id>"` (always, even closed), `data-orientation`, caller attrs, `data-slot="accordion-content"`.
- Classes verbatim, NOT mergeable: `overflow-hidden text-sm data-[state=closed]:animate-accordion-up data-[state=open]:animate-accordion-down`.
- `style`: always `--radix-accordion-content-height: var(--radix-collapsible-content-height); --radix-accordion-content-width: var(--radix-collapsible-content-width)` then caller style (accordion.mjs:310-314). `--radix-collapsible-content-height/width: <n>px` are added only once a non-zero size has been measured (collapsible.mjs:132-134); React adds new style keys with `setProperty`, so they appear AFTER the accordion vars (and after the mount-prevention declarations, see Behavior). Values are `${rect.height}px` / `${rect.width}px` with no rounding.
- Children: ONLY while open/present (`children: isOpen && children`, collapsible.mjs:137): `<div class="pt-0 pb-4 <caller class>">block</div>`. A closed item's content div is EMPTY (unless `force_mount: true`).

Ids: each Item owns a trigger id (accordion.mjs:219) and a content id (collapsible.mjs:40), server-generated from a per-render counter in `Components::V2::Base` ids (runner normalizes by first-seen order). A caller `id:` on Trigger replaces the button id (spread after, accordion.mjs:285-287) but the content's `aria-labelledby` keeps the generated trigger id; a caller `id:` on Content replaces its id (collapsible.mjs:128-130) but the trigger's `aria-controls` keeps the generated content id. Both relations dangle, as in React (scenario `caller-ids-override__dangling-relations`).

Server vs Stimulus: the server renders every attribute above for the initial state, including `hidden`, `aria-controls` for open items and, for initially open items, `transition-duration: 0s; animation-name: none` in the content style. Closed content bodies are rendered by the server inside a `<template data-shadcn--accordion-target="body">` within the content div (so they exist without a round trip); `connect()` moves each template's content into an in-memory fragment and removes the template, so the post-connect DOM equals React's (empty closed content). Stimulus then owns: toggling, `data-state` on item/h3/button/content, `aria-expanded`, `aria-controls`, `aria-disabled`, `hidden`, inserting/removing the inner div, measurement CSS vars, keyboard navigation, events.

## Behavior

States per item: `closed` <-> `open`; orthogonal `disabled` (item or root). Root value: single = one String or `""`; multiple = Array.

Transitions (click on an enabled trigger, after consumer handlers, unless `defaultPrevented`; collapsible.mjs:42, 73 -> accordion.mjs:239-245):
- single, item closed: value becomes the item value (other open item closes in the same update, accordion.mjs:73-74).
- single, item open, `collapsible: false`: nothing happens (accordion.mjs:75); trigger shows `aria-disabled="true"` but stays focusable and clickable.
- single, item open, `collapsible: true`: value becomes `""`.
- multiple: open appends the value (accordion.mjs:95-98), close removes it (accordion.mjs:99-102).
- Controlled (`value:` given): compute the next value as above, dispatch `value-change`, leave the DOM on the server-rendered state.
- Disabled items: the button is `disabled`, no click; `disabled:pointer-events-none` also blocks hover.

Keyboard (keydown on the root, accordion.mjs:129-190; NOT attached at all when the root is `disabled`, accordion.mjs:204):
| Key | Vertical (default) | Horizontal |
|---|---|---|
| Enter / Space | native button click -> toggle (no Radix key handler) | same |
| ArrowDown | focus next enabled trigger, wraps last -> first | preventDefault only, focus stays |
| ArrowUp | focus previous, wraps first -> last | preventDefault only |
| ArrowRight | preventDefault only | ltr: next (wrap); rtl: previous |
| ArrowLeft | preventDefault only | ltr: previous (wrap); rtl: next |
| Home / End | first / last enabled trigger | same |
| Tab / Shift+Tab | native order: every enabled trigger is a tab stop (NO roving tabindex), then focusable content | same |
- Handled only when `event.target` is one of THIS accordion's enabled triggers (`triggerIndex === -1` -> return, before preventDefault, accordion.mjs:132-135); keys from inside content (inputs) or from a nested accordion's triggers are ignored by the outer root (Radix collection is scoped per accordion; nested triggers are not in the outer collection). Disabled triggers are excluded (`item.ref.current?.disabled`). Order = DOM order (collection.mjs:55-64). Keys are preventDefault-ed when handled, including the no-op arrows.
- Direction: `dir:` kwarg or a DirectionProvider, default `ltr` (react-direction `useDirection`: `localDir || globalDir || "ltr"`). It does NOT read `html[dir]` or ancestors; the shared `direction` primitive's ancestor fallback must not be used here.
- Focus: Radix moves no focus on open/close. A mouse click focuses the button natively (no ring: rings are `focus-visible:` only). No focus trap, no dismissal, no scroll lock, no positioning, no timers.

Presence and measurement (collapsible.mjs:79-140, presence.mjs:20-130), reproduced exactly:
- Mount: a content that is open at connect gets inline `transition-duration: 0s; animation-name: none`, measures `getBoundingClientRect()` and appends `--radix-collapsible-content-height/width` (Presence's `setNode` re-render, presence.mjs:127). Mount animation is prevented (`isMountAnimationPreventedRef = isOpen`, collapsible.mjs:98, 111-119) only until the first animation frame after mount: a `requestAnimationFrame` set in a mount effect clears the flag (collapsible.mjs:100-103). The inline mount-time values (`animation-name: none` and the measured size vars) stay until the next measure (the layout step of that item's next toggle), but suppression has already ended, so a close after that first frame restores the original animation values and plays the exit animation. Closed contents measure 0 at mount -> no collapsible vars.
- Open: set `data-state="open"`, remove `hidden`, insert the inner div; then (layout step) set inline `transition-duration: 0s; animation-name: none`, measure, restore both to their mount-time inline values (empty -> removed), write the collapsible vars (in place if already present). The CSS `animate-accordion-down` then runs from `--radix-accordion-content-height`.
- Close: set `data-state="closed"` immediately (trigger, h3, item, content), keep the content visible with children, re-measure the same way, then Presence: if the computed `animation-name` is `none` (motion disabled by the runner, reduced motion, or no animation) hide in the same frame (`UNMOUNT`, presence.mjs:66-67); otherwise wait for `animationend`/`animationcancel` of the current animation on the content itself (presence.mjs:83-97), then set `hidden=""` and remove the inner div, setting `animation-fill-mode: forwards` for one `setTimeout(0)` tick as Presence does (presence.mjs:88-95). Re-opening during the exit animation cancels the unmount (`unmountSuspended` -> `MOUNT`). After close, the measured collapsible vars stay in the style attribute.
- `force_mount: true`: content is never `hidden` and always has its inner div; `data-state` still toggles; mount prevention applies as for an open item.

Primitives composed: `presence` (exit-animation wait, Radix rules above), `collection` (ordered enabled triggers of this root only), `ids` (server ids first). The measurement/mount-prevention logic is identical in Collapsible and should live in ONE shared module (e.g. a `collapsible_content` helper next to `presence.js`), not inside the accordion controller. No `roving_focus` (Radix Accordion does not use RovingFocusGroup). Controller `shadcn--accordion`: one per root, targets item/trigger/header/content/body, `disconnect()` removes listeners and cancels pending animation waits/timeouts; on Turbo restore `connect()` reconciles from `data-state` (radix-stimulus R4, R10).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Accordion` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Accordion::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Accordion::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `accordion.item` | `Accordion::Item` | `AccordionItem` |
| `accordion.trigger` | `Accordion::Trigger` | `AccordionTrigger` |
| `accordion.content` | `Accordion::Content` | `AccordionContent` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Icon` (infra `_icons`): `Icon.new(name: "chevron-down", class: ...)` in every `Accordion::Trigger`.
- `Components::V2::Base`: `cn`, `merge_attrs`, `render_as_child`, ids.
- No other V2 component (manifest `registry_dependencies: []`). Scenarios use raw `_p`, `_section`, `_article` for example paragraphs and `asChild` children, and `<icon:package>` for an icon inside a trigger.

## Deviations

One, API only (no DOM or class difference). Entry written to `gems/chadcn/dev/port/deviations/accordion.json`:

- `as_child:` is not offered on `Accordion::Trigger` and `Accordion::Content`. Trigger: shadcn always passes `{children}` plus `<ChevronDownIcon/>` to `AccordionPrimitive.Trigger`, so with `asChild` Radix Slot receives two children and throws (react-slot 1.4.0 `createSlotError`); there is no working React output to match. Content: shadcn always wraps the caller's children in its own `<div className="pt-0 pb-4">`, so `asChild` would merge the region onto that internal div (and render nothing while closed), never onto a caller element; no registry example uses it.

```json
{ "reason": "shadcn AccordionTrigger always renders children plus ChevronDownIcon (Radix Slot throws with two children) and AccordionContent always wraps children in its own div (asChild would slot onto that internal div), so as_child is not offered on Trigger and Content", "allow_tokens": [], "allow_missing_tokens": [], "api": ["Accordion::Trigger: as_child not supported", "Accordion::Content: as_child not supported"] }
```

The `<template>` holder for closed content bodies is removed in `connect()`, so the compared (post-connect) DOM is identical; it is not a deviation.
