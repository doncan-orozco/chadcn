# Collapsible

Oracle: `dev/port/oracle/src/collapsible.tsx` (manifest `source_sha` c6598e5584f4258b, tier `radix_stateful`), wrapping `CollapsiblePrimitive.Root/CollapsibleTrigger/CollapsibleContent` from `radix-ui` 1.7.0 -> `@radix-ui/react-collapsible` 1.1.21, built on `react-presence` 1.1.11, `react-primitive` / `react-slot` 1.4.0, `react-id`, `react-use-controllable-state`. Sources read from `dev/react-shadcn-catalog/node_modules/@radix-ui/<pkg>/dist/index.mjs`, cited as `collapsible.mjs:<line>` and `presence.mjs:<line>`. No classes, no cva, no icons, no text literals in the oracle (manifest `class_tokens: []`, `cva: {}`): shadcn only adds `data-slot` to each part and spreads `...props`. Examples: registry `new-york-v4/collapsible-demo.json` (the only registry item), plus the docs examples `collapsible-basic`, `collapsible-file-tree`, `collapsible-rtl`, `collapsible-settings` (`apps/v4/examples/radix/*.tsx` on shadcn-ui/ui main; published only for radix-nova, the collapsible markup is style-independent).

This spec is kept consistent with `dev/port/specs/accordion.md`: Accordion's Item/Trigger/Content ARE Radix Collapsible parts, so the content measurement, mount-animation prevention and Presence rules below are the same code (shared `collapsible_content` module, see Behavior).

## API

Three exports, three Ruby classes (`Collapsible` -> `Components::V2::Collapsible`, `CollapsibleTrigger` -> `Collapsible::Trigger`, `CollapsibleContent` -> `Collapsible::Content`). All three render an element (manifest `non_rendered_slots: []`).

```ruby
Components::V2::Collapsible.new(
  open: nil,            # controlled when not nil (true/false). useControllableState: isControlled = prop !== undefined (collapsible.mjs:29-34)
  default_open: false,  # uncontrolled initial state (`defaultProp: defaultOpen ?? false`, collapsible.mjs:31)
  disabled: false,      # collapsible.mjs:25, 39: trigger gets disabled + data-disabled, root and content get data-disabled
  as_child: false,      # Radix Slot on Root (Primitive.div, collapsible.mjs:44): false | tag symbol | V2 component instance
  class: nil,           # cn(class) onto the root div (shadcn adds no base classes)
  **attrs               # id, dir, aria: {}, data: {}... spread onto the root div (collapsibleProps, collapsible.mjs:48); `dir:` is a plain DOM attribute here (collapsible-rtl example)
) { trigger(s), content(s), any other markup }

Components::V2::Collapsible::Trigger.new(
  as_child: false,      # Radix Slot on Primitive.button (collapsible.mjs:63); typical use: as_child: Components::V2::Button.new(variant: "ghost", size: "icon")
  class: nil,           # cn(class) onto the button (no base classes)
  **attrs               # spread AFTER Radix's attrs (collapsible.mjs:71): caller `type:`, `disabled:`, `aria-*`, `id:` win; data: { action: } handlers run before the toggle
) { label }

Components::V2::Collapsible::Content.new(
  force_mount: false,   # Radix `forceMount` (collapsible.mjs:82-84): always present, never hidden, children always rendered
  as_child: false,      # Radix Slot on Primitive.div (collapsible.mjs:124): the slotted child receives the content attrs; while closed NOTHING is rendered (see Structure)
  class: nil,           # cn(class) onto the content div (no base classes)
  style: nil,           # caller style, written after the collapsible CSS vars (collapsible.mjs:132-136)
  **attrs               # id, aria-*, data-* spread onto the content div (contentProps, collapsible.mjs:130)
) { body }
```

