# Decision: a caller's `data-controller` is appended to the component's, never a replacement

Status: decided and implemented by item #202 (phlex-shadcn-adoption-followups); normalization of the caller value on every path added by item #239 (phlex-shadcn-hardening, PR #245). Proof: `test/chadcn/base_merge_attrs_test.rb`. Confirmed by the maintainer on 2026-10-22 (#224): no caller opt-out.

## The bug

`Base#merge_attrs` deep-merged `data:` with the caller winning every key. For `data-controller` that meant a caller passing
`data: { controller: "x" }` to a component that wires its own Stimulus controller replaced it: `Calendar.new(data: { controller: "x" })`
rendered `data-controller="x"`, the `chadcn--calendar` controller never connected and the calendar stayed empty. The same held for
every component that merges its root attrs this way (Sonner toaster, Dialog and the other roots), and for `as_child`: the Slot merge
already unioned the controllers of slot and child, but the child's own `merge_attrs` then overwrote its default with that union.

## Semantic

`data-controller` is a space separated token list. The result is the component's controller names followed by the caller's, split on
whitespace and de-duplicated, joined by one space: `chadcn--calendar` + `x` => `chadcn--calendar x`; `chadcn--x` + `chadcn--x mine`
=> `chadcn--x mine`. A component controller with no caller one is untouched. Every other `data:`/`aria:` key keeps the deep-merge rule
(caller wins), `data-action` keeps its concatenation (defaults first), and `class` keeps going through `cn`.

The caller's value is normalized the same way on every path, whether or not the component has a controller of its own, and on
`as_child`:

- It is flattened: String, Symbol, Array (nested too) and Set (Phlex token lists) all become names.
- Each string is split on whitespace, and the names are de-duplicated, keeping the first occurrence.
- `nil`, `false` and blank entries (`""`, `"  "`) are dropped. `false` is blank (it never becomes the name `"false"`), also inside a list.
- An empty result removes the `data-controller` attribute (a component without a controller of its own renders none) instead of
  emitting `data-controller=""`.
- A caller `nil`, `false` or blank value is not an opt-out: the component's own controller stays, like `data-action`.

Real renders (plain Phlex process, `Chadcn` loaded, class attribute elided):

```
Badge.new(data: { controller: ["a", "b a"] })        => <span data-slot="badge" data-variant="default" data-controller="a b" ...>
Badge.new(data: { controller: Set[:a, "a b"] })      => <span ... data-controller="a b" ...>
Badge.new(data: { controller: "  a   b " })          => <span ... data-controller="a b" ...>
Badge.new(data: { controller: nil })                 => <span data-slot="badge" data-variant="default" ...>   (no attribute)
Badge.new(data: { controller: false })               => same, no attribute
Badge.new(data: { controller: "" })                  => same, no attribute
Badge.new(data: { controller: [nil, false, ""] })    => same, no attribute
Calendar.new(data: { controller: "x" })              => <div lang="en-US" data-slot="calendar" data-controller="chadcn--calendar x" ...>
Calendar.new(data: { controller: ["x", "chadcn--calendar"] }) => data-controller="chadcn--calendar x"
Calendar.new(data: { controller: nil })              => data-controller="chadcn--calendar"
Calendar.new(data: { controller: false })            => data-controller="chadcn--calendar"
Calendar.new(data: { controller: "" })               => data-controller="chadcn--calendar"
Badge.new(as_child: :a, data: { controller: ["a", "b a"] }) => <a data-slot="badge" ... data-controller="a b" ...>
Badge.new(as_child: :a, data: { controller: false })        => <a data-slot="badge" ...>   (no attribute)
```

`as_child` follows the same rule on both targets. Onto a component instance the Slot merge (`slot_merge`) unions the slot's and the
child's tokens (slot first) and the child's own `merge_attrs` then puts its default controller first, followed by that union; onto a bare tag (Symbol or String) there is no component
controller, but the slot's list is still normalized (`normalize_slot_controller`).

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
really wants an inert element can use the plain tag. The maintainer confirmed this on 2026-10-22 (#224); an opt-out (for example `replace_controller:`) would be a new item with its own API, docs and tests.

## Implementation notes

- `merge_attrs` calls a private `merge_controllers`, which returns early (key-presence check) when the caller passed no `controller:` key,
  so the common path allocates nothing new (`bin/bench --check` unchanged). Otherwise it builds the list with `controller_tokens`
  (the recursive `add_controller_tokens` drops nil and false, recurses into Array/Set and calls `to_s.split` on anything else; `controller_tokens` then calls `uniq!`) and writes it
  through `with_controllers`, which returns a copy of `data` with the joined names, or without the key when the list is empty.
- `canonical_attrs` (through `canonical_value`) leaves the `controller` value untouched (no boolean stringification), so `false` reaches the normalizer and is dropped.
- `slot_merge` (component instance) and `normalize_slot_controller` (bare tag) share `controller_tokens`; `normalize_slot_controller` writes through
  `with_controllers`, while `slot_merge` writes the joined names into (or deletes the key from) its own copy of `data`.
- Nothing is written into a hash the caller holds (`with_controllers` copies; covered by frozen-input tests).
- The render cache memoizes class strings only, so it is unaffected.
