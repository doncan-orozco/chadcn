# ScrollArea

Oracle: `gems/chadcn/dev/port/oracle/src/scroll-area.tsx` (manifest `source_sha` 8b73bb9be5130007, tier `radix_stateful`), wrapping `ScrollAreaPrimitive.Root / Viewport / ScrollAreaScrollbar / ScrollAreaThumb / Corner` from `radix-ui` 1.7.0 -> `@radix-ui/react-scroll-area` 1.3.0 (`gems/chadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-scroll-area/dist/index.mjs`, cited below as `sa.mjs:<line>`), built on `@radix-ui/react-presence` 1.1.11 (`presence.mjs`), `@radix-ui/react-direction` 1.1.5 (`dir.mjs`) and `@radix-ui/react-slot` 1.4.0 (`slot.mjs`, only for `createSlottable`). Registry examples: `scroll-area-demo` and `scroll-area-horizontal-demo` (`https://ui.shadcn.com/r/styles/new-york-v4/<name>.json`, fetched online). The registry item has no `meta.links`.

Exports: `ScrollArea`, `ScrollBar`.

## API

### `ScrollArea` -> `Components::V2::ScrollArea`

```ruby
Components::V2::ScrollArea.new(
  type: "hover",            # "auto" | "always" | "scroll" | "hover"  (sa.mjs:31-36, default sa.mjs:52)
  dir: nil,                 # "ltr" | "rtl" | nil -> use_direction(dir) (sa.mjs:67, dir.mjs:17-20)
  scroll_hide_delay: 600,   # Integer ms (sa.mjs:54)
  class: nil,
  **attrs                   # id, role, aria: {}, data: {}, "aria-label":, style: ...
) { children }
```

- Props reach Radix `ScrollArea` (Root) through shadcn's `...props` (scroll-area.tsx `{...props}` on `ScrollAreaPrimitive.Root`). `type`, `dir`, `scrollHideDelay` are the Root's destructured props (sa.mjs:50-56); everything else is rendered on the Root `div` (sa.mjs:91-94).
- `type:` accepts strings and symbols (shadcn-port R4); unknown value raises `ArgumentError` (TS union). `scroll_hide_delay:` maps React `scrollHideDelay`.
- `dir:`: effective direction = `dir || <nearest Direction::Provider> || "ltr"` via `Components::V2::Direction::Consumer#use_direction` (direction spec). Always rendered as the `dir` attribute on the Root (sa.mjs:93).
- `class:` -> `cn("relative", class)` (caller wins through tailwind_merge, e.g. `static` drops `relative`).
- `style:` (in `**attrs`): merged AFTER Radix's own style keys (sa.mjs:96-102, `...props.style` last), so a caller can override `position` or the corner vars.
- Block = children; always rendered inside the Radix content wrapper inside the Viewport (see Structure).
- `as_child:` is NOT supported: Radix Root is `Primitive.div` and accepts `asChild`, but shadcn always gives it three children (Viewport, ScrollBar, Corner), so `Slot` throws (`slot.mjs:44-49`, "failed to slot onto its children"). Passing `as_child:` raises `ArgumentError`. No scenario.
- The Viewport is not configurable through shadcn (no props reach it; `nonce` / `disableImplicitContentElement` / `asChild` of `ScrollAreaPrimitive.Viewport`, sa.mjs:114, are unreachable).
- Events: none. Radix ScrollArea has no callbacks (no `onXChange` in sa.mjs). `ref` has no equivalent.

### `ScrollBar` -> `Components::V2::ScrollArea::ScrollBar`

Name rule: `ScrollBar` does not start with the root name `ScrollArea`, so nothing is stripped; it nests under the file's root as `ScrollArea::ScrollBar` (the TreeRenderer maps the export `ScrollBar` to this class).

```ruby
Components::V2::ScrollArea::ScrollBar.new(
  orientation: "vertical",  # "vertical" | "horizontal" (scroll-area.tsx `orientation = "vertical"`)
  force_mount: false,       # React `forceMount` (sa.mjs:220, 230)
  class: nil,
  **attrs
)
```

