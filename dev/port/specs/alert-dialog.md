# AlertDialog (shadcn new-york-v4, Radix `AlertDialog`)

Oracle: `gems/chadcn/dev/port/oracle/src/alert-dialog.tsx` (source_sha `b3dfb83e54ed8c82`), manifest `oracle/manifest/alert-dialog.json`.
Behavior source: `gems/chadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-alert-dialog/dist/index.mjs` v1.1.24 (cited as `ad:<line>`), a thin wrapper over
`@radix-ui/react-dialog` v1.2.0 (`dialog:<line>`, same file the Dialog spec cites), which builds on `react-dismissable-layer` 1.1.20 (`dl:`), `react-focus-scope` 1.2.0 (`fs:`),
`react-focus-guards` 1.1.6, `react-presence` 1.1.11 (`pr:`), `react-portal` 1.1.18 (`po:`), `react-remove-scroll`, `aria-hidden` (all from `radix-ui` 1.7.0).
Tier: `overlay`. Family: Overlay (modal). Sibling spec: `gems/chadcn/dev/port/specs/dialog.md`; everything not listed as different below is identical to Dialog with `modal: true`.

Differences from Dialog, all from `ad:`:
1. Always modal: Root renders `DialogPrimitive.Root { ...props, modal: true }` (ad:21), `modal` is spread last so it cannot be overridden.
2. Content `role="alertdialog"` (ad:54; spread BEFORE caller props, so a caller `role:` wins).
3. Open auto focus always goes to `AlertDialog::Cancel` (ad:58-61), never to the first tabbable, never to Content.
4. Pointer-down outside and interact outside are always prevented (ad:62-63): overlay click / outside press never closes. The caller cannot pass handlers for them (they are set after `...contentProps`).
5. `Action` and `Cancel` are both `DialogPrimitive.Close` (ad:85, 95): both close.
6. shadcn: no X close button, Content has `size` (`data-size`), new `Media` part, Action/Cancel render through `Button asChild`.

## API

Every part: `class:` goes through `cn` last (caller wins, tailwind-merge) EXCEPT on `Action`/`Cancel` (see below), `**attrs` pass through (`data:`/`aria:` deep-merged), string and symbol option values accepted. Parts wrapping a `Primitive.*` (Trigger, Overlay, Content, Title, Description, Action, Cancel) accept `as_child:` (`false` | tag symbol | `Components::V2::*` instance) via `Components::V2::Base#render_as_child` (Radix Slot merge, child wins).

