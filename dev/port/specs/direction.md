# Direction

Oracle: `dev/port/oracle/src/direction.tsx` (manifest `source_sha` 84ae2ad658207f0e, tier `radix_stateful`), wrapping `Direction.DirectionProvider` / `Direction.useDirection` from `radix-ui` 1.7.0 -> `@radix-ui/react-direction` 1.1.5 (`dev/react-shadcn-catalog/node_modules/@radix-ui/react-direction/dist/index.mjs`, cited below as `dir.mjs:<line>`). Registry item `dev/port/oracle/registry/direction.json` has no `meta.links` and there is no `direction-demo` registry example (`https://ui.shadcn.com/r/styles/new-york-v4/direction-demo.json` returns the site's HTML 404 page), so scenarios are derived from the TSX and the Radix source only.

Exports: `DirectionProvider` (a part) and `useDirection` (a hook, lower-case export, mapped to a Ruby helper per api-mapping "Exceptions (`buttonVariants`, `useSidebar`) map to class methods").

## API

### `DirectionProvider` -> `Components::V2::Direction::Provider`

Name rule: root `Direction`, strip the prefix -> `Direction::Provider` (Radix also exports it as `Provider`, dir.mjs:24).

```ruby
Components::V2::Direction::Provider.new(
  dir: nil,        # "ltr" | "rtl" | :ltr | :rtl | nil   (Radix prop, dir.mjs:14)
  direction: nil   # "ltr" | "rtl" | :ltr | :rtl | nil   (shadcn alias, direction.tsx `direction ?? dir`)
) { children }
```

- Effective value = `direction.nil? ? dir : direction` (direction.tsx: `dir={direction ?? dir}`; JS `??` only falls back on `null`/`undefined`, so `direction:` wins whenever it is given, even when `dir:` is also given). Symbols are normalized to strings (shadcn-port R4).
- Accepted values: the TS type of `dir` is `Direction = "ltr" | "rtl"` (dir.mjs:8-11). Anything else raises `ArgumentError` at construction (Ruby has no type checker; this is not DOM-visible).
- No `class:`, no `as_child:`, no `**attrs`: shadcn destructures only `dir`, `direction`, `children` and Radix's `DirectionProviderProps` is `{ children, dir }`; nothing reaches the DOM because the part renders no element. Unknown kwargs raise `ArgumentError` (Ruby default for keyword-only initializers).
- No events: Radix dispatches none (dir.mjs has no state, no handlers).
- Block = children; rendered unchanged.

### `useDirection` -> `Components::V2::Direction.use_direction`

```ruby
Components::V2::Direction.use_direction(context, local_dir = nil) # => "ltr" | "rtl"

# mixin for consumers (Accordion, Tabs, menus, Select, RadioGroup, ToggleGroup, Slider, ScrollArea,
# NavigationMenu, Menubar, Toolbar...): include Components::V2::Direction::Consumer
use_direction(local_dir = nil) # instance helper, delegates with the component's Phlex `context`
```

Semantics copied from dir.mjs:17-20: `localDir || globalDir || "ltr"`:
- `local_dir` = the consumer's own `dir:` kwarg; it wins when truthy (JS `||`, so `nil` and `""` fall through).
- `globalDir` = the value of the NEAREST enclosing `Direction::Provider` in the render tree (React context, dir.mjs:12,18). A nearer Provider whose value is `nil` shadows an outer one (React context value `undefined`), so the result is `"ltr"`, not the outer provider's value.
- Fallback `"ltr"` (dir.mjs:19 `Direction.LTR`). Radix does NOT read `document.dir`, `<html dir>` or any ancestor `dir` attribute: a consumer outside any Provider is `"ltr"` even inside `<html dir="rtl">`.

Server-side mechanism (React context -> Phlex user context, Phlex 2.4.1 `Phlex::SGML#context`, `phlex/sgml.rb:89`): `Provider#view_template` saves `context[Chadcn::Direction::KEY]`, sets it to the effective value (possibly `nil`), yields, and restores the previous value in an `ensure`, so siblings after the Provider and the outer tree are unaffected and nesting behaves like React context. Content that a consumer later portals (Select/menu content moved to `body`) is rendered inside the same render tree, so it gets the same value, matching React portals preserving context.

## Structure

Part `DirectionProvider` / `Direction::Provider`:
- Renders NO element: `jsx(DirectionContext.Provider, { value: dir, children })` (dir.mjs:15). No tag, no `data-slot` (the oracle has none: manifest `data_slot: null`, `data_slots: []`), no `dir` attribute, no ARIA, no `data-*`, no ids, no wrapper and no `display: contents` host. Output = the block's output byte for byte.
- It does NOT set `dir` on its children; text direction of plain children is unchanged (the `dir` HTML attribute only appears where a consumer part renders it, e.g. Radix Tabs root `dir: direction` react-tabs/dist/index.mjs:55-60, RovingFocusGroup react-roving-focus/dist/index.mjs:81, Menu content react-menu/dist/index.mjs:313/329, Select content react-select/dist/index.mjs:203/493, RadioGroup react-radio-group/dist/index.mjs:280/289, ScrollArea react-scroll-area/dist/index.mjs:73/93, Slider react-slider/dist/index.mjs:241, ToggleGroup react-toggle-group/dist/index.mjs:112-119, NavigationMenu react-navigation-menu/dist/index.mjs:124/163/200, Menubar react-menubar/dist/index.mjs:74/83/125; Accordion passes it to its collection/keyboard logic, react-accordion/dist/index.mjs:127/196). Those consumers emit `dir="<use_direction(dir)>"` server-side themselves; that is their spec's responsibility, not this one's.
- Server vs Stimulus: the server renders everything; Stimulus sets nothing.
- DOM order: children only, in block order.

## Behavior

Tier `radix_stateful` comes from the Radix import classification; dir.mjs has no state, no effects, no event handlers and no timers (dir.mjs:13-20 is the entire implementation).

- States/transitions: none. The value is fixed at render; changing direction means re-rendering (Turbo), exactly like re-rendering React with a new prop.
- Keyboard: none of its own. Tab order is the children's native order (scenarios `focusable-children__tab`, `focusable-children__tab-rtl`). Direction only changes arrow-key semantics inside consumers (e.g. roving focus flips ArrowLeft/ArrowRight in `rtl`), which is verified in each consumer's scenarios.
- Focus on open/close/select, pointer rules, timers, dismissal, scroll lock, Presence, positioning: none.
- No Stimulus controller (`chadcn--direction` does not exist); attaching one would add a `data-controller` the oracle lacks (radix-stimulus R11).
- Client-side consumers: a consumer controller reads the direction from the `dir` attribute that its own server-rendered root carries (which is how the Radix consumer DOM looks), never from `document.dir`/`<html dir>`. Note for the infra wave: `radix-stimulus/references/primitives.md` describes `direction.js` as "reads `dir` from nearest ancestor/`html`"; per dir.mjs:17-20 that would diverge from Radix for a consumer inside `<html dir="rtl">` without a Provider (Radix: `ltr`). `direction.js` must read the consumer element's own `dir` attribute and default to `"ltr"`.
- Primitives composed: none.
- Parity scenarios (`scenarios/direction.json`): the provider renders no DOM, so every scenario observes it through already-ported CONSUMERS that call `useDirection`: `SelectTrigger`/`SelectContent` emit `dir` (react-select/dist/index.mjs:74,124,203,493), `DropdownMenuContent` emits `dir` and flips the sub-menu open key (react-menu/dist/index.mjs:313/329), and a horizontal `Accordion` flips ArrowLeft/ArrowRight (react-accordion/dist/index.mjs:127-128). Covered: provider rtl/ltr via `direction` and `dir`, `direction` beating `dir`, no value -> ltr, nesting (inner overrides outer, outer restored after it, inner without value shadows to ltr), a consumer's local `dir` beating the provider, and the html[dir] negative proofs (`rtl-ancestor-without-provider`, `rtl-ancestor-without-provider-prop`, `focusable-children__tab-rtl-ancestor`: a `dir="rtl"` ancestor without a provider value leaves consumers ltr). This requires every consumer port to resolve its direction with `Components::V2::Direction::Consumer#use_direction(dir)` instead of defaulting its own `dir:` kwarg to `"ltr"`.

## Dependencies

None. `registry_dependencies: []`; renders no other `Components::V2` component and no icon. Consumers (listed in Structure) depend on `Components::V2::Direction::Consumer`.

## Deviations

None. No `deviations/direction.json` is written.
