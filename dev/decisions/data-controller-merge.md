# Decision: a caller's `data-controller` is appended to the component's, never a replacement

Status: decided and implemented by item #202 (phlex-shadcn-adoption-followups). Proof: `test/phlex/shadcn/base_merge_attrs_test.rb`.

## The bug

`Base#merge_attrs` deep-merged `data:` with the caller winning every key. For `data-controller` that meant a caller passing
`data: { controller: "x" }` to a component that wires its own Stimulus controller replaced it: `Calendar.new(data: { controller: "x" })`
rendered `data-controller="x"`, the `shadcn--calendar` controller never connected and the calendar stayed empty. The same held for
every component that merges its root attrs this way (Sonner toaster, Dialog and the other roots), and for `as_child`: the Slot merge
already unioned the controllers of slot and child, but the child's own `merge_attrs` then overwrote its default with that union.

## Semantic

`data-controller` is a space separated token list. The result is the component's controller names followed by the caller's, split on
whitespace and de-duplicated, joined by one space: `shadcn--calendar` + `x` => `shadcn--calendar x`; `shadcn--x` + `shadcn--x mine`
=> `shadcn--x mine`. A caller controller on a component without one is kept as is, and a component controller with no caller one is
untouched. An explicit `nil` or blank caller value keeps the component's controller (it is not an opt-out), like `data-action`; Array and
Set values (Phlex token lists) and Symbols are accepted and flattened to names. Every other `data:`/`aria:` key keeps the deep-merge rule (caller wins), `data-action` keeps its concatenation (defaults
first), and `class` keeps going through `cn`. The Slot merge (`as_child`) already behaved this way and is now consistent end to end.

## Why append and not replace

- React merges props, but the unit that carries behavior there is the component, not an attribute. A shadcn React component's
  behavior (Radix state, handlers) cannot be removed by a prop you pass: `onClick` passed to a Radix trigger is composed with the
  internal handler (`composeEventHandlers`), and Radix `Slot` `mergeProps` runs both handlers, concatenates `className` and merges
  `style`. Only plain value props (`id`, `title`) are overridden by the caller.
- In this port the Stimulus controller IS that behavior. `data-controller` plays the role of Radix's internal handlers, so it follows
  the composing rule (like `data-action`, which we already concatenated), not the override rule. Replacing it silently disables the
  component, with no error, which no caller intends.
- A caller who adds a controller (analytics, a form helper, a test hook) wants it next to the component's, which is the Stimulus idiom
  (`data-controller="a b"`).
- Order: the component's names first, like `data-action` (defaults first) and the Slot merge, so the output is stable.

Radix also lets a caller cancel an internal handler with `event.preventDefault()` (`composeEventHandlers`); the Stimulus counterpart is a
caller action that calls `preventDefault` before the component's. That, not removal of the controller, is the supported way to intervene.

Not chosen: letting the caller opt out of the component controller. Nothing needs it today, it would add public API, and a caller who
really wants an inert element can use the plain tag.

## Implementation notes

- `merge_attrs` calls a private `merge_controllers`; `slot_merge` shares the `controller_tokens` helper. It returns early (key-presence check)
  when the caller passed no `controller:` key, so the common path allocates nothing new (`bin/bench --check` unchanged).
- It writes into the `data` hash that `canonical_attrs`/`merge_deep` built for this call, never into a hash the caller holds
  (covered by a frozen-input test).
- The render cache memoizes class strings only, so it is unaffected.
