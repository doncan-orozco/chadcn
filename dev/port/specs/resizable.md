# Resizable

Oracle: `dev/port/oracle/src/resizable.tsx` (manifest `source_sha` aaf3ea20e8060c75, tier `third_party`), wrapping `Group`, `Panel` and `Separator` of `react-resizable-panels` 4.14.3 (catalog `package.json` `^4.14.3`, `package-lock.json` resolves 4.14.3). Behavior below is read from that version's `dist/react-resizable-panels.js` (cited `rrp.js:<line>`; minified names in parentheses) and its `dist/react-resizable-panels.d.ts` (`rrp.d.ts:<line>`). This worktree has no `dev/react-shadcn-catalog/node_modules` (run `npm ci` there); the source was read from an identical 4.14.3 install of the same lockfile. React 19.3.0 (client `useId` format verified in `react-dom-client.development.js`: `"_" + prefix + "r_" + counter.toString(32) + "_"`). Registry examples (fetched online from `https://ui.shadcn.com/r/styles/new-york-v4/<name>.json`): `resizable-demo`, `resizable-demo-with-handle`, `resizable-handle`, `resizable-vertical`. The registry item has no `meta.links`.

Exports: `ResizablePanelGroup`, `ResizablePanel`, `ResizableHandle`. There is no `Resizable` export.

## API

Name rule: the root name is `Resizable` (component file name), stripped once from each export. `Chadcn::Resizable` is a renderless namespace root (`Chadcn::Resizable < Chadcn::Base`, `view_template` only yields, emits no element and no `data-slot`), like `Chadcn::Direction`; it exists so the TreeRenderer resolves the three exports to its nested classes. `spec_helpers.rb` derives no helpers because the root is not exported, but `Chadcn::Base` generates the yielded-root helpers `resizable.panel_group`, `resizable.panel` and `resizable.handle` for the nested classes (shadcn-port R16); they have no React counterpart and render the same HTML as the explicit class calls (unit-tested).

### `ResizablePanelGroup` -> `Chadcn::Resizable::PanelGroup`

```ruby
Chadcn::Resizable::PanelGroup.new(
  orientation: "horizontal",          # "horizontal" | "vertical" (strings or symbols), rrp.js:3113
  default_layout: nil,                # Hash{panel id => Numeric percent} | nil, React `defaultLayout` (rrp.js:3105, 3229-3235)
  disabled: false,                    # React `disabled`, rrp.js:3107, 3237
  disable_cursor: false,              # React `disableCursor`, rrp.js:3106, 3242
  resize_preview_mode: "panel",       # "panel" | "separator", rrp.js:3114
  resize_target_minimum_size: { coarse: 20, fine: 10 },  # React `resizeTargetMinimumSize`, rrp.js:3115-3118
  id: nil,                            # String | Integer; default = generated React-style id (see Structure). An explicit id must be one token (non-empty, no whitespace, double quote or backslash, else ArgumentError); `false` is treated as nil.
  class: nil,                         # cn("flex h-full w-full aria-[orientation=vertical]:flex-col", class)
  style: nil,                         # String or Hash; merged where the library merges it (Structure)
  **attrs                             # data:, aria:, role, title, ... rendered on the Group div (rrp.js:3301 `...m`)
) { panels and handles }
```

- Unknown `orientation:` / `resize_preview_mode:` raise `ArgumentError` (TS unions, rrp.d.ts:587, 606).
- `default_layout:` keys are panel ids (strings; symbols accepted and stringified). It is applied only when its key count equals the panel count and every panel id is present (rrp.js:3229-3235 and `Dt`/`Xn` rrp.js:1867-1882); otherwise ignored.
- Callbacks become events dispatched from the Group element (`bubbles: true`, not cancelable; the library callbacks are not preventable):
  - `chadcn--resizable:layout-change`, `detail: { layout }` (React `onLayoutChange`, rrp.js:3125-3127): every layout change, including every pointer move of a drag; skipped when the layout equals the last dispatched one (`ie`, rrp.js:1061-1068).
  - `chadcn--resizable:layout-changed`, `detail: { layout, isUserInteraction, requestedLayout }` (React `onLayoutChanged`, rrp.js:3127-3130, 3261, 3278-3279): after mount (`isUserInteraction: false`), after every change that is not part of an active drag of this group, and once at drag end (`isUserInteraction: true`, rrp.js:1163-1173). Same dedup.
  - `layout` is `{ panelId => percent }` (percent rounded to 3 decimals, `X` rrp.js:751-753).
