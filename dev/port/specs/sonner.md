# Sonner / Toaster (shadcn new-york-v4, sonner 2.0.7)

Sources read: `gems/chadcn/dev/port/oracle/src/sonner.tsx` (manifest `source_sha` 13ccc9b0fe4248e6; shadcn's wrapper: `Toaster` = sonner's `Toaster` with `className="toaster group"`, the Lucide icons `CircleCheckIcon/InfoIcon/TriangleAlertIcon/OctagonXIcon/Loader2Icon className="size-4"` (loading also `animate-spin`) and the colors `--normal-bg: var(--popover)`, `--normal-text: var(--popover-foreground)`, `--normal-border: var(--border)`, `--border-radius: var(--radius)`), and the library it wraps, `gems/chadcn/dev/react-shadcn-catalog/node_modules/sonner/dist/index.mjs` (cited as `sonner:<line>`) with the CSS it injects at runtime (`__insertCSS`, sonner:404). `next-themes` only supplies `theme` (default `system`).

**No third-party JavaScript** (maintainer constraint of the adoption epic): the library's behavior is re-implemented in `app/javascript/shadcn/primitives/toast_stack.js` (state, stacking, timers, swipe, hotkey) and its stylesheet is shipped as `app/assets/tailwind/chadcn/sonner.css` (MIT, `THIRD_PARTY_NOTICES.md`). No new importmap pin, no vendor file, no npm dependency (a unit test asserts it).

## API

`Toaster` is the only export (`Sonner` is the namespace, `Chadcn::Toaster` the 1:1 name):

```ruby
Chadcn::Toaster.new(position: "bottom-right", theme: "system", rich_colors: nil, expand: false, close_button: false, invert: false,
  duration: nil, visible_toasts: 3, gap: 14, offset: nil, mobile_offset: nil, dir: nil, hotkey: %w[altKey KeyT],
  container_aria_label: "Notifications", swipe_directions: nil, toast_options: nil, icons: nil, style: nil, toaster_id: nil,
  flash: nil, toasts: nil, class: nil, **attrs) { |toaster| ... }
Chadcn::Sonner::Toast.new(title: nil, description: nil, type: nil, id: nil, duration: nil, position: nil, dismissible: nil, close_button: nil,
  rich_colors: nil, invert: nil, icon: nil, action: nil, cancel: nil, toaster_id: nil, test_id: nil, **attrs) { "title when title: is nil" }
```

