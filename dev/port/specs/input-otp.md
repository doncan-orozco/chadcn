# InputOTP (shadcn new-york-v4, input-otp 1.5.0)

Sources read: oracle `dev/port/oracle/src/input-otp.tsx` (manifest `source_sha` 9f81898aeaabbb10, tier `third_party`, cited `src:<part>`), the library it wraps, `dev/react-shadcn-catalog/node_modules/input-otp/dist/index.mjs` 1.5.0 (minified; cited as `otp:<n>` = line n of `npx esbuild node_modules/input-otp/dist/index.mjs --format=esm`, run in the catalog), React DOM 19.3.0 (`react-dom-client.development.js`: `shouldSetTextContent` treats `noscript` as text content), lucide-react 0.577.0. Registry examples (new-york-v4, fetched from ui.shadcn.com): `input-otp-demo`, `input-otp-pattern`, `input-otp-separator`, `input-otp-controlled` (`input-otp-form` is not served as a registry item and uses react-hook-form, which is skipped; see `skip_reasons`). No Radix primitive is involved (manifest `radix_primitives: []`).

Tier `third_party`. Stimulus identifier `chadcn--input-otp` (one controller, host = the container `div`). **No third-party JavaScript**: input-otp is re-implemented in the `chadcn--input-otp` controller (same constraint as command, item #178); no importmap pin, vendor file or npm dependency is added (a unit test asserts it).

## API

Every part: `class:` goes through `cn` last (caller wins); `**attrs` pass through (`data:`/`aria:` deep-merged); string values only, no cva tables. Option kwargs accept strings and symbols (`input_mode: :text`, `push_password_manager_strategy: :increase_width` == `"increase-width"`).

```ruby
Chadcn::InputOtp.new(
  max_length:,                               # required Integer (OTPInput `maxLength`, otp:69); number of slots and the input's maxlength
  value: nil,                                # controlled String; nil = uncontrolled (otp:71 `l = o != null ? o : rt`)
  default_value: nil,                        # uncontrolled initial String (otp:71 `typeof i.defaultValue == "string" ? ... : ""`)
  pattern: nil,                              # String regexp source (JS RegExp semantics), e.g. Chadcn::InputOtp::REGEXP_ONLY_DIGITS (otp:73, 213)
  placeholder: nil,                          # String; rendered ONLY as aria-placeholder (otp:162); shadcn's Slot never shows placeholderChar
  input_mode: "numeric",                     # otp:69 default "numeric"; any inputmode value
  text_align: "left",                        # "left" | "center" | "right" (otp:69 default "left"); input style `text-align`
  push_password_manager_strategy: "increase-width", # "increase-width" | "experimental-no-flickering" | "none" (otp:69)
  no_script_css_fallback: Chadcn::InputOtp::NO_SCRIPT_CSS_FALLBACK, # String or nil (nil = no <noscript>), otp:69 default `Ft` (otp:193-212)
  nonce: nil,                                # CSP nonce for the injected <style id="input-otp-style"> (otp:107)
  container_class_name: nil,                 # React `containerClassName`: merged through cn after "flex items-center gap-2 has-disabled:opacity-50" on the container div (src:InputOTP)
  class: nil,                                # React `className`: merged through cn after "disabled:cursor-not-allowed" on the INPUT (src:InputOTP; OTPInput spreads className onto the input, otp:162)
  **attrs                                    # go to the <input> (OTPInput spreads every other prop there, otp:162): id, name, disabled, required,
                                             # auto_complete (default "one-time-code"), spell_check (default false), aria: {}, data: {}, form, autofocus...
) { |input_otp| ... }                        # block = the slots layout (Group/Slot/Separator), rendered inside the container before the input wrapper

Chadcn::InputOtp::Group.new(class: nil, **attrs) { ... }        # React InputOTPGroup
Chadcn::InputOtp::Slot.new(index:, class: nil, **attrs)        # React InputOTPSlot; index: required Integer; attrs (aria-invalid...) on the slot div
Chadcn::InputOtp::Separator.new(**attrs)                        # React InputOTPSeparator; attrs (class: too, via cn) on the separator div
```

- Constants mirroring the library exports used by the examples (otp:213): `Chadcn::InputOtp::REGEXP_ONLY_DIGITS = "^\\d+$"`, `REGEXP_ONLY_CHARS = "^[a-zA-Z]+$"`, `REGEXP_ONLY_DIGITS_AND_CHARS = "^[a-zA-Z0-9]+$"`, and `NO_SCRIPT_CSS_FALLBACK` (the `Ft` string, verbatim, otp:193-212).
- `value:` (controlled): the server renders that value; user input dispatches `change` with the attempted value and the controller puts the input back to the rendered value (React re-renders the controlled `<input value={l}>`, otp:71-72: `O` calls `onChange` and sets internal state, which is ignored while `o != null`).
- `max_length:` is not used to truncate `value:`/`default_value:` on the server (React renders `l` as given; slots read `l[n]` for `n < maxLength`, otp:178-181).
- `as_child:` is not offered (OTPInput has no asChild; shadcn's parts are plain divs without Slot).
- Events (dispatched from the container, `this.dispatch`, bubbling, not cancelable):
  - `chadcn--input-otp:change`, `detail: { value }`: React `onChange(value)` (otp:71-72 `O`), after every accepted input change (otp:136-141) and on the iOS/pasteTransformer paste path (otp:157). Not dispatched for a rejected pattern (otp:137-139).
  - `chadcn--input-otp:complete`, `detail: { value }`: React `onComplete(value)`, when the rendered value goes from `length < max_length` to `length === max_length` (otp:132-134, compares with the previous rendered value).
- `render` (render-prop) and `pasteTransformer` are JS functions: see Deviations. `onFocus`/`onBlur`/`onPaste`/`onMouseOver`/`onMouseLeave` callers use plain `data: { action: "focus->x#y" }` on the input (the library calls the consumer handler after its own, otp:162-177).
- `ref` has no equivalent (React forwards it to the input, otp:74).

## Structure

React client DOM (shadcn passes `data-slot="input-otp"` through `...props`, so it lands on the **input**, not on the container; the container has no `data-slot`):

```html
<noscript></noscript>                                 <!-- otp:183; React client renders noscript children as text content, i.e. empty -->
<div data-input-otp-container="true" translate="no"
     style="position: relative; cursor: text; user-select: none; -webkit-user-select: none; pointer-events: none; --root-height: 36px;"
     class="flex items-center gap-2 has-disabled:opacity-50"                 <!-- containerClassName, src:InputOTP -->
     data-controller="chadcn--input-otp">                                    <!-- port only -->
  {children: Group / Slot / Separator}
  <div style="position: absolute; inset: 0px; pointer-events: none;">       <!-- otp:183 -->
    <input autocomplete="one-time-code" data-slot="input-otp" class="disabled:cursor-not-allowed"
           data-input-otp="true" data-input-otp-placeholder-shown="true" data-input-otp-mss="0" data-input-otp-mse="0"
           inputmode="numeric" maxlength="6" value="" spellcheck="false" style="...">
  </div>
</div>
```

Part `InputOTP` (`Chadcn::InputOtp`; container + input wrapper + input), otp:160-183:
- Optional `<noscript>` immediately before the container when `no_script_css_fallback` is non-nil. The port renders `<noscript><style>{Ft}</style></noscript>` (the SSR output, which is what makes the no-JS fallback work); see Deviations.
- Container `div`: `data-input-otp-container="true"`, `translate="no"`, inline style `position: relative; cursor: text|default; user-select: none; -webkit-user-select: none; pointer-events: none` (`cursor: default` iff the input is disabled, otp:160 `It`), class = `cn("flex items-center gap-2 has-disabled:opacity-50", container_class_name)`. The controller adds `--root-height: <input.clientHeight>px` to its style on connect and on every input resize (`ResizeObserver` on the input, otp:112-117). Server renders no `--root-height` (React also sets it in an effect).
- Children (the block) in order, then the wrapper `div` with inline style `position: absolute; inset: 0px; pointer-events: none` (otp:183) holding the input.
- `input` attributes (otp:162; React prop order: `autoComplete`, caller props, then the library's): `autocomplete="one-time-code"` unless the caller passes `auto_complete:`; caller attrs (`data-slot="input-otp"` is shadcn's and comes first, `class`, `id`, `name`, `disabled`, `aria-*`, `data-*`...); `data-input-otp="true"`; `data-input-otp-placeholder-shown="true"` only when the value is empty (absent otherwise); `data-input-otp-mss` / `data-input-otp-mse` (selection start/end, see Behavior; absent while null, so the server never renders them); `inputmode` (default `numeric`); `pattern` only when given (the source string); `aria-placeholder` only when `placeholder:` is given; `style`; `maxlength`; `value` (current value; React syncs the attribute on every update, so the controller keeps the `value` ATTRIBUTE equal to the property); `spellcheck="false"` unless the caller passes `spell_check:`. React never renders a native `placeholder` attribute (destructured, otp:69) and never a `defaultValue` (controlled input).
- Input inline style, in this order (otp:160 `dt`): `position: absolute; inset: 0px; width: 100%; height: 100%; display: flex; text-align: <text_align>; opacity: 1; color: transparent; pointer-events: all; background: transparent; caret-color: transparent; border: 0px solid transparent; outline: transparent solid 0px; box-shadow: none; line-height: 1; letter-spacing: -0.5em; font-size: var(--root-height, 16px); font-family: monospace; font-variant-numeric: tabular-nums`. When the password-manager badge push is on (Behavior), `width: calc(100% + 40px)` and `clip-path: inset(0px 40px 0px 0px)` (clip-path only then, otp:160).
- Classes on the input: `cn("disabled:cursor-not-allowed", class)`.

Part `InputOTPGroup` (`InputOtp::Group`, `data-slot="input-otp-group"`), src:InputOTPGroup: `div`, class `cn("flex items-center", class)`, attrs, children.

Part `InputOTPSlot` (`InputOtp::Slot`, `data-slot="input-otp-slot"`), src:InputOTPSlot + otp:178-181:
- `div data-slot="input-otp-slot" data-active="true|false"`, class = `cn("relative flex h-9 w-9 items-center justify-center border-y border-r border-input text-sm shadow-xs transition-all outline-none first:rounded-l-md first:border-l last:rounded-r-md aria-invalid:border-destructive data-[active=true]:z-10 data-[active=true]:border-ring data-[active=true]:ring-[3px] data-[active=true]:ring-ring/50 data-[active=true]:aria-invalid:border-destructive data-[active=true]:aria-invalid:ring-destructive/20 dark:bg-input/30 dark:data-[active=true]:aria-invalid:ring-destructive/40", class)`, then caller attrs (React spreads `...props` after `className`, so a caller `data-active` wins; keep the same order).
- `data-active`: `"false"` for every `index < max_length` while the input is not focused (server render and blurred state); `"true"` per the Behavior active rule. For `index >= max_length` the context slot is undefined: NO `data-active` attribute and no char (src:InputOTPSlot `?? {}`).
- Children: the char (`value[index]`, a text node, nothing when absent), then the fake caret only when `hasFakeCaret` (active and no char): `<div class="pointer-events-none absolute inset-0 flex items-center justify-center"><div class="h-4 w-px animate-caret-blink bg-foreground duration-1000"></div></div>`. The port ships the caret markup in an inert `<template data-chadcn--input-otp-target="caret">` (no data-slot) as the slot's last child and mounts it with `template_mount` (`into: "after"`) when needed; see Deviations. `animate-caret-blink` comes from the vendored tw-animate (`caret-blink 1.25s ease-out infinite`).
- Server: the root passes `value`/`max_length` to its slots through the render context (the Slot needs no kwarg beyond `index:`); the server renders the initial char and `data-active="false"`.

Part `InputOTPSeparator` (`InputOtp::Separator`, `data-slot="input-otp-separator"`), src:InputOTPSeparator: `div data-slot="input-otp-separator" role="separator"`, caller attrs after (so `role:` can be overridden), child `Chadcn::Icon.new(name: "minus")` (lucide `MinusIcon`, renders `svg.lucide.lucide-minus` with `aria-hidden="true"`). No classes of its own.

Ids: none generated; only a caller `id:` on the input (for `<label for>`).

## Behavior

Model (otp:71-73, 121): `value` (rendered), `focused` (`L`), `mss`/`mse` (`H`/`A`, selection start/end or null), `hovering` (unused by shadcn's slots, not reproduced in the DOM). Slot `n` (0..max_length-1) derives: `char = value[n] ?? null`; `isActive = focused && mss !== null && mse !== null && ((mss === mse && n === mss) || (n >= mss && n < mse))`; `hasFakeCaret = isActive && char === null` (otp:180-181). After every model change the controller rewrites each slot's char, `data-active`, fake caret, and the input's `value`/`data-input-otp-*` attributes.

Input handling (`onChange` = React's `input` event listener, otp:136-141):
1. `next = input.value.slice(0, max_length)`.
2. If `next.length > 0` and `pattern` is set and `!new RegExp(pattern).test(next)`: reject; put the input back to the rendered value (React re-render of the controlled input; setting `.value` moves the caret to the end) and stop. No event.
3. If `next.length < previous value length`: `document.dispatchEvent(new Event("selectionchange"))` (otp:141).
4. Commit: uncontrolled -> value = next; controlled -> keep the rendered value (put the input back). Dispatch `change { value: next }`. Then `complete` if the rendered value went from `< max_length` to `=== max_length` (otp:132-134).

Selection normalization (`selectionchange` listener on `document`, capture, added on connect, otp:78-105). Reproduce `c()` verbatim:
- If `document.activeElement !== input`: `mss = mse = null`, done.
- `s = selectionStart, e = selectionEnd, dir = selectionDirection, max = input.maxLength, v = input.value, prev = last [s, e, dir]`.
- If `v.length !== 0` and both non-null, collapsed (`s === e`) and NOT (`s === v.length && v.length < max`): `W = s`; `W === 0` -> select `[0, 1]` forward; `W === max` -> `[W-1, W]` backward; else if `max > 1 && v.length > 1`: `dir = W < prev[1] ? "backward" : "forward"`, `offset = (dir === "backward" && !(prev[0] === prev[1] && prev[0] < max)) ? -1 : 0`, select `[offset+W, offset+W+1]`. Apply with `setSelectionRange(start, end, dir)` when both set and different.
- `mss/mse` = the applied range (or the raw selection), `prev = [mss, mse, dir]`.
- On connect `c()` runs once; if the input is already focused, `focused = true` (otp:105).
Consequences that the scenarios check: an empty focused input has a collapsed caret at 0 -> slot 0 active with fake caret; at the end of a partial value (`len < max`) the caret stays collapsed -> slot `len` active with fake caret; a full value selects the last char `[max-1, max]` -> last slot active without caret, so typing replaces it (`type__overflow-replaces-last`) and Backspace deletes it; ArrowLeft/ArrowRight/Home/End move a one-char selection (native keys, normalized here). There is NO keydown handler: Backspace, Delete, arrows, Home/End and typing are native text-input editing, normalized by this listener.

Focus (otp:142-148, 171-176): on `focus`, `setSelectionRange(min(value.length, max_length-1), value.length)`, set `mss/mse` to those, `focused = true`. On `blur`, `focused = false` (slots go `data-active="false"`; `mss/mse` keep the last numbers, see timers). Tab order: the input is the only focusable element (native; `disabled` inputs are skipped). Focus ring: none on the input (transparent); the active slot shows `data-[active=true]:ring-*`.

Timers:
- Sync timers (otp:17-20, 122-132): after connect and after every change of `value` or `focused`, schedule `setTimeout` 0, 10 and 50 ms; each re-reads the input (if `input.value` differs from the rendered value, run Input handling, which covers browser autofill; React's re-dispatched `input` event fires `onChange` only on a real change) and then, if `selectionStart`/`selectionEnd` are non-null, sets `mss/mse` to them (even when blurred: this is why an untouched input shows `data-input-otp-mss="0" data-input-otp-mse="0"` after mount). Pending timers are cleared when rescheduled and on disconnect.
- Password-manager badge (otp:29-67, `Mt`), skipped entirely when `push_password_manager_strategy` is `"none"`: on connect and every 1000 ms (`setInterval`), `hasSpace = spaceRight(container) >= 40` where `spaceRight` walks up from the container to the first ancestor with `overflow-x !== visible` (`left + clientLeft + clientWidth - container.right`) or uses `documentElement.clientWidth - container.right` (otp:30-37). When the input is focused (and not yet `done`): `setTimeout` 0, 2000, 5000 ms run `check`, and 6000 ms sets `done = true`. `check` (otp:40-45): unless `done`, `x = container.left + container.offsetWidth - 18`, `y = container.top + offsetHeight/2`; if `document.querySelectorAll('[data-lastpass-icon-root],com-1password-button,[data-dashlanecreated],[style$="2147483647 !important;"]').length === 0 && document.elementFromPoint(x, y) === container` nothing happens; otherwise `hasSpace` is recomputed, `hasBadge = true`, `done = true`. `willPush = (strategy is "increase-width" or "experimental-no-flickering") && hasBadge && hasSpace` switches the input style to `width: calc(100% + 40px); clip-path: inset(0px 40px 0px 0px)`. Note: the container has `pointer-events: none`, so `elementFromPoint` returns the input, never the container; with the default strategy and 40px of room the push therefore happens on the first focus (0 ms timer) in the oracle too, and the port must match it (`focus__tab`, `push-password-manager-none__focus`).

Paste (otp:149-160): only intercepted when the browser is iOS (`CSS.supports("-webkit-touch-callout", "none")`, otp:73) or a `pasteTransformer` is set; then `preventDefault`, splice the clipboard text into the value at the selection (replace the selected range, or insert at the caret), slice to `max_length`, reject on pattern failure, set `input.value`, commit (event `change`), and select `[min(len, max-1), len]`. On desktop browsers paste is native (the browser inserts within `maxlength` and fires `input`, handled above). The parity scenarios cannot use the clipboard; `fill__*` covers the replace-whole-value path and the controller's browser test covers both paste paths.

Global stylesheet (otp:105-111): once per document, if `#input-otp-style` is absent, append `<style id="input-otp-style">` to `head` (with `nonce` when given) and `insertRule` the five rules verbatim: `[data-input-otp]::selection {...}`, `[data-input-otp]:autofill {...}`, `[data-input-otp]:-webkit-autofill {...}`, the `@supports (-webkit-touch-callout: none)` rule, `[data-input-otp] + * { pointer-events: all !important; }` (each wrapped in try/catch with the same `console.warn`). It is never removed (the library does not remove it either).

States: `focused`/blurred, value length 0..max (empty -> `data-input-otp-placeholder-shown`), active slot range, disabled (native: no focus, no input, container `cursor: default`, `has-disabled:opacity-50`), controlled vs uncontrolled. No dismissal, no scroll lock, no Presence (the fake caret mounts and unmounts instantly, React conditional rendering), no positioning, no direction handling (the library never reads `dir`).

Primitives composed: `template_mount` (fake caret). Nothing else applies (no Radix primitive in the oracle). The ResizeObserver, `selectionchange` listener, timers and interval are owned by the controller and released in `disconnect()`.

Turbo: `connect()` reconciles from the input's current value (unmount any mounted caret, rewrite chars and `data-active`), so a cached snapshot taken while focused restores consistently; no `turbo_cache` restore is needed (the controller does not move server markup).

Scenario notes: the `input-otp-controlled` example keeps its value in React state; the harness has no state, so its scenario renders the controlled `value=""` with the static helper text (the `value=""` case freezes typing in both, `controlled__value-without-feedback` covers it). Clicks target `[data-slot=input-otp]` (the input covers the container).

## Third-party

shadcn wraps `input-otp` 1.5.0 (`OTPInput`, `OTPInputContext`; `REGEXP_ONLY_*` are used by the examples). Chosen JS library: **none**; the port is a hand-written Stimulus controller reproducing OTPInput's DOM and state machine (above), with no new npm dependency, importmap pin or vendor file.

Mapping input-otp -> port: `OTPInput` `$t` (otp:68-184) -> `Chadcn::InputOtp` (container, input wrapper, input) + the `chadcn--input-otp` controller; `OTPInputContext` slots (otp:178-182) -> the controller rewriting each `InputOtp::Slot` (`data-chadcn--input-otp-target="slot"`; the slot's `index:` travels in an attribute matched by `IGNORED_ATTR` in `.claude/scripts/shadcn/parity_run.mjs` (line 67: `data-.*-target`, `data-.*-value`...), e.g. `data-chadcn--input-otp-index-value="3"`; a `-param` attribute is NOT ignored by the runner and would fail G2); `usePrevious` `Tt` (otp:22-27) -> the controller's last rendered value; `_t` sync timers (otp:17-20) -> the 0/10/50 ms timers; `Mt` password-manager badge hook (otp:39-67) -> the badge check; the injected `#input-otp-style` sheet (otp:105-111) -> the same element inserted by the controller; `noScriptCSSFallback` `Ft` (otp:193-212) -> `NO_SCRIPT_CSS_FALLBACK`; `REGEXP_ONLY_DIGITS`/`CHARS`/`DIGITS_AND_CHARS` (otp:213) -> Ruby constants.

## Dependencies

- `Chadcn::Icon` (`minus`, already in `icons/catalog.rb`): `InputOtp::Separator`.
- `Chadcn::Base`: `cn`, `merge_attrs`, render context (root -> slots), generated helpers.
- JavaScript: Stimulus and `chadcn/primitives/template_mount.js`; no new pin.
- Scenario trees use raw `_div`, `_form`, `_label` only (no other component).

## Deviations

Recorded in `dev/port/deviations/input-otp.json` (API/structure only; no class-token allowance, G1 unchanged):

1. The input-otp library is re-implemented in the `chadcn--input-otp` Stimulus controller with no new npm dependency (reason: no JavaScript dependency for the Phlex port, same constraint as command/cmdk); DOM, attributes and inline styles follow otp:160-183.
2. The fake caret markup ships in an inert `<template>` (no data-slot, not in the document) as each Slot's last child and is mounted by `template_mount` while `hasFakeCaret`; React mounts it conditionally and the server cannot know focus.
3. `<noscript>`: the port renders the SSR form `<noscript><style>…</style></noscript>`; React's client render leaves the noscript empty (React DOM treats `noscript` children as text content). Neither is a data-slot element; keeping the style is what makes the no-JS fallback work.
4. `render` (render-prop alternative to children) and `pasteTransformer` are JS functions: `render` is not offered (the block is the children); `pasteTransformer` is assigned from JavaScript on the controller (`controller.pasteTransformer = (text) => string`), like command's `filter`.
5. Callbacks are events: `onChange` -> `chadcn--input-otp:change`, `onComplete` -> `chadcn--input-otp:complete` (`detail: { value }`).
6. The container carries `data-controller="chadcn--input-otp"` and the slots/input/caret templates carry Stimulus target attributes plus the slot index (in a `data-*-value`-shaped attribute), which the oracle does not have; the runner ignores these (`IGNORED_ATTR`, parity_run.mjs:67).