- `groupRef` (imperative `getLayout`/`setLayout`, rrp.js:1524-1562) and `elementRef`: no Ruby equivalent. The controller exposes `getLayout()` and `setLayout(layout)` as public methods (same semantics as `Ge`, rrp.js:1534-1561) for JS callers.
- `as_child:` is not offered: neither shadcn nor the library supports `asChild` on these parts.

### `ResizablePanel` -> `Chadcn::Resizable::Panel`

```ruby
Chadcn::Resizable::Panel.new(
  default_size: nil,                  # Numeric (pixels) | String ("50%", "50" = percent, "200px", "10rem", "2em", "20vh", "30vw"); rrp.js:3491
  min_size: "0%",                     # rrp.js:3497
  max_size: "100%",                   # rrp.js:3496
  collapsible: false,                 # rrp.js:3490
  collapsed_size: "0%",               # rrp.js:3488
  collapsed_threshold: nil,           # rrp.js:3489 (default: half the distance collapsedSize..minSize)
  disabled: false,                    # rrp.js:3492
  group_resize_behavior: "preserve-relative-size",  # | "preserve-pixel-size", rrp.js:3494
  id: nil,                            # String | Integer; layout key, also `id` and `data-testid`. An explicit id must be one token (non-empty, no whitespace, double quote or backslash, else ArgumentError); `false` is treated as nil. The constraints JSON carries exactly: defaultSize, minSize, maxSize, collapsible, collapsedSize, collapsedThreshold, disabled, groupResizeBehavior, id (the controller reads `id` for the resize event)
  class: nil,                         # goes to the INNER div (rrp.js:3592), verbatim, no cn base (shadcn adds no classes)
  style: nil,                         # goes to the INNER div (rrp.js:3598)
  **attrs                             # rendered on the OUTER div (rrp.js:3575 `...f`)
) { content }
```

- Size props follow the library's interpretation (`Wt`, rrp.js:347-356): a Ruby Integer/Float is pixels; a String is parsed with `parseFloat` and its suffix (`%`, `px`, `rem`, `em`, `vh`, `vw`, none = percent).
- `class:`/`style:` land on the inner div because shadcn's `ResizablePanel` forwards `className` to `Panel`, which applies it to its nested div (rrp.d.ts:776, rrp.js:3589-3606). This is the oracle's DOM, not a port choice.
- Event: `chadcn--resizable:resize` dispatched from the panel's outer div (`bubbles: true`), `detail: { size: { asPercentage, inPixels }, id, prevSize }` (React `onResize`, `Jn` rrp.js:1900-1911: `inPixels` = `offsetWidth` (horizontal) / `offsetHeight` (vertical), `asPercentage` = `X(inPixels / axisSize * 100)`, `prevSize` undefined on the first report). `id` is the caller `id:` or `undefined` when generated (rrp.js:3513 passes the prop `c`).
- `panelRef` (`collapse`, `expand`, `getSize`, `isCollapsed`, `resize`, rrp.js:1463-1494): no Ruby equivalent; the controller exposes `collapse(panelId)`, `expand(panelId)`, `getSize(panelId)`, `isCollapsed(panelId)`, `resize(panelId, size)` with the same semantics (`mt`, rrp.js:1365-1495).

### `ResizableHandle` -> `Chadcn::Resizable::Handle`

```ruby
Chadcn::Resizable::Handle.new(
  with_handle: false,                 # shadcn `withHandle` (renders the grip div)
  disabled: false,                    # rrp.js:3634
  disable_double_click: false,        # rrp.js:3635
  preview: nil,                       # a Phlex component instance (React `preview` ReactNode, rrp.js:3638), used only with resize_preview_mode: "separator"
  id: nil,
  class: nil,                         # cn(<handle classes>, class)
  style: nil,                         # merged where the library merges it (Structure)
  **attrs                             # rendered on the separator div (rrp.js:2280 `...e`)
)
```

- `role` and `tabIndex` are not accepted by the library (rrp.d.ts:42 omits them): `role:`/`tabindex:` in `**attrs` are overwritten by the library values (role and tabindex come after `...e`, rrp.js:2295, 2305).
- No events (the library has no Separator callbacks).
- Block: none. shadcn renders only the optional grip as children.

## Structure

Server-rendered DOM of `PanelGroup.new(class: "h-[200px] w-[401px]") { Panel.new { "One" }; Handle.new(with_handle: true); Panel.new { "Two" } }` after connect (horizontal):

