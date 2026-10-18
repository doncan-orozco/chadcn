# Toggle

Oracle: `gems/phlex-shadcn/dev/port/oracle/src/toggle.tsx` (manifest `source_sha` 28ae7d72730890a3, tier `radix_stateful`), wrapping `TogglePrimitive.Root` from `radix-ui` 1.7.0 -> `@radix-ui/react-toggle` 1.1.19 (`gems/phlex-shadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-toggle/dist/index.mjs`, cited as `toggle.mjs:<line>`), state via `@radix-ui/react-use-controllable-state` 1.2.6 (`ucs.mjs:<line>`), handler composition via `@radix-ui/primitive` (`primitive.mjs:<line>`). React 19.

## API

Two exports: `Toggle` (component) and `toggleVariants` (cva function, consumed by toggle-group).

```ruby
Components::V2::Toggle.new(
  variant: nil,            # nil -> cva default "default"; options "default" | "outline" (strings or symbols, shadcn-port R4)
  size: nil,               # nil -> cva default "default"; options "default" | "sm" | "lg"
  pressed: nil,            # controlled: true | false; nil = uncontrolled (ucs.mjs:20 `isControlled = prop !== void 0`)
  default_pressed: false,  # uncontrolled initial value (toggle.mjs:18 `defaultProp: defaultPressed ?? false`)
  disabled: false,         # toggle.mjs:27 + native `disabled` via buttonProps spread
  as_child: false,         # false | tag symbol | V2 component instance (Radix Slot merge, Components::V2::Base#render_as_child)
  class: nil,              # passed into toggleVariants as `className`, i.e. merged last through cn (tailwind_merge), caller wins
  **attrs                  # id, type, aria: {}, data: {}, "aria-label", "aria-invalid", title, ... onto the button (Root)
)
```

- `variant:` / `size:` are destructured in shadcn with no default (`function Toggle({ className, variant, size, ...props })`); cva `defaultVariants: { variant: "default", size: "default" }` applies when `undefined`. Ruby: `nil` -> defaults; `:outline`, `"outline"`, `:sm`, `"sm"`, `:lg`, `"lg"`, `:default`, `"default"` accepted.
- `toggleVariants` -> `Components::V2::Toggle.variants(variant: nil, size: nil, class: nil)` returns the merged class string (cva base + variant + size + class through `cn`), same semantics as calling `toggleVariants({ variant, size, className })`. Used by `ToggleGroup` items later.
- `pressed:` (controlled): the server renders that state; click/Space/Enter does NOT change `data-state`/`aria-pressed`, it only dispatches `shadcn--toggle:pressed-change` with `detail: { pressed: !pressed }` (ucs.mjs:37-43: in controlled mode `onChange(value2)` only when `value2 !== prop`, nothing stored). Callers re-render.
- `default_pressed:` (uncontrolled): the controller owns state after connect.
- Event: `shadcn--toggle:pressed-change`, `detail: { pressed: <Boolean> }`, dispatched from the button after every user toggle (uncontrolled: after the DOM is updated, like useUncontrolledState's effect ucs.mjs:62-67; controlled: instead of updating). Not cancelable (`onPressedChange` is not preventable). Consumer `onClick` -> plain `data: { action: "click->x#y" }`; Radix runs the consumer onClick first and skips the toggle when it called `preventDefault()` (primitive.mjs:6-12 `composeEventHandlers`), so the controller checks `event.defaultPrevented` and must run after caller actions (its `click->shadcn--toggle#toggle` descriptor is appended after the caller's `data-action` tokens).
- `as_child:`: Radix Root is `Primitive.button` (toggle.mjs:22), so `asChild` renders the single child through Slot with `type="button"`, `aria-pressed`, `data-state`, `data-disabled`, `data-slot="toggle"`, the toggle classes and the click handler merged onto it (child props win, class plain-joined slot first; see api-mapping "as_child"). Stimulus `data-controller="shadcn--toggle"` and its action are merged the same way so the child toggles on click.
- `ref` has no equivalent.

## Structure

Single part `Toggle` (`data-slot="toggle"`). Server-rendered DOM, attribute order follows toggle.mjs:23-29 then shadcn's props:

```html
<button type="button" aria-pressed="false" data-state="off"
        data-slot="toggle" class="<toggleVariants classes>"
        data-controller="shadcn--toggle" data-action="click->shadcn--toggle#toggle" ...caller attrs>
  ...children
</button>
```