- Props of `ToasterProps` map mechanically (`richColors` -> `rich_colors:`, `visibleToasts`, `mobileOffset`, `swipeDirections`, `containerAriaLabel`, `toastOptions`...). String and symbol values are equivalent (`position: :top_center`). `theme` defaults to `"system"` (what the wrapper gets from `next-themes` with no provider). `rich_colors: nil` (an omitted prop) leaves `data-rich-colors` off the toasts; `false` renders `"false"` like React.
- `toast_options:` keys are Ruby names of sonner's `toastOptions`: `duration`, `close_button`, `class`, `description_class_name`, `unstyled`, `style`, `close_button_aria_label`, `action_button_style`, `cancel_button_style`, `class_names` (`toast`, `title`, `description`, `icon`, `content`, `close_button`, `cancel_button`, `action_button`, `loader`, `default` or a type).
- `icons:` per type (`success`, `info`, `warning`, `error`, `loading`, `close`): a component instance, or `false` for none. Default: the shadcn wrapper icons and sonner's close icon.
- `style:` is the inline style of the `<ol>` lists (like sonner's `style`), merged over the four shadcn theme variables.
- Deliberate differences (see `deviations/sonner.json`): `id:` is the HTML id of the `<section>` (default `"toaster"`, the Turbo Stream target); sonner's `id` is `toaster_id:`; `class:` is added to `toaster group`; `ref`, `useSonner` and every React-element prop are not ported.
- Server entry points (no React equivalent): `flash:` (a Hash such as `flash.to_h`: `notice`/`success` -> success, `alert`/`error` -> error, `warning`, `info`, anything else a plain toast; blank values skipped), `toasts:` (array of `Sonner::Toast` keyword hashes) and the block (render `Sonner::Toast`s), all of which become toasts when the controller connects.
- `Sonner::Toast` renders an inert `<template data-shadcn--sonner-toast data-type=... data-id=... data-duration=... data-position=... data-dismissible=... data-close-button=... data-rich-colors=... data-invert=... data-icon="none" data-action-label/-href/-event data-cancel-label/-href/-event data-toaster-id data-test-id>` with `<div data-title>` and `<div data-description>` children (plain text). `duration: :infinity` -> `"Infinity"`. A Turbo Stream `append` onto the Toaster id inserts it; the controller turns every such template into a toast and removes it. `href` navigates (Turbo.visit) only for http(s) URLs.
- JS API: `window.Toaster` is sonner's `toast` (`Toaster(msg, data)`, `.success/.info/.warning/.error/.loading/.message/.promise/.dismiss/.custom/.getToasts/.getHistory`; `custom` takes a DOM node or a function returning one). The `shadcn--sonner:show` event (`detail: { message, type, ...options }`, bubbling to `document`) and the Stimulus actions `show`/`dismiss` (buttons inside the Toaster, `data-shadcn--sonner-message-param`...) call the same functions.
- Events (dispatched on the section, bubbling, `detail.id`): `shadcn--sonner:dismiss`, `shadcn--sonner:auto-close`, `shadcn--sonner:action`, `shadcn--sonner:cancel` (the last two also `detail.name` = the toast's `event`). The JS API still takes sonner's callbacks (`onDismiss`, `onAutoClose`, `action.onClick`).

Example (layout, a controller and a stream):

```ruby
render Chadcn::Toaster.new(flash: flash.to_h, close_button: true, position: "top-center")
turbo_stream.append "toaster", Chadcn::Sonner::Toast.new(type: :success, title: "Saved", description: "Stored")
```

## Structure

Server render: `<section id="toaster" tabindex="-1" aria-label="Notifications alt+T" aria-live="polite" aria-relevant="additions text" aria-atomic="false" data-controller="shadcn--sonner" ...values>` containing only inert `<template data-shadcn--sonner-icon="success|info|warning|error|loading|close">` (the Lucide icons and sonner's close icon) and the server toasts. The `aria-label` is `"<container_aria_label> <hotkey>"`, the hotkey written as sonner does (`altKey+KeyT` -> `alt+T`). The section has no `data-slot`, no class and no style (sonner:`section`), so the compared nodes are the `observe` selectors of the scenarios.

Client render (created by `ToastStack`, sonner:`Toaster`/`Toast`), one `<ol>` per position that has toasts (none while empty), each toast an `<li>`:

```html
<ol tabindex="-1" dir="ltr" class="toaster group" data-sonner-toaster="true" data-sonner-theme="light" data-y-position="bottom" data-x-position="right"
    style="--front-toast-height: 53.5px; --width: 356px; --gap: 14px; --normal-bg: var(--popover); ...; --offset-top: 24px; ...; --mobile-offset-top: 16px; ...">
  <li tabindex="0" class="" data-sonner-toast="" data-styled="true" data-mounted="true" data-promise="false" data-swiped="false" data-removed="false"
      data-visible="true" data-y-position="bottom" data-x-position="right" data-index="0" data-front="true" data-swiping="false" data-dismissible="true"
      data-type="success" data-swipe-out="false" data-expanded="false" style="--index: 0; --toasts-before: 0; --z-index: 1; --offset: 0px; --initial-height: 53.5px;">
    <button aria-label="Close toast" data-disabled="false" data-close-button="true">...close svg...</button>       <!-- close_button and not loading -->
    <div data-icon="">[loader] [type icon]</div>                                                                      <!-- typed, promise or icon -->
    <div data-content=""><div data-title="">Title</div><div data-description="">...</div></div>
    <button data-button="true" data-cancel="true">Cancel</button><button data-button="true" data-action="true">Undo</button>
  </li>
</ol>
```

`data-*` booleans are the strings `"true"`/`"false"` (React DOM), undefined ones are omitted (`data-type` of a plain toast, `data-rich-colors`, `data-invert`, `data-swipe-direction`, `data-testid`). Stacking is entirely `sonner.css` reading the variables above.

## Behavior

Primitives composed: none of the overlay primitives (a Toaster is a non-modal live region: no focus scope, no scroll lock, no hide-others, no portal, no positioner). The state machine is `toast_stack.js` (`ToastStack`), the store is its module singleton shared by every Toaster (sonner's `ToastState`).

- **Store** (sonner:`Observer`): `toast()`/`create` assign ids from a counter, an existing id updates the toast; `dismiss(id)` records the id and publishes after a frame, `dismiss()` publishes for every toast at once; `promise` creates a loading toast and replaces it with success/error (`unwrap` supported). A published message is applied one task later (sonner defers to prevent batching), newest first.
- **Mount** (sonner:`Toast`): the `<li>` is inserted with `data-mounted="false"`, its height measured (forcing the first style computation, so the CSS enter transition starts from there), then `data-mounted="true"`; the height is re-measured with `height: auto` (also after a content update). `--offset` = `heightIndex * gap + sum(previous heights)`.
- **Lifetime**: 4000 ms default (`duration` of the toast, `toast_options`, the Toaster, in that order); `loading` toasts and `Infinity` have no timer. The timer is paused while the stack is expanded, being interacted with, or the document is hidden, keeping the remaining time (sonner:`pauseTimer`/`startTimer`). On expiry: `auto-close` event/callback, exit state (`data-removed="true"`), removal 200 ms later (matches the CSS exit transition).
- **Expand**: pointer enter/move on a list expands the stack, leave collapses it unless a pointer is down; `drag-end` collapses. `expand: true` keeps it expanded. Fewer than two toasts always collapse. `visible_toasts` limits `data-visible`.
- **Swipe** (sonner:`onPointer*`): pointer down on a toast (not on a button, not right button, not loading, not non-dismissible) starts a swipe and captures the pointer; the first move that exceeds 1 px locks the axis (`x`/`y`) for the following moves; the toast follows through `--swipe-amount-x/y`, dampened against the allowed directions (`swipe_directions`, default the edges of `position`). Releasing at >= 45 px or a velocity above 0.11 px/ms dismisses it in that direction (`data-swipe-out`, `data-swipe-direction`), otherwise it snaps back.
- **Dismiss**: close button (when `close_button`), a swipe, the action button (unless it prevents the default), the cancel button, `toast.dismiss`. `dismissible: false` disables close, swipe and cancel.
- **Hotkey and focus**: `hotkey` (default Alt+T; every listed `KeyboardEvent` property or `code` must match) expands the stack and focuses the last list (`tabindex="-1"`); Escape while focus is inside the list collapses it; focus entering the list from outside is remembered and restored when focus leaves the list. A toast is `tabindex="0"`.
- **Theme**: `light`/`dark` set `data-sonner-theme`; `system` follows `prefers-color-scheme` and its changes. The shadcn colors come from the theme variables, so a theme paste restyles the toasts.
- **Accessibility**: the section is the polite live region (`aria-live="polite"`, `aria-relevant="additions text"`, `aria-atomic="false"`, exactly like sonner); toasts need no extra roles. Deliberate addition (deviation): an `error` toast is also written, after 50 ms, to a visually hidden `role="alert"` element appended to `<body>`, so errors interrupt (assertive) while every other type stays polite. Escape/focus behavior is the sonner one above; there is no focus trap.
- **Cleanup** (radix-stimulus R10): `disconnect()` and `turbo:before-cache` unsubscribe, clear every timer, remove the lists and the announcer and restore focus, so a Turbo cache restore never shows stale toasts or fires timers on a detached tree.
- **Ingestion**: on connect the controller turns the `<template data-shadcn--sonner-toast>` children into toasts, and a `MutationObserver` (child list of the section) does the same for later appends (Turbo Stream). Templates are removed once read.

Not expressible in the parity runner (covered in `test/javascript/sonner.test.mjs`): the flash/Turbo Stream/`window.Toaster`/show-event entry points, the assertive announcer, event dispatch and unsafe `href`, text-only titles (no HTML injection), the Turbo cache and removal cleanup, promise and loading timers.

## Oracle driving

sonner's `toast()` is a module function, so a static scenario tree cannot call it. The scenarios use a root `_div[data-controller="shadcn---probe-toast"]` whose descendants carry `data-parity-toast='{"method": "success", "message": "...", "data": {...}}'`; a click calls `toast[method]` on the React side (`react-shadcn-catalog/src/parity/primitives/toast_probe.tsx`) and `window.Toaster[method]` on the Phlex side (`dev/dummy/app/javascript/controllers/shadcn/_probe_toast_controller.js`). Compared nodes are chosen per scenario with `observe` (`section[aria-live]`, `[data-sonner-toaster]`, `[data-sonner-toast]`, `[data-icon]`, `[data-content]`, `[data-title]`, `[data-description]`, `[data-button]`, `[data-close-button]`).

## DX helpers

The oracle exports only `Toaster`, so `spec_helpers.rb` derives none. The root `Chadcn::Sonner` (renders a `Sonner::Toaster` with the options it is given and `yield self`s) gets the generated helpers `sonner.toaster` and `sonner.toast` from `Base`; `test/chadcn/sonner_test.rb` asserts `sonner.toast(...)` renders the same HTML as `Sonner::Toast.new(...)`.

## Dependencies

- Renders `Chadcn::Icon` (`circle-check`, `info`, `triangle-alert`, `octagon-x`, `loader-circle`; all already in the icon catalog) and `Chadcn::Base` (`merge_attrs`, `cn`, `normalize_option`, `json`).
- JavaScript: Stimulus and `shadcn/primitives/toast_stack` only.

## Deviations

One register entry (`gems/chadcn/dev/port/deviations/sonner.json`), no class-token allowance (G1 passes unchanged, the stylesheet carries the toast look): the Rails entry points, `id:`/`class:` handling, the missing React-element surface, callbacks as events, the assertive announcer for errors and the inert icon templates. Everything else (DOM, `data-*` state, stacking variables, computed styles, hover/hotkey/swipe/timer behavior) is compared with sonner in the 81 scenarios of `scenarios/sonner.json`.