```html
<div data-slot="resizable-panel-group" class="flex h-full w-full aria-[orientation=vertical]:flex-col h-[200px] w-[401px]"
     data-group="true" data-testid="_r_0_" id="_r_0_"
     style="height: 100%; width: 100%; overflow: hidden; display: flex; flex-direction: row; flex-wrap: nowrap; touch-action: pan-y;"
     data-controller="chadcn--resizable">
  <div data-slot="resizable-panel" data-panel="true" data-testid="_r_1_" id="_r_1_"
       style="min-height: 0px; max-height: 100%; height: auto; min-width: 0px; max-width: 100%; width: auto; border: none; border-width: 0px; padding: 0px; margin: 0px; display: flex; flex-basis: 0px; flex-shrink: 1; overflow: visible; flex-grow: 50;">
    <div style="max-height: 100%; max-width: 100%; flex-grow: 1; overflow: auto; touch-action: pan-y;">One</div>
  </div>
  <div data-slot="resizable-handle" class="relative flex w-px ..." role="separator" tabindex="0"
       aria-controls="_r_1_" aria-orientation="vertical" aria-valuemax="100" aria-valuemin="0" aria-valuenow="50"
       data-separator="inactive" data-testid="_r_2_" id="_r_2_"
       style="flex-basis: auto; flex-grow: 0; flex-shrink: 0; touch-action: none;">
    <div class="z-10 flex h-4 w-3 items-center justify-center rounded-xs border bg-border"><svg class="lucide lucide-grip-vertical size-2.5" ...></svg></div>
  </div>
  <div data-slot="resizable-panel" data-panel="true" data-testid="_r_3_" id="_r_3_" style="... flex-grow: 50;">
    <div style="...">Two</div>
  </div>
</div>
```

### Part `ResizablePanelGroup` (`data-slot="resizable-panel-group"`), `mo` rrp.js:3102-3335

