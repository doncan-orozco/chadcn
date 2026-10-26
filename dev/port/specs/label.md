# Label

Oracle: `dev/port/oracle/src/label.tsx` (manifest `source_sha` 344bde38b8531615, tier `radix_stateful`), wrapping `LabelPrimitive.Root` from `radix-ui` 1.7.0 -> `@radix-ui/react-label` 2.1.16 (`dev/react-shadcn-catalog/node_modules/@radix-ui/react-label/dist/index.mjs`, cited as `label.mjs:<line>`), whose element is `Primitive.label` from `@radix-ui/react-primitive` 2.1.11 (`react-primitive/dist/index.mjs`, cited as `primitive.mjs:<line>`). Registry example: `label-demo` (fetched from `https://ui.shadcn.com/r/styles/new-york-v4/label-demo.json`).

## API

One export, one Ruby class, no nested parts.

```ruby
Chadcn::Label.new(
  html_for: nil,     # React `htmlFor` (mechanical camelCase -> snake_case); rendered as the `for` attribute. `for:` through **attrs is accepted too (same output); if both are given, `html_for:` wins.
  as_child: false,   # false | tag symbol | Chadcn component instance (primitive.mjs:32-33, Primitive.label supports asChild via Radix Slot)
  class: nil,        # merged through cn (tailwind_merge) AFTER the base classes, caller wins (label.tsx `cn(base, className)`)
  **attrs            # id, title, form, role, aria: {}, data: {}, aria-*/data-* pass through to the <label>
) { children }
```

- shadcn's `Label` destructures only `className` and `...props` (label.tsx). No variants, no defaults, no cva (manifest `cva: {}`).
- Base class string, verbatim (label.tsx, manifest `class_tokens`): `flex items-center gap-2 text-sm leading-none font-medium select-none group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed peer-disabled:opacity-50`.
- `data-slot="label"` is written BEFORE `{...props}` in label.tsx, so a caller `data: { slot: "x" }` wins. `class` is destructured, so it always goes through `cn`.
- Caller `data-action` descriptors are kept and come FIRST, the component's own `mousedown->chadcn--label#mousedown` LAST (Radix calls `props.onMouseDown` before its own `defaultPrevented` check, label.mjs:19-20); `data-controller` tokens are unioned (caller first, then `chadcn--label`).
- No events are dispatched (Radix Label has no `onXChange`). `ref` has no equivalent.

## Structure

```html
<label data-slot="label" class="flex items-center gap-2 text-sm leading-none font-medium select-none group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed peer-disabled:opacity-50"
       for="terms" data-controller="chadcn--label" data-action="mousedown->chadcn--label#mousedown" ...attrs>
  ...children
</label>
```

Part `Label` (`data-slot="label"`):
- tag `label` (primitive.mjs:19 `"label"` in NODES, label.mjs:12 `Primitive.label`), or the `as_child` element.
- attributes: `data-slot="label"`, `class`, `for` (only when `html_for:`/`for:` is given), caller attrs. No role, no aria-*, no `data-state`, no ids generated (Radix Label adds none, label.mjs:13-22).
- `as_child:` (primitive.mjs:30-33): the `<label>` is replaced by the child; `data-slot`, classes, `for`, attrs and the controller/action are merged with `Chadcn::Base#render_as_child` semantics (class plain-joined slot-then-child, child attrs win, `data-action` child first then slot, `data-controller` unioned). Scenario `as-child-span`.
- DOM order: label > children. Server renders everything; Stimulus sets nothing on the DOM (`data-controller`/`data-action` are ignored by the parity runner, `IGNORED_ATTR` in parity_run.mjs).

State styling is driven entirely by surrounding markup, never by the component:
- `peer-disabled:*` applies when an EARLIER sibling with class `peer` is `:disabled` (scenarios `peer-disabled*`, `peer-enabled`).
- `group-data-[disabled=true]:*` applies when an ancestor with class `group` has `data-disabled="true"` (scenarios `group-disabled*`, `group-disabled-false`).

## Behavior

Source: `label.mjs:16-21` (the only behavior Radix Label adds; it has no state, no effects, no timers, no keyboard handling):

```js
onMouseDown: (event) => {
  const target = event.target;
  if (target.closest("button, input, select, textarea")) return;
  props.onMouseDown?.(event);
  if (!event.defaultPrevented && event.detail > 1) event.preventDefault();
}
```

Stimulus controller `chadcn--label` (host = the label, or the `as_child` element), one action `mousedown->chadcn--label#mousedown`:
1. If `event.target.closest("button, input, select, textarea")` matches, return without doing anything (double-click inside a nested native control keeps its default: text selection inside an input, etc.). Note `closest` also matches ancestors of the label, exactly as in Radix (a Label rendered inside a `<button>` never prevents).
2. Otherwise, if `!event.defaultPrevented && event.detail > 1`, call `event.preventDefault()`: the second (and later) mousedown of a multi-click does not start a text selection and does not move focus. A first click (`detail === 1`) is never prevented.
- No values, no targets, no timers, nothing to clean up beyond the Stimulus-managed action. No primitives composed.
- Keyboard: none. The label is not focusable; `Tab` skips it. Focus moves only through native label activation.
- Pointer / native activation (browser, not Radix): a click on the label activates its labelable control (`for` id or the first labelable descendant): a checkbox toggles, a text input receives focus. Scenarios `example__label-demo`, `for-text-input__click`, `wrapping-checkbox__click`.
- Disabled: no `disabled` prop; disabled appearance comes from `peer-disabled` / `group-data-[disabled=true]` (`pointer-events-none` makes the group-disabled label ignore clicks and hover).
- Dismissal, scroll lock, Presence, positioning, direction: none. `dir="rtl"` only flips the flex row through inheritance (scenario `rtl__icon-text`).

## Dependencies

None (`registry_dependencies: []`, manifest `icons: []`). Scenarios with icons use the harness `<icon:x>` child. The `label-demo` example composes `Checkbox`, which is not a dependency of `label`, so the scenario coverage check rejects its export here; the scenario uses a raw `_input type="checkbox"` with the example's `id` instead (scenario-level substitution on both harnesses, not a component deviation). The full composition belongs to the `checkbox` scenarios.

## Deviations

One API-only deviation, not observable in the DOM or in any scenario:

- React suppresses the caller's `onMouseDown` when the target is inside `button, input, select, textarea` (label.mjs:18-19 returns before calling `props.onMouseDown`). Ruby has no JS callbacks; a caller attaches `data-action="mousedown->..."`, which Stimulus fires as an independent listener regardless of the target. The component's own prevention logic is identical. Entry written to `dev/port/deviations/label.json`:

```json
{
  "reason": "Radix Label skips the caller's onMouseDown when the target is inside button/input/select/textarea (label.mjs:18-19); Ruby callers use data-action listeners, which Stimulus always fires, so that suppression of caller handlers cannot be reproduced. The label's own double-click preventDefault logic is identical.",
  "allow_tokens": [],
  "allow_missing_tokens": [],
  "api": ["Label: caller mousedown data-action is not suppressed for targets inside button/input/select/textarea"]
}
```
