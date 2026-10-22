# Tooltip (shadcn new-york-v4, Radix `radix-ui` Tooltip)

Sources read: `gems/chadcn/dev/port/oracle/src/tooltip.tsx` (manifest `source_sha` 611e4305879b2773), `gems/chadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-tooltip/dist/index.mjs` (v1.3.0, cited as `tooltip:<line>`), `react-popper` 1.3.8 (`popper:<line>`), `react-dismissable-layer` 1.1.20 (`layer:<line>`), `react-arrow` 1.1.16, `react-visually-hidden` 1.2.12, `react-presence` 1.1.11. Examples: `new-york-v4/tooltip-demo.json` (registry), plus the docs examples `tooltip-sides`, `tooltip-keyboard`, `tooltip-disabled`, `tooltip-rtl` (`apps/v4/examples/radix/*.tsx` on shadcn-ui/ui main; the registry only publishes them for the radix-nova style, the markup is style-independent).

## API

Exports `Tooltip`, `TooltipTrigger`, `TooltipContent`, `TooltipProvider` map to:

```ruby
Components::V2::Tooltip::Provider.new(delay_duration: 0, skip_delay_duration: 300, disable_hoverable_content: false) { ... }
Components::V2::Tooltip.new(open: nil, default_open: false, delay_duration: nil, disable_hoverable_content: nil) { ... }
Components::V2::Tooltip::Trigger.new(as_child: false, class: nil, **attrs) { ... }
Components::V2::Tooltip::Content.new(side: "top", side_offset: 0, align: "center", align_offset: 0,
  avoid_collisions: true, collision_padding: 0, collision_boundary: nil, arrow_padding: 0,
  sticky: "partial", hide_when_detached: false, update_position_strategy: "optimized",
  force_mount: false, class: nil, **attrs) { ... }
```