- tag `div`. Attribute order of the library: caller attrs (`...m`, which carries shadcn's `data-slot`), `class`, `data-group="true"` (React renders `true` on a `data-*` as `"true"`), `data-testid="<id>"`, `id="<id>"`, `style`.
- No `aria-orientation`, no `data-orientation`, no `data-disabled`: `orientation`, `disabled`, `defaultLayout`, `disableCursor`, `resizePreviewMode`, `resizeTargetMinimumSize` are destructured (rrp.js:3102-3121). shadcn's `aria-[orientation=vertical]:flex-col` therefore never matches unless the caller passes `aria-orientation` (scenario `api__group-aria-orientation-attr`); the vertical layout comes from the inline `flex-direction: column`.
- Classes verbatim from resizable.tsx: `flex h-full w-full aria-[orientation=vertical]:flex-col`, then `class:` through `cn` (tailwind_merge; caller wins).
- `style` in this order (rrp.js:3307-3321): `height: 100%`, `width: 100%`, `overflow: hidden`, `position: relative` ONLY when `resize_preview_mode` is `"separator"`, then the caller `style` (can override height, width, overflow, position), then NOT overridable: `display: flex`, `flex-direction: row|column`, `flex-wrap: nowrap`, `touch-action: pan-y` (horizontal) / `pan-x` (vertical).
- Children: the block, then (only while a separator-mode drag is active) one preview overlay per separator (see Behavior, Preview mode).
- Stimulus wiring (ignored by the runner): `data-controller="chadcn--resizable"`, values `orientation`, `disabled`, `disable-cursor`, `default-layout` (JSON), `resize-preview-mode`, `resize-target-minimum-size` (JSON), all with the library defaults.

### Part `ResizablePanel` (`data-slot="resizable-panel"`), `yo` rrp.js:3485-3611

- OUTER `div`: caller attrs (`...f`, with shadcn's `data-slot`), `data-disabled="true"` only when `disabled:` (rrp.js:3576, `s || void 0`), `data-panel="true"`, `data-testid="<id>"`, `id="<id>"`, `style`. No class. Stimulus: `data-chadcn--resizable-target="panel"` and `data-chadcn--resizable-constraints` (JSON of the raw size props with React names, ignored by the runner).
- OUTER style (rrp.js:3581-3588, `So` rrp.js:3612-3623): `min-height: 0; max-height: 100%; height: auto; min-width: 0; max-width: 100%; width: auto; border: none; border-width: 0; padding: 0; margin: 0; display: flex; flex-basis: 0; flex-shrink: 1; overflow: visible;` then the size entry `E` (rrp.js:3567-3572):
  - layout known (after connect): `flex-grow: <layout[id]>` (`getPanelStyles`, rrp.js:3141-3153; `?? 1` when the id is missing). The number is the layout percent as JS `String(Number)` (`50`, `33.333`, `0`).
  - before layout (server render, identical to React's first render and SSR): with `default_size:` -> `flex-basis: <default_size>` with no flex-grow and no flex-shrink (both overridden by `undefined`); a Numeric renders with `px` (React adds `px` to a numeric `flexBasis`), a String verbatim (a unit-less string such as `"50"` is invalid CSS and ignored by the browser, as in React); without `default_size:` -> `flex-grow: 1`. When the group has `default_layout:` with this panel's id, the server already renders `flex-grow: <default_layout[id]>` (rrp.js:3148-3151).
- INNER `div` (rrp.js:3589-3606): `class` = caller `class:` (attribute omitted when nil), style `max-height: 100%; max-width: 100%; flex-grow: 1; overflow: auto;` then caller `style`, then `touch-action: pan-y` (horizontal group) / `pan-x` (vertical). Children inside. The inner div has no `data-slot`.
- The panel must be a direct DOM child of its group (rrp.d.ts:695); nested groups live inside a panel's inner div.

### Part `ResizableHandle` (`data-slot="resizable-handle"`), `xo` rrp.js:3631-3671 -> `un` rrp.js:2170-2308

- tag `div`. Attributes (rrp.js:2279-2306): caller attrs (`...e`, with shadcn's `data-slot`), `aria-controls="<id of the panel before it>"`, `aria-disabled="true"` only when `disabled:`, `aria-orientation` = the OPPOSITE of the group orientation (`vertical` in a horizontal group, `horizontal` in a vertical group, rrp.js:2197), `aria-valuemax`, `aria-valuemin`, `aria-valuenow` (layout percents of the panel before it, see Behavior; JS number formatting), `class`, `data-separator="<state>"`, `data-testid="<id>"`, `id="<id>"`, `role="separator"`, `style`, `tabindex="0"` (omitted when `disabled:`, rrp.js:2305).
- `aria-controls` and `aria-value*` are absent until the layout is known (the server cannot measure); the controller sets them on connect (rrp.js:2228-2252). Post-connect DOM equals React's.
- `data-separator` (rrp.js:2263-2276): `"disabled"` when `disabled:`; else `"active"` while a drag involving it is active; else `"focus"` while it has DOM focus (any focus, also from pointerdown); else `"hover"` when the pointer is in its hit region; else `"inactive"`. The server renders `"disabled"` or `"inactive"`.
- `style` in this order (rrp.js:2296-2304): `flex-basis: auto`, `cursor: not-allowed` ONLY when `disabled:` and the group is not `disable_cursor:`, the caller `style`, then not overridable: `flex-grow: 0`, `flex-shrink: 0`, `touch-action: none`.
- Classes verbatim from resizable.tsx, then `class:` through `cn`: `relative flex w-px items-center justify-center bg-border after:absolute after:inset-y-0 after:left-1/2 after:w-1 after:-translate-x-1/2 focus-visible:ring-1 focus-visible:ring-ring focus-visible:ring-offset-1 focus-visible:outline-hidden aria-[orientation=horizontal]:h-px aria-[orientation=horizontal]:w-full aria-[orientation=horizontal]:after:left-0 aria-[orientation=horizontal]:after:h-1 aria-[orientation=horizontal]:after:w-full aria-[orientation=horizontal]:after:translate-x-0 aria-[orientation=horizontal]:after:-translate-y-1/2 [&[aria-orientation=horizontal]>div]:rotate-90`.
- `with_handle: true` renders one child (resizable.tsx): `<div class="z-10 flex h-4 w-3 items-center justify-center rounded-xs border bg-border">` containing `Chadcn::Icon("grip-vertical", class: "size-2.5")` (lucide `GripVerticalIcon`, `aria-hidden="true"`). No `data-slot`. Rotated 90 degrees by `[&[aria-orientation=horizontal]>div]:rotate-90` in vertical groups.
- Stimulus: `data-chadcn--resizable-target="handle"`, `data-chadcn--resizable-disable-double-click` when set, `data-action="keydown->chadcn--resizable#keydown focus->chadcn--resizable#focus blur->chadcn--resizable#blur"` (a caller `data-action` is appended; the controller methods delegate to the library keyboard handler and the focus bookkeeping, there are no imperative separator listeners), and (with `preview:`) one inert `<template data-chadcn--resizable-target="preview">` child holding the preview markup, mounted only through `template_mount` (no `data-slot`, no box).

### Ids

The library calls `useId` once per Group, Panel and Separator (`Te`, rrp.js:4-7; rrp.js:3131, 3503, 3642) and uses `` `${idProp ?? useId()}` `` as `id`, `data-testid` and layout key. The runner normalizes `id`/`aria-controls` but compares `data-testid` literally, so the port reproduces React's client format: an auto id is `"_r_#{n.to_s(32)}_"` with `n` a counter starting at 0, incremented in render (DFS pre-order) order for every Group, Panel and Handle without `id:` AND with `id:` (React calls `useId` even when the prop is given, so explicit ids still consume a number). The counter is `next_sequence(SEQUENCE_KEY) - 1` (`Chadcn::Sequence`, key `:shadcn_resizable_sequence`) (per render, or per request with the engine's store). An explicit `id:` is stringified (`String(42)` -> `"42"`).

### Server vs Stimulus

- Server: every element, attribute and class above, the pre-layout panel styles, `data-separator` `inactive`/`disabled`, no `aria-controls`/`aria-value*`.
- Stimulus `chadcn--resizable` (one controller per Group element; panels and handles are its `:scope >` direct children, so a nested group is a separate controller): on connect computes the layout (Behavior, Mount), writes every panel's `flex-grow` style, every handle's `aria-controls`/`aria-value*`, then follows changes. All writes go through `element.style` / `setAttribute`, never class toggling (radix-stimulus R3).

## Behavior

All constants and algorithms are copied from rrp.js; the builder ports these functions literally (same float operations and rounding) because aria values and flex-grow are compared as strings.

### Numbers and comparison

- `X(n) = parseFloat(n.toFixed(3))` (rrp.js:751-753); `Y(a, b, tol = 0) = |X(a) - X(b)| <= tol` (rrp.js:867-869); `ce(a, b)` = 0 when `Y`, else sign (rrp.js:870-872); `ie(layoutA, layoutB)` layout equality through `ce` (rrp.js:1061-1068).

### Constraints (`it`, rrp.js:754-824)

- `axisSize = ke(axis)` = sum of the panels' `offsetWidth` (horizontal) / `offsetHeight` (vertical) (rrp.js:535-540); separators are not included.
- `axisSize === 0` (hidden group): every panel gets `{ collapsedSize: 0, minSize: 0, maxSize: 100, defaultSize: undefined }` and the layout is deferred until a ResizeObserver reports a size (rrp.js:755-765, 2046, 1990-1996).
- Otherwise each size prop is converted with `Ce` (rrp.js:716-750: `%` -> `v / 100 * axisSize`; `px` -> `v`; `rem` -> `v * <html font-size>`; `em` -> `v * <panel element font-size>`; `vh`/`vw` -> `v / 100 * innerHeight/innerWidth`) and to percent `X(px / axisSize * 100)`. Defaults: `collapsedSize` 0, `minSize` 0, `maxSize` 100, `collapsedThreshold`/`defaultSize` undefined.

### Mount (`an`, rrp.js:1971-2097; Group effect rrp.js:3213-3284)

1. Order panels and separators by `offsetLeft` (horizontal) / `offsetTop` (vertical), ties by width/height then document order (`Ne`, rrp.js:545-558).
2. Initial layout `Dt` (rrp.js:1876-1882): the in-memory layout cache for this panel-id list, else `default_layout:` when it names exactly the panels, else `Kn` (rrp.js:1849-1866): panels with `defaultSize` keep `X(defaultSize)`; the rest share `X((100 - sum) / count)` equally.
3. Validate with `ye` (rrp.js:1317-1364): when the sum is not 100 (by `Y`), scale every entry by `100 / sum`; clamp each with `Ee` (overriding disabled); distribute the remainder through `Ee` from the first panel on until it is absorbed.
4. `separatorToItems`: for every separator, the pair `[panel before, panel after]` from `ut` with `includeDisabled` (rrp.js:590-701, 2042-2045).
5. Store the state (`fe`, rrp.js:850-858), write styles/ARIA, dispatch `layout-change` and `layout-changed` (`isUserInteraction: false`) when not deferred (rrp.js:3261).
6. `ResizeObserver` on the group element: on a size change recompute constraints, rescale with `Qn` (rrp.js:1923-1969: `preserve-pixel-size` panels keep their pixels, `X(prevPct / 100 * prevAxis / nextAxis * 100)`, the `preserve-relative-size` panels share the rest proportionally; no-op without a pixel panel), validate with `ye`, and apply unless unchanged (rrp.js:1977-2024). Also observes panels for the `resize` event (`Jn`, rrp.js:1900-1911).
7. Every applied change also records the requested layout in the cache keyed by the panel-id list and, for a collapsible panel that just collapsed, its previous size as the size to expand back to (`ln`, rrp.js:2098-2118).

### Item size validation `Ee` (rrp.js:873-896)

- Disabled panel (and not overridden): keep the previous size.
- Below `minSize`: collapsible -> threshold `t = collapsedThreshold ?? (minSize - collapsedSize) / 2`; if the panel was collapsed, it expands only past `collapsedSize + t`, else it collapses below `minSize - t` (and always when at or below `collapsedSize`); the result snaps to `collapsedSize` or `minSize`. Not collapsible -> `minSize`.
- Then `min(maxSize, size)` and `X`.

### Delta resize `Fe` (rrp.js:897-1060)

`Fe({ delta, initialLayout, itemConstraints, pivotIndices: [before, after], prevLayout, trigger })` with `trigger` `"keyboard"`, `"mouse-or-touch"` (pointer, also used for aria min/max) or `"imperative-api"` (overrides disabled panels):
- keyboard: a collapsed collapsible panel on the growing side expands by at least `minSize - size`; a collapsible panel at `minSize` on the shrinking side collapses fully (`size - collapsedSize`) (rrp.js:915-961).
- pointer: a collapsible panel below `minSize` on the growing side only moves when the delta reaches the threshold, then jumps by `minSize - collapsedSize` (rrp.js:962-977).
- Clamp the delta to what the panels on the growing side can absorb (rrp.js:979-999), shrink panels from the pivot outward with `Ee` until the delta is consumed (cascade into further panels, rrp.js:1000-1020), give the consumed amount to the pivot panel on the other side and push any overflow outward (rrp.js:1023-1054). Return `prevLayout` when nothing changed or when the total is not 100 within 0.1 (rrp.js:1021, 1055-1059).

### Handle ARIA values (`eo`, rrp.js:2131-2169)

For a handle between panels `i` and `i + 1` (the first item of its pair): `aria-valuenow` = `layout[panel i]`; `aria-valuemin` = `layout[panel i]` after `ye(Fe(delta: (collapsible ? collapsedSize : minSize) - now, pivots [i, i+1]))`; `aria-valuemax` = the same with `delta: maxSize - now`. Recomputed after every layout change (rrp.js:2228-2252).

### Keyboard (`Ct`, rrp.js:1599-1663; keydown listener on each handle, rrp.js:2060)

Ignored entirely (no `preventDefault`) when the event is already `defaultPrevented`, the group is `disabled:` or the handle is `disabled:`. Resizes use `we(handle, delta)` (rrp.js:1563-1598): `Fe` with trigger `keyboard` on the current layout, then `ye`; applied with `isUserInteraction: true` when changed.

| Key | Effect |
|---|---|
| `ArrowLeft` / `ArrowRight` | `preventDefault()`; horizontal group only: delta `-5` / `+5` (percent of the panel before the handle) |
| `ArrowUp` / `ArrowDown` | `preventDefault()`; vertical group only: delta `-5` / `+5` |
| `Home` / `End` | `preventDefault()`; delta `-100` / `+100` (clamped by constraints) |
| `Enter` | `preventDefault()`; when the panel before the handle is `collapsible`: collapsed -> expand to its remembered size (else `minSize`); otherwise collapse to `collapsedSize` (rrp.js:1627-1643). Nothing for a non-collapsible panel |
| `F6` / `Shift+F6` | `preventDefault()`; focus the next / previous handle of the same group (wrapping), `focus({ preventScroll: true })` (rrp.js:1644-1657) |

Arrow keys of the other axis still call `preventDefault()` but change nothing. Tab: every non-disabled handle is a tab stop (`tabindex="0"`), disabled handles are skipped; panels are not focusable (their inner `overflow: auto` div becomes a Chrome scroller tab stop only when its content overflows, same in both). Focus ring only on `:focus-visible`.

### Pointer (document listeners, rrp.js:2061-2069; one shared registry for all groups of a document, ref-counted per document like `Le`, rrp.js:1970, 2038-2041)

Listeners: `pointerdown` (capture), `pointermove`, `pointerup` (capture), `pointerleave`, `pointerout`, `pointercancel` (capture), `lostpointercapture` (capture), `contextmenu` (capture), `dblclick` (capture) on the document and `blur` on the window. Global interaction state `{ state: "inactive" | "hover" | "active", hitRegions, cursorFlags, ... }` (`V`, rrp.js:396-452).

- Hit regions (`ut`, rrp.js:590-701; `ot`, rrp.js:126-151): for each pair of adjacent panels, the separator's rect (or, without a separator element between them, the gap between the panels); a rect thinner than the minimum target is grown symmetrically to `resize_target_minimum_size.fine` (10px; `coarse` 20px when `matchMedia("(pointer:coarse)")` matches, `wn` rrp.js:122-125). Regions next to disabled separators (`aria-disabled`) are skipped; regions at or outside the first/last non-disabled panel are skipped; a group with fewer than two enabled panels has none.
- Hit test (`ft`, rrp.js:1301-1316): for every non-disabled group, the region closest to the pointer along the group's axis (`_n`, rrp.js:1180-1202) that contains the pointer; it is kept unless the pointer target sits in a modal `<dialog>` that does not contain the group or a stacking-order check says another element covers the region (`Wn`, rrp.js:1277-1300; `Bn` rrp.js:1206-1236). Several groups can match at once (crossing nested handles resize both).
- `pointermove` while not active (`kt`, rrp.js:1812-1822): hits -> state `hover` with those regions (their handles get `data-separator="hover"`), none -> `inactive`. `pointerout` to an iframe clears hover (rrp.js:1826-1835).
- `pointerdown` (`Et`, rrp.js:1734-1766): ignored when `defaultPrevented` or a mouse button other than the primary; on a hit, focus the first hit handle with `focus({ focusVisible: false, preventScroll: true })` (so `data-separator` would be `focus` but `active` wins and no ring shows), snapshot each hit group's layout, state `active` with `pointerDownAtPoint`, `didPointerMove: false`, then `preventDefault()`.
- `pointermove` while active (`kt`, rrp.js:1786-1811): `buttons === 0` ends the drag (`Je`); otherwise `setPointerCapture(pointerId)` on every hit handle that does not hold it yet, then `dt` (rrp.js:1069-1148): per hit region `delta = (clientX - downX) / axisSize * 100` (vertical: `clientY`), `Fe` with trigger `mouse-or-touch` from the layout at pointerdown, applied when changed (not a user-interaction `layout-changed` yet: the group only dispatches `layout-change` during the drag, rrp.js:3278-3279). `didPointerMove` becomes true once the pointer left the down point.
- `pointerup` (`$t`, rrp.js:1836-1845) / `contextmenu` (`xt`, rrp.js:1177-1179): ignored when `defaultPrevented` (and for non-primary mouse buttons on pointerup); otherwise a last `dt` (commit), state `inactive`, cursor reset, `layout-changed` with `isUserInteraction: true`, and `preventDefault()` on pointerup. When the drag moved, the handles that hold focus are BLURRED (rrp.js:414-422), so after a real drag `data-separator` is `inactive`; after a click without movement the handle keeps focus (`focus`, no ring).
- `pointercancel`, window `blur`, and `lostpointercapture` on a hit handle that no longer holds the capture end the drag the same way (`Je`, rrp.js:1664-1702, 1846-1848).
- `pointerleave` of the document while active runs `dt` without a down point: the delta becomes `-100`/`+100` by the side the pointer left (rrp.js:1091, 1767-1781).
- Double click (`Lt`, rrp.js:1496-1514): for each hit region whose handle is not `disable_double_click:`, the first panel of the pair that has `default_size:` is resized back to it through the imperative `resize` (`Fe` trigger `imperative-api`), then `preventDefault()`. No default size in the pair -> nothing.

### Cursor (`En`/`Ve`, rrp.js:459-534)

While the state is `hover` or `active` the library installs one constructed stylesheet in `document.adoptedStyleSheets` with `*, *:hover {cursor: <c> !important; }` and removes the rule when inactive. `c` (Chromium/Firefox, `vt` rrp.js:455-458 by user agent): `ew-resize` for horizontal groups, `ns-resize` for vertical, `move` for both; during an active drag blocked by constraints the cursor flags give `e-resize`/`w-resize`/`n-resize`/`s-resize` and diagonals (rrp.js:484-496, 1122-1132, 1145). Other browsers: `col-resize`/`row-resize`/`grab`. Groups with `disable_cursor:` do not count. The controller manages the same single adopted sheet per document (shared module state, removed when the last group disconnects).

### Preview mode (`resize_preview_mode: "separator"`)

The group style gains `position: relative`. During an active drag, pointer moves only update a preview layout (`previewLayoutMap`) and the group appends, after its children, one overlay per separator region (`Yn` rrp.js:1703-1733, `lo` rrp.js:3031-3060): `<div aria-hidden="true" data-resize-preview="true" inert style="height; left; pointer-events: none; position: absolute; top; transform: translateX(<offset>px) | translateY(...); width">` containing either the handle's `preview:` markup (wrapped in `ao`, rrp.js:2994-3030, `data-separator-overlay="active|inactive"`), or a deep clone of the handle (`so`, rrp.js:2937-2976: every computed style copied inline, `id` and `data-testid` removed, then `box-sizing: border-box; height: 100%; margin: 0; position: static; transform: none; width: 100%`, inside `<div style="height: 100%; opacity: 0.65; pointer-events: none; width: 100%">`). The clone keeps `data-slot="resizable-handle"`. Overlays exist only for the active separator and for separators with a non-zero offset (rrp.js:3085-3087). Release commits the preview layout (rrp.js:1087, 1133, 1664-1676) and removes the overlays.

### Other

- Disabled group: no hit regions, no keyboard resizing; handles stay focusable and render no `aria-disabled` (the group's `disabled` is not forwarded to handles).
- Disabled panel: `Ee` keeps its size for user input (keyboard and pointer); the imperative API overrides it; hit regions skip a group with fewer than two enabled panels.
- No timers, no Presence, no scroll lock, no dismissal, no positioning library. Direction is not read: arrow keys and pointer deltas are physical in RTL too.
- Turbo: `disconnect()` disconnects the ResizeObserver (the handle keydown/focus/blur are Stimulus actions, released by Stimulus), decrements the document registry (removing the document listeners and the cursor sheet with the last group), and drops this group's regions from an active interaction (`Rn`, rrp.js:431-452). `connect()` recomputes from the server props (like React remounting), so a restored snapshot shows the default layout and `data-separator` is re-derived.

Primitives composed: `ids.js` is not needed (ids are server-rendered); `template_mount` for `preview:` markup; `pointer_capture` is NOT used: the library captures on the handle at the first move (not on the pointerdown target) and hit-tests document-wide across groups, which the root-scoped primitive does not model; the hit regions, layout math and the cursor sheet are resizable-specific and live in the controller module (one shared module state for all groups of a document). Not used: focus scope, dismissable layer, presence, positioner, roving focus, direction.

## Third-party

- Oracle library: `react-resizable-panels` 4.14.3 (`Group`, `Panel`, `Separator`), plus `lucide-react` `GripVerticalIcon`.
- Port: NO JavaScript library (no new npm/importmap dependency; the library is React-only). `chadcn--resizable` re-implements the library's DOM contract and the functions cited above (layout math `Kn`/`ye`/`Ee`/`Fe`/`eo`/`Qn`, unit conversion `Wt`/`Ce`, hit regions `ut`/`ot`/`ft`/`_n`/`Wn`, pointer/keyboard handlers, cursor sheet, preview overlays).
- DOM mapping:

| library element | shadcn part | port |
|---|---|---|
| `Group` div `[data-group]` | `ResizablePanelGroup` (`data-slot="resizable-panel-group"`, classes) | `Resizable::PanelGroup` div, controller host |
| `Panel` outer div `[data-panel]` + inner div | `ResizablePanel` (`data-slot` on the outer div, `className` on the inner div) | `Resizable::Panel`, same two divs |
| `Separator` div `[role=separator][data-separator]` | `ResizableHandle` (`data-slot="resizable-handle"`, classes, optional grip div) | `Resizable::Handle` div |
| preview overlay `[data-resize-preview]` | none | appended by the controller during separator-mode drags only |

- Not ported (not reachable through shadcn's exports): `Grid`, `Cell`, `Gridline`, `SeparatorOverlay`, `useDefaultLayout`, `useDefaultGridLayout`, `useGroupRef`/`usePanelRef` hooks.

## Dependencies

- `Chadcn::Icon` (`grip-vertical`, already in `lib/chadcn/icons/catalog.rb`) for `with_handle: true`.
- `Chadcn::Base` (`merge_attrs`, `cn`, option normalization), `Chadcn::Sequence` (auto ids).
- No other `Chadcn` component. Scenario trees use only the three exports plus raw `_div`/`_span` content wrappers taken from the registry examples.

## Deviations

None. The library re-implementation is the tier `third_party` mapping (shadcn-port R14) and produces the oracle DOM after connect; callbacks map to events and refs to "no equivalent" per api-mapping.md; the pre-layout panel style the server renders is the library's own first-render/SSR output. No `deviations/resizable.json` is written.