| React | Ruby | Notes |
|---|---|---|
| `AlertDialog` (`AlertDialogPrimitive.Root`; props `open`, `defaultOpen`, `onOpenChange`, dialog:30-38; `modal` forced true, ad:21) | `Components::V2::AlertDialog.new(open: nil, default_open: false) { ... }` | No `modal:` kwarg (Radix type is `Omit<DialogProps, "modal">` and ad:21 overrides it); passing `modal:` raises `ArgumentError`. `open:` true/false = controlled (controller only dispatches `open-change`, caller sets `data-shadcn--alert-dialog-open-value`), `nil` = uncontrolled from `default_open`. Renders no shadcn element (Structure, deviation 1). |
| `AlertDialogTrigger` | `Components::V2::AlertDialog::Trigger.new(as_child: false, class: nil, **attrs) { label }` | No default classes. Toggles (dialog:89). |
| `AlertDialogPortal` (`forceMount`, `container`, dialog:98-102) | `Components::V2::AlertDialog::Portal.new(force_mount: false, container: nil) { ... }` | Renders nothing; children moved to `container` (CSS selector string, deviation 3), default `document.body`. |
| `AlertDialogOverlay` (`forceMount`, dialog:107) | `Components::V2::AlertDialog::Overlay.new(force_mount: false, as_child: false, class: nil, **attrs)` | Always rendered (always modal, dialog:109). |
| `AlertDialogContent` (`size = "default"`; Radix `forceMount`, `onOpenAutoFocus`, `onCloseAutoFocus`, `onEscapeKeyDown`, `onFocusOutside`) | `Components::V2::AlertDialog::Content.new(size: "default", force_mount: false, as_child: false, class: nil, **attrs) { ... }` | `size:` accepts `"default"`/`:default`, `"sm"`/`:sm`; `nil` = `"default"`; anything else raises `ArgumentError` (TS union). Always renders its own `AlertDialog::Portal` containing `AlertDialog::Overlay` then the content element (shadcn source). No close button. |
| `AlertDialogHeader` | `Components::V2::AlertDialog::Header.new(class: nil, **attrs) { ... }` | plain `div`. |
| `AlertDialogFooter` | `Components::V2::AlertDialog::Footer.new(class: nil, **attrs) { ... }` | plain `div`, no `show_close_button` (unlike Dialog). |
| `AlertDialogTitle` | `Components::V2::AlertDialog::Title.new(as_child: false, class: nil, **attrs) { text }` | `h2`. |
| `AlertDialogDescription` | `Components::V2::AlertDialog::Description.new(as_child: false, class: nil, **attrs) { text }` | `p`. |
| `AlertDialogMedia` | `Components::V2::AlertDialog::Media.new(class: nil, **attrs) { icon }` | plain `div`, no `as_child`. |
| `AlertDialogAction` (`variant = "default"`, `size = "default"`) | `Components::V2::AlertDialog::Action.new(variant: "default", size: "default", as_child: false, class: nil, **attrs) { label }` | `variant:`/`size:` are the Button options (all keys of `Components::V2::Button`, strings or symbols, `:icon_sm` == `"icon-sm"`). Closes (dialog:311 via ad:85). |
| `AlertDialogCancel` (`variant = "outline"`, `size = "default"`) | `Components::V2::AlertDialog::Cancel.new(variant: "outline", size: "default", as_child: false, class: nil, **attrs) { label }` | Same as Action but default variant `outline`; registers as the open-autofocus target (ad:92-94). |

**Action/Cancel class merge (load-bearing).** The shadcn source is `<Button variant size asChild><Primitive.Action data-slot="alert-dialog-action" className={cn(className)} {...props}/></Button>`. Button's own `className` is undefined, so the Slot's class is exactly `buttonVariants({ variant, size })`; the caller's class is on the child. Radix Slot `mergeProps` joins them as a plain string, slot first, NO tailwind-merge. So the port computes `[Components::V2::Button.variants(variant:, size:), cn(class)].compact_blank.join(" ")`; `class: "rounded-full"` keeps BOTH `rounded-md` and `rounded-full` (scenario `api__action-classname-no-merge`). Do not run the caller class through `cn` together with the button classes. The simplest correct implementation is literally `render_as_child` with a Button slot and a Close-like child.

Events (dispatched with `this.dispatch` from the `shadcn--alert-dialog` host, `bubbles: true`; prefix `shadcn--alert-dialog:`):

| Event | Radix origin | detail | cancelable | default action when not prevented |
|---|---|---|---|---|
| `open-change` | `onOpenChange` (dialog:42-47) | `{ open }` | no | uncontrolled: state changes; controlled: nothing |
| `open-auto-focus` | Content `onOpenAutoFocus` composed BEFORE AlertDialog's handler (ad:58, `composeEventHandlers` skips the second handler when the first prevented) | `{}` | yes | focus the `Cancel` element with `preventScroll` (ad:59-60). If prevented: nothing is focused at all (FocusScope's own default is also skipped, fs:98). |
| `close-auto-focus` | `onCloseAutoFocus` (dialog:174-177, fs:105-117) | `{}` | yes | focus the trigger |
| `escape-key-down` | `onEscapeKeyDown` (passes through `...contentProps`, dl:91-100) | `{ originalEvent }` | yes | close |
| `focus-outside` | `onFocusOutside` (passes through, composed in dialog:184-187, dl:86) | `{ originalEvent }` | yes | none: modal and AlertDialog both prevent it (dialog:186, ad:63) |