- Booleans only (`open`, `default_open`, `disabled`, `force_mount`); there are no string/symbol option kwargs, so shadcn-port R4 has nothing to normalise.
- Events: `chadcn--collapsible:open-change`, dispatched from the root element, `detail: { open: <Boolean> }` (Radix `onOpenChange`, collapsible.mjs:32). Not cancelable. Uncontrolled: dispatched after the DOM has been updated (useUncontrolledState effect). Controlled (`open:` given): dispatched with the requested value (`!open`) and the DOM is NOT changed; the caller re-renders with the new `open:`.
- Consumer click handlers on the Trigger (`data: { action: "click->x#y" }`) run first; the toggle is skipped when the consumer called `preventDefault()` (`composeEventHandlers(props.onClick, context.onOpenToggle)`, collapsible.mjs:73). The controller checks `event.defaultPrevented`.
- The React demos use `open={isOpen} onOpenChange={setIsOpen}` with local state that mirrors every change; in Ruby that is simply the uncontrolled form (`default_open: false`) plus an optional listener on `chadcn--collapsible:open-change`. Scenarios render those examples uncontrolled (the scenario JSON cannot carry React state); the DOM sequence is identical.
- `ref` has no Ruby equivalent. `onOpenChange` maps to the event above.
- Several `Collapsible::Trigger`s and/or `Collapsible::Content`s may sit inside one root: they all read the same state and share the one content id (collapsible.mjs:40, 66, 128).

## Structure

DOM (uncontrolled, closed, after connect; the content id is a React `useId` value, normalised by the runner):

```html
<div data-state="closed" data-slot="collapsible" class="..." data-controller="chadcn--collapsible">
  <button type="button" aria-expanded="false" data-state="closed" data-slot="collapsible-trigger">Toggle</button>
  <div data-state="closed" id="C1" hidden="" data-slot="collapsible-content" style=""></div>
</div>
```

Open (after connect or after a click):

```html
<div data-state="open" data-slot="collapsible" ...>
  <button type="button" aria-controls="C1" aria-expanded="true" data-state="open" data-slot="collapsible-trigger">Toggle</button>
  <div data-state="open" id="C1" data-slot="collapsible-content"
       style="--radix-collapsible-content-height: 40px; --radix-collapsible-content-width: 350px;">body</div>
</div>
```

