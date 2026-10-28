# Drawer (shadcn new-york-v4, `vaul` as `DrawerPrimitive`)

Oracle: `dev/port/oracle/src/drawer.tsx` (source_sha `63f04fe50a4bf29b`), manifest `oracle/manifest/drawer.json`.
Behavior source: `dev/react-shadcn-catalog/node_modules/vaul/dist/index.mjs` **vaul 1.1.2** (cited as `vaul:<line>`), which wraps
`@radix-ui/react-dialog` **1.2.0** (`dialog:<line>`, the same file and version as `specs/dialog.md` and `specs/sheet.md`), built on
`react-dismissable-layer` 1.1.20 (`dl:`), `react-focus-scope` 1.2.0 (`fs:`), `react-focus-guards` 1.1.6 (`fg:`), `react-presence` 1.1.11 (`pr:`),
`react-portal` 1.1.18 (`po:`), `react-remove-scroll` 2.7.2 + `react-remove-scroll-bar` 2.3.8 (`rsb:`), `aria-hidden` 1.2.6 (`ah:`).
Tier: `third_party`. Family: Overlay (modal) + a new drag gesture. Drawer is a Radix Dialog whose Root/Overlay/Content are vaul components;
vaul adds the drag-to-dismiss gesture, snap points, background scaling, its own `data-vaul-*` attributes and an injected stylesheet.

Examples: registry `new-york-v4/drawer-demo.json`, `new-york-v4/drawer-dialog.json`; docs examples `drawer-demo`, `drawer-dialog`,
`drawer-scrollable-content`, `drawer-sides`, `drawer-rtl` (`apps/v4/examples/radix/*.tsx`, shadcn-ui/ui main). The recharts `BarChart` of
drawer-demo / drawer-rtl is replaced by its `mt-3 h-[120px]` container (no chart port is involved); `Button`/`Input`/`Label` are raw
elements in scenarios (manifest `registry_dependencies: []`); drawer-dialog is the `< 768px` branch only (the desktop branch is a Dialog,
covered by `scenarios/dialog.json`); the `useTranslation` hook of drawer-rtl is replaced by its Arabic strings.

## API

Every part: `class:` goes through `cn` last (caller wins, tailwind-merge), `**attrs` pass through (`data:`/`aria:` deep-merged), string and
symbol option values accepted (`direction: :left` == `"left"`). Parts that wrap a Radix `Primitive.*` element (Trigger, Close, Overlay,
Content, Title, Description) accept `as_child:` (`false` | tag symbol | `Chadcn::*` instance) through `Chadcn::Base#render_as_child`
(Radix Slot merge: child wins, class plain join slot-first, `data-controller` unioned, `data-action` child first).