- Must be rendered inside a `ScrollArea` (Radix context, sa.mjs:221; outside it React throws). Port: raises `ArgumentError` when no enclosing `ScrollArea` is in the render context.
- `orientation:` strings or symbols; unknown raises `ArgumentError`. Also rendered by Radix as `data-orientation` (sa.mjs:431, 481) and decides the class branch below.
- `force_mount: true` keeps the scrollbar element mounted when the type logic would unmount it, with semantics per type copied from sa.mjs:220-346 (see Behavior "forceMount").
- `class:` merged last via `cn`. `**attrs` pass through to the scrollbar `div` (`id`, `aria-*`, `data-*`, `style` merged after Radix's positional style, sa.mjs:435-441/485-491, then `position: absolute` is prepended by sa.mjs:580).
- No block (shadcn renders the thumb itself). `as_child:` is NOT supported (ScrollbarImpl's only child is the Thumb, so `asChild` would merge the scrollbar onto the thumb; not a meaningful API) and raises `ArgumentError`.
- Events: none.

## Structure

Post-mount DOM produced by React (attribute/inline-style values as Radix writes them):

```html
<div dir="ltr" data-slot="scroll-area" class="relative h-72 ..." style="position: relative; --radix-scroll-area-corner-width: 0px; --radix-scroll-area-corner-height: 0px;">
  <style>[data-radix-scroll-area-viewport]{scrollbar-width:none;-ms-overflow-style:none;-webkit-overflow-scrolling:touch;}[data-radix-scroll-area-viewport]::-webkit-scrollbar{display:none}</style>
  <div data-radix-scroll-area-viewport="" data-slot="scroll-area-viewport" class="size-full rounded-[inherit] ..." style="overflow: hidden scroll;">
    <div style="min-width: 100%; display: table;">
      ...children...
      <!-- a caller <ScrollBar orientation="horizontal" /> lands here, inside the content wrapper -->
    </div>
  </div>
  <div data-state="visible" data-orientation="vertical" data-slot="scroll-area-scrollbar" class="flex touch-none p-px transition-colors select-none h-full w-2.5 border-l border-l-transparent" style="position: absolute; top: 0px; right: 0px; bottom: var(--radix-scroll-area-corner-height); --radix-scroll-area-thumb-height: 120px;">
    <div data-state="visible" data-slot="scroll-area-thumb" class="relative flex-1 rounded-full bg-border" style="width: var(--radix-scroll-area-thumb-width); height: var(--radix-scroll-area-thumb-height); transform: translate3d(0px, 0px, 0px);"></div>
  </div>
  <!-- Corner: only when both scrollbars are mounted, type != "scroll" and both sizes are non-zero -->
  <div style="width: 10px; height: 10px; position: absolute; right: 0px; bottom: 0px;"></div>
</div>
```

Part `ScrollArea` (`data-slot="scroll-area"`), Radix Root (sa.mjs:91-104):
- tag `div`; attrs: `dir` (effective direction, always present), `data-slot="scroll-area"`, `class` = `relative` + `class:`, caller attrs; no role, no aria, no `data-state`.
- inline style, in this order: `position: relative; --radix-scroll-area-corner-width: <Npx>; --radix-scroll-area-corner-height: <Npx>` then caller `style`. Corner vars start at `0px` and are updated by the Corner (sa.mjs:88-89, 688-703).
- children, in DOM order: (1) the `<style>` element, (2) the Viewport, (3) the built-in vertical ScrollBar (when mounted), (4) the Corner (when mounted). The `<style>` text is copied verbatim from sa.mjs:185, one per ScrollArea instance (Radix renders one per Viewport, sa.mjs:132; React 19 does not hoist a `<style>` without `precedence`), no `nonce`. CSP: `style-src-elem`/`style-src-attr` allow `unsafe-inline` (`config/initializers/content_security_policy.rb`), so inline `<style>` and style attributes are allowed.

Viewport (`data-slot="scroll-area-viewport"`), Radix Viewport (sa.mjs:133-175):
- tag `div`; attrs `data-radix-scroll-area-viewport=""` (FIRST, required by the `<style>` selector; ignored by the snapshot but load-bearing for layout because it hides the native scrollbars), `data-slot="scroll-area-viewport"`, `class` verbatim `size-full rounded-[inherit] transition-[color,box-shadow] outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1` (scroll-area.tsx; not caller-configurable).
- inline style `overflow-x: <scroll|hidden>; overflow-y: <scroll|hidden>` (sa.mjs:151-152): an axis is `scroll` iff a ScrollBar of that orientation is rendered in this ScrollArea, mounted or not (the outer `ScrollAreaScrollbar` effect enables the axis regardless of type, sa.mjs:224-229). The built-in ScrollBar always enables Y; a caller `ScrollBar orientation="horizontal"` enables X. The server renders the final value: `ScrollArea` captures its block first (each `ScrollBar` registers its orientation in the Phlex render context), then emits the Viewport with the computed style. The controller re-checks on `connect()`.
- no `tabindex`, no role. Keyboard focusability comes from Chromium's focusable-scroller behavior (a scroll container without focusable descendants is in the tab order); the port renders no `tabindex` either.
- one child: the content wrapper `div` with inline style `min-width: 100%; display: table;` (sa.mjs:205-212), no `data-slot`, no class, no attrs. ALL block children go inside it (Slottable without a Slot parent calls `children(child)`, slot.mjs:66, and the multi-child branch also wraps, sa.mjs:155-173). An empty block still renders the wrapper.

Part `ScrollBar` (`data-slot="scroll-area-scrollbar"`), Radix ScrollAreaScrollbar -> (Hover|Scroll|Auto|Visible) -> ScrollbarX/Y -> ScrollbarImpl (sa.mjs:217-607):
- tag `div`; attrs (React order): `data-state` (`visible|hidden`, see Behavior), `data-orientation` (`vertical|horizontal`, sa.mjs:431/481), `data-slot="scroll-area-scrollbar"`, `class`, caller attrs. No role, no aria.
- classes verbatim from scroll-area.tsx `cn("flex touch-none p-px transition-colors select-none", vertical && "h-full w-2.5 border-l border-l-transparent", horizontal && "h-2.5 flex-col border-t border-t-transparent", className)`:
  - vertical: `flex touch-none p-px transition-colors select-none h-full w-2.5 border-l border-l-transparent`
  - horizontal: `flex touch-none p-px transition-colors select-none h-2.5 flex-col border-t border-t-transparent`
  - The manifest's `class_tokens` lists `vertical` and `horizontal`: those are the `orientation === "..."` string literals picked up by the extractor, not classes; the port must not emit them (same situation as `default` in badge.md).
- inline style (set by the controller, React key order):
  - vertical (sa.mjs:485-491 + 580): `position: absolute; top: 0px; right: 0px; bottom: var(--radix-scroll-area-corner-height); --radix-scroll-area-thumb-height: <N>px` in `ltr`; in `rtl` `left: 0px` replaces `right: 0px` (`right`/`left` are `undefined` otherwise, i.e. omitted).
  - horizontal (sa.mjs:435-441 + 580): `position: absolute; bottom: 0px; left: <ltr ? 0px : var(--radix-scroll-area-corner-width)>; right: <ltr ? var(--radix-scroll-area-corner-width) : 0px>; --radix-scroll-area-thumb-width: <N>px`.
  - thumb size var = `getThumbSize(sizes)` (sa.mjs:730-735): `max((scrollbar.size - paddingStart - paddingEnd) * (viewport / content), 18)`, `ratio = NaN -> 0`; before the first measurement all sizes are 0, so the var is `18px`.
- placement: the built-in vertical ScrollBar is a direct child of the Root after the Viewport. A caller ScrollBar is rendered where the caller put it, i.e. inside the content wrapper (horizontal demo); being `position: absolute` with the Root as its containing block, it stays pinned while content scrolls.
- the scrollbar element exists only while mounted (Presence, see Behavior); the server never renders it live (see Deviations).

Thumb (`data-slot="scroll-area-thumb"`), Radix ScrollAreaThumb/ThumbImpl (sa.mjs:609-670):
- tag `div`; attrs `data-state` (`visible` while `hasThumb`, sa.mjs:651; `hidden` is unobservable through shadcn because the thumb has no `forceMount` and no exit animation), `data-slot="scroll-area-thumb"`, `class` verbatim `relative flex-1 rounded-full bg-border` (not caller-configurable).
- inline style `width: var(--radix-scroll-area-thumb-width); height: var(--radix-scroll-area-thumb-height);` (sa.mjs:654-658) plus `transform: translate3d(...)` written imperatively: vertical `translate3d(0, <offset>px, 0)`, horizontal `translate3d(<offset>px, 0, 0)` (sa.mjs:381, 405). The transform is written on mount even at offset 0 (Thumb effect calls `onThumbPositionChange()` immediately, sa.mjs:643), so the computed `transform` is `matrix(1, 0, 0, 1, 0, 0)`, never `none`.
- mounted only while `hasThumb` = `0 < viewport/content < 1` (sa.mjs:362, 614): absent when the content does not overflow and before the first size measurement.

Corner (no `data-slot`; shadcn renders `<ScrollAreaPrimitive.Corner />` with no props): tag `div`, no class, inline style `width: <W>px; height: <H>px; position: absolute; right: 0px (ltr) | left: 0px (rtl); bottom: 0px` (sa.mjs:704-718). Rendered only when both the X and Y scrollbar elements are mounted, `type != "scroll"` (sa.mjs:676-678) and both measured sizes are non-zero (sa.mjs:686, 704): `W` = vertical scrollbar `offsetWidth`, `H` = horizontal scrollbar `offsetHeight`; it also writes them into the Root's corner vars (sa.mjs:688-697), and resets them to 0 on unmount (sa.mjs:698-703). Not snapshotted (no `data-slot`) but it changes the scrollbars' boxes.

Server vs Stimulus (controller `chadcn--scroll-area`, host = the Root `div`):
- Server: Root (`dir`, class, style with `0px` corner vars), `<style>`, Viewport (final overflow style), content wrapper, children. Each ScrollBar (built-in and caller ones) is rendered at its DOM position as a complete scrollbar element (classes, `data-orientation`, `data-slot`, caller attrs, inner thumb) inside an inert `<template data-chadcn--scroll-area-target="scrollbar">` (deviation, see below); the thumb inside it is likewise kept in a nested `<template>` until `hasThumb`.
- Stimulus: mounts/unmounts scrollbars and thumbs per the type state machine, writes `data-state`, the scrollbar inline styles, the thumb-size vars and the thumb `transform`, creates/removes the Corner and updates the Root corner vars. Values: `type` (default `"hover"`), `scroll-hide-delay` (default `600`), `dir` read from the Root's own `dir` attribute (never `document.dir`).
- Ids: none generated; no aria relations.

## Behavior

No keyboard handlers, no focus management, no dismissal, no scroll lock, no positioning: sa.mjs registers only `pointerenter/pointerleave` (root), `scroll` (viewport), `wheel` (document), pointer down/move/up (scrollbar, thumb) and ResizeObservers. Keyboard scrolling is the browser's native scrolling of the focused Viewport.

### Visibility by `type` (all four implemented in the controller; Presence semantics below)

Common: the outer ScrollAreaScrollbar always mounts (enables its axis, sa.mjs:224-229) and delegates to the per-type component (sa.mjs:230).

- `hover` (default, sa.mjs:233-265): local `visible=false`. Root `pointerenter` -> clear hide timer, `visible=true`; Root `pointerleave` -> `setTimeout(visible=false, scroll_hide_delay)` (default 600 ms). Re-entering before the timer fires cancels it. Presence `present = force_mount || visible` wraps an `auto` scrollbar, so the element is mounted only while hovered (or until the delay elapses) AND the content overflows in that axis (inner auto check). `data-state` = `visible ? "visible" : "hidden"` from the hover state (it overrides the auto value because the hover props are spread after, sa.mjs:259-262).
- `auto` (sa.mjs:324-346): `visible = isHorizontal ? viewport.offsetWidth < viewport.scrollWidth : viewport.offsetHeight < viewport.scrollHeight`, recomputed by ResizeObservers on the viewport and on the content wrapper, each notification coalesced into one `requestAnimationFrame` (sa.mjs:798-814) and then debounced 10 ms (sa.mjs:329-335). Mounted iff `force_mount || visible`; `data-state` = `visible|hidden`.
- `always` (sa.mjs:230): always mounted, `data-state="visible"`; thumb still mounts only while the content overflows.
- `scroll` (sa.mjs:266-323): state machine copied verbatim (sa.mjs:271-288): `hidden --SCROLL--> scrolling`; `scrolling --SCROLL_END--> idle`, `scrolling --POINTER_ENTER--> interacting`; `interacting --SCROLL--> interacting`, `interacting --POINTER_LEAVE--> idle`; `idle --HIDE--> hidden`, `idle --SCROLL--> scrolling`, `idle --POINTER_ENTER--> interacting`; unknown events keep the state. `SCROLL` is sent on a viewport `scroll` event only when `scrollTop` (vertical) / `scrollLeft` (horizontal) changed since the previous event (sa.mjs:296-308), each followed by a 100 ms debounced `SCROLL_END` (sa.mjs:270). Entering `idle` starts `setTimeout(HIDE, scroll_hide_delay)`, cleared when leaving `idle` (sa.mjs:289-294). `POINTER_ENTER`/`POINTER_LEAVE` come from `pointerenter`/`pointerleave` on the scrollbar element itself (sa.mjs:319-320). Mounted iff `force_mount || state != "hidden"`; `data-state` = `hidden` iff state is `hidden`, else `visible`. No Corner in this type.

`forceMount` (exact semantics): the outer part passes `force_mount` to the type component (sa.mjs:230). `hover` and `scroll` destructure it and do NOT pass it on (sa.mjs:234, 267), so `hover + force_mount` keeps the element mounted only while the inner auto check says the content overflows, with `data-state="hidden"` when not hovered; `scroll + force_mount` keeps it mounted with `data-state="hidden"` at rest; `auto + force_mount` keeps it mounted even without overflow, `data-state="hidden"`. `always` ignores it.

Presence (presence.mjs:28-110, via the `presence` primitive): on `present -> false` the element is removed in the same frame unless its computed `animation-name` is not `none` and differs from the one it had while mounted, in which case removal waits for `animationend`/`animationcancel` on that element (then `animation-fill-mode: forwards` is applied for one task, presence.mjs:83-92). Only CSS animations count, not transitions (`transition-colors` on the scrollbar never delays). shadcn's own classes have no animation, so removal is immediate; caller classes such as `data-[state=hidden]:animate-out` delay it (scenario `presence__exit-animation`). On `present -> true` it mounts immediately.

### Sizes and thumb position

- Each mounted scrollbar measures `{ content: viewport.scrollHeight|scrollWidth, viewport: viewport.offsetHeight|offsetWidth, scrollbar: { size: scrollbar.clientHeight|clientWidth, paddingStart: paddingTop|paddingLeft, paddingEnd: paddingBottom|paddingRight } }` (sa.mjs:453-465, 504-516; paddings parsed with `parseInt(value, 10)`, `toInt` sa.mjs:721-723, from the computed style captured once after mount, sa.mjs:425-427), on ResizeObserver notifications of the scrollbar and of the content wrapper (rAF-coalesced, then debounced 10 ms, sa.mjs:544, 563-564). Then it writes the thumb-size var and `hasThumb`, and repositions the thumb (sa.mjs:562).
- Thumb offset = `getThumbOffsetFromScroll` (sa.mjs:750-760, with `linearScale` sa.mjs:762-768 and `clamp` from `@radix-ui/number`): `maxScroll = content - viewport`, `maxThumb = (size - paddings) - thumbSize`, scroll clamped to `[0, maxScroll]` (ltr) or `[-maxScroll, 0]` (rtl, horizontal only; vertical never passes `dir`), mapped `[0, maxScroll] -> [0, maxThumb]`. Copy the formulas verbatim (the thumb's computed `transform` is compared). In rtl the horizontal offset is therefore `<= 0`, exactly as Radix computes it.
- On viewport `scroll` the thumb starts a `requestAnimationFrame` loop that repositions the thumb whenever `scrollLeft/scrollTop` changed, and stops 100 ms after the last scroll event (sa.mjs:626-647, 774-787).

### Pointer

- `pointerdown` on the scrollbar (track or thumb) with `button === 0` only (sa.mjs:581-592; right/middle clicks do nothing): `setPointerCapture(pointerId)` on the event target, store `scrollbar.getBoundingClientRect()`, save `document.body.style.webkitUserSelect` and set it to `none`, set `viewport.style.scrollBehavior = "auto"`, then immediately drag-scroll to the pointer position.
- Thumb `pointerdown` in the CAPTURE phase records the pointer offset inside the thumb (`clientX/Y - thumbRect.left/top`, sa.mjs:659-665), before the scrollbar handler runs; thumb `pointerup` resets it to 0 (sa.mjs:666, 364).
- Drag position = `getScrollPositionFromPointer` (sa.mjs:737-748): `offset = pointerOffset || thumbSize / 2` (an offset of exactly 0, i.e. grabbing the thumb's top/left edge, falls back to the center: reproduce), mapping `[paddingStart + offset, size - paddingEnd - (thumbSize - offset)]` to `[0, maxScroll]` (ltr) or `[-maxScroll, 0]` (rtl, horizontal). A track click therefore jumps so the thumb is centered on the pointer. The value is assigned to `scrollTop/scrollLeft` (the browser clamps).
- `pointermove` on the scrollbar drag-scrolls while the rect is stored (sa.mjs:593); `pointerup` releases capture if held, restores `webkitUserSelect`, clears `viewport.style.scrollBehavior`, clears the rect (sa.mjs:594-602).
- `wheel` (document listener, `passive: false`, sa.mjs:553-561): when the event target is inside the scrollbar, set `scrollTop += deltaY` (vertical) / `scrollLeft += deltaX` (horizontal) and `preventDefault()` only when the new position is strictly between 0 and `maxScroll` (sa.mjs:444-451, 495-502, 770-772). Wheel over the viewport is native. (The runner has no wheel step; not scenario-covered.)

### Keyboard and focus

- None from Radix. Tab focuses the Viewport only when it has no focusable descendants (Chromium focusable scrollers); `focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1` then apply. Arrow keys / PageUp / PageDown / Home / End / Space scroll natively; the thumb follows via the scroll listener. Focusing a descendant scrolls it into view natively.
- `dir` affects only scrollbar placement and the horizontal scroll range; there is no key mapping.

### Cleanup (radix-stimulus R10)

`disconnect()` clears the hide timer, the scroll debounce timers, the rAF loop, both ResizeObservers per scrollbar, the document `wheel` listener, releases pointer capture and restores `document.body.style.webkitUserSelect` / `viewport.style.scrollBehavior` if a drag was in progress, and puts scrollbars/thumbs back into their templates and removes the Corner, so a Turbo snapshot equals the server DOM.

Primitives composed: `presence` (scrollbar and thumb mount/unmount). The ResizeObserver+rAF helper, the debounce and the scroll state machine are private to react-scroll-area (no other Radix package uses them) and live in the controller, unless the orchestrator adds the `resize-observer` helper listed in radix-stimulus "Media/layout" as a primitive, in which case the controller uses it. `direction` is read from the Root's own `dir` attribute (direction spec note). Pointer capture uses the native API directly (Radix does too); `pointer_capture.js` may be reused if its API matches.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::ScrollArea` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render ScrollArea::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::ScrollArea::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `scroll_area.scroll_bar` | `ScrollArea::ScrollBar` | `ScrollBar` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

None. `registry_dependencies: []`; renders no other `Components::V2` component and no icon. Uses `Components::V2::Direction::Consumer` (`use_direction`) for the Root `dir`.

Scenario fixtures: the `scroll-area-demo` uses `Separator` between tags; Separator is not a registry dependency of scroll-area, so the scenario renders a neutral `_div` with the same box (`my-2 h-px w-full shrink-0 bg-border`) in its place (no `data-slot`, not compared). The horizontal demo's `next/image` Unsplash photos become `_img` elements with inline 300x400 SVG data URIs so both harnesses load identically without network.

## Deviations

One structural deviation, recorded in `gems/chadcn/dev/port/deviations/scroll-area.json`:

- ScrollBar (scrollbar element and its thumb) are conditionally mounted by Radix (Presence, sa.mjs:257, 313, 338, 614), but a server render cannot "not render" an element and still know its classes and caller attrs when the client later mounts it. The port renders each scrollbar (and the thumb inside it) inside an inert `<template>` placeholder at its JSX position; the template has no `data-slot`, no class, is not in the accessibility tree and not in the parity snapshot. Once mounted the DOM is identical to React's. Machine-readable entry: `{ "reason": "...", "allow_tokens": [], "allow_missing_tokens": [], "api": ["ScrollArea::ScrollBar: unmounted scrollbar/thumb kept in an inert <template> placeholder (no data-slot) until the controller mounts them"] }`.