Part `Collapsible` (Root, `data-slot="collapsible"`; collapsible.mjs:19-55):
- tag `div` (or the `as_child` element). Attributes: `data-state="open|closed"` (always, collapsible.mjs:46), `data-disabled=""` only when `disabled` (collapsible.mjs:47), then caller attrs including `class` and `data-slot="collapsible"`. No role, no aria-*, no data-orientation (`open`, `defaultOpen`, `disabled`, `onOpenChange` are destructured away, collapsible.mjs:21-28).
- Controller host: `data-controller="chadcn--collapsible"` on this element, with values `open` (Boolean), `controlled` (Boolean), `disabled` (Boolean), plus whatever the content helper needs (e.g. caller's original `transition-duration`/`animation-name`, see Behavior). Stimulus wiring attributes (`data-controller`, `data-chadcn--collapsible-*`, `data-action`) are not compared. With `as_child:` the wiring merges onto the slotted element (data-controller tokens unioned, Base `render_as_child`).

Part `Collapsible::Trigger` (`CollapsibleTrigger`, `data-slot="collapsible-trigger"`; collapsible.mjs:57-77):
- tag `button`, `type="button"` (overridable by a caller `type:`), `aria-controls="<content id>"` ONLY while open (`context.open ? context.contentId : undefined`, collapsible.mjs:66), `aria-expanded="true|false"` (always, collapsible.mjs:67), `data-state="open|closed"`, `data-disabled=""` + `disabled=""` when the root is disabled (collapsible.mjs:69-70), caller attrs (win), `data-slot="collapsible-trigger"`. No `id` is generated for the trigger, and the content does not reference it.
- `as_child:` with a component instance: Radix Slot merge (child props win, `class` plain join slot-then-child), so `Collapsible::Trigger.new(as_child: Components::V2::Button.new(variant: "ghost", size: "icon", class: "size-8"))` renders the Button's `<button>` with the Button's own `data-slot="button"` (child wins over `collapsible-trigger`), its classes, plus `type`, `aria-expanded`, `aria-controls`, `data-state`, `data-disabled`, `disabled`. Child-side `group-data-[state=open]:` classes then react to the merged `data-state` (collapsible-basic / file-tree examples).
- Wiring: `data-action="click->chadcn--collapsible#toggle"` and a `trigger` target, merged on the element (child's actions first per Slot rules).

Part `Collapsible::Content` (`CollapsibleContent`, `data-slot="collapsible-content"`; collapsible.mjs:79-140):
- tag `div`, `data-state="open|closed"`, `data-disabled=""` when disabled, `id="<content id>"` (caller `id:` replaces it, spread after, collapsible.mjs:128-130; the trigger's `aria-controls` keeps the generated id and dangles, as in React), `hidden=""` while not open and not present (collapsible.mjs:129), caller attrs, `data-slot="collapsible-content"`, `style` (below).
- NO `role="region"`, NO `aria-labelledby`, NO `data-orientation`: those are Accordion additions. This corrects the `radix-dom-contract.md` checklist row "Accordion / Collapsible", which lists `role="region" aria-labelledby` for both.
- Children: ONLY while open/present (`children: isOpen && children`, collapsible.mjs:137). A closed content element is EMPTY (unless `force_mount: true`).
- `style`, built exactly as React does it:
  1. React style object: `--radix-collapsible-content-height: <h>px` and `--radix-collapsible-content-width: <w>px` only when the measured value is non-zero, then the caller's `style` (collapsible.mjs:132-136). Values are `${rect.height}px` / `${rect.width}px` from `getBoundingClientRect()`, unrounded.
  2. CSSOM writes from the layout effect (collapsible.mjs:104-122): `transition-duration: 0s; animation-name: none` are set before measuring and restored to the original inline values afterwards, except while mount animation is prevented.
  Resulting serialisations: closed at mount -> `style=""` (the CSSOM wrote and then removed both properties, leaving an empty attribute); open at mount -> `style="transition-duration: 0s; animation-name: none; --radix-collapsible-content-height: <h>px; --radix-collapsible-content-width: <w>px;"` (prevention kept; vars appended by the Presence `setNode` re-render, presence.mjs:119-127); after any toggle -> the two prevention properties are gone and the vars stay (updated in place) even when closed again.
- `as_child:` (Slot onto the single child): while open the child element carries every content attribute above; while closed `children` is `false`, so Slot renders nothing and the content element is ABSENT from the DOM (no `hidden` element). The server renders the closed body inside a `<template data-chadcn--collapsible-target="body">` at the content's position; `connect()` replaces it with an empty Text node anchor (invisible in serialisation) and keeps the fragment in memory, re-inserting the slotted element there on open and removing it after close.

Ids: one content id per root (collapsible.mjs:40), server-generated from the per-render counter in `Components::V2::Base` (runner normalises by first-seen order); every trigger's `aria-controls` and every content's `id` use it.

Server vs Stimulus: the server renders every attribute above for the initial state (`data-state` on all parts, `aria-expanded`, `aria-controls` when open, `hidden` when closed, `data-disabled`/`disabled`, ids) and, for content that is open (or force-mounted) at render time, `transition-duration: 0s; animation-name: none` in the content style so the open animation does not run on first paint. Closed content bodies are rendered inside `<template data-chadcn--collapsible-target="body">` within the content div; `connect()` moves the template content into an in-memory fragment and removes the template, so the post-connect DOM equals React's (empty closed content). `connect()` then runs the mount layout step (measure, vars, `style=""` for closed content). Stimulus owns toggling, `data-state` on root/trigger/content, `aria-expanded`, `aria-controls`, `hidden`, inserting/removing children, measurement CSS vars, Presence and events.

## Behavior

States: `closed` <-> `open`; orthogonal `disabled`. Composes the `presence` primitive and the shared `collapsible_content` module (measurement + mount-animation prevention, the module the accordion spec asks for; Accordion::Content and Collapsible::Content must use the same code), plus `ids`. No focus scope, roving focus, dismissable layer, scroll lock, positioning, typeahead or timers (none in collapsible.mjs).

Transitions:
- Click on an enabled trigger (after consumer handlers, unless `defaultPrevented`): `open = !open` (`setOpen(prev => !prev)`, collapsible.mjs:42, 73).
  - Uncontrolled: update the DOM, then dispatch `open-change { open }`.
  - Controlled (`open:` given): dispatch `open-change { open: !open }` only; the DOM stays as rendered.
- Disabled root: every trigger has `disabled`, so no click event and no toggle; `default_open: true` + `disabled: true` still renders open content (disabled does not affect `open`).
- Several triggers: each toggles the same state; all reflect it.

Keyboard: Radix adds NO key handler. Enter and Space work only through the native `<button>` click (and through the slotted element when `as_child` is a button). Tab order is native: the trigger is a tab stop (skipped when disabled); hidden content is not focusable; open content's focusables follow in DOM order. Focus never moves on open/close (a mouse click focuses the button natively; there are no focus classes in the oracle, only those of an `as_child` Button).

Content measurement and mount prevention (collapsible.mjs:87-122), implemented once in `collapsible_content`:
- Mount (`connect()`): `isMountAnimationPrevented = isOpen` (collapsible.mjs:98). Record the original inline `transition-duration` and `animation-name` (the caller's own values from `style:`; NOT the server-rendered prevention, so the builder passes the caller originals to the helper, e.g. as a controller value; normally both empty). Set `0s`/`none`, measure, and, if not prevented, restore the originals (closed content -> `style=""`). Write the vars if non-zero (open content). Prevention lasts only until the first animation frame after mount (a `requestAnimationFrame` in a mount effect clears `isMountAnimationPrevented`, collapsible.mjs:100-103). The inline mount-time values (`animation-name: none`, `transition-duration: 0s` and the measured size vars) stay until the next measure (the layout step of the next toggle), but suppression has already ended, so a close after that first frame restores the original animation values and plays the exit animation.
- Open: set `data-state="open"` on root, triggers and content, `aria-expanded="true"`, add `aria-controls`, remove `hidden`, insert the children; then the layout step: set `0s`/`none`, measure, restore the originals (prevention lifted), write/update the vars. A caller animation such as `data-[state=open]:animate-collapsible-down` then runs from `0` to `var(--radix-collapsible-content-height)` (tw-animate-css keyframes `collapsible-down`/`collapsible-up`).
- Close: set `data-state="closed"` everywhere, `aria-expanded="false"`, remove `aria-controls` immediately; the content keeps its children and stays visible; layout step re-measures (full height) and updates the vars; then Presence decides (presence.mjs:56-77): if the computed `animation-name` is `none` or `display` is `none` -> hide in the same frame (`hidden=""`, children removed); else if the animation name differs from the one recorded while mounted (`isAnimating`) -> wait for `animationend`/`animationcancel` on the content itself whose name is in the current `animation-name`, then hide and set `animation-fill-mode: forwards` for one `setTimeout(0)` tick (presence.mjs:83-97); otherwise hide immediately. Re-opening during the exit animation cancels the unmount (`unmountSuspended` -> `MOUNT`): children stay, `data-state="open"`.
- Since shadcn adds no animation classes, a plain `Collapsible::Content` has `animation-name: none` and closes in the same frame. The scenario runner disables motion except in `animation__*` scenarios.
- `force_mount: true`: always present (`present: forceMount || context.open`, collapsible.mjs:84): never `hidden`, children always rendered, `data-state` still toggles, mount prevention applies as for open content.
- `disconnect()` removes listeners, cancels the rAF, pending animation waits and the fill-mode timeout; on Turbo restore `connect()` reconciles from the root's `data-state` (radix-stimulus R4, R10).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Collapsible` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Collapsible::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Collapsible::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `collapsible.trigger` | `Collapsible::Trigger` | `CollapsibleTrigger` |
| `collapsible.content` | `Collapsible::Content` | `CollapsibleContent` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Base`: `cn`, `merge_attrs`, `render_as_child`, ids.
- No V2 component is rendered by the parts themselves (manifest `registry_dependencies: []`, no icons). Callers commonly compose `Components::V2::Button` (and `Icon`) through `as_child:` on the Trigger, as every example does. Because the manifest declares no registry dependency, scenario_coverage only accepts Collapsible exports and raw elements, so the scenarios use raw `_button` elements (with `<icon:...>` children) as the `asChild` child, following the tooltip precedent; the Slot merge is the same.
- JS: `presence` primitive, shared `collapsible_content` module (also used by Accordion), `ids`.

## Deviations

None. The `<template>` holder for closed bodies is removed in `connect()` and the `as_child` closed-content anchor is an empty Text node, so the compared (post-connect) DOM is identical to React's. No `deviations/collapsible.json` is written.
