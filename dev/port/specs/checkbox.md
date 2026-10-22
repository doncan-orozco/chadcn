# Checkbox

Oracle: `gems/chadcn/dev/port/oracle/src/checkbox.tsx` (manifest `source_sha` ba0ac64064e2d8fa, tier `radix_stateful`), wrapping `CheckboxPrimitive.Root` / `CheckboxPrimitive.Indicator` from `radix-ui` 1.7.0 -> `@radix-ui/react-checkbox` 1.3.12 (`gems/chadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-checkbox/dist/index.mjs`, cited below as `cb.mjs:<line>`), Presence from `@radix-ui/react-presence` (`presence.mjs:<line>`), size from `@radix-ui/react-use-size` (`use-size.mjs:<line>`). Icon from `lucide-react` 0.577.0. React 19.

## API

One export (`Checkbox`), one Ruby class. The Indicator is not exported by shadcn; it is rendered internally (no Ruby class for callers).

```ruby
Components::V2::Checkbox.new(
  checked: nil,             # controlled: true | false | "indeterminate" (also :indeterminate); nil = uncontrolled
                            # (Radix useControllableState: controlled iff prop !== undefined, cb.mjs:33-38)
  default_checked: false,   # uncontrolled initial value: true | false | "indeterminate" (cb.mjs:35 `defaultProp: defaultChecked ?? false`)
  disabled: false,          # cb.mjs:112-113
  required: nil,            # nil -> no aria-required; true/false -> aria-required="true"/"false" (cb.mjs:110)
  name: nil,                # bubble input only (cb.mjs:258), never on the button
  value: "on",              # cb.mjs:29 default "on"; on the button (cb.mjs:114) AND the bubble input (cb.mjs:259)
  form: nil,                # bubble input `form` attribute (cb.mjs:260) and form-control detection (cb.mjs:46)
  class: nil,               # merged last into the Root classes through cn (tailwind_merge), caller wins
  **attrs                   # id, aria: {}, data: {}, "aria-invalid", "aria-label", title, ... pass through to the button (Root)
)
```

- `checked:` / `default_checked:` accept `true`, `false`, `"indeterminate"` and `:indeterminate` (R4); any other value is an `ArgumentError`.
- Controlled (`checked:` given): the server renders that state; click/Space does NOT change `data-state`/`aria-checked`/Indicator, it only dispatches `chadcn--checkbox:checked-change` with the value Radix would compute (`isIndeterminate(prev) ? true : !prev`, cb.mjs:122). useControllableState in controlled mode calls `onChange(next)` only when `next !== prop`, and never stores it. Callers re-render the next state from the server.
- Uncontrolled (`default_checked:`): the controller owns state after connect.
- Events: `chadcn--checkbox:checked-change`, `detail: { checked: true | false | "indeterminate" }`, dispatched from the Root button after each change (uncontrolled: after the DOM update; controlled: instead of it). Also dispatched on form reset when the value changes (reset calls `setChecked`, cb.mjs:99). Not cancelable (`onCheckedChange` is not preventable). Consumer `onClick` / `onKeyDown` are plain `data: { action: ... }`; Radix composes consumer first and skips its own handler when the consumer called `preventDefault()` (`composeEventHandlers`, cb.mjs:117-127), so the controller checks `event.defaultPrevented` before acting.
- `as_child:` is NOT offered (see Deviations).
- `ref` has no equivalent.

## Structure

Server-rendered DOM. Radix renders a Fragment: button, then (when it is a form control) the bubble input as next sibling (cb.mjs:159-174).

```html
<!-- unchecked -->
<button type="button" role="checkbox" aria-checked="false" data-state="unchecked" value="on"
        data-slot="checkbox" class="<Root classes>" data-controller="chadcn--checkbox" ...></button>
<!-- checked / indeterminate -->
<button type="button" role="checkbox" aria-checked="true|mixed" data-state="checked|indeterminate" value="on" data-slot="checkbox" class="...">
  <span data-state="checked|indeterminate" data-slot="checkbox-indicator" class="grid place-content-center text-current transition-none" style="pointer-events: none;">
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor"
         stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-check size-3.5" aria-hidden="true">
      <path d="M20 6 9 17l-5-5"></path>
    </svg>
  </span>
</button>
<input type="checkbox" aria-hidden="true" tabindex="-1" value="on"
       style="position: absolute; pointer-events: none; opacity: 0; margin: 0px; transform: translateX(-100%);">
```