| React (drawer.tsx) | Ruby | Notes |
|---|---|---|
| `Drawer` (`DrawerPrimitive.Root`, every vaul Root prop, vaul:879) | `Chadcn::Drawer.new(open: nil, default_open: false, direction: "bottom", dismissible: true, modal: true, handle_only: false, auto_focus: false, snap_points: nil, active_snap_point: nil, fade_from_index: nil, snap_to_sequential_point: false, close_threshold: 0.25, scroll_lock_timeout: 100, should_scale_background: false, set_background_color_on_scale: true, no_body_styles: false, fixed: false, nested: false, disable_prevent_scroll: true, prevent_scroll_restoration: false, reposition_inputs: true, container: nil, id: nil, **attrs) { ... }` | Defaults are vaul's (vaul:879, constants vaul:446-448). `open:` true/false = controlled (the controller only dispatches `open-change`; callers set `data-chadcn--drawer-open-value`), `nil` = uncontrolled from `default_open`. `direction:` one of `"top" \| "bottom" \| "left" \| "right"` (vaul `DrawerDirection`), `nil` = `"bottom"`, anything else raises `ArgumentError`. `snap_points:` Array of Floats (fraction of the viewport) and/or `"<n>px"` Strings (vaul:552-569). `fade_from_index:` `nil` = `snap_points.length - 1` (vaul:879). `active_snap_point:` non-nil = controlled snap point (vaul:509-513). `container:` CSS selector (deviation 3). The `data-slot="drawer"` passed by shadcn never reaches the DOM (vaul Root does not spread props, vaul:879). `**attrs` land on the `display: contents` host (a port-only seam; `class` goes through `cn`). `container:` must be a non-empty String or nil, anything else raises `ArgumentError`. Host values: `modal` is always `true` (the Radix side is always modal) and `vaul-modal` carries vaul's `modal`. |
| `DrawerTrigger` (`DialogPrimitive.Trigger`, vaul:1647) | `Chadcn::Drawer::Trigger.new(as_child: false, class: nil, **attrs) { label }` | Toggles (dialog:89). No default classes. |
| `DrawerPortal` (vaul `Portal` -> `DialogPrimitive.Portal`, vaul:1634-1641) | `Chadcn::Drawer::Portal.new(container: nil, force_mount: false) { ... }` | Renders nothing; each child goes to `container` (default: the Root's `container:`, else `document.body`). Usable on its own (scenario `api__portal-overlay-standalone`). |
| `DrawerOverlay` (vaul `Overlay`, vaul:1387-1407) | `Chadcn::Drawer::Overlay.new(force_mount: false, as_child: false, class: nil, **attrs)` | Renders NOTHING when the Root is `modal: false` (vaul:1392). |
| `DrawerContent` (vaul `Content`, vaul:1409-1533, plus Radix `forceMount`, `onOpenAutoFocus`, `onCloseAutoFocus`, `onEscapeKeyDown`, `onPointerDownOutside`, `onInteractOutside`, `onFocusOutside`) | `Chadcn::Drawer::Content.new(force_mount: false, as_child: false, class: nil, **attrs) { ... }` | Always renders `Drawer::Portal` > (`Drawer::Overlay`, content div) like the oracle; the content div starts with the drag bar (Structure). No `direction` kwarg: the direction comes from the Root. `style:` is passed through (merged after the controller's snap-point variable, vaul:1463-1466). |
| `DrawerHeader` | `Chadcn::Drawer::Header.new(class: nil, **attrs) { ... }` | plain `div`. |
| `DrawerFooter` | `Chadcn::Drawer::Footer.new(class: nil, **attrs) { ... }` | plain `div`. |
| `DrawerTitle` (`DialogPrimitive.Title`) | `Chadcn::Drawer::Title.new(as_child: false, class: nil, **attrs) { text }` | `h2`. |
| `DrawerDescription` (`DialogPrimitive.Description`) | `Chadcn::Drawer::Description.new(as_child: false, class: nil, **attrs) { text }` | `p`. |
| `DrawerClose` (`DialogPrimitive.Close`) | `Chadcn::Drawer::Close.new(as_child: false, class: nil, **attrs) { ... }` | Requests close (dialog:311); a no-op when `dismissible: false` (vaul:1344). |

Not exported by drawer.tsx, so NOT part of the port: vaul `Handle` and `NestedRoot` (vaul:1535-1633). Consequently `handle_only: true` turns
the drag gesture off entirely (only a Handle could start it, vaul:1468, 1591), and the `nested`/`onNested*` displacement of a parent drawer
(vaul:1290-1330) is unreachable: a `Drawer` inside a `Drawer::Content` is an independent Radix layer stacked on top.

Booleans are booleans (`"true"` strings are not accepted). Numbers: `close_threshold` Float 0..1, `scroll_lock_timeout` Integer ms.

Events (dispatched with `this.dispatch` from the `chadcn--drawer` host, `bubbles: true`, prefix `chadcn--drawer:`):

| Event | Origin | detail | cancelable | default action when not prevented |
|---|---|---|---|---|
| `open-change` | vaul `onOpenChange` via its `useControllableState` (vaul:880-904) | `{ open }` | no | uncontrolled: state changes; controlled: nothing |
| `drag` | `onDrag(event, percentageDragged)` (vaul:1081-1082) | `{ originalEvent, percentageDragged }` | no | - |
| `release` | `onRelease(event, open)` (vaul:1249, 1255, 1260, 1270, 1273) | `{ originalEvent, open }` | no | - |
| `close` | `onClose()` (vaul:1175) | `{}` | no | - |
| `animation-end` | `onAnimationEnd(open)`, 500 ms after every state change (vaul:889-891) | `{ open }` | no | - |
| `active-snap-point-change` | `setActiveSnapPoint` (vaul:509-513, 599) | `{ activeSnapPoint }` | no | uncontrolled: snap changes; controlled: nothing |
| `open-auto-focus` | Content `onOpenAutoFocus` (vaul:1476-1481, fs:94-103) | `{}` | yes | with `auto_focus: false` (default) vaul prevents it itself AFTER dispatch, so nothing is focused; with `auto_focus: true` focus first tabbable |
| `close-auto-focus` | `onCloseAutoFocus` (dialog:174-177) | `{}` | yes | focus trigger |
| `escape-key-down` | `onEscapeKeyDown` (dl:91-100) | `{ originalEvent }` | yes | request close |
| `pointer-down-outside` | `onPointerDownOutside` (vaul:1482-1491, dl:55-58) | `{ originalEvent }` | yes | request close (modal only; vaul prevents it when `modal: false`) |
| `focus-outside` | `onFocusOutside` (vaul:1492-1497, dialog:184-187) | `{ originalEvent }` | yes | none: always prevented (Radix side is always modal) |
| `interact-outside` | `onInteractOutside` (dl:57, 87) | `{ originalEvent }` | yes | request close |

"Request close" = vaul's `onOpenChange` guard (vaul:1343-1351): ignored when `dismissible: false`, otherwise `closeDrawer(true)` then state false.
`aria: { describedby: }` on Content is concatenated with the Description id (dialog:262, 319-328). `dir:` on Content is a plain attribute
(vaul and Radix Dialog do not read direction; drawer-rtl only sets it). `ref` has no equivalent.

Example (registry drawer-demo):

```ruby
render Chadcn::Drawer.new do
  render Chadcn::Drawer::Trigger.new(as_child: Chadcn::Button.new(variant: "outline")) { "Open Drawer" }
  render Chadcn::Drawer::Content.new do
    div(class: "mx-auto w-full max-w-sm") do
      render Chadcn::Drawer::Header.new do
        render Chadcn::Drawer::Title.new { "Move Goal" }
        render Chadcn::Drawer::Description.new { "Set your daily activity goal." }
      end
      # ...
      render Chadcn::Drawer::Footer.new do
        render Chadcn::Button.new { "Submit" }
        render Chadcn::Drawer::Close.new(as_child: Chadcn::Button.new(variant: "outline")) { "Cancel" }
      end
    end
  end
end
```

## Structure

Class strings are verbatim from the oracle (set equality is the gate).

**`Drawer` (data-slot `drawer`) and `Drawer::Portal` (data-slot `drawer-portal`)** render NO element and no `data-slot`: vaul Root returns
`DialogPrimitive.Root` + a context provider and drops every unknown prop (vaul:879, 1341-1385); Radix Portal maps children into
`Presence > Portal asChild` (dialog:101). The manifest lists only `drawer-portal` under `non_rendered_slots` (extractor `NO_DOM` does not know
`DrawerPrimitive.Root`; blocker reported), but the port must render no `data-slot="drawer"`. Controller host (deviation 1):
`<div style="display: contents" data-controller="chadcn--drawer" data-chadcn--drawer-*-value...>` with no `data-slot`, no classes, wrapping the
block in place.

**Markers (port-only, the shared dialog controller reads them).** Trigger, Overlay, Content and Close carry `data-chadcn--dialog-part="trigger|overlay|content|close"`; the Portal `<template>` carries `data-chadcn--dialog-template="<root id>"` and `data-chadcn--dialog-options` (JSON `{forceMount, container}`). They are not React attributes and are excluded from the DOM comparison.

**Portal and Presence.** Overlay then Content are appended directly to the container (`document.body` default) with no wrapper (po:17); closed
and not force-mounted they do not exist (pr:26). Server: closed -> the Portal children ship in one inert `<template>` in the host
(deviation 2, `template_mount` primitive); open on first render (`default_open: true` / `open: true`) -> rendered in place and moved in
`connect()`. Focus guards (fg:15-47) while a Content is mounted, ref-counted.

| Part | Tag | data-slot | Server-rendered attributes | Set by Stimulus | Classes |
|---|---|---|---|---|---|
| `Drawer::Trigger` | `button type="button"` | `drawer-trigger` (child wins with `as_child:` a component) | `aria-haspopup="dialog" aria-expanded data-state="closed\|open"`, `aria-controls` = content id only while open (dialog:80-87) | same on every transition | none |
| `Drawer::Overlay` | `div` | `drawer-overlay` | `data-state` (dialog:137), `style="pointer-events: auto"` (dialog:140), `data-vaul-overlay=""`, `data-vaul-snap-points="true"` iff open AND snap points given else `"false"`, `data-vaul-snap-points-overlay="true"` iff open AND `shouldFade` (true without snap points; with snap points iff the active point is `snap_points[fade_from_index]`, vaul:539) else `"false"`, `data-vaul-animate` (below) (vaul:1398-1406); caller attrs after | `data-state`, the three `data-vaul-*` flags, `aria-hidden="true" data-aria-hidden="true"` while a modal Content is mounted (ah:38-90), inline `opacity`/`transition` during drag and snapping (Behavior) | `fixed inset-0 z-50 bg-black/50 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:animate-in data-[state=open]:fade-in-0` |
| `Drawer::Content` | `div` | `drawer-content` | `role="dialog" id tabindex="-1" data-state` (dialog:259-263, fs:145), `aria-labelledby` iff a Title is rendered, `aria-describedby` iff a Description is rendered or passed (dialog:261-262); `data-vaul-drawer=""`, `data-vaul-drawer-direction="<direction>"`, `data-vaul-delayed-snap-points="false"`, `data-vaul-snap-points="true"` iff open AND snap points else `"false"`, `data-vaul-custom-container="true"` iff a container is set else `"false"`, `data-vaul-animate` (vaul:1454-1466); caller attrs after them (can override) | `data-state`; `data-vaul-snap-points`; `data-vaul-delayed-snap-points="true"` one rAF after mount when snap points exist (vaul:1442-1448); `style`: `pointer-events: auto` while body pointer events are disabled (dl:147), `--snap-point-height: <offset>px` before the caller style when snap points exist (vaul:1463-1466), `transform`/`transition` during drag/reset/snap; class `vaul-dragging` while a drag is active (vaul:1057, 1217, 1224) | `group/drawer-content fixed z-50 flex h-auto flex-col bg-background` + the four direction strings below + `class:` (one `cn`) |
| direction `top` | | | | | `data-[vaul-drawer-direction=top]:inset-x-0 data-[vaul-drawer-direction=top]:top-0 data-[vaul-drawer-direction=top]:mb-24 data-[vaul-drawer-direction=top]:max-h-[80vh] data-[vaul-drawer-direction=top]:rounded-b-lg data-[vaul-drawer-direction=top]:border-b` |
| direction `bottom` | | | | | `data-[vaul-drawer-direction=bottom]:inset-x-0 data-[vaul-drawer-direction=bottom]:bottom-0 data-[vaul-drawer-direction=bottom]:mt-24 data-[vaul-drawer-direction=bottom]:max-h-[80vh] data-[vaul-drawer-direction=bottom]:rounded-t-lg data-[vaul-drawer-direction=bottom]:border-t` |
| direction `right` | | | | | `data-[vaul-drawer-direction=right]:inset-y-0 data-[vaul-drawer-direction=right]:right-0 data-[vaul-drawer-direction=right]:w-3/4 data-[vaul-drawer-direction=right]:border-l data-[vaul-drawer-direction=right]:sm:max-w-sm` |
| direction `left` | | | | | `data-[vaul-drawer-direction=left]:inset-y-0 data-[vaul-drawer-direction=left]:left-0 data-[vaul-drawer-direction=left]:w-3/4 data-[vaul-drawer-direction=left]:border-r data-[vaul-drawer-direction=left]:sm:max-w-sm` |
| drag bar (first child of Content, before the block) | `div` | **none** (plain div in the oracle, not vaul `Handle`: no `data-vaul-handle`, no `aria-hidden`) | class only | | `mx-auto mt-4 hidden h-2 w-[100px] shrink-0 rounded-full bg-muted group-data-[vaul-drawer-direction=bottom]/drawer-content:block` (visible only for `bottom`; scenarios observe it as `[data-slot=drawer-content] > div:first-child`) |
| `Drawer::Header` | `div` | `drawer-header` | | | `flex flex-col gap-0.5 p-4 group-data-[vaul-drawer-direction=bottom]/drawer-content:text-center group-data-[vaul-drawer-direction=top]/drawer-content:text-center md:gap-1.5 md:text-left` |
| `Drawer::Footer` | `div` | `drawer-footer` | | | `mt-auto flex flex-col gap-2 p-4` |
| `Drawer::Title` | `h2` | `drawer-title` | `id` (dialog:284) | | `font-semibold text-foreground` |
| `Drawer::Description` | `p` | `drawer-description` | `id` (dialog:297) | | `text-sm text-muted-foreground` |
| `Drawer::Close` | `button type="button"` | `drawer-close` | no `data-state`, no `aria-*` (dialog:305-312) | | none |

`data-vaul-animate` (Overlay and Content): `"false"` when the drawer is open on first render (`shouldAnimate = !defaultOpen`, vaul:917), else
`"true"`. vaul flips its ref to true one rAF after mount (vaul:1107-1111) but the attribute is only re-read when the Root re-renders, so a
default-open drawer keeps `"false"` (no enter animation, CSS `[data-vaul-animate=false]{animation:none!important}`) until the first Root
state change: the first `pointerdown` inside Content (drag start, vaul:959) or the first open/close transition; then `"true"` forever.
Scenarios `open__default-open`, `open__default-open-pointerdown-flips-animate`, `animation__default-open-no-enter`.

DOM order inside Content: drag bar, then the block. Body order while open: `[focus-guard] ... page ... Overlay, Content [focus-guard]`.

**Ids.** As Dialog (dialog:56-58): content, title and description ids from the Root; a caller `id:` on a part replaces that element's id but
`aria-controls`/`aria-labelledby`/`aria-describedby` keep the generated ids (dangling, scenario `aria__caller-ids-override`).

**Document while open (modal):** body `style="pointer-events: none"` (dl:110-115) and, after the first close, `pointer-events: auto` left on
body by vaul (vaul:899-902, it runs after Radix restored the original value); scroll lock owned by the Overlay (`data-scroll-locked="1"` +
the injected `body[data-scroll-locked]` rule, rsb:10-39); `aria-hidden="true" data-aria-hidden="true"` on every other body child (ah:65-79,
133); `html` gets `style="scroll-behavior: auto"` while open, restored on close (vaul:1276-1289).

**vaul stylesheet.** vaul injects one `<style>` into `<head>` at import (vaul:2-9, 62). Its rules give the drawer its motion and layout and must
be shipped verbatim (Third-party): `[data-vaul-drawer]{touch-action:none;will-change:transform;transition:transform .5s cubic-bezier(.32,.72,0,1);animation-duration:.5s;animation-timing-function:cubic-bezier(0.32,0.72,0,1)}`,
the `slideFrom*/slideTo*` animations keyed on `[data-vaul-snap-points=false][data-vaul-drawer-direction=*][data-state=open|closed]`, the
snap-point transforms (`--initial-transform`, `--snap-point-height`), overlay `fadeIn`/`fadeOut` and snap-point opacity rules,
`[data-vaul-animate=false]{animation:none!important}`, the `::after` background extension (200% beyond the edge, skipped with
`data-vaul-custom-container=true`), `[data-vaul-handle]` rules (unused: no Handle), and `@media (hover:hover) and (pointer:fine){[data-vaul-drawer]{user-select:none}}`.
Without it the shadcn classes alone produce no slide animation (the oracle has no `slide-in-*` classes).

## Behavior

States: `closed` / `open` (Radix `getState`, dialog:330-332) plus Presence `unmountSuspended`; orthogonal: `dragging` (class `vaul-dragging`),
and with snap points the active snap index. Radix Dialog is ALWAYS modal inside vaul: vaul passes only `defaultOpen`, `open`, `onOpenChange`
to `DialogPrimitive.Root` (vaul:1341-1352), never `modal`. vaul's `modal` prop only removes the Overlay (vaul:1392) and changes the
outside-pointer and body rules below.

**Transitions**

| From | Trigger | To | Notes |
|---|---|---|---|
| closed | click on `Drawer::Trigger` (Enter/Space = native click) | open | dialog:65, 89 -> vaul guard vaul:1343-1351 (`hasBeenOpened = true`). Caller `preventDefault()` on the click cancels. Disabled trigger never fires. |
| open | click on `Drawer::Trigger` | closed | reachable: with the default `auto_focus: false` focus STAYS on the trigger after opening, so Enter/Space on it toggles closed (scenario `keyboard__enter-on-trigger-toggles-closed`); by pointer only with `modal: false` (body pointer events restored). |
| open | click on any `Drawer::Close` | closed | dialog:311 -> vaul guard (no-op if `dismissible: false`). |
| open | `Escape` (document capture, top layer only) | closed | dl:91-107, dispatch `escape-key-down` first; then vaul guard. |
| open | primary press+release outside Content | closed | modal only: Radix deferred pointer-down-outside (dialog:266, dl:264-277), Overlay is a dismissable surface (dialog:118-119); vaul first calls the caller handler, then prevents it when `modal: false` (vaul:1482-1491). Right-click and ctrl+left-click are prevented (dialog:178-183). "Outside" by direction: above a bottom drawer, below a top one, left of a right one, right of a left one. |
| open | focus moves outside | unchanged | always prevented (dialog:184-187, vaul:1492-1497). |
| open | drag released past the threshold or flicked (below) | closed | `closeDrawer()` (vaul:1173-1184): cancels drag, dispatches `close`, sets state false; NOT gated by the Radix path, but drag never starts when `dismissible: false` without snap points (vaul:955). |
| any | `open:` controlled | unchanged | requests only dispatch `open-change` (vaul:488-494). |

`open-change` fires on every state change, also uncontrolled (vaul:468-477). Side effects of each state change (vaul:884-903): closing (not
`nested`) restores the Safari body position; after 500 ms `animation-end {open}`; opening non-modal sets `body.style.pointerEvents = "auto"` in
the next rAF; closing sets it to `"auto"` immediately. On close, if snap points exist, the active snap point resets to `snap_points[0]` 500 ms
later (vaul:1179-1183).

**Modal vs non-modal** (vaul `modal`, default true):

| Aspect | `modal: true` | `modal: false` |
|---|---|---|
| Overlay | rendered | not rendered (vaul:1392) |
| Scroll lock | yes (Radix Overlay `RemoveScroll`, dialog:125-133) | no (it lives in the Overlay) |
| hideOthers | yes (dialog:163-166) | yes (Radix side is still modal) |
| body `pointer-events: none` | while open (dl:108-127) | set by Radix, then `auto` in the next rAF (vaul:892-898, 1331-1340): the page is clickable; Content keeps `style="pointer-events: auto"` |
| Outside press | dismisses | never dismisses (vaul:1484-1486) |
| Focus trap | trapped (dialog:172) | trapped too: focus that leaves Content after having been inside is pulled back (fs:52-66) |
| Close focus | trigger (dialog:174-177) | trigger |

**Keyboard**

| Key | Where | Effect |
|---|---|---|
| Enter / Space | Trigger | toggles (opens; when still focused after opening, closes) |
| Enter / Space | any `Drawer::Close` | requests close |
| Escape | anywhere, top layer | requests close (cancelable via `escape-key-down`) |
| Tab / Shift+Tab | inside Content | loops last->first / first->last (fs:133-138, `loop: true` dialog:251) |
| Tab | focus still on the trigger after opening | normal document order; the trap is inert until focus first enters Content, because `lastFocusedElement` is null and `focus(null)` is a no-op (fs:52-66); once inside, leaving is pulled back |
| Tab | Content focused with no tabbables | prevented (fs:130-131) |

No arrow-key behavior (vaul has none).

**Focus on open.** Dispatch `open-auto-focus`; vaul then calls `preventDefault()` unless `auto_focus: true` (vaul:1476-1481), so by default
NOTHING is focused: focus stays where it was (the trigger) although the trigger is now `aria-hidden` (React does the same; do not "fix" it).
With `auto_focus: true` Radix's default applies: first tabbable non-link candidate with `select` (fs:98-102, 266-268), else Content.
**Focus on close.** After Presence exit, `setTimeout(0)`: `close-auto-focus`, then focus the (last rendered) trigger (dialog:174-177, fs:105-117).
Nested drawers stack focus scopes (fs:238-255).

**Drag gesture (new; vaul:953-1106, 1185-1275, 1409-1533).** Pointer handlers live on Content (and the Overlay `mouseup`, vaul:1395):

1. `pointerdown` on Content (ignored when `handle_only`, vaul:1468): record `pointerStart {x: pageX, y: pageY}`; `onPress` (vaul:953-970):
   return if `!dismissible && !snap_points`; record Content height/width, `isDragging = true`, `dragStartTime = now`, `setPointerCapture` on the
   event target, `pointerStart` = `pageY` (vertical) or `pageX` (horizontal). On iOS a one-shot `touchend` resets `isAllowedToDrag`.
2. `pointermove` on Content (vaul:1498-1515): remember it as the last pointer event; with a start point, `delta = page - start`; swipe start
   threshold 10 px for touch, 2 px otherwise; `isDeltaInDirection` (vaul:1419-1441): once beyond the threshold (or moving in reverse) it
   latches true; within the threshold it allows only the axis of the direction. Allowed -> `onDrag`; otherwise, past the threshold on either
   axis, forget the start point (no drag until the next press).
3. `onDrag` (vaul:1029-1106): `dirMul = +1` for bottom/right, `-1` for top/left; `draggedDistance = (start - current) * dirMul` (> 0 = toward
   opening). With snap points and `!dismissible`, refuse closing past the first point. `percentageDragged = |d| / drawerDimension` (or the
   snap fraction, vaul:679-700). Unless already allowed, `shouldDrag(target, d > 0)` (vaul:971-1028) must pass: never from a `<select>` or
   inside `[data-vaul-no-drag]`; horizontal directions always pass; vertical: blocked for 500 ms after open (`openTime`, vaul:988, 1282), passes
   if already displaced in the closing direction, blocked while text is selected, blocked within `scroll_lock_timeout` (100 ms) of the last
   prevented attempt, blocked when dragging toward opening (records the time), and blocked when an ancestor below `role=dialog` is scrolled
   (`scrollTop != 0`). Once allowed it stays allowed until release. Then: add class `vaul-dragging`; inline `transition: none` on Content and
   Overlay; with snap points move to the snap-relative offset (vaul:665-678); toward opening without snap points: rubber band
   `translate = min(-8 * (ln(d + 1) - 2), 0) * dirMul` (vaul:413-415, 1072-1079) and stop; otherwise dispatch `drag`, set Overlay
   `opacity: 1 - percentageDragged; transition: none` (when `shouldFade`), scale the background wrapper (if enabled, vaul:1088-1098) and
   set Content `transform: translate3d(0, |d| * dirMul px, 0)` (vertical) / `translate3d(|d| * dirMul px, 0, 0)` (horizontal).
4. `pointerup` on Content, `mouseup` on Overlay, `pointerout` / `contextmenu` on Content (with the last pointer event) -> `onRelease`
   (vaul:1222-1275): no-op unless dragging; remove `vaul-dragging`, end drag; read the current translate from the computed transform
   (vaul:397-412); stop if `shouldDrag` fails or the translate is 0/NaN. `velocity = |distMoved| / ms since press`; if > 0.05, suppress
   input auto-focus for 200 ms (`justReleased`). Snap points -> snap release (vaul:623-664). Else: moved toward opening -> `resetDrawer`,
   `release {open: true}`; `velocity > 0.4` (`VELOCITY_THRESHOLD`) -> close, `release {open: false}`; `|translate| >= visible size *
   close_threshold` (default 0.25 of min(rect, viewport) height for vertical, width for horizontal) -> close; else `release {open: true}` +
   `resetDrawer`.
5. `resetDrawer` (vaul:1185-1214): Content `transform: translate3d(0, 0, 0); transition: transform 0.5s cubic-bezier(0.32,0.72,0,1)`;
   Overlay `transition: opacity 0.5s cubic-bezier(0.32,0.72,0,1); opacity: 1`; these inline styles STAY on the elements (they are compared).

**Snap points** (vaul:508-712): offsets per point = viewport (or container) size minus the point in px (fraction x size, or parsed `"Npx"`),
negated for top/left (vaul:540-575). Initial active point `snap_points[0]` (vaul:511). Content gets `data-vaul-snap-points="true"` and
`--snap-point-height: <offset of active>px`; one rAF after mount `data-vaul-delayed-snap-points="true"` so the CSS transform
`translate3d(0, var(--snap-point-height), 0)` positions it. `snapToPoint` (vaul:580-607) writes Content `transition: transform 0.5s ...;
transform: translate3d(...)` and Overlay `transition: opacity 0.5s ...; opacity: 0|1` (0 below `fade_from_index`), dispatches
`active-snap-point-change`; in React it runs on every snap change and whenever the Root re-renders with a mounted Content (the first drag
press after open), reproduce both. Release (vaul:623-664): `velocity > 2` without `snap_to_sequential_point` jumps to the last point
(upward) or closes / returns to the first (downward); `velocity > 0.4` and `|d| < 40%` of the viewport moves one point in the drag
direction (closing from the first point if dismissible); otherwise snap to the closest offset. Overlay fade (`shouldFade`, vaul:539) and
`getPercentageDragged` (vaul:679-700) between `fade_from_index - 1` and `fade_from_index`. With snap points `onSnapPointChange` at the last
point resets `openTime` (500 ms drag block, vaul:923-926).

**Background scaling** (`should_scale_background`, vaul:714-760; needs a caller element `[data-vaul-drawer-wrapper]`, legacy
`[vaul-drawer-wrapper]`): while open, body `background: black` (unless `set_background_color_on_scale: false` or `no_body_styles`), wrapper
`transform-origin: top|left; transition-property: transform, border-radius; transition-duration: 0.5s; transition-timing-function:
cubic-bezier(0.32,0.72,0,1); border-radius: 8px; overflow: hidden; transform: scale((innerWidth - 26) / innerWidth) translate3d(0,
calc(env(safe-area-inset-top) + 14px), 0)` (horizontal: translate on x); on close the wrapper's previous `cssText` is restored at once and the
body background 500 ms later. During drag the wrapper follows `percentageDragged` (vaul:1088-1098).

**Platform-specific (must be reproduced, not observable in Chromium):** Safari only `usePositionFixed` (vaul:762-877: body
`position: fixed !important; top: -scrollY; left: -scrollX; right: 0; height: auto` while open unless `no_body_styles`/standalone PWA, 300 ms
toolbar correction, scroll restored on close unless `prevent_scroll_restoration` and the URL changed; non-modal restores after 500 ms);
iOS only `usePreventScroll` (vaul:136-290, active while open, modal, not dragging, not `justReleased`, `reposition_inputs` and
`disable_prevent_scroll`); `visualViewport` resize keyboard handling of Content `height`/`bottom` (vaul:1112-1172, `fixed` keeps the
position). These change no `data-slot` DOM in the parity browser.

**Presence.** Open: Overlay/Content mount with `data-state="open"`; vaul CSS runs `slideFrom<Direction>` (0.5 s, cubic-bezier(0.32,0.72,0,1))
on Content and `fadeIn` on the Overlay (the shadcn `animate-in fade-in-0` classes on the Overlay apply as well; CSS cascade decides, same
stylesheet order as the catalog: vaul's `<style>` is appended to `<head>` after the app CSS). Close: `data-state="closed"` at once on Trigger,
Overlay and Content, `data-vaul-snap-points*` drop to `"false"`, trap and body pointer events released; nodes stay until `animationend` of
`slideTo<Direction>`/`fadeOut`, then are removed together with hideOthers, scroll lock and focus guards (pr:20-130). `animation-name: none`
-> removed in the same frame.

**forceMount.** `force_mount: true` on `Drawer::Content` has no effect (its inner Portal is not force-mounted, dialog:101), same as Sheet.
`Drawer::Portal.new(force_mount: true)` keeps its children mounted while closed.

**Timers** (vaul defaults): 500 ms drag block after open / after reaching the last snap point; 100 ms `scroll_lock_timeout`; 200 ms
`justReleased`; 500 ms `animation-end`, snap reset, background-color restore; 300 ms Safari toolbar fix; one rAF for `data-vaul-animate`,
`data-vaul-delayed-snap-points` and non-modal body pointer events; `setTimeout(0)` close autofocus (fs:107) and outside-pointerdown arming
(dl:292-294).

Positioning: none (CSS `fixed` at an edge). Responsive: left/right `w-3/4`, `sm:max-w-sm` from 640 px; top/bottom `max-h-[80vh]`; header
centered for top/bottom below 768 px (`md:text-left`).

Primitives composed: `portal`, `template_mount`, `presence`, `dismissable_layer`, `focus_scope`, `focus_guards`, `hide_others`, `scroll_lock`,
`ids`, `turbo_cache`, and the Dialog overlay behavior shared with `chadcn--dialog`/`chadcn--sheet` (import it, do
not copy it). The drag calls `setPointerCapture` directly instead of composing `pointer_capture`, because that primitive calls `preventDefault()` on pointerdown, which vaul does not. The drag/snap/scale logic is new and drawer-only: it lives in `chadcn--drawer` (or a `drawer_gesture.js` primitive if the
orchestrator wants it shared). Controller `chadcn--drawer` (radix-stimulus R12) with values for every Root kwarg above (`open`,
`controlled`, `direction`, `dismissible`, `modal`, `handle-only`, `auto-focus`, `snap-points` (JSON), `active-snap-point`, `fade-from-index`,
`snap-to-sequential-point`, `close-threshold` 0.25, `scroll-lock-timeout` 100, `should-scale-background`, `set-background-color-on-scale`,
`no-body-styles`, `fixed`, `nested`, `disable-prevent-scroll`, `prevent-scroll-restoration`, `reposition-inputs`, `container`).
`disconnect()` cancels timers, releases every primitive, removes portaled nodes, restores body/html/wrapper styles.

## Third-party

Library: **vaul 1.1.2** (`dev/react-shadcn-catalog/package.json` `"vaul": "^1.1.2"`, resolved 1.1.2) on `@radix-ui/react-dialog` 1.2.0.
Choice: NO JavaScript dependency is added (vaul is React-only; same policy as sonner, see `deviations/sonner.json`). vaul's behavior is
reimplemented in the `chadcn--drawer` Stimulus controller on the shared Radix primitives, and vaul's injected stylesheet (vaul:62) is shipped
verbatim as `app/assets/tailwind/chadcn/vaul.css`, imported from `engine.css` like `sonner.css` (MIT, attribution in THIRD_PARTY_NOTICES.md).
No class tokens are added to the oracle's.

DOM mapping (vaul -> shadcn -> port):

| vaul | shadcn part | DOM |
|---|---|---|
| `Drawer.Root` (Radix `Dialog.Root` + DrawerContext) | `Drawer` | none (controller host, deviation 1) |
| `Drawer.Trigger` = Radix `Dialog.Trigger` | `DrawerTrigger` | `button[data-slot=drawer-trigger]` |
| `Drawer.Portal` = Radix `Dialog.Portal` with the Root's container | `DrawerPortal` | none |
| `Drawer.Overlay` = Radix `Dialog.Overlay` + `data-vaul-overlay`, `data-vaul-snap-points`, `data-vaul-snap-points-overlay`, `data-vaul-animate`, `onMouseUp` release | `DrawerOverlay` | `div[data-slot=drawer-overlay]` |
| `Drawer.Content` = Radix `Dialog.Content` + `data-vaul-drawer`, `data-vaul-drawer-direction`, `data-vaul-delayed-snap-points`, `data-vaul-snap-points`, `data-vaul-custom-container`, `data-vaul-animate`, pointer handlers, `onOpenAutoFocus` prevented, `onPointerDownOutside`/`onFocusOutside` rules | `DrawerContent` | `div[data-slot=drawer-content][role=dialog]`, first child the shadcn drag bar `div` |
| Radix `Dialog.Title` / `Dialog.Description` / `Dialog.Close` | `DrawerTitle` / `DrawerDescription` / `DrawerClose` | `h2` / `p` / `button` |
| `Drawer.Handle`, `Drawer.NestedRoot` | not exported by shadcn | not ported |

## Dependencies

- `Chadcn::Base`: `cn`, `merge_attrs`, `render_as_child`, ids (`Chadcn::Sequence`).
- No icon and no other `Chadcn` component is rendered (manifest `icons: []`, `registry_dependencies: []`). Callers compose `Chadcn::Button`
  (trigger/close via `as_child:`), `Chadcn::Input`, `Chadcn::Label`; scenarios use raw elements for them.
- Primitives (`app/javascript/chadcn/primitives/`): `portal.js`, `template_mount.js`, `presence.js`, `dismissable_layer.js`, `focus_scope.js`,
  `focus_guards.js`, `hide_others.js`, `scroll_lock.js`, `ids.js`, `turbo_cache.js`; behavior shared with `chadcn--dialog`.
- Shared files the orchestrator/infra must add (the builder may not, shadcn-port R13): `app/assets/tailwind/chadcn/vaul.css` (vaul:62 verbatim)
  + `@import "./vaul.css";` in `engine.css` + a THIRD_PARTY_NOTICES.md entry; `oracle_extract.rb` `NO_DOM` must include `DrawerPrimitive.Root`
  so `drawer` lands in `non_rendered_slots` (otherwise G1 demands a `data-slot="drawer"` React never renders).

## Deviations

Recorded in `dev/port/deviations/drawer.json`:

1. **Controller host.** `Drawer` renders nothing in React; one `<div style="display: contents" data-controller="chadcn--drawer">` without
   `data-slot`/classes wraps the block (zero, one or several triggers; controlled `open`). Layout-neutral, invisible to G2.
2. **Closed Presence parts in a `<template>`** inside the host, mounted into the container on open (`template_mount`).
3. **`container:`** (Root and `Drawer::Portal`) is a CSS selector string instead of a DOM element (React passes an `HTMLElement`).
4. **Ids**: `Drawer` takes `id:` as the base of the generated ids (Radix uses React `useId`), same as Dialog/Sheet.
5. **Callbacks are events**: `onDrag`, `onRelease`, `onClose`, `onAnimationEnd`, `setActiveSnapPoint` become `chadcn--drawer:drag`, `:release`,
   `:close`, `:animation-end`, `:active-snap-point-change` (api-mapping rule for callbacks; `setActiveSnapPoint` has no `on` prefix, so the
   event name is spelled out here).
6. **No JS dependency**: vaul is reimplemented, its stylesheet shipped as `vaul.css` (Third-party).

No class tokens added or removed (`allow_tokens` / `allow_missing_tokens` empty).