- tag `button`; `type="button"` (toggle.mjs:24) unless the caller passes `type:` (buttonProps spread after, toggle.mjs:28, caller wins: `api__type-override`).
- `aria-pressed="true|false"` always present (React stringifies the boolean, toggle.mjs:25). No `role` (native button).
- `data-state="on|off"` (toggle.mjs:26).
- `data-disabled=""` only when `disabled` is truthy (toggle.mjs:27), plus native `disabled=""` from the buttonProps spread.
- `data-slot="toggle"` (toggle.tsx), `class` = `toggleVariants({ variant, size, className })` (toggle.tsx).
- Caller attrs (`id`, `aria-*`, `data-*`, `title`) pass through and win (R6, buttonProps spread after the Radix attrs). No ids generated, no hidden input (Toggle is not a form control: no bubble input in toggle.mjs), no sr-only text, no icons rendered by the component (manifest `icons: []`).
- Children: the block (text, `Icon`, any markup) in order.

Classes, verbatim from toggle.tsx `toggleVariants`:
- base: `inline-flex items-center justify-center gap-2 rounded-md text-sm font-medium whitespace-nowrap transition-[color,box-shadow] outline-none hover:bg-muted hover:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 data-[state=on]:bg-accent data-[state=on]:text-accent-foreground dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4`
- variant `default`: `bg-transparent`
- variant `outline`: `border border-input bg-transparent shadow-xs hover:bg-accent hover:text-accent-foreground`
- size `default`: `h-9 min-w-9 px-2`
- size `sm`: `h-8 min-w-8 px-1.5`
- size `lg`: `h-10 min-w-10 px-2.5`
- No `compoundVariants`. The manifest's `class_tokens` lists `default`: that is the cva key picked up by the extractor, not a class; the port must not emit a `default` class.

Server vs Stimulus: the server renders every attribute for the initial state (R4). Stimulus (`shadcn--toggle`, host = the button itself) only flips `aria-pressed` and `data-state` in uncontrolled mode and dispatches the event.

## Behavior

States: `off` <-> `on` (toggle.mjs:26); orthogonal `disabled`. Values: `pressed` (Boolean), `defaultPressed` (Boolean), `disabled` (Boolean).

Transition (toggle.mjs:30-34): on the button's native `click`, after consumer handlers, unless `event.defaultPrevented`: if not disabled, `setPressed(!pressed)`:
- uncontrolled: set `aria-pressed` and `data-state` to the new value, then dispatch `pressed-change { pressed }`.
- controlled (`pressed:` given): dispatch `pressed-change { pressed: !pressed }` and leave the DOM as rendered.
The `disabled` check reads the `disabled` prop (Stimulus value mirrored from the server; a native disabled button receives no click anyway).

Keyboard: NONE handled by Radix (toggle.mjs has no `onKeyDown`). Native `<button>`: Space (activates on keyup) and Enter (on keydown) both produce a `click` and toggle. The controller adds no key handlers. Tab focuses the button in native order; disabled buttons are skipped. Focus ring only on `:focus-visible` (classes); a mouse click focuses without the ring. Inside a `<form>`, `type="button"` means neither click nor Enter submits.

Pointer: plain `click` (not `pointerdown`). `disabled:pointer-events-none` means a disabled toggle never receives hover or click; the runner cannot drive pointer actions at it (Playwright actionability fails on `pointer-events: none`), so disabled pointer behavior is covered by the static disabled scenarios plus `disabled__tab-skipped` / `disabled__on__tab-skipped`.

Timers: none. Presence: none (only `transition-[color,box-shadow]`). No dismissal, scroll lock, positioning, focus scope, roving focus or direction handling (Toggle does not read `dir`; roving focus belongs to ToggleGroup, not Toggle).

Primitives composed: none. (`form_bubble_input` is not needed: react-toggle renders no hidden input.)

Turbo: no listeners outside the element; `disconnect()` has nothing to clean beyond Stimulus' own action binding. A cached page restores the last rendered `data-state`, which `connect()` reconciles into its internal value from the DOM.

## Dependencies

None. Toggle renders no other `Components::V2` component (manifest `registry_dependencies: []`, `icons: []`). Scenarios put lucide icons as children (`<icon:italic>`, `<icon:bold>`, `<icon:bookmark>`, `<icon:underline>`), which the harness renders through `Components::V2::Icon`.

Harness notes (not component deviations):
- `example__toggle-disabled`: the registry example passes `className="h-4 w-4"` to the `Underline` icon; the `<icon:x>` child syntax cannot carry a className, so the scenario uses the bare icon. Both sides render the same tree; the computed size is identical because neither `h-4 w-4` nor the bare lucide class contains `size-` and `[&_svg:not([class*='size-'])]:size-4` applies.
- `example__toggle-demo` uses caller classes not present in toggle.tsx (`data-[state=on]:*:[svg]:fill-blue-500`, ...); the Phlex Tailwind build must scan the scenario files so those utilities exist on both sides.

## Deviations

None. `Toggle` maps 1:1 (as_child included); no `deviations/toggle.json` is written.