NOT dispatched: `pointer-down-outside`, `interact-outside` (AlertDialog replaces the caller's handlers, ad:62-63, and its type omits them). `aria: { describedby: }` on Content concatenates with the Description id (dialog:262, 319-328). `ref` has no equivalent.

Example (registry `alert-dialog-demo`):

```ruby
render Components::V2::AlertDialog.new do
  render Components::V2::AlertDialog::Trigger.new(as_child: Components::V2::Button.new(variant: "outline")) { "Show Dialog" }
  render Components::V2::AlertDialog::Content.new do
    render Components::V2::AlertDialog::Header.new do
      render Components::V2::AlertDialog::Title.new { "Are you absolutely sure?" }
      render Components::V2::AlertDialog::Description.new { "This action cannot be undone. ..." }
    end
    render Components::V2::AlertDialog::Footer.new do
      render Components::V2::AlertDialog::Cancel.new { "Cancel" }
      render Components::V2::AlertDialog::Action.new { "Continue" }
    end
  end
end
```

## Structure

Class strings are verbatim from the oracle (set equality is the gate).

**`AlertDialog` (data-slot `alert-dialog`) and `AlertDialog::Portal` (data-slot `alert-dialog-portal`)** render NO element and no `data-slot` (manifest `non_rendered_slots`; Root is a provider, ad:21 + dialog:50-71; Portal maps children into `Presence > Portal asChild`, dialog:101). As in Dialog, the port renders one controller host (deviation 1): `<div style="display: contents" data-controller="shadcn--alert-dialog" data-shadcn--alert-dialog-open-value data-shadcn--alert-dialog-controlled-value>` with no `data-slot` and no classes, wrapping the block in place. There is no `modal` value (always modal).

**Portal and Presence.** Identical to Dialog: Overlay then Content are appended directly to `document.body` (or `container`) with no wrapper (po:17), only while open (pr:26). Closed server markup ships in one `<template>` in the host (deviation 2); open on first render (`default_open: true` / `open: true`) renders in place and moves in `connect()`. Focus guards `<span data-radix-focus-guard tabindex="0" style="outline: none; opacity: 0; position: fixed; pointer-events: none">` first and last in `body` while Content is mounted (dialog:246).

| Part | Tag | data-slot | Server-rendered attributes | Set by Stimulus | Classes |
|---|---|---|---|---|---|
| `AlertDialog::Trigger` | `button` `type="button"` | `alert-dialog-trigger` (with `as_child: Button` the child wins: `data-slot="button"`, `data-variant`, `data-size`) | `type="button" aria-haspopup="dialog" aria-expanded="false|true" data-state="closed|open"`; `aria-controls`=content id only while open (dialog:80-87). `aria-haspopup` stays `"dialog"` (not `alertdialog`). | `aria-expanded`, `data-state`, `aria-controls` | none |
| `AlertDialog::Overlay` | `div` | `alert-dialog-overlay` | `data-state`, `style="pointer-events: auto"` (dialog:137-140) | `data-state`; `aria-hidden="true" data-aria-hidden="true"` while Content is mounted (hideOthers on Content, dialog:163-166) | `fixed inset-0 z-50 bg-black/50 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:animate-in data-[state=open]:fade-in-0` |
| `AlertDialog::Content` | `div` | `alert-dialog-content` | `role="alertdialog"` (ad:54; caller `role:` overrides), `data-size="default|sm"` (shadcn, before `{...props}`: a caller `data-size` overrides), `id=<content id> tabindex="-1" data-state` (dialog:259-263, fs:145), `aria-labelledby=<title id>` only if a Title is rendered, `aria-describedby` only if a Description is rendered or the caller passed one (dialog:261-262) | `data-state`; `style="pointer-events: auto"` while open (dl:147) | `group/alert-dialog-content fixed top-[50%] left-[50%] z-50 grid w-full max-w-[calc(100%-2rem)] translate-x-[-50%] translate-y-[-50%] gap-4 rounded-lg border bg-background p-6 shadow-lg duration-200 data-[size=sm]:max-w-xs data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95 data-[size=default]:sm:max-w-lg` (note: no `outline-none`, unlike Dialog) |
| `AlertDialog::Header` | `div` | `alert-dialog-header` | | | `grid grid-rows-[auto_1fr] place-items-center gap-1.5 text-center has-data-[slot=alert-dialog-media]:grid-rows-[auto_auto_1fr] has-data-[slot=alert-dialog-media]:gap-x-6 sm:group-data-[size=default]/alert-dialog-content:place-items-start sm:group-data-[size=default]/alert-dialog-content:text-left sm:group-data-[size=default]/alert-dialog-content:has-data-[slot=alert-dialog-media]:grid-rows-[auto_1fr]` |
| `AlertDialog::Footer` | `div` | `alert-dialog-footer` | | | `flex flex-col-reverse gap-2 group-data-[size=sm]/alert-dialog-content:grid group-data-[size=sm]/alert-dialog-content:grid-cols-2 sm:flex-row sm:justify-end` |
| `AlertDialog::Title` | `h2` | `alert-dialog-title` | `id=<title id>` (dialog:284) | | `text-lg font-semibold sm:group-data-[size=default]/alert-dialog-content:group-has-data-[slot=alert-dialog-media]/alert-dialog-content:col-start-2` |
| `AlertDialog::Description` | `p` | `alert-dialog-description` | `id=<description id>` (dialog:297) | | `text-sm text-muted-foreground` |
| `AlertDialog::Media` | `div` | `alert-dialog-media` | | | `mb-2 inline-flex size-16 items-center justify-center rounded-md bg-muted sm:group-data-[size=default]/alert-dialog-content:row-span-2 *:[svg:not([class*='size-'])]:size-8` |
| `AlertDialog::Action` | `button` `type="button"` (dialog:308) | `alert-dialog-action` (child wins over Button's `button`) | `type="button" data-slot="alert-dialog-action" data-variant="<variant>" data-size="<size>"` (from Button through the Slot) `class="<buttonVariants(variant,size)> <caller class>"`; no `data-state`, no aria | | Button cva output for `variant`/`size` (see `specs/button.md`), plus caller class plain-joined |
| `AlertDialog::Cancel` | `button` `type="button"` | `alert-dialog-cancel` | same as Action, default `data-variant="outline"` | | Button `outline`/`default` output plus caller class |

Attribute precedence on Action/Cancel (Slot: child wins): caller `data-variant`/`data-size`/`data-slot`/`type` override the Button/Close values; `disabled: true` renders `disabled=""` (native button, click does nothing). With `as_child: :a` (or an instance) the Close itself is a Slot: the final element is the child (`<a>`), receiving `type="button"`, `data-slot="alert-dialog-action"`, `data-variant`, `data-size` and the joined class (scenario `api__action-as-child-link`).

DOM order inside Content: exactly the block (no appended close button). Body while open: `[focus-guard] ... page ... Overlay, Content [focus-guard]`; a nested alert dialog appends its Overlay and Content after the outer Content.

**Ids.** Root owns content/title/description ids (dialog:56-58), generated server-side from a per-render counter. Caller `id:` on Content/Title/Description replaces that element's id but `aria-controls`/`aria-labelledby`/`aria-describedby` keep the generated ids (dangling), exactly as in Dialog (scenario `aria__caller-ids-override`).

**Body while open:** `style="pointer-events: none"` (dl:110-115), `data-scroll-locked="1"` plus the injected `body[data-scroll-locked]` rule (`react-remove-scroll-bar` 2.3.8 `dist/es2015/component.js`:10-39, detailed in the Dialog spec), every other body child `aria-hidden="true" data-aria-hidden="true"`.

## Behavior

States `closed` / `open` (dialog:330-332), plus Presence `unmountSuspended` while the exit animation runs.

**Transitions**

| From | Trigger | To | Notes |
|---|---|---|---|
| closed | click on `AlertDialog::Trigger` (Enter/Space = native click) | open | dialog:65, 89; caller click handlers run first, `preventDefault()` in them cancels. |
| open | click on `AlertDialog::Action` or `AlertDialog::Cancel` | closed | both are `DialogPrimitive.Close` (ad:85, 95, dialog:311); same `preventDefault` rule (a caller `click` handler that prevents keeps it open, e.g. async confirm). |
| open | `Escape` keydown (document, capture) while top layer | closed | dl:91-107; `escape-key-down` first, cancelable. Nested: only the top one closes. |
| open | any pointer press outside Content (Overlay click, press-release, right-click) | **open (no change)** | ad:62-63 prevent `onPointerDownOutside`/`onInteractOutside` (dl:54-58 then never calls `onDismiss`). No event dispatched to the caller. |
| open | focus moves outside Content | open | prevented (dialog:184-187 and ad:63); the trap refocuses (fs:50-66). |
| open | click on Trigger | n/a | unreachable: body `pointer-events: none` and the Overlay cover it. |
| any | controlled `open:` | unchanged | requests only dispatch `open-change`. |

Every state change dispatches `open-change { open }` (dialog:45).

**Modal (always):** Overlay rendered with scroll lock (`RemoveScroll` `allowPinchZoom`, shards Content + nested branches, dialog:125-133); `hideOthers(content)` on Content mount (dialog:163-166); body `pointer-events: none` while open (dialog:173); focus trapped while open (dialog:172, fs:50-88: focusin outside refocuses the last focused element inside; if nothing inside was ever focused, `focus(null)` is a no-op); `loop: true` (dialog:251); focus guards (dialog:246); close focus always to the trigger (dialog:174-177).

**Keyboard**

| Key | Where | Effect |
|---|---|---|
| Enter / Space | Trigger | opens |
| Enter / Space | Action, Cancel | closes |
| Escape | anywhere, top layer | closes (cancelable via `escape-key-down`) |
| Tab / Shift+Tab | last / first tabbable in Content | wraps to first / last (fs:133-138) |
| Tab | Content with no tabbables, focus on Content | prevented (fs:130-131) |

Tabbable rules identical to Dialog (fs:192-213).

**Focus on open** (fs:89-104 + ad:58-61): if focus is not already inside Content, dispatch `open-auto-focus`. AlertDialog's handler ALWAYS calls `preventDefault()` on it, so FocusScope's "first tabbable / select input / focus container" path never runs. It then focuses the registered Cancel (`cancelRef.current?.focus({ preventScroll: true })`):
- With a Cancel: Cancel gets focus (programmatic, so `focus-visible` follows the browser heuristic: keyboard-opened -> ring visible). In the demo the footer is `flex-col-reverse sm:flex-row` with Cancel first in DOM, so Cancel is focused even though Action may be visually first on mobile.
- Several Cancels: the single `cancelRef` (ad:50, 94) holds the LAST mounted one (refs attach in commit order), so the last Cancel in DOM order is focused (scenario `focus__multiple-cancels-last-wins`).
- No Cancel: nothing is focused; focus stays where it was (the trigger, now outside and `aria-hidden`); Content is NOT focused. The next Tab follows normal document order from there and, if it lands outside, the trap's `focus(null)` does nothing (scenario `focus__no-cancel-stays-on-trigger`).
- Caller prevents `open-auto-focus`: nothing is focused.

**Focus on close** (fs:105-117, `setTimeout(0)` after Presence exit): dispatch `close-auto-focus`; unless prevented, focus the trigger (the LAST rendered trigger when several exist, single `triggerRef`, dialog:78). No trigger: focus goes nowhere (body).

**Presence** (pr:20-130): identical to Dialog. Open: Overlay `animate-in fade-in-0`, Content `animate-in fade-in-0 zoom-in-95 duration-200`. Close: `data-state="closed"` immediately on Trigger, Overlay, Content; trap and body pointer-events released immediately; nodes removed on `animationend`/`animationcancel` (or same frame if `animation-name: none`); hideOthers, scroll lock and focus guards released on removal; reopening during exit cancels removal.

**forceMount**: `AlertDialog::Portal.new(force_mount: true)` keeps children mounted while closed; `force_mount:` on Content/Overlay alone has no effect through shadcn's Content (inner Portal not force-mounted, dialog:101), as in Dialog.

**Layout states (pure CSS, no JS):** `data-size="sm"` -> Content `max-w-xs`, Footer `grid grid-cols-2`, Header stays centered at all widths (the `sm:group-data-[size=default]` rules do not match). `data-size="default"` at >= 640px -> `sm:max-w-lg`, Header left-aligned, Media spans two rows and Title moves to column 2 when a Media is present (`group-has-data-[slot=alert-dialog-media]`). Below 640px both sizes center the Header and the Footer is `flex-col-reverse`. Media icon gets `size-8` unless it has its own `size-*` class.

Timers: only `setTimeout(0)` for close autofocus (fs:107) and the one-tick delayed `pointerdown` listener (dl:292-294). No positioning (CSS-centred `fixed`).

Primitives composed: `portal`, `presence`, `dismissable_layer` (escape + layer stack; outside pointer always prevented, so `onPointerDownOutside`/`onInteractOutside` are passed as `(e) => e.preventDefault()`), `focus_scope` (trapped, loop, mount autofocus overridden to the Cancel), `focus_guards`, `hide_others`, `scroll_lock`, `ids`. Controller `shadcn--alert-dialog`, values `open` (Boolean), `controlled` (Boolean); target `cancel` (last one wins). The builder may share code with `shadcn--dialog` only through the primitives (radix-stimulus R2), not by importing the dialog controller. `disconnect()` releases every primitive, removes portaled nodes and restores `body`.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::AlertDialog` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render AlertDialog::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::AlertDialog::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `alert_dialog.action` | `AlertDialog::Action` | `AlertDialogAction` |
| `alert_dialog.cancel` | `AlertDialog::Cancel` | `AlertDialogCancel` |
| `alert_dialog.content` | `AlertDialog::Content` | `AlertDialogContent` |
| `alert_dialog.description` | `AlertDialog::Description` | `AlertDialogDescription` |
| `alert_dialog.footer` | `AlertDialog::Footer` | `AlertDialogFooter` |
| `alert_dialog.header` | `AlertDialog::Header` | `AlertDialogHeader` |
| `alert_dialog.media` | `AlertDialog::Media` | `AlertDialogMedia` |
| `alert_dialog.overlay` | `AlertDialog::Overlay` | `AlertDialogOverlay` |
| `alert_dialog.portal` | `AlertDialog::Portal` | `AlertDialogPortal` |
| `alert_dialog.title` | `AlertDialog::Title` | `AlertDialogTitle` |
| `alert_dialog.trigger` | `AlertDialog::Trigger` | `AlertDialogTrigger` |

Names that shadow a Phlex HTML element inside `AlertDialog`'s OWN `view_template` (use `tag(:footer)` there, never the bare method): `footer`, `header`, `title`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Button`: `Action` and `Cancel` render through `Button` as slot (`Button.variants(variant:, size:)` for the class, `data-variant`/`data-size`); examples use it as `as_child` of Trigger.
- `Components::V2::Icon` (scenarios only: `circle-fading-plus`, `bluetooth`, `trash-2` inside `AlertDialog::Media`); the component itself renders no icon.
- `Components::V2::Base`: `cn`, `merge_attrs`, `render_as_child`, ids.
- Primitives `app/javascript/v2/primitives/`: `portal.js`, `presence.js`, `dismissable_layer.js`, `focus_scope.js`, `focus_guards.js`, `hide_others.js`, `scroll_lock.js`, `ids.js`.

## Deviations

Recorded in `gems/chadcn/dev/port/deviations/alert-dialog.json`, the same three as Dialog (same reasons):

1. **Controller host.** `AlertDialog` renders no element, but the Trigger cannot host the controller (zero, one or several triggers, controlled `open`). One `<div style="display: contents" data-controller="shadcn--alert-dialog">` without `data-slot`, classes or other data attributes wraps the block.
2. **Closed Presence parts in a `<template>`** inside the host (closed Overlay/Content are not mounted in React; the server must ship their markup).
3. **`AlertDialog::Portal` `container:`** is a CSS selector string (a DOM node cannot be passed from Ruby).

No class tokens added or removed (`allow_tokens` / `allow_missing_tokens` empty).

Scenario-level substitutions (identical on both harnesses, not component deviations): the upstream examples `alert-dialog-basic|small|media|small-media|destructive|rtl` live in the `radix-nova` style docs (`apps/v4/examples/radix/`); they are rendered with the new-york-v4 parts; `rtl` uses a fixed `dir="rtl"` wrapper with the Arabic strings instead of the language selector hook.
