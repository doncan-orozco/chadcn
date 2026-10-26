# Sheet (shadcn new-york-v4, Radix `Dialog` as `SheetPrimitive`)

Oracle: `dev/port/oracle/src/sheet.tsx` (source_sha `ea473d38a26a9b0b`), manifest `oracle/manifest/sheet.json`.
Behavior source: `dev/react-shadcn-catalog/node_modules/@radix-ui/react-dialog/dist/index.mjs` v1.2.0 (cited as `dialog:<line>`), built on
`react-dismissable-layer` 1.1.20 (`dl:`), `react-focus-scope` 1.2.0 (`fs:`), `react-focus-guards` 1.1.6 (`fg:`), `react-presence` 1.1.11 (`pr:`),
`react-portal` 1.1.18 (`po:`), `react-remove-scroll` 2.7.2 + `react-remove-scroll-bar` 2.3.8 (`rsb:`), `aria-hidden` 1.2.6 (`ah:`), all from `radix-ui` 1.7.0.
Same Radix primitive and versions as `specs/dialog.md`; every line reference below was re-checked against the same files. Icons: `lucide-react` 0.577.0.
Tier: `overlay`. Family: Overlay (modal). Sheet is a Dialog with different shadcn styling, a `side` prop, and no footer close button.

Examples: registry `new-york-v4/sheet-demo.json`, `new-york-v4/sheet-side.json`; docs examples `sheet-demo`, `sheet-side`, `sheet-no-close-button`, `sheet-rtl` (`apps/v4/examples/radix/*.tsx` on shadcn-ui/ui main; the sheet markup they use is style independent, their Button/Input/Label/Field are replaced by raw elements in scenarios, see Dependencies).

## API

Every part: `class:` goes through `cn` last (caller wins, tailwind-merge), `**attrs` pass through (`data:`/`aria:` deep-merged), string and symbol keys accepted. Parts that wrap a Radix `Primitive.*` element (Trigger, Close, Overlay, Content, Title, Description) accept `as_child:` (`false` | tag symbol | `Chadcn::*` instance), implemented once by `Chadcn::Base#render_as_child` (Radix Slot merge: child wins, so `as_child: Button.new` keeps `data-slot="button"`; class plain join slot-first; `data-controller` unioned; `data-action` child first).

| React (sheet.tsx) | Ruby | Notes |
|---|---|---|
| `Sheet` (`SheetPrimitive.Root`; Radix props `open`, `defaultOpen`, `onOpenChange`, `modal = true`, dialog:30-38) | `Chadcn::Sheet.new(open: nil, default_open: false, modal: true, **attrs) { ... }` | `open:` true/false = controlled: the controller never changes its own state, it only dispatches `open-change` (callers set `data-chadcn--sheet-open-value`). `open: nil` = uncontrolled, starts at `default_open`. Renders no shadcn element (see Structure, deviation 1). |
| `SheetTrigger` | `Chadcn::Sheet::Trigger.new(as_child: false, class: nil, **attrs) { label }` | Toggles (dialog:89 `onOpenToggle`). No default classes. |
| `SheetClose` | `Chadcn::Sheet::Close.new(as_child: false, class: nil, **attrs) { ... }` | Closes (dialog:311). No default classes. |
| `SheetPortal` (NOT exported by sheet.tsx; used only inside `SheetContent`) | `Chadcn::Sheet::Portal.new { ... }` | Exists because `Sheet::Content` composes it (same structure as the oracle). Renders nothing itself; its children go to `document.body`. Because the React file does not export it, no caller can pass `forceMount` / `container` to it, so the Ruby class takes no options (no `container:` deviation needed). Not usable in scenarios (not an export). |
| `SheetOverlay` (NOT exported; rendered by `SheetContent` with no props) | `Chadcn::Sheet::Overlay.new(force_mount: false, as_child: false, class: nil, **attrs)` | Rendered only when `modal` (dialog:109). Same reachability as Portal: only `Sheet::Content` renders it, with no arguments. |
| `SheetContent` (`side = "right"`, `showCloseButton = true`, plus Radix `forceMount`, `onOpenAutoFocus`, `onCloseAutoFocus`, `onEscapeKeyDown`, `onPointerDownOutside`, `onInteractOutside`, `onFocusOutside`) | `Chadcn::Sheet::Content.new(side: "right", show_close_button: true, force_mount: false, as_child: false, class: nil, **attrs) { ... }` | Always renders `Sheet::Portal` > (`Sheet::Overlay`, content div) like the oracle. `side:` one of `"top" \| "right" \| "bottom" \| "left"` (TS union), strings or symbols (`side: :left` == `"left"`), `nil` = `"right"`; any other value raises `ArgumentError` (the TS type forbids it; React at runtime would silently emit no side classes). `side` is NOT rendered as an attribute (no `data-side` in new-york-v4). Radix callbacks become cancelable events (below). |
| `SheetHeader` | `Chadcn::Sheet::Header.new(class: nil, **attrs) { ... }` | plain `div`. |
| `SheetFooter` | `Chadcn::Sheet::Footer.new(class: nil, **attrs) { ... }` | plain `div`; NO `show_close_button` (unlike Dialog::Footer, the oracle has none). |
| `SheetTitle` | `Chadcn::Sheet::Title.new(as_child: false, class: nil, **attrs) { text }` | `h2`. |
| `SheetDescription` | `Chadcn::Sheet::Description.new(as_child: false, class: nil, **attrs) { text }` | `p`. |

