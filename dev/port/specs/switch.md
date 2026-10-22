# Switch

Oracle: `gems/chadcn/dev/port/oracle/src/switch.tsx` (manifest `source_sha` 743676f33f823ffa, tier `radix_stateful`), wrapping `SwitchPrimitive.Root` / `SwitchPrimitive.Thumb` from `radix-ui` 1.7.0 -> `@radix-ui/react-switch` 1.3.8 (`gems/chadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-switch/dist/index.mjs`, cited below as `switch.mjs:<line>`). React 19.

## API

One export, one Ruby class. The Thumb is not exported by shadcn; it is rendered internally (no Ruby class for callers).

```ruby
Components::V2::Switch.new(
  size: "default",          # "default" | "sm" (strings or symbols, R4); default from switch.tsx `size = "default"`
  checked: nil,             # controlled: true | false; nil = uncontrolled (Radix useControllableState: controlled iff prop !== undefined)
  default_checked: false,   # uncontrolled initial value (switch.mjs:34 `defaultProp: defaultChecked ?? false`)
  disabled: false,          # switch.mjs:105-106
  required: nil,            # nil -> no aria-required; true/false -> aria-required="true"/"false" (switch.mjs:103)
  name: nil,                # bubble input only (switch.mjs:239), never on the button
  value: "on",              # switch.mjs:28 default "on"; on the button AND the bubble input
  form: nil,                # bubble input `form` attribute (switch.mjs:241) and form-control detection (switch.mjs:45)
  class: nil,               # merged last into the Root classes through cn (tailwind_merge), caller wins
  **attrs                   # id, aria: {}, data: {}, aria-invalid, aria-label, ... pass through to the button (Root)
)
```