Part `Checkbox` (Radix Root -> `CheckboxTrigger`, `data-slot="checkbox"`), cb.mjs:104-129 + checkbox.tsx:
- tag `button`, `type="button"`, `role="checkbox"`, `aria-checked="true" | "false" | "mixed"` (always present; `mixed` iff indeterminate, cb.mjs:109), `aria-required` only when `required:` is non-nil, `data-state="checked|unchecked|indeterminate"` (`getState`, cb.mjs:293-295), `data-disabled=""` and `disabled=""` only when disabled, `value="on"` (or `value:`), `data-slot="checkbox"`, then caller attrs (they win: `...checkboxProps` is spread after Radix's attributes, cb.mjs:115).
- Classes, verbatim from checkbox.tsx: `peer size-4 shrink-0 rounded-[4px] border border-input shadow-xs transition-shadow outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 data-[state=checked]:border-primary data-[state=checked]:bg-primary data-[state=checked]:text-primary-foreground dark:bg-input/30 dark:aria-invalid:ring-destructive/40 dark:data-[state=checked]:bg-primary`, then `class:` through `cn`.
- Note: there is no `data-[state=indeterminate]:` class in the oracle; the indeterminate state shows the same check icon on the unchecked background (`text-current`). Reproduce exactly, do not add a minus icon.
- Children: exactly the Indicator, only while present (see Behavior/Presence). When unchecked the button is empty. The server must not add any helper node Radix lacks (e.g. a `<template>` inside the button would fail G2 NODE_COUNT); the controller keeps the Indicator markup outside the DOM (captured on connect when initially present, or built from the server-provided markup passed as a Stimulus value) and re-inserts it on check.

Indicator (`data-slot="checkbox-indicator"`, Radix `CheckboxIndicator`, cb.mjs:180-201):
- tag `span`, `data-state` mirrors the Root, `data-disabled=""` when disabled, `data-slot="checkbox-indicator"`, `class="grid place-content-center text-current transition-none"` (verbatim, no caller merge), inline `style="pointer-events: none;"` (cb.mjs:196).
- Rendered only when `checked === true` or `"indeterminate"` (`present`, cb.mjs:188; no `forceMount` from shadcn). Unchecked = not in the DOM.
- Child: `Components::V2::Icon` `check` with `class: "size-3.5"`: lucide 0.577.0 markup `class="lucide lucide-check size-3.5"`, `aria-hidden="true"` (lucide `Icon.js:33` adds it because there are no children and no a11y prop), path `M20 6 9 17l-5-5`.

Bubble input (no data-slot; Radix `CheckboxBubbleInput`, cb.mjs:204-284):
- `input type="checkbox" aria-hidden="true" tabindex="-1"`, `checked=""` attribute when the initial value is `true` (React `defaultChecked: defaultChecked ?? defaultCheckedRef.current`, cb.mjs:249, 255; with a controlled `checked: true` and no `default_checked` it is also `checked=""`; indeterminate initial -> not checked), `required=""`, `disabled=""`, `name`, `value`, `form` when given. Style in Radix order: `width`/`height` px once measured (`...controlSize`, cb.mjs:271), then `position: absolute; pointer-events: none; opacity: 0; margin: 0px; transform: translateX(-100%)` (cb.mjs:272-279).
- Rendered iff it is a form control: `!!form || !!control.closest("form")`; before mount Radix assumes `true` (cb.mjs:46-49, "so that events bubble to forms without JS (SSR)"). Port: the server ALWAYS renders it (identical to Radix SSR); the controller removes it in `connect()` when there is no `form:` and no `closest("form")`. Post-connect DOM equals React in both cases.
- The initial indeterminate value does not set `input.indeterminate` (the effect at cb.mjs:226-248 only writes on change); after a change to indeterminate it does (`input.indeterminate = true`, checked false).

Server vs Stimulus: the server renders every attribute above for the initial state, including the Indicator when checked/indeterminate. Stimulus (`chadcn--checkbox`, host = the button itself) updates `aria-checked`, `data-state` on button and Indicator, mounts/unmounts the Indicator, syncs the bubble input and its size. No ids are generated (only a caller `id:`, typically for `<label for>`).

## Behavior

States: `unchecked`, `checked`, `indeterminate`; orthogonal `disabled`. `aria-invalid` is a caller attribute (style only).

Transitions (cb.mjs:117-127, `onClick` composed after the consumer onClick):
1. Native `click` on the button (unless `event.defaultPrevented`): count a user interaction, `next = prev === "indeterminate" ? true : !prev` (cb.mjs:122). So indeterminate -> checked -> unchecked -> checked; indeterminate is never reached by user input, only via props/reset.
2. If the bubble input exists and it is a form control: record whether the consumer already stopped propagation; if not, `event.stopPropagation()` on the button click (cb.mjs:123-126).
3. On every value change (cb.mjs:226-248): `input.indeterminate = (next === "indeterminate")`, set `checked` via the native `HTMLInputElement.prototype` setter to `next === true`, dispatch `new Event("click", { bubbles })` on the input with `bubbles = !(isUserInteraction && consumerStoppedPropagation)`; for non-user changes (reset, controlled prop change) the input's own click listener stops propagation (`shouldStopClickPropagationRef`, cb.mjs:241, 264-268). An `Event` (not `MouseEvent`) has no activation behavior, so it does not re-toggle the input.
4. Update DOM (`aria-checked`, `data-state` x2, Indicator presence) and dispatch `chadcn--checkbox:checked-change`.
- Controlled: step 1 computes `next` and dispatches only; DOM stays server-rendered.

Keyboard (cb.mjs:117-119):

| Key | Result |
|---|---|
| Space | native button activation (click on keyup) -> toggles |
| Enter | `keydown` `preventDefault()` -> NO click, no toggle (WAI-ARIA checkbox: Space only) |
| Tab / Shift+Tab | native tab order; disabled buttons skipped |

The controller handles only `keydown` Enter (`preventDefault()`); no other key handler. Focus ring only on `:focus-visible`; a mouse click focuses without a visible ring.

Pointer: plain `click` (not `pointerdown`). Disabled buttons get no click. `<label for="<id>">` click and a wrapping `<label>` click activate the button (labelable element) and toggle it (checkbox-demo).

Presence (Indicator, presence.mjs:21-171): mounting is immediate when `present` becomes true. On unmount Presence keeps the node only if the computed `animation-name` is not `none` and changed (presence.mjs:59-76), waiting for `animationend`. shadcn's Indicator has `transition-none` and no animation class, so it is removed synchronously. Port: use the `presence` primitive (so a caller-added `data-[state=unchecked]:animate-out` class would behave like Radix), which in the oracle configuration degenerates to an immediate remove. Note: the unmounting Indicator would carry `data-state="unchecked"` during an exit animation (it reads `context.checked`).

Form integration:
- Reset: on `button.form` (`control?.form`, cb.mjs:97, native `form` IDL so the `form` attribute is honored) `reset` event, revert to the value captured at first render (`initialCheckedStateRef`, cb.mjs:95-103), including `"indeterminate"`. Controlled: dispatches `checked-change` only if different. Listener removed on disconnect.
- Bubble input size: on connect `{ width: offsetWidth, height: offsetHeight }` of the button, then a `ResizeObserver` (`box: "border-box"`, `borderBoxSize[0].inlineSize/blockSize`, rAF-debounced) exactly like `use-size.mjs:7-47`. Cancel rAF and unobserve on disconnect.

Timers: none. No dismissal, no scroll lock, no positioning, no direction handling (Radix Checkbox does not read `dir`).

Primitives composed: `form_bubble_input` (create/remove decision, native setter + synthetic click with Radix's bubbles/stop rules, `indeterminate` property, size observation, reset hook) and `presence` (Indicator mount/unmount). Nothing else.

Turbo: `disconnect()` removes the reset listener, ResizeObserver and rAF; `connect()` reconciles from the DOM (radix-stimulus R4).

## Dependencies

- `Components::V2::Icon` (`check`, `class: "size-3.5"`) inside the Indicator (manifest `icons: ["CheckIcon"]`).
- No other V2 component (`registry_dependencies: []`). Registry examples use `Label` (checkbox-demo) and `Field*` (field-checkbox, form-rhf-checkbox), which are not dependencies of `checkbox`; their scenarios use raw `_label` / `_div` / `_fieldset` / `_form` instead.

## Deviations

One, API only (no DOM or class difference):

- `as_child:` is not supported on `Components::V2::Checkbox`. Reason: Radix Root (`Primitive.button`) accepts `asChild`, but shadcn's `Checkbox` always renders `CheckboxPrimitive.Indicator` as the Root's only child, so Radix `Slot` would merge every checkbox attribute and handler onto the Indicator, which renders nothing at all while unchecked (Presence) and a `span` otherwise: no usable control. No registry example uses it. Entry in `gems/chadcn/dev/port/deviations/checkbox.json`:

```json
{ "reason": "shadcn Checkbox always passes CheckboxPrimitive.Indicator as the Root's only child, so Radix asChild would merge the checkbox onto the indicator (absent while unchecked); as_child is therefore not offered", "allow_tokens": [], "allow_missing_tokens": [], "api": ["Checkbox: as_child not supported"] }
```