Options: `modal:`, `open:`, `default_open:`, `show_close_button:`, `force_mount:` are booleans (React types are boolean; strings `"true"`/`"false"` are not accepted).

Events (dispatched with `this.dispatch` from the `chadcn--sheet` host, `bubbles: true`; prefix `chadcn--sheet:`), identical to Dialog because the primitive is the same:

| Event | Radix origin | detail | cancelable | default action when not prevented |
|---|---|---|---|---|
| `open-change` | `onOpenChange` (dialog:42-47) | `{ open }` | no | uncontrolled: state changes; controlled: nothing |
| `open-auto-focus` | Content `onOpenAutoFocus` -> FocusScope `onMountAutoFocus` (dialog:254, fs:94-103) | `{}` | yes | focus first tabbable (see Behavior) |
| `close-auto-focus` | `onCloseAutoFocus` (dialog:174-177, fs:106-113) | `{}` | yes | focus trigger |
| `escape-key-down` | `onEscapeKeyDown` (dl:91-100) | `{ originalEvent }` | yes | close |
| `pointer-down-outside` | `onPointerDownOutside` (dl:55-58) | `{ originalEvent }` | yes | close |
| `focus-outside` | `onFocusOutside` (dl:79-89) | `{ originalEvent }` | yes | close (modal always prevents it, dialog:184-187) |
| `interact-outside` | `onInteractOutside` (dl:57, 87) | `{ originalEvent }` | yes | close |

`aria: { describedby: }` / `"aria-describedby":` on Content is concatenated with the Description id (dialog:262, `concatAriaDescribedby` dialog:319-328: split on whitespace, dedupe, caller ids first). `dir:` on Content is a plain pass-through attribute (Radix Dialog does not read direction; the `sheet-rtl` docs example only sets `dir` and picks `side`). `ref` has no equivalent.

Example (registry sheet-demo):

```ruby
render Chadcn::Sheet.new do
  render Chadcn::Sheet::Trigger.new(as_child: Chadcn::Button.new(variant: "outline")) { "Open" }
  render Chadcn::Sheet::Content.new do
    render Chadcn::Sheet::Header.new do
      render Chadcn::Sheet::Title.new { "Edit profile" }
      render Chadcn::Sheet::Description.new { "Make changes to your profile here. Click save when you're done." }
    end
    div(class: "grid flex-1 auto-rows-min gap-6 px-4") { ... }
    render Chadcn::Sheet::Footer.new do
      render Chadcn::Button.new(type: "submit") { "Save changes" }
      render Chadcn::Sheet::Close.new(as_child: Chadcn::Button.new(variant: "outline")) { "Close" }
    end
  end
end
```

## Structure

Class strings below are verbatim from the oracle (order irrelevant, set equality is the gate).