- `size:` accepted as `"sm"`, `:sm`, `"default"`, `:default`. Rendered as `data-size="<size>"` on the Root (switch.tsx `data-size={size}`); there is no cva table, the size styling is entirely `data-[size=...]` / `group-data-[size=...]/switch` classes.
- `checked:` (controlled): the server renders that state; a click/Space/Enter does NOT change `data-state`/`aria-checked`, it only dispatches `shadcn--switch:checked-change` with `detail: { checked: !checked }` (useControllableState `setValue`: in controlled mode it calls `onChange(nextValue(prop))` only when it differs from `prop` and never stores it). Callers re-render the next state from the server.
- `default_checked:` (uncontrolled): the controller owns state after connect.
- Events: `shadcn--switch:checked-change`, `detail: { checked: <Boolean> }`, dispatched from the Root button after every user toggle (uncontrolled: after the DOM is updated, like useUncontrolledState's effect calling onChange; controlled: instead of updating). Not cancelable (Radix `onCheckedChange` is not preventable). `onClick` callers use plain `data: { action: "click->x#y" }`; Radix runs the consumer onClick first and skips the toggle only if it called `preventDefault()` (`composeEventHandlers`), so the controller must check `event.defaultPrevented` before toggling.
- `as_child:` is NOT offered: see Deviations (shadcn always passes the Thumb as the Root's only child, so Radix Slot would merge the switch onto the Thumb span).
- `ref` has no equivalent.

## Structure

Server-rendered DOM (DOM order: button, then the optional bubble input as a following sibling; switch.mjs:149-164 renders a Fragment):

```html
<button type="button" role="switch" aria-checked="false" data-state="unchecked" value="on"
        data-slot="switch" data-size="default" class="<Root classes>" data-controller="shadcn--switch" ...>
  <span data-state="unchecked" data-slot="switch-thumb" class="<Thumb classes>"></span>
</button>
<input type="checkbox" aria-hidden="true" tabindex="-1" value="on"
       style="position: absolute; pointer-events: none; opacity: 0; margin: 0px; transform: translateX(-100%);">
```

Part `Switch` (Root, `data-slot="switch"`), switch.mjs:97-119 + switch.tsx:
- tag `button`, `type="button"`, `role="switch"`, `aria-checked="true|false"` (always present, boolean stringified by React), `aria-required` only when `required:` is non-nil, `data-state="checked|unchecked"` (switch.mjs:270-272 `getState`), `data-disabled=""` and `disabled=""` only when disabled, `value="on"` (or `value:`), `data-slot="switch"`, `data-size="default|sm"`, then caller attrs (they win over Radix's, switch.mjs:108 spreads `switchProps` after them; `id`, `aria-*`, `data-*`).
- Classes, verbatim from switch.tsx: `peer group/switch inline-flex shrink-0 items-center rounded-full border border-transparent shadow-xs transition-all outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 data-[size=default]:h-[1.15rem] data-[size=default]:w-8 data-[size=sm]:h-3.5 data-[size=sm]:w-6 data-[state=checked]:bg-primary data-[state=unchecked]:bg-input dark:data-[state=unchecked]:bg-input/80`, then `class:` through `cn`.

Thumb (`data-slot="switch-thumb"`), switch.mjs:174-182:
- tag `span`, `data-state` mirrors the Root, `data-disabled=""` when disabled, `data-slot="switch-thumb"`, no other attributes, no children.
- Classes, verbatim (no caller merge, shadcn passes no className through): `pointer-events-none block rounded-full bg-background ring-0 transition-transform group-data-[size=default]/switch:size-4 group-data-[size=sm]/switch:size-3 data-[state=checked]:translate-x-[calc(100%-2px)] data-[state=unchecked]:translate-x-0 dark:data-[state=checked]:bg-primary-foreground dark:data-[state=unchecked]:bg-foreground`.

Bubble input (no data-slot; Radix `SwitchBubbleInput`, switch.mjs:186-264):
- `input type="checkbox" aria-hidden="true" tabindex="-1"`, `checked=""` attribute when the initial state is checked (React `defaultChecked` reflects to the content attribute, switch.mjs:236), `required=""`, `disabled=""`, `name`, `value`, `form` when given. Style in Radix order: `width`/`height` (only once measured, see Behavior), then `position: absolute; pointer-events: none; opacity: 0; margin: 0px; transform: translateX(-100%)` (switch.mjs:250-261).
- Rendered iff it is a form control: `!!form || !!control.closest("form")`; before the control is mounted Radix assumes `true` (switch.mjs:45-48, "so that events bubble to forms without JS (SSR)"). Port: the server ALWAYS renders it (identical to Radix SSR, keeps no-JS form submission); the controller removes it in `connect()` when the button has no `form:` and no `closest("form")`. Post-connect DOM therefore equals the React DOM in both cases.

Server vs Stimulus: the server renders every attribute above for the initial state. Stimulus (`shadcn--switch`, host = the button itself) updates `aria-checked`, `data-state` on button and thumb, the bubble input's `checked` property, and the input's width/height. No ids are generated (only a caller `id:`, typically for `<label for>`).

## Behavior

States: `unchecked` <-> `checked`; orthogonal `disabled`. No indeterminate (switch.mjs:270-272 has two states only).

Transitions (switch.mjs:110-117, `onClick` composed after the consumer onClick):
1. On the button's native `click` (unless `event.defaultPrevented`): count a user interaction, toggle (`setChecked(prev => !prev)`).
2. If the bubble input exists and it is a form control: remember whether a consumer already stopped propagation; if not, `event.stopPropagation()` on the button click (the form sees the input's click instead).
3. When `checked` changes (switch.mjs:208-229): set the input's `checked` via the native `HTMLInputElement.prototype` setter (property, not attribute) and dispatch `new Event("click", { bubbles })` on the input, where `bubbles = !(isUserInteraction && consumerStoppedPropagation)`. For non-user changes (form reset, controlled re-render) the input's own click listener stops propagation (`shouldStopClickPropagationRef`, switch.mjs:223, 245-249). An `Event` (not `MouseEvent`) "click" has no activation behavior, so it does not re-toggle the checkbox.
4. Dispatch `shadcn--switch:checked-change` `{ checked }`.
- Controlled (`checked:` given): step 1 computes `!checked` and dispatches the event but the DOM stays on the server-rendered state (useControllableState lines 37-43).

Keyboard: NONE handled by Radix. The Root is a native `<button>`, so Space (on keyup) and Enter (on keydown) both produce a `click` and toggle. The controller must not add key handlers (radix-dom-contract "Switch and Toggle have NO key handler"; confirmed: switch.mjs has no `onKeyDown`). Tab focuses the button (native tab order; disabled buttons are skipped). Focus ring only on `:focus-visible` (Tailwind classes); a mouse click focuses without a visible ring.

Pointer: plain `click` (not `pointerdown`). Disabled buttons receive no click. A `<label for="<id>">` click activates the button (labelable element) and toggles it (switch-demo example).

Form integration:
- Reset: on the associated form's `reset` event (`form:` attribute -> `document.getElementById(form)`, else `button.form`), revert to the state captured at first render (`initialCheckedStateRef`, switch.mjs:88-96). In controlled mode this dispatches `checked-change` with the initial value only if it differs. Listener removed on disconnect.
- Bubble input size: on connect set `{ width: offsetWidth, height: offsetHeight }` of the button (px), then follow a `ResizeObserver` (`box: "border-box"`, `borderBoxSize[0].inlineSize/blockSize`, rAF-debounced) exactly like `@radix-ui/react-use-size` (dist/index.mjs). Cancel rAF and unobserve on disconnect.

Timers: none. Presence: none (thumb movement is the CSS `transition-transform`, root color `transition-all`). No dismissal, no scroll lock, no positioning, no direction handling (Radix Switch does not read `dir`).

Primitives composed: `form_bubble_input` (primitives.md: hidden native input kept in sync for checkbox/switch/radio/select): create/remove decision, native `checked` setter + synthetic click with Radix's bubbles/stop rules, size observation, form reset hook. Nothing else.

Turbo: `disconnect()` removes the reset listener and the ResizeObserver; a cached page restores whatever `data-state` was last rendered, which `connect()` reconciles from the DOM (R4).

## Dependencies

None. Switch renders no other `Components::V2` component and no icon (manifest `icons: []`, `registry_dependencies: []`). Registry examples use `Label` (switch-demo) and `Field*` (field-switch, form-rhf-switch), which are not dependencies of `switch`; their scenarios use a raw `_label` / neutral `_div` / `_form` instead (harness requirement: the raw `_label` node passes `htmlFor` as the `for` attribute on both sides; the runner ignores `for` values but the click-through must work).

## Deviations

One, API only (no DOM or class difference):

- `as_child:` is not supported on `Components::V2::Switch`. Reason: Radix Root is a `Primitive.button` that accepts `asChild`, but shadcn's `Switch` always renders `SwitchPrimitive.Thumb` as the Root's only child, so with `asChild` Radix `Slot` would merge every switch attribute onto the Thumb `span` and render no button, which is not a usable control; no registry example uses it. Entry written to `gems/chadcn/dev/port/deviations/switch.json`:

```json
{ "reason": "shadcn Switch always passes SwitchPrimitive.Thumb as the Root's only child, so Radix asChild would merge the switch onto the thumb span; as_child is therefore not offered", "allow_tokens": [], "allow_missing_tokens": [], "api": ["Switch: as_child not supported"] }
```