- `TooltipProvider` (`Tooltip::Provider`): `delay_duration:` defaults to **0** (shadcn overrides Radix's `DEFAULT_DELAY_DURATION = 700`, tooltip:27, tsx `delayDuration = 0`). `skip_delay_duration: 300` and `disable_hoverable_content: false` are Radix defaults (tooltip:33-35). Renders no element; it pushes its options into the Phlex render context for the Tooltips inside its block.
- `Tooltip` (root): `open:` (controlled when not `nil`), `default_open: false` (tooltip:96), `delay_duration:` and `disable_hoverable_content:` fall back to the provider's when `nil` (tooltip:91-92). Renders no element. Rendering a `Tooltip` outside a `Tooltip::Provider` raises `ArgumentError, "`Tooltip` must be used within `TooltipProvider`"` (Radix `createContext` throws the same message; the shadcn oracle does NOT self-wrap in a provider).
- `TooltipTrigger` (`Tooltip::Trigger`): `<button>`; `as_child:` false | tag symbol | V2 component instance (Radix Slot merge from `Components::V2::Base#render_as_child`; the trigger's `data-state`, `aria-describedby`, `data-slot` and controller wiring merge onto the child, child attributes win, `class` plain join). `aria: { describedby: }` / `"aria-describedby":` is concatenated with the content id while open (tooltip:186, `concatAriaDescribedby` tooltip:501-510: split on whitespace, dedupe, caller ids first). `disabled:` and every other attr pass through.
- `TooltipContent` (`Tooltip::Content`): `side:` default `"top"` (tooltip:230 overrides Popper's `"bottom"`), `side_offset:` default `0` (tsx), `align: "center"`, `align_offset: 0`, `arrow_padding: 0`, `avoid_collisions: true`, `collision_boundary: nil` (Radix `[]`), `collision_padding: 0` (Integer or Hash `{top:, right:, bottom:, left:}`, missing keys 0, popper:110), `sticky: "partial"` (`"partial" | "always"`), `hide_when_detached: false`, `update_position_strategy: "optimized"` (`"optimized" | "always"`) (popper:96-108), `force_mount: false` (tooltip:230). String and symbol values accepted for every option (`side: :left` == `side: "left"`). `aria: { label: }` / `"aria-label":` switches the accessible-label mode (see Structure). `id:` overrides the generated content id (tooltip:328-333). `class:` merged last through `cn` onto the oracle class string.
- Events (all dispatched by the `shadcn--tooltip` controller on the trigger element, bubbling):
  - `shadcn--tooltip:open-change` `detail: { open }` on every open/close request (Radix `onOpenChange`, tooltip:97-105). In controlled mode (`open:` given) the DOM does not change; only the event fires.
  - `shadcn--tooltip:escape-key-down` (cancelable; `preventDefault()` keeps it open) = `onEscapeKeyDown` (tooltip:305, layer:91-99).
  - `shadcn--tooltip:pointer-down-outside` (cancelable) = `onPointerDownOutside` (tooltip:306).
- Not ported: `ref`; `TooltipPortal` `container:` (shadcn does not expose the Portal); `TooltipArrow` (shadcn renders it internally with fixed classes, not exported).

Example (tooltip-demo):

```ruby
render Components::V2::Tooltip::Provider.new do
  render Components::V2::Tooltip.new do
    render Components::V2::Tooltip::Trigger.new(as_child: Components::V2::Button.new(variant: "outline")) { "Hover" }
    render Components::V2::Tooltip::Content.new { p { "Add to library" } }
  end
end
```

## Structure

Server render (closed, default):

```html
<button data-state="closed" data-slot="tooltip-trigger" data-controller="shadcn--tooltip" data-shadcn--tooltip-*-value="...">Hover</button>
<template data-shadcn--tooltip-template="<content-id>"> ...Content markup below... </template>
```

- `tooltip-provider` (Provider) and `tooltip` (Root): **no element, no data-slot** (manifest `non_rendered_slots`; radix-dom-contract "Parts that render no element").
- `tooltip-trigger` (Trigger): `<button>` from `Primitive.button` (tooltip:184) with **no `type` attribute** (Radix does not add one; do not add `type="button"`). Attributes in this order of precedence: `aria-describedby` (only while open: caller ids + content id; when closed only the caller's value, tooltip:186), `data-state` = `closed | delayed-open | instant-open` (tooltip:108-110, 187), then caller attrs (they can override, tooltip:188), `data-slot="tooltip-trigger"`. No `aria-expanded`, no `aria-haspopup`, no `aria-controls`. While the content is placed, Popper Anchor also writes `data-radix-popper-side` / `data-radix-popper-align` with the placed side/align (popper:81-91; removed when the content unmounts, popper:186-191). The trigger is the Stimulus host (`data-controller="shadcn--tooltip"`), with values `open`, `controlled`, `delay-duration` (resolved Root ?? Provider), `skip-delay-duration`, `disable-hoverable-content` (resolved), `provider-id`, `content-id`, plus the Content positioning values (`side`, `side-offset`, `align`, `align-offset`, `avoid-collisions`, `collision-padding`, `arrow-padding`, `sticky`, `hide-when-detached`, `update-position-strategy`).
- Content while closed: nothing in the live DOM (Portal + Presence `present = forceMount || open` both false, tooltip:224, 232). The port renders the content markup inside an inert `<template data-shadcn--tooltip-template="<content-id>">` emitted where `Tooltip::Content` is called (no data-slot, not rendered, invisible to the runner; declared in `deviations/tooltip.json`). The controller finds it by content id.
- Content while open, appended directly to `document.body` (Portal, no extra wrapper besides Popper's):

```html
<div data-radix-popper-content-wrapper="" style="position: fixed; left: 0px; top: 0px; transform: translate(Xpx, Ypx); min-width: max-content; z-index: 50; --radix-popper-transform-origin: ...; --radix-popper-available-width: ...px; --radix-popper-available-height: ...px; --radix-popper-anchor-width: ...px; --radix-popper-anchor-height: ...px">
  <div data-side="top" data-align="center" data-state="delayed-open" role="tooltip" id="<content-id>" data-slot="tooltip-content"
       class="z-50 w-fit origin-(--radix-tooltip-content-transform-origin) animate-in rounded-md bg-foreground px-3 py-1.5 text-xs text-balance text-background fade-in-0 zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95"
       style="--radix-tooltip-content-transform-origin: var(--radix-popper-transform-origin); --radix-tooltip-content-available-width: var(--radix-popper-available-width); --radix-tooltip-content-available-height: var(--radix-popper-available-height); --radix-tooltip-trigger-width: var(--radix-popper-anchor-width); --radix-tooltip-trigger-height: var(--radix-popper-anchor-height);">
    {children}
    <span style="position: absolute; left: <arrowX>px; bottom: 0px; transform: translateY(100%);">
      <svg class="z-50 size-2.5 translate-y-[calc(-50%_-_2px)] rotate-45 rounded-[2px] bg-foreground fill-foreground" width="10" height="5" viewBox="0 0 30 10" preserveAspectRatio="none" style="display: block;"><polygon points="0,0 30,0 15,10"></polygon></svg>
    </span>
  </div>
</div>
```

  - Wrapper (popper:205-222): floating-ui `floatingStyles` (strategy `fixed`, transform-based), `transform: translate(0, -200%)` until positioned, `min-width: max-content`, `z-index` copied from the content's computed z-index (`50`), `--radix-popper-transform-origin` from the transformOrigin middleware; the `size` middleware writes the four `--radix-popper-available-*/anchor-*` vars on the wrapper (popper:136-141, `elements.floating` is the wrapper). `dir` only if a `dir` attr is passed to Content. `visibility: hidden; pointer-events: none` when `hide_when_detached` and the anchor is hidden.
  - Content div (popper:230-245, tooltip:346-362): `data-side`, `data-align` (placed values, after flip/shift), `data-state` (same value as the trigger), `role="tooltip"` and `id` (unless `aria-label`), caller attrs, `data-slot="tooltip-content"`, oracle classes + `class:`; inline style = caller `style` + the five `--radix-tooltip-*` vars + `animation: none` until positioned (popper:242). `aria-label` is consumed, never rendered on the div (tooltip:303).
  - Children order (tsx + tooltip:363-366): the block, then the Arrow, then (only with `aria-label`) `<span id="<content-id>" role="tooltip" style="position: absolute; border: 0px; width: 1px; height: 1px; padding: 0px; margin: -1px; overflow: hidden; clip: rect(0px, 0px, 0px, 0px); white-space: nowrap; overflow-wrap: normal;">{aria-label}</span>` (VisuallyHidden). In that mode the content div has no `role` and no `id`; the trigger's `aria-describedby` points at the span.
  - Arrow (shadcn `TooltipPrimitive.Arrow`, popper:262-300, react-arrow): wrapper `span` with `position: absolute; left: arrowX; top: arrowY; [opposite of placed side]: 0`, `transform-origin` `{top: "", right: "0 0", bottom: "center 0", left: "100% 0"}`, `transform` `{top: translateY(100%), right: translateY(50%) rotate(90deg) translateX(-50%), bottom: rotate(180deg), left: translateY(50%) rotate(-90deg) translateX(50%)}`, `visibility: hidden` when floating-ui `arrow.centerOffset !== 0`. The `svg` keeps `width="10" height="5"` attributes but `size-2.5` makes it 10x10 CSS px; no data-slot on the arrow.
- Ids: the Root generates the content id on the server (`id:` of Content wins, else a per-render counter, e.g. `tooltip-content-1`); the trigger value and template use the same id so `aria-describedby` resolves. The runner compares relations only.
- Server vs Stimulus: server renders the trigger with `data-state` = `closed`, or `instant-open` + `aria-describedby` when `open: true` / `default_open: true` (Radix initial `wasOpenDelayedRef = false`, tooltip:93, 109), and the template. Stimulus mounts/unmounts the content in `body`, positions it, toggles `data-state` and `aria-describedby`, and runs all timers/listeners.

## Behavior

Primitives composed: `hover_intent` (provider delay/skip-delay state, keyed by `provider-id`), `positioner`, `presence`, `portal`, `dismissable_layer`, `ids`; plus a grace-area polygon (same algorithm as `submenu_grace`: `getExitSideFromRect`, `getPaddedExitPoints` padding 5, `getPointsFromRect`, `getHull` monotone chain, `isPointInPolygon`, tooltip:380-500). No focus scope, no scroll lock, no hide-others, no focus guards, no outside pointer-events blocking (`disableOutsidePointerEvents: false`, tooltip:338).

States: `closed` -> `delayed-open` (opened by the delay timer, tooltip:122-129) | `instant-open` (opened by focus, by hover during the skip window, or initially open; tooltip:111-116). `data-state` is computed when `open` changes (tooltip:108-110) and stays the same while open. Close returns to `closed` on trigger and content at once; Presence keeps the content mounted until its exit animation (`data-[state=closed]:animate-out fade-out-0 zoom-out-95`) ends, then removes the wrapper; with no animation it unmounts in the same frame.

Provider (tooltip:30-72): `isOpenDelayed` starts `true`. When any tooltip opens: clear skip timer, `isOpenDelayed = false` (only if `skip_delay_duration > 0`). When any closes: restart a `skip_delay_duration` timer that sets `isOpenDelayed = true`. `isPointerInTransit` is shared across tooltips of the provider.

Pointer (trigger, tooltip:190-212):
| Event | Rule |
|---|---|
| `pointermove` (not `pointerType === "touch"`) | once per entry (`hasPointerMoveOpened`), and only when no pointer is in transit through a grace area: if provider `isOpenDelayed` -> start timer `delay_duration` (Root ?? Provider; shadcn 0 = `setTimeout(0)`) that opens as `delayed-open`; else open immediately as `instant-open` (tooltip:149-152). |
| `pointerleave` | if `disable_hoverable_content` -> close; else only clear the pending open timer (tooltip:153-160); reset `hasPointerMoveOpened`. |
| `pointerdown` | close if open; mark pointer-down until the next document `pointerup` (once). |
| `focus` | open immediately (`instant-open`) unless the focus comes from that pointer-down. |
| `blur` | close. |
| `click` | close. |

Hoverable content (default, `disable_hoverable_content` false; tooltip:235-295): on `pointerleave` of the trigger build a grace polygon from the exit point (padded 5px toward the leaving side) plus the content rect, and on content `pointerleave` from the exit point plus the trigger rect; set `isPointerInTransit = true`. A document `pointermove` then: target inside trigger or content -> drop the polygon; point outside the polygon -> drop it and close. With `disable_hoverable_content` true the content is not hoverable: leaving the trigger closes immediately.

Global rules while the content is mounted (tooltip:312-326):
- Opening any tooltip dispatches a document event (Radix `tooltip.open`, port `shadcn--tooltip:global-open`) and every mounted content closes on it, so only one tooltip is open at a time; the newly opened one dispatches after its own state change so it is not affected.
- A capture-phase `scroll` on `window` whose target contains the trigger closes it.

Keyboard: no roving, no key handlers on the trigger. `Escape` anywhere while open (document `keydown` capture, top-most layer only, layer:91-107): dispatch cancelable `escape-key-down`; unless prevented, `preventDefault` the key and close. `Tab` moves focus normally; leaving the trigger blurs it and closes. Focus is never moved into the content and never restored (no focus scope).

Dismissal (DismissableLayer, tooltip:335-343): pointerdown outside the content -> cancelable `pointer-down-outside`, then close; focus outside is always prevented (`onFocusOutside: preventDefault`), so only trigger blur closes on focus change.

Controlled: with `open:` the controller never changes `data-state`/mount on its own; every open/close request only dispatches `open-change` (useControllableState). The provider skip-delay bookkeeping and the global-open event still run as Radix does inside `onChange` (tooltip:97-104).

Timers (Radix defaults unless shadcn overrides): open delay `delay_duration` (shadcn 0, Radix 700), skip window `skip_delay_duration` 300ms, all cleared on disconnect (tooltip:130-137, 41-44). Grace padding 5px.

Positioning (popper:96-191): floating-ui `computePosition` + `autoUpdate` (`animationFrame` only with `update_position_strategy: "always"`), strategy `fixed`, placement `side` + (`-align` unless center). Middleware in order: `offset({ mainAxis: side_offset + arrowHeight, alignmentAxis: align_offset })` where arrowHeight is the measured arrow wrapper span height (10px with `size-2.5`, so the default gap is 10px), `shift({ mainAxis: true, crossAxis: false, limiter: limitShift() when sticky "partial" })`, `flip()`, `size()` (CSS vars), `arrow({ element: arrowSpan, padding: arrow_padding })`, `transformOrigin`, `hide({ strategy: "referenceHidden" })` only with `hide_when_detached`; shift/flip/size share `{ padding: collision_padding, boundary, altBoundary: boundary.any? }`; shift and flip only when `avoid_collisions`. `data-side`/`data-align` reflect the final placement. floating-ui version must match the catalog (G5_FLOATING_UI_VERSION).

Presence: enter animation (`animate-in fade-in-0 zoom-in-95` + `slide-in-from-*` by placed side) starts only after the first position (`animation: none` before). Exit waits for `animationend` on the content with `data-state="closed"`.

Turbo/cleanup: disconnect clears timers, removes the mounted content, the document/window listeners, `autoUpdate`, and releases the provider subscription; a cached page must not restore an open tooltip.

Not expressible in the runner, covered by the browser tests in `test/javascript/tooltip.test.mjs` (`pointerType === "touch"` ignored, scroll-close, cancelable `escape-key-down`, `open-change`, `hide_when_detached`, `update_position_strategy: "always"`, `collision_boundary`). Run them with `bin/rails test:javascript`.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Tooltip` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Tooltip::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Tooltip::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `tooltip.trigger` | `Tooltip::Trigger` | `TooltipTrigger` |
| `tooltip.content` | `Tooltip::Content` | `TooltipContent` |
| `tooltip.provider` | `Tooltip::Provider` | `TooltipProvider` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- No `Components::V2` component is rendered by Tooltip itself (no icons, no sr-only literals; manifest `registry_dependencies: []`, `icons: []`).
- Callers commonly compose `Components::V2::Button` (and `Kbd`) via `as_child:`; scenarios use raw `_button` / `_kbd` elements for that because the tooltip manifest declares no registry dependency (scenario_coverage only allows dependency exports).
- `Components::V2::Base#render_as_child` (Slot merge), `cn`.

## Deviations

One structural, invisible deviation (`gems/chadcn/dev/port/deviations/tooltip.json`):

- `Tooltip::Content` emits an inert `<template data-shadcn--tooltip-template="<id>">` sibling at its call site that carries the content markup until the controller mounts it in `body`. Reason: Radix renders nothing while closed and creates the node on the client; the server must ship the markup somewhere and the trigger (controller host) cannot contain it. The template has no `data-slot`, generates no box, and its content is not in the document, so G2 node lists, boxes and a11y are unaffected.

```json
{ "component": "tooltip", "reason": "...", "allow_tokens": [], "allow_missing_tokens": [], "api": ["Tooltip::Content renders an inert <template> (no data-slot) holding the content markup while closed"] }
```