**`Sheet` (data-slot `sheet`) and `Sheet::Portal` (data-slot `sheet-portal`)** render NO element and no `data-slot`: Radix Root is a context provider (dialog:50-71) and Portal maps each child into `Presence > Portal asChild` (dialog:101); `data-slot="sheet"` / `"sheet-portal"` are dropped by Radix and never reach the React DOM. (The manifest lists only `sheet-portal` under `non_rendered_slots`; `sheet` is missing because the extractor's `NO_DOM` pattern matches `DialogPrimitive.Root` but not the alias `SheetPrimitive.Root`. That is an oracle bug, reported as a blocker; the port must still render NO `data-slot="sheet"`, as the React DOM has none.) The port renders one controller host (deviation 1): `<div style="display: contents" data-controller="chadcn--sheet" data-chadcn--sheet-open-value data-chadcn--sheet-modal-value data-chadcn--sheet-controlled-value>` with no `data-slot`, no classes. The host wraps the block in place.

**Portal and Presence.** Each child of the Portal (Overlay, then Content) is appended **directly** to `document.body`, with no wrapper (po:17 `Primitive.div asChild`), in order Overlay, Content, after existing body children. While closed (and not force-mounted) they do not exist in the DOM (pr:26). Server rendering: closed -> the Portal children are rendered inside one `<template>` in the host (deviation 2; no `data-slot`, inert); open on first render (`default_open: true` / `open: true`) -> rendered in place and moved to `body` in `connect()`. Because the moved nodes leave the controller element, the controller binds their listeners directly.

Focus guards (fg:15-47, while any Content is mounted): `<span data-radix-focus-guard tabindex="0" style="outline: none; opacity: 0; position: fixed; pointer-events: none">` as first and last child of `body`, ref-counted. No `data-slot`.

| Part | Tag | data-slot | Server-rendered attributes | Set by Stimulus | Classes |
|---|---|---|---|---|---|
| `Sheet::Trigger` | `button` (`type="button"`) | `sheet-trigger` (with `as_child:` a Chadcn component the child wins, e.g. `data-slot="button"`) | `type="button" aria-haspopup="dialog" aria-expanded="false\|true" data-state="closed\|open"`, `aria-controls` = content id ONLY while open (dialog:80-87); caller attrs after them (can override) | `aria-expanded`, `data-state`, `aria-controls` on every transition | none |
| `Sheet::Overlay` | `div` | `sheet-overlay` | `data-state`, `style="pointer-events: auto"` (dialog:137-140, caller style merged after) | `data-state`; `aria-hidden="true" data-aria-hidden="true"` while the modal Content is mounted (hideOthers marks every body child except Content, ah:38-90, 124-135) | `fixed inset-0 z-50 bg-black/50 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:animate-in data-[state=open]:fade-in-0` |
| `Sheet::Content` | `div` | `sheet-content` | `role="dialog" id=<content id> tabindex="-1" data-state` (dialog:259-263, fs:145); `aria-labelledby=<title id>` only if a `Sheet::Title` is rendered in this sheet; `aria-describedby` only if a `Sheet::Description` is rendered (concat with caller value) or the caller passed one (dialog:261-262). NO `data-side`. | `data-state`; `style="pointer-events: auto"` while a layer disables outside pointer events (modal open), otherwise no pointer-events style (dl:147) | base: `fixed z-50 flex flex-col gap-4 bg-background shadow-lg transition ease-in-out data-[state=closed]:animate-out data-[state=closed]:duration-300 data-[state=open]:animate-in data-[state=open]:duration-500`, then the side string, then `class:` (all through one `cn`) |
| side `right` (default) | | | | | `inset-y-0 right-0 h-full w-3/4 border-l data-[state=closed]:slide-out-to-right data-[state=open]:slide-in-from-right sm:max-w-sm` |
| side `left` | | | | | `inset-y-0 left-0 h-full w-3/4 border-r data-[state=closed]:slide-out-to-left data-[state=open]:slide-in-from-left sm:max-w-sm` |
| side `top` | | | | | `inset-x-0 top-0 h-auto border-b data-[state=closed]:slide-out-to-top data-[state=open]:slide-in-from-top` |
| side `bottom` | | | | | `inset-x-0 bottom-0 h-auto border-t data-[state=closed]:slide-out-to-bottom data-[state=open]:slide-in-from-bottom` |
| X close (inside Content, after the block, when `show_close_button`) | `button` (`type="button"`) | **none**: the oracle renders `SheetPrimitive.Close` directly, not `SheetClose`, so there is NO `data-slot` (unlike Dialog's `dialog-close`). Do not add one. | `type="button"` only; NO `data-state` (Radix Close sets none, dialog:305-312, so `data-[state=open]:bg-secondary` never matches; do not add it) | none | `absolute top-4 right-4 rounded-xs opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:ring-2 focus:ring-ring focus:ring-offset-2 focus:outline-hidden disabled:pointer-events-none data-[state=open]:bg-secondary` |
| X close children | `svg` + `span` | none | `Icon("x", class: "size-4")`: `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-x size-4" aria-hidden="true">` with paths `M18 6 6 18`, `m6 6 12 12` (lucide-react 0.577.0 `createLucideIcon` adds `lucide-x` twice, deduped by `mergeClasses`; `Icon.js` adds `lucide` and `aria-hidden`), then `<span class="sr-only">Close</span>` | | |
| `Sheet::Header` | `div` | `sheet-header` | | | `flex flex-col gap-1.5 p-4` |
| `Sheet::Footer` | `div` | `sheet-footer` | block only | | `mt-auto flex flex-col gap-2 p-4` |
| `Sheet::Title` | `h2` | `sheet-title` | `id=<title id>` (dialog:284) | | `font-semibold text-foreground` |
| `Sheet::Description` | `p` | `sheet-description` | `id=<description id>` (dialog:297) | | `text-sm text-muted-foreground` |
| `Sheet::Close` | `button` (`type="button"`) | `sheet-close` | `type="button"`, no `data-state`, no `aria-*` (dialog:305-312) | | none |

Notes on the classes:
- Content has NO `outline-none` / `outline-hidden` (Dialog has `outline-none`): when focus lands on the Content itself (no tabbables, `show_close_button: false`) the UA focus outline is visible in React and must be in the port (scenario `focus__no-tabbables-focuses-content`).
- Content uses `transition ease-in-out` with `duration-300` (closing) / `duration-500` (opening) gated on `data-state`; the slide animations come from `tw-animate-css` (`slide-in-from-right` etc. = translate 100%).
- Manifest tokens `top`, `right`, `bottom`, `left` are the `side === "..."` comparison literals the extractor picked up, not classes; they appear in the port naturally as the side table keys. The text literal `Close` is the sr-only label.

DOM order inside Content: block children, then the X close. Body order while open: `[focus-guard] ... page ... Overlay, Content [focus-guard]`; a nested sheet appends its Overlay and Content after the outer Content.

**Ids.** The Root owns three ids (content, title, description; dialog:56-58), derived server-side from a per-render counter. A caller `id:` on Content/Title/Description replaces the element's id (props spread after the generated id, dialog:263-264, 284, 297) but the references keep pointing to the GENERATED ids (`aria-controls`, `aria-labelledby`, `aria-describedby` use `context.*Id`), so they dangle; reproduce that (scenario `aria__caller-ids-override`).

**Body while a modal sheet is open:** `style="pointer-events: none"` (dl:110-115, restored when the last such layer goes); `data-scroll-locked="1"` (ref-counted, rsb:26-39) plus the injected `body[data-scroll-locked]` rule (`overflow: hidden !important; overscroll-behavior: contain; position: relative !important; margin-right: <scrollbar gap>px !important; --removed-body-scroll-bar-size`, rsb:10-20, gapMode `margin`). Every other body child gets `aria-hidden="true" data-aria-hidden="true"` (elements already `aria-hidden` are left untouched, ah:65-79; `[aria-live]` and `script` are kept, ah:133).

## Behavior

States: `closed` and `open` (`getState`, dialog:330-332), plus Presence's internal `unmountSuspended` (closing animation running: `data-state="closed"` but still mounted). The `side` prop changes only classes; behavior is identical for all four sides.

**Transitions**

| From | Trigger | To | Notes |
|---|---|---|---|
| closed | click on `Sheet::Trigger` (or Enter/Space: native button click) | open | `onOpenToggle` (dialog:65, 89); runs AFTER the caller's click handlers; a caller `preventDefault()` cancels it (`composeEventHandlers` checks `defaultPrevented`). A `disabled` trigger never fires click. |
| open | click on `Sheet::Trigger` | closed | only reachable when non-modal (modal: body `pointer-events: none` and the overlay cover it). |
| open | click on any `Sheet::Close` or the X close | closed | dialog:311, same `preventDefault` rule. |
| open | `Escape` keydown (document, capture phase) while this is the highest layer | closed | dl:91-107; dispatch `escape-key-down` first; if not prevented, `preventDefault()` the key and dismiss. Nested sheets: only the top one closes. |
| open | primary-button press outside Content | closed | `deferPointerDownOutside: true` (dialog:266): a left `pointerdown` outside only arms the dismissal, which fires on the following `click` (dl:264-273); the Overlay is a dismissable surface (dialog:118-119, dl:216-224) so press-and-release on it dismisses; a press that starts INSIDE Content and is released on the Overlay does not dismiss (dl:274-277). Non-primary buttons dispatch immediately (dl:267-268); modal prevents right-click and ctrl+left-click (dialog:178-183). Dispatch `pointer-down-outside` then `interact-outside`; dismiss unless prevented. "Outside" depends on `side`: the visible overlay area is left of a right sheet, right of a left sheet, below a top sheet, above a bottom sheet. |
| open | focus moves outside Content | closed | non-modal only (modal prevents it, dialog:184-187); skipped while an outside left-press is pending (dl:80-82). Dispatch `focus-outside` then `interact-outside`. |
| any | `open:` controlled | unchanged | every request above only dispatches `open-change` with the requested value; the DOM changes only when the caller updates the `open` value. |

Every state change dispatches `open-change` `{ open }` (dialog:45, `useControllableState`), also in uncontrolled mode.

**Modal vs non-modal** (`modal:` default true):

| Aspect | modal (dialog:157-191) | non-modal (dialog:192-232) |
|---|---|---|
| Overlay | rendered | not rendered (dialog:109) |
| Scroll lock | yes, owned by the Overlay (`RemoveScroll` with `allowPinchZoom`, shards = Content + nested branches, dialog:125-133) | no |
| hideOthers | yes, on Content mount (dialog:163-166); undone on unmount | no |
| body `pointer-events: none` | while `open` (dialog:173, dl:108-127); Content and Overlay carry `pointer-events: auto` | no |
| Focus trap | `trapped: open` (dialog:172): focus leaving Content is pulled back to the last focused element inside (fs:50-88); if the focused node is removed, Content is focused | not trapped |
| Tab loop | yes (`loop: true`, dialog:251) | yes (`loop: true` regardless) |
| Focus guards | yes (dialog:246) | yes |
| Close focus | always the trigger (dialog:174-177); no trigger -> body | trigger unless the user interacted outside (dialog:205-213); an outside interaction on the trigger is ignored (dialog:222-224), so clicking the trigger toggles closed |

**Keyboard**

| Key | Where | Effect |
|---|---|---|
| Enter / Space | Trigger (native button) | opens (toggle) |
| Enter / Space | X close or any `Sheet::Close` | closes |
| Escape | anywhere, top layer | closes the top sheet (cancelable via `escape-key-down`) |
| Tab | last tabbable in Content (the X close with the default layout) | moves to the first (fs:133-135); `Shift+Tab` on the first moves to the last (fs:136-138) |
| Tab | Content with no tabbables, focus on Content | prevented, focus stays (fs:130-131) |

Tabbable = tree walk over Content skipping `disabled`, `hidden`, `input[type=hidden]`, `tabIndex < 0` (fs:192-203); edges skip invisible elements (fs:205-213).

**Focus on open** (Content mount, fs:89-104): if focus is not already inside, dispatch `open-auto-focus`; unless prevented, focus the first tabbable candidate in DOM order that is NOT an `<a>` (`removeLinks`, fs:266-268) with `preventScroll`, selecting `<input>` text (fs:229-236); if nothing took focus, focus Content (`tabindex="-1"`, UA outline visible because the oracle has no `outline-none`). With the shadcn layout the X close is the last child: in the demo the first input gets focus; a sheet with only header text focuses the X close (`focus:ring-2 focus:ring-ring focus:ring-offset-2` apply because the `focus:` classes match programmatic focus).

**Focus on close** (Content unmount, after Presence exit; `setTimeout(0)`, fs:105-117): dispatch `close-auto-focus`; Dialog's own handler prevents FocusScope's default and focuses the trigger (modal) per the table above. With several triggers the "trigger" is the LAST rendered one (single `triggerRef`, dialog:78). Focus scopes stack: a nested sheet pauses the outer trap, closing it resumes it (fs:238-255).

**Presence** (pr:20-130): on open Overlay/Content mount with `data-state="open"`: Overlay `animate-in fade-in-0`, Content `animate-in slide-in-from-<side>` for `duration-500`. On close `data-state` flips to `closed` immediately on Trigger, Overlay and Content, `aria-expanded="false"`, `aria-controls` removed, trap and body `pointer-events` released immediately; the nodes stay mounted until `animationend`/`animationcancel` of the current animation on that node (Content `slide-out-to-<side>` `duration-300`, Overlay `fade-out-0`), then are removed; `hideOthers`, scroll lock and focus guards are released on that removal. If the computed `animation-name` is `none` or `display: none` they are removed in the same frame (pr:66-67). Reopening during the exit cancels the removal.

**forceMount.** `force_mount: true` on `Sheet::Content` has NO effect through shadcn's `SheetContent`, because the inner `SheetPortal` is not force-mounted and its own Presence gate (dialog:101) still removes the child on close (scenario `api__content-force-mount`).

Timers: none besides `setTimeout(0)` for close autofocus (fs:107) and the outside-`pointerdown` listener being attached one tick after mount (dl:292-294), so the click that opened the sheet never dismisses it.

Positioning: none (CSS `fixed` against a viewport edge); no floating-ui. Responsive: `sm:max-w-sm` caps left/right sheets at 24rem from 640px; below it they are `w-3/4` of the viewport.

Primitives composed: `portal`, `presence`, `dismissable_layer` (layer stack, deferred pointer-down, dismissable surfaces), `focus_scope` (trap + loop + auto focus, stack), `focus_guards`, `hide_others`, `scroll_lock`, `ids` (`.ai/skills/radix-stimulus/references/primitives.md`). Controller `chadcn--sheet` (radix-stimulus R12) with values `open` (Boolean), `controlled` (Boolean), `modal` (Boolean, default true). Its logic is the same as `chadcn--dialog`; the builder must share it (import the dialog behavior / primitives), not copy it. `disconnect()` releases every primitive, removes portaled nodes and restores `body`.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Sheet` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Sheet::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Sheet::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `sheet.trigger` | `Sheet::Trigger` | `SheetTrigger` |
| `sheet.close` | `Sheet::Close` | `SheetClose` |
| `sheet.content` | `Sheet::Content` | `SheetContent` |
| `sheet.header` | `Sheet::Header` | `SheetHeader` |
| `sheet.footer` | `Sheet::Footer` | `SheetFooter` |
| `sheet.title` | `Sheet::Title` | `SheetTitle` |
| `sheet.description` | `Sheet::Description` | `SheetDescription` |

Names that shadow a Phlex HTML element inside `Sheet`'s OWN `view_template` (use `tag(:header)` there, never the bare method): `header`, `footer`, `title`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Chadcn::Icon` (infra `_icons`): `Icon.new(name: "x", class: "size-4")` inside the Content X close.
- `Chadcn::Base`: `cn`, `merge_attrs`, `render_as_child`, ids.
- Primitives `app/javascript/v2/primitives/`: `portal.js`, `presence.js`, `dismissable_layer.js`, `focus_scope.js`, `focus_guards.js`, `hide_others.js`, `scroll_lock.js`, `ids.js`; behavior shared with `chadcn--dialog`.
- No registry dependency (manifest `registry_dependencies: []`): the oracle renders no Button. Callers commonly compose `Chadcn::Button` (trigger / close via `as_child:`), `Chadcn::Input` and `Chadcn::Label`, as in the examples. Scenarios use raw `_button` / `_input` / `_label` elements for them because scenario_coverage only allows dependency exports (same choice as the Popover/HoverCard/Tooltip plans).

## Deviations

Recorded in `dev/port/deviations/sheet.json` (same two structural deviations as Dialog; the Dialog `container:` deviation does not apply because `SheetPortal` is not exported):

1. **Controller host.** `Sheet` must render no element, but Trigger cannot host the controller (zero, one or several triggers; controlled `open` without trigger). One `<div style="display: contents" data-controller="chadcn--sheet">` without `data-slot`, classes or other data attributes wraps the block. Not visible to G2 (no `data-slot`) and layout-neutral.
2. **Closed Presence parts in a `<template>`.** React does not mount closed Overlay/Content; the server ships their markup in a `<template>` inside the host (inert, not matched by `[data-slot]`, not rendered).

No class tokens are added or removed (`allow_tokens` / `allow_missing_tokens` empty).
