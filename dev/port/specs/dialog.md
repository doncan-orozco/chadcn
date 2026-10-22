# Dialog (shadcn new-york-v4, Radix `Dialog`)

Oracle: `gems/chadcn/dev/port/oracle/src/dialog.tsx` (source_sha `2ade6074e5fad0a4`), manifest `oracle/manifest/dialog.json`.
Behavior source: `gems/chadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-dialog/dist/index.mjs` v1.2.0 (cited as `dialog:<line>`), built on
`react-dismissable-layer` 1.1.20 (`dl:`), `react-focus-scope` 1.2.0 (`fs:`), `react-focus-guards` 1.1.6 (`fg:`), `react-presence` 1.1.11 (`pr:`),
`react-portal` 1.1.18 (`po:`), `react-remove-scroll` 2.7.2 + `react-remove-scroll-bar` 2.3.8 (`rsb:` = `dist/es2015/component.js`), `aria-hidden` 1.2.6 (`ah:` = `dist/es2015/index.js`), all from `radix-ui` 1.7.0.
Tier: `overlay`. Family: Overlay (modal).

## API

Every part: `class:` goes through `cn` last (caller wins, tailwind-merge), `**attrs` pass through (`data:`/`aria:` deep-merged), string and symbol keys accepted. Parts that wrap a Radix primitive that is `Primitive.*` (Trigger, Close, Overlay, Content, Title, Description) accept `as_child:` (`false` | tag symbol | `Components::V2::*` instance), implemented once by `Components::V2::Base#render_as_child` (Radix Slot merge: props the child element was given win, but the wrapper's own `data-slot` reaches the child as a prop; shadcn `Button` renders `data-slot="button"` and then spreads `{...props}` last (button.tsx), so `Dialog::Trigger.new(as_child: Button.new)` renders `data-slot="dialog-trigger"` and `Dialog::Close.new(as_child: Button.new)` renders `data-slot="dialog-close"`, keeping Button's `data-variant`/`data-size`/classes. Only the Footer's built-in Close (`DialogPrimitive.Close asChild` with no `data-slot`, dialog.tsx:113-115) keeps `data-slot="button"`).

| React | Ruby | Notes |
|---|---|---|
| `Dialog` (`DialogPrimitive.Root`, props `open`, `defaultOpen`, `onOpenChange`, `modal = true`, dialog:30-38) | `Components::V2::Dialog.new(open: nil, default_open: false, modal: true, **attrs) { ... }` | `open:` given (true/false) = controlled: the controller never changes its own state, it only dispatches `open-change` (callers set `data-chadcn--dialog-open-value`). `open: nil` = uncontrolled, starts at `default_open`. Renders no shadcn element (see Structure, deviation). |
| `DialogTrigger` | `Components::V2::Dialog::Trigger.new(as_child: false, class: nil, **attrs) { label }` | Toggles (dialog:89 `onOpenToggle`). |
| `DialogPortal` (`forceMount`, `container`, dialog:98-102) | `Components::V2::Dialog::Portal.new(force_mount: false, container: nil) { ... }` | Renders nothing itself; its children are moved to `container` (default `document.body`). `container:` is a CSS selector string (deviation `api`, a DOM node cannot be passed from Ruby). |
| `DialogOverlay` (`forceMount`, dialog:107) | `Components::V2::Dialog::Overlay.new(force_mount: false, as_child: false, class: nil, **attrs)` | Rendered only when `modal` (dialog:109). |
| `DialogContent` (`showCloseButton = true`, plus Radix `forceMount`, `onOpenAutoFocus`, `onCloseAutoFocus`, `onEscapeKeyDown`, `onPointerDownOutside`, `onInteractOutside`, `onFocusOutside`) | `Components::V2::Dialog::Content.new(show_close_button: true, force_mount: false, as_child: false, class: nil, **attrs) { ... }` | Always renders inside its own `Dialog::Portal` with a `Dialog::Overlay` first (shadcn source). Radix callbacks become cancelable events (below). |
| `DialogHeader` | `Components::V2::Dialog::Header.new(class: nil, **attrs) { ... }` | plain `div`. |
| `DialogFooter` (`showCloseButton = false`) | `Components::V2::Dialog::Footer.new(show_close_button: false, class: nil, **attrs) { ... }` | When true appends `Dialog::Close.new(as_child: Components::V2::Button.new(variant: "outline")) { "Close" }` after the block. |
| `DialogTitle` | `Components::V2::Dialog::Title.new(as_child: false, class: nil, **attrs) { text }` | `h2`. |
| `DialogDescription` | `Components::V2::Dialog::Description.new(as_child: false, class: nil, **attrs) { text }` | `p`. |
| `DialogClose` | `Components::V2::Dialog::Close.new(as_child: false, class: nil, **attrs) { ... }` | Closes (dialog:311). No default classes (the classes in the oracle belong to the X button inside Content only). |

Options: `modal:`, `open:`, `default_open:`, `show_close_button:`, `force_mount:` are booleans; `"true"`/`"false"` strings are not accepted (React types are boolean).

Events (dispatched with `this.dispatch` from the `chadcn--dialog` host, `bubbles: true`; prefix `chadcn--dialog:`):

| Event | Radix origin | detail | cancelable | default action when not prevented |
|---|---|---|---|---|
| `open-change` | `onOpenChange` (dialog:42-47) | `{ open }` | no | uncontrolled: state changes; controlled: nothing |
| `open-auto-focus` | Content `onOpenAutoFocus` -> FocusScope `onMountAutoFocus` (dialog:254, fs:95-103) | `{}` | yes | focus first tabbable (see Behavior) |
| `close-auto-focus` | `onCloseAutoFocus` (dialog:174-177, fs:108-113) | `{}` | yes | focus trigger |
| `escape-key-down` | `onEscapeKeyDown` (dl:91-100) | `{ originalEvent }` | yes | close |
| `pointer-down-outside` | `onPointerDownOutside` (dl:55-58) | `{ originalEvent }` | yes | close |
| `focus-outside` | `onFocusOutside` (dl:79-89) | `{ originalEvent }` | yes | close (modal always prevents it, dialog:184-187) |
| `interact-outside` | `onInteractOutside` (dl:57, 87) | `{ originalEvent }` | yes | close |

`aria: { describedby: }` / `"aria-describedby":` on Content is concatenated with the Description id (dialog:262, `concatAriaDescribedby` dialog:319-328: split on whitespace, dedupe, caller ids first). `ref` has no equivalent.

Example:

```ruby
render Components::V2::Dialog.new do
  render Components::V2::Dialog::Trigger.new(as_child: Components::V2::Button.new(variant: "outline")) { "Open Dialog" }
  render Components::V2::Dialog::Content.new(class: "sm:max-w-[425px]") do
    render Components::V2::Dialog::Header.new do
      render Components::V2::Dialog::Title.new { "Edit profile" }
      render Components::V2::Dialog::Description.new { "Make changes to your profile here." }
    end
    render Components::V2::Dialog::Footer.new do
      render Components::V2::Dialog::Close.new(as_child: Components::V2::Button.new(variant: "outline")) { "Cancel" }
      render Components::V2::Button.new { "Save changes" }
    end
  end
end
```

## Structure

Class strings below are verbatim from the oracle (order irrelevant, set equality is the gate).

**`Dialog` (data-slot `dialog`) and `Dialog::Portal` (data-slot `dialog-portal`)** render NO element and no `data-slot` (manifest `non_rendered_slots`; Radix Root is a context provider dialog:50-71, Portal maps each child into `Presence > Portal asChild` dialog:101, `data-slot="dialog-portal"` is dropped). The port renders one controller host (deviation): `<div style="display: contents" data-controller="chadcn--dialog" data-chadcn--dialog-open-value data-chadcn--dialog-modal-value data-chadcn--dialog-controlled-value>` with no `data-slot`, no classes. The host wraps the block in place (inside a caller `<form>` in the demo, exactly where React's tree is).

**Portal and Presence.** Each child of a Portal (in shadcn: Overlay, then Content) is appended **directly** to `document.body` (or `container`), with no wrapper (po:17 `Primitive.div asChild`), in order Overlay, Content, after existing body children. While closed (and not force-mounted) they do not exist in the DOM (pr:26). Server rendering: closed -> the Portal children are rendered inside one `<template>` in the host (deviation; invisible to the runner, it has no `data-slot`); open on first render (`default_open: true` / `open: true`) -> rendered in place and moved to the container in `connect()`. Because the moved nodes leave the controller element, the controller binds their listeners directly (Stimulus `data-action` scoping does not reach them).

Focus guards (fg:38-47, inserted while any Content is mounted, fg:15-35): `<span data-radix-focus-guard tabindex="0" style="outline: none; opacity: 0; position: fixed; pointer-events: none">` as first and last child of `body`, ref-counted. No `data-slot`.

| Part | Tag | data-slot | Server-rendered attributes | Set by Stimulus | Classes |
|---|---|---|---|---|---|
| `Dialog::Trigger` | `button` (`type="button"`) | `dialog-trigger` (also with `as_child: Button`: the Trigger's `data-slot="dialog-trigger"` is passed to Button, which spreads props after its own `data-slot="button"`, so `dialog-trigger` wins; Button contributes `data-variant`, `data-size` and its classes) | `type="button" aria-haspopup="dialog" aria-expanded="false|true" data-state="closed|open"`, `aria-controls` = content id ONLY while open (dialog:80-87) | `aria-expanded`, `data-state`, `aria-controls` added/removed on every transition | none |
| `Dialog::Overlay` | `div` | `dialog-overlay` | `data-state`, `style="pointer-events: auto"` (dialog:137-140) | `data-state`; `aria-hidden="true" data-aria-hidden="true"` while a modal Content is mounted (hideOthers marks every body child except the Content, ah:38-90, 124-135) | `fixed inset-0 z-50 bg-black/50 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:animate-in data-[state=open]:fade-in-0` |
| `Dialog::Content` | `div` | `dialog-content` | `role="dialog" id=<content id> tabindex="-1" data-state` (dialog:259-263, fs:145); `aria-labelledby=<title id>` only if a `Dialog::Title` is rendered in this dialog; `aria-describedby` only if a `Dialog::Description` is rendered (concat with caller value) or the caller passed one (dialog:261-262) | `data-state`; `style="pointer-events: auto"` while any layer disables outside pointer events (modal open), otherwise no pointer-events style (dl:147) | `fixed top-[50%] left-[50%] z-50 grid w-full max-w-[calc(100%-2rem)] translate-x-[-50%] translate-y-[-50%] gap-4 rounded-lg border bg-background p-6 shadow-lg duration-200 outline-none data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95 sm:max-w-lg` |
| X close (inside Content, after the block, when `show_close_button`) | `button` (`type="button"`) | `dialog-close` | NO `data-state` (Radix Close sets none, dialog:305-312, so `data-[state=open]:*` never matches; do not add it) | none | `absolute top-4 right-4 rounded-xs opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:ring-2 focus:ring-ring focus:ring-offset-2 focus:outline-hidden disabled:pointer-events-none data-[state=open]:bg-accent data-[state=open]:text-muted-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4` |
| X close children | `svg` + `span` | none | `Icon("x")`: `<svg xmlns width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-x" aria-hidden="true">` with paths `M18 6 6 18`, `m6 6 12 12` (lucide-react 0.577.0), then `<span class="sr-only">Close</span>` | | |
| `Dialog::Header` | `div` | `dialog-header` | | | `flex flex-col gap-2 text-center sm:text-left` |
| `Dialog::Footer` | `div` | `dialog-footer` | block, then (when `show_close_button`) `<button type="button" data-slot="button" data-variant="outline" data-size="default" class="<buttonVariants outline/default>">Close</button>` (`DialogPrimitive.Close asChild` is used directly with no `data-slot`, so Button's own `data-slot="button"` stays; there is no `dialog-close` slot here) | | `flex flex-col-reverse gap-2 sm:flex-row sm:justify-end` |
| `Dialog::Title` | `h2` | `dialog-title` | `id=<title id>` (dialog:284) | | `text-lg leading-none font-semibold` |
| `Dialog::Description` | `p` | `dialog-description` | `id=<description id>` (dialog:297) | | `text-sm text-muted-foreground` |
| `Dialog::Close` | `button` (`type="button"`) | `dialog-close` | `type="button"`, no `data-state`, no `aria-*` (dialog:305-312) | | none |

DOM order inside Content: block children, then the X close. Body order while open: `[focus-guard] ... page ... Overlay, Content [focus-guard]`; a nested dialog appends its Overlay and Content after the outer Content.

**Ids.** The Root owns three ids (content, title, description; dialog:56-58), derived server-side from a per-render counter. A caller `id:` on Content/Title/Description replaces the element's id (props spread after the generated id, dialog:263-264, 284, 297) but the references keep pointing to the GENERATED ids (`aria-controls`, `aria-labelledby`, `aria-describedby` use `context.*Id`), so they dangle; reproduce that (scenario `aria__caller-ids-override`).

**Body while a modal dialog is open:** `style="pointer-events: none"` (dl:110-115, restored when the last such layer goes); `data-scroll-locked="1"` (ref-counted, rsb:26-39) plus the injected rule `body[data-scroll-locked] { overflow: hidden !important; overscroll-behavior: contain; position: relative !important; padding-left/top/right: <original>; margin-left:0; margin-top:0; margin-right: <scrollbar gap>px !important; --removed-body-scroll-bar-size: <gap>px }` (rsb:10-20, gapMode `margin`). Every other body child gets `aria-hidden="true" data-aria-hidden="true"` (elements already `aria-hidden` are left untouched and not restored, ah:65-79; `[aria-live]` and `script` are kept, ah:133).

## Behavior

States: `closed` and `open` (`getState`, dialog:330-332), plus Presence's internal `unmountSuspended` (closing animation running: `data-state="closed"` but still mounted).

**Transitions**

| From | Trigger | To | Notes |
|---|---|---|---|
| closed | click on `Dialog::Trigger` (or Enter/Space: native button click) | open | `onOpenToggle` (dialog:65, 89); runs AFTER the caller's own click handlers; if a caller handler called `preventDefault()` nothing happens (`composeEventHandlers` checks `defaultPrevented`). |
| open | click on `Dialog::Trigger` | closed | only reachable when non-modal (modal: body `pointer-events: none` and the overlay cover it). |
| open | click on any `Dialog::Close` (X, footer Close, custom) | closed | dialog:311, same `preventDefault` rule. |
| open | `Escape` keydown (document, capture phase) while this is the highest layer | closed | dl:91-107; dispatch `escape-key-down` first; if not prevented, `preventDefault()` the key event and dismiss. Nested dialogs: only the top one closes. |
| open | primary-button press outside Content | closed | `deferPointerDownOutside: true` (dialog:266): a left-button `pointerdown` outside only arms the dismissal, which fires on the following `click` (dl:264-273); the Overlay is a "dismissable surface" (dialog:118-119, dl:216-224) so a press-and-release on it always dismisses; a press that starts INSIDE Content and is released on the Overlay does not dismiss (pointerdown inside resets, dl:274-277). Non-primary buttons dispatch immediately (dl:267-268); modal prevents right-click and ctrl+left-click (dialog:178-183). Ignored when the pointer is on a lower layer than the highest one with outside pointer events disabled (dl:52, 73). Dispatch `pointer-down-outside` then `interact-outside`; dismiss unless prevented. |
| open | focus moves outside Content | closed | non-modal only (modal prevents it, dialog:184-187); skipped while an outside left-press is pending (dl:80-82). Dispatch `focus-outside` then `interact-outside`. |
| any | `open:` controlled | unchanged | every request above only dispatches `open-change` with the requested value; the DOM changes only when the caller updates the `open` value. |

Every state change dispatches `open-change` `{ open }` (dialog:45, `useControllableState`), also in uncontrolled mode.

**Modal vs non-modal** (`modal:` default true):

| Aspect | modal (dialog:157-191) | non-modal (dialog:192-232) |
|---|---|---|
| Overlay | rendered | not rendered (dialog:109) |
| Scroll lock | yes, owned by the Overlay (`RemoveScroll` with `allowPinchZoom`, shards = Content + nested branches, dialog:125-133); wheel/touch scrolling outside the shards is blocked | no |
| hideOthers | yes, on Content mount (dialog:163-166); undone on unmount | no |
| body `pointer-events: none` | while `open` (dialog:173, dl:108-127); Content and Overlay carry `pointer-events: auto` | no |
| Focus trap | `trapped: open` (dialog:172): `focusin` outside refocuses the last focused element inside; `focusout` to an outside `relatedTarget` refocuses it (fs:50-88); if the focused node is removed and focus falls to body, Content is focused (fs:67-73) | not trapped |
| Tab loop | yes (`loop: true`, dialog:251) | yes, also non-modal (`loop: true` regardless) |
| Focus guards | yes (dialog:246) | yes |
| Close focus | always the trigger (dialog:174-177); no trigger -> stays on body | trigger unless the user interacted outside (dialog:205-213); an outside interaction whose target is the trigger is ignored (dialog:222-224), so clicking the trigger toggles closed |

**Keyboard**

| Key | Where | Effect |
|---|---|---|
| Enter / Space | Trigger (native button) | opens (toggle) |
| Enter / Space | any Close | closes |
| Escape | anywhere, top layer | closes the top dialog (cancelable via `escape-key-down`) |
| Tab | last tabbable in Content | moves to the first (fs:133-135); `Shift+Tab` on the first moves to the last (fs:136-138) |
| Tab | Content with no tabbables, focus on Content | prevented, focus stays (fs:130-131) |

Tabbable = tree walk over Content skipping `disabled`, `hidden`, `input[type=hidden]`, `tabIndex < 0` (fs:192-203); edges skip invisible elements (`checkVisibility({ checkVisibilityCSS: true })`, fs:205-213).

**Focus on open** (Content mount, fs:89-104): if focus is not already inside, dispatch `open-auto-focus`; unless prevented, focus the first candidate in DOM order that is NOT an `<a>` (`removeLinks`, fs:266-268) with `preventScroll`, selecting the text of `<input>`s (fs:229-236); if nothing took focus, focus Content (`tabindex="-1"`). With the shadcn layout the X close is the last child, so the first footer button or the first form field gets focus, not the X. The focus is programmatic `focus()`, so `focus:` classes (X close ring) apply and `focus-visible` follows the browser heuristic (keyboard-opened -> visible).

**Focus on close** (Content unmount, after Presence exit; `setTimeout(0)`, fs:105-117): dispatch `close-auto-focus`; Dialog's own handler prevents FocusScope's default and focuses the trigger (modal) per the table above. With several triggers the "trigger" is the LAST rendered one (single `triggerRef`, every trigger composes it, dialog:78), so focus returns there even if another trigger opened the dialog (scenario `triggers__multiple`). Focus scopes stack: opening a nested dialog pauses the outer trap, closing it resumes it (fs:238-255).

**Presence** (pr:20-130): on open Overlay/Content mount with `data-state="open"` (enter animation `animate-in fade-in-0` / `zoom-in-95`, Content `duration-200`). On close `data-state` flips to `closed` immediately on Trigger, Overlay and Content, `aria-expanded="false"`, `aria-controls` removed, trap and body `pointer-events` released immediately (they depend on `open`); the nodes stay mounted until `animationend`/`animationcancel` of the current animation on that node (`unmountSuspended`), then are removed; `hideOthers`, scroll lock and focus guards are released on that removal. If the computed `animation-name` is `none` or `display: none` they are removed in the same frame (pr:66-67). After the end event `animation-fill-mode: forwards` is set on the node for one tick (pr:88-96). Reopening during the exit animation cancels the removal (`MOUNT`).

**forceMount.** `Dialog::Portal.new(force_mount: true)` keeps its children mounted while closed (`data-state="closed"`). `force_mount: true` on Content or Overlay alone has NO effect through shadcn's `Dialog::Content`, because the inner `Dialog::Portal` is not force-mounted and its own Presence gate (dialog:101) still removes the child (scenario `api__content-force-mount`).

Timers: none besides `setTimeout(0)` for close autofocus (fs:107) and the `pointerdown` listener being attached one tick after mount (dl:292-294), so the click that opened the dialog never dismisses it.

Positioning: none (CSS-centred `fixed`); no floating-ui.

Primitives composed: `portal`, `presence`, `dismissable_layer` (layer stack, Escape on top layer only, outside pointer/focus detection, body `pointer-events` for modal layers; it has NO deferred pointer-down and NO dismissable-surface option: the `chadcn--dialog` controller implements Radix Dialog's own deferral (dialog:266, a primary press outside arms the dismissal and the following click fires it) in its `onPointerDownOutside` handler), `focus_scope` (trap + loop + auto focus, stack), `focus_guards`, `hide_others`, `scroll_lock`, `ids`. Controller `chadcn--dialog` values: `open` (Boolean), `controlled` (Boolean), `modal` (Boolean, default true). `disconnect()` releases every primitive, removes portaled nodes and restores `body` (Turbo cache must not keep a dialog open).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Dialog` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Dialog::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Dialog::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `dialog.close` | `Dialog::Close` | `DialogClose` |
| `dialog.content` | `Dialog::Content` | `DialogContent` |
| `dialog.description` | `Dialog::Description` | `DialogDescription` |
| `dialog.footer` | `Dialog::Footer` | `DialogFooter` |
| `dialog.header` | `Dialog::Header` | `DialogHeader` |
| `dialog.overlay` | `Dialog::Overlay` | `DialogOverlay` |
| `dialog.portal` | `Dialog::Portal` | `DialogPortal` |
| `dialog.title` | `Dialog::Title` | `DialogTitle` |
| `dialog.trigger` | `Dialog::Trigger` | `DialogTrigger` |

Names that shadow a Phlex HTML element inside `Dialog`'s OWN `view_template` (use `tag(:footer)` there, never the bare method): `footer`, `header`, `title`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Button`: `Dialog::Footer` with `show_close_button: true` renders `Button.new(variant: "outline")`; examples use it as `as_child` of Trigger/Close.
- `Components::V2::Icon` (infra `_icons`): `Icon.new(name: "x")` inside the Content X close.
- `Components::V2::Base`: `cn`, `merge_attrs`, `render_as_child`, `ids`.
- Primitives `app/javascript/v2/primitives/`: `portal.js`, `presence.js`, `dismissable_layer.js`, `focus_scope.js`, `focus_guards.js`, `hide_others.js`, `scroll_lock.js`, `ids.js`.

## Deviations

Recorded in `gems/chadcn/dev/port/deviations/dialog.json`:

1. **Controller host.** `Dialog` must render no element, but Trigger cannot host the controller (zero, one or several triggers; controlled `open` without trigger). One `<div style="display: contents" data-controller="chadcn--dialog">` without `data-slot`, classes or other data attributes wraps the block. Not visible to G2 (no `data-slot`) and layout-neutral.
2. **Closed Presence parts in a `<template>`.** React does not mount closed Overlay/Content; the server must ship their markup somewhere, so it goes in a `<template>` inside the host (inert, not in `querySelectorAll("[data-slot]")`, not rendered).
3. **`Dialog::Portal` `container:`** takes a CSS selector string because a DOM node cannot be passed from Ruby.

No class tokens are added or removed (`allow_tokens` / `allow_missing_tokens` empty).
