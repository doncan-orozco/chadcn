# Carousel

Oracle: `dev/port/oracle/src/carousel.tsx` (manifest `source_sha` 70ba30941a3adb44, tier `third_party`, cited as `tsx:<line>`), a thin
React wrapper around `embla-carousel-react` 8.6.0 -> `embla-carousel` 8.6.0 (`dev/react-shadcn-catalog/node_modules/embla-carousel/esm/embla-carousel.esm.js`,
cited as `embla:<line>`; the React hook `embla-carousel-react/esm/embla-carousel-react.esm.js` only creates the instance on the
viewport node, re-inits on option/plugin changes and destroys on unmount). Registry examples fetched online
(`https://ui.shadcn.com/r/styles/new-york-v4/carousel-{demo,size,spacing,orientation,api,plugin}.json`). No Radix primitive.

Exports: `CarouselApi` (type only), `Carousel`, `CarouselContent`, `CarouselItem`, `CarouselPrevious`, `CarouselNext`. The hook
`useCarousel` (lowercase, not exported) has no Ruby class: its context is the Phlex render context of the root (see API).

## API

### `Carousel` -> `Chadcn::Carousel`

```ruby
Chadcn::Carousel.new(
  orientation: "horizontal", # "horizontal" | "vertical" (tsx:46); strings or symbols; anything else raises ArgumentError
  opts: nil,                 # Hash of embla options (tsx:47, 54-58), see below; nil == {}
  class: nil,                # cn("relative", class) (tsx:123)
  **attrs                    # id, dir, aria: {}, data: {}, "aria-label":, style: ... rendered on the root div after the defaults (tsx:127)
) { |carousel| children }    # yields self (generated DX helpers)
```

- `opts:` keys are accepted as symbols or strings, snake_case or camelCase (`start_index:` == `startIndex`); they are serialized
  camelCase into `data-chadcn--carousel-opts-value` (JSON). The scenario trees pass React's camelCase object unchanged. Supported
  keys and embla defaults (embla:1426-1447): `align` (`"center"`; `"start" | "center" | "end"`), `containScroll` (`"trimSnaps"`;
  `"trimSnaps" | "keepSnaps" | false`), `direction` (`"ltr"`; `"ltr" | "rtl"`), `slidesToScroll` (`1`; Integer or `"auto"`),
  `loop` (`false`), `dragFree` (`false`), `dragThreshold` (`10`), `skipSnaps` (`false`), `duration` (`25`), `startIndex` (`0`),
  `inViewThreshold` (`0`; number or array), `active` (`true`), `watchDrag`, `watchResize`, `watchSlides`, `watchFocus` (`true`;
  booleans only), `breakpoints` (`{}`; media query String -> Hash of the same options, merged when the query matches,
  embla:1449-1468), `container` / `slides` (`null`; CSS selector Strings, embla:1516-1525). Enum values outside the lists raise
  `ArgumentError` (TS unions). Unknown keys are serialized and ignored by the controller, like embla ignores them.
- Changing the `orientation` or `opts` value of a rendered root (Stimulus value change) re-initializes the engine with the new
  axis/options (embla-carousel-react re-inits on option change); the server-rendered part classes (`-ml-4`/`flex-col`, `pl-4`/`pt-4`,
  the arrow placement) belong to the Ruby render and do NOT change, so switching `orientation` at runtime is only correct when the
  markup is rendered again.
- `axis` is always derived from `orientation` (`"horizontal"` -> `"x"`, else `"y"`, tsx:57, written after `...opts`, so an `axis`
  in `opts` is overridden). Scenario `opts-axis-ignored__orientation-wins`.
- `plugins:` and `set_api:` (React-only JS values, tsx:48-49) ARE keyword arguments, declared only so that a non-nil value raises
  `ArgumentError` naming the JS API below (deviation); `nil` is accepted and ignored. They are never rendered as attributes.
- Not forwarded: `orientation`, `opts` (tsx:45-53 destructure them). The root has NO `data-orientation`/`aria-orientation`.
- JS API (the `setApi` / `CarouselApi` equivalent, deviation): the controller exposes `api` (an embla-shaped object, see Behavior)
  and dispatches, on the root, bubbling:
  - `chadcn--carousel:api` with `detail: { api }` every time an engine is built (connect, an `opts`/`orientation` value change, and
    the restore after a Turbo cache snapshot; tsx:91-94 calls `setApi(api)` in an effect, which also runs again when the api changes);
  - `chadcn--carousel:select` with `detail: { index, previousIndex }` (embla `select`, embla:871);
  - `chadcn--carousel:reinit` with `detail: { index }` (embla `reInit`, embla:1564);
  - `chadcn--carousel:settle` with `detail: { index }` (embla `settle`, embla:1330).
  Every other embla event (`init`, `scroll`, `resize`, `slidesChanged`, `slidesInView`, `pointerDown`, `pointerUp`,
  `slideFocusStart`, `slideFocus`, `destroy`) is available through `api.on(name, cb)` / `api.off`.
- `as_child:` is not supported (the React root is a plain `div` with no `asChild`).

### `CarouselContent` -> `Chadcn::Carousel::Content`

```ruby
Chadcn::Carousel::Content.new(class: nil, **attrs) { items }
```

- Renders TWO elements (tsx:135-153): the viewport `div.overflow-hidden[data-slot=carousel-content]` that takes NO caller
  attributes (only `ref`), and inside it the container `div` that receives `class:` (`cn("flex", horizontal ? "-ml-4" : "-mt-4 flex-col", class)`, tsx:145-149)
  and all `**attrs` (tsx:150). The block renders inside the container. `className="-ml-1"` (spacing example) therefore merges on
  the inner div (`-ml-4` dropped by tailwind_merge).
- Orientation comes from the enclosing `Chadcn::Carousel` (render context, like `useCarousel`); rendered outside a Carousel it
  raises `ArgumentError` ("useCarousel must be used within a <Carousel />", tsx:37-41).

### `CarouselItem` -> `Chadcn::Carousel::Item`

```ruby
Chadcn::Carousel::Item.new(class: nil, **attrs) { slide content }
```

- `div[role=group][aria-roledescription=slide][data-slot=carousel-item]`, class `cn("min-w-0 shrink-0 grow-0 basis-full", horizontal ? "pl-4" : "pt-4", class)`
  (tsx:156-171); `**attrs` after the defaults (tsx:169), so a caller `role:`/`aria-roledescription` wins. Same context rule.

### `CarouselPrevious` / `CarouselNext` -> `Chadcn::Carousel::Previous` / `Chadcn::Carousel::Next`

```ruby
Chadcn::Carousel::Previous.new(variant: "outline", size: "icon", label: "Previous slide", class: nil, **attrs)
Chadcn::Carousel::Next.new(variant: "outline", size: "icon", label: "Next slide", class: nil, **attrs)
```

- Render `Chadcn::Button.new(variant:, size:, ...)` (tsx:182-200, 212-230) with `data-slot="carousel-previous"` /
  `"carousel-next"` (overrides Button's `data-slot="button"`; Button's `data-variant` / `data-size` stay), class
  `cn(buttonVariants({variant, size}), "absolute size-8 rounded-full", orientation classes, class)`:
  - Previous horizontal `top-1/2 -left-12 -translate-y-1/2`, vertical `-top-12 left-1/2 -translate-x-1/2 rotate-90` (tsx:189-191);
  - Next horizontal `top-1/2 -right-12 -translate-y-1/2`, vertical `-bottom-12 left-1/2 -translate-x-1/2 rotate-90` (tsx:219-221).
  `size-8` beats the size cva (`size-9` for `icon`), `rounded-full` beats `rounded-md`.
- `variant:` / `size:` accept every Button option as string or symbol (`size: :icon_lg` == `"icon-lg"`).
- Content is fixed: `Icon("arrow-left")` + `span.sr-only "Previous slide"` / `Icon("arrow-right")` + `span.sr-only "Next slide"`
  (tsx:198-199, 228-229); the sr-only text is the `label:` kwarg (design-system R13: the default string is a kwarg, the DOM is
  unchanged by default). A block is ignored, like React (explicit JSX children win over `props.children`). `as_child:` is not
  supported (Radix Slot would receive two children and throw).
- `disabled:` in `**attrs`: React spreads `{...props}` after `disabled={!canScrollX}` (tsx:194-196), so a caller value (true OR
  false) is final: it is rendered and the controller never touches it (scenarios `next__disabled-prop`,
  `previous__disabled-false-prop`). `nil` == not given.
- Click: `scrollPrev` / `scrollNext` (tsx:195, 225). A caller `data: { action: }` is ADDED to the controller's action (React's
  `onClick` would replace it; deviation).

## Structure

Server render (horizontal, 2 items):

```html
<div class="relative w-full max-w-xs" role="region" aria-roledescription="carousel" data-slot="carousel"
     data-controller="chadcn--carousel" data-action="keydown->chadcn--carousel#keydown:capture"
     data-chadcn--carousel-orientation-value="horizontal" data-chadcn--carousel-opts-value="{}">
  <div class="overflow-hidden" data-slot="carousel-content" data-chadcn--carousel-target="viewport">
    <div class="flex -ml-4">
      <div role="group" aria-roledescription="slide" data-slot="carousel-item" class="min-w-0 shrink-0 grow-0 basis-full pl-4">...</div>
      <div role="group" aria-roledescription="slide" data-slot="carousel-item" class="min-w-0 shrink-0 grow-0 basis-full pl-4">...</div>
    </div>
  </div>
  <button data-slot="carousel-previous" data-variant="outline" data-size="icon" class="... absolute size-8 rounded-full top-1/2 -left-12 -translate-y-1/2"
          disabled="" data-chadcn--carousel-target="previous" data-action="click->chadcn--carousel#scrollPrev">
    <svg class="lucide lucide-arrow-left" aria-hidden="true">...</svg><span class="sr-only">Previous slide</span>
  </button>
  <button data-slot="carousel-next" data-variant="outline" data-size="icon" class="... absolute size-8 rounded-full top-1/2 -right-12 -translate-y-1/2"
          disabled="" data-chadcn--carousel-target="next" data-action="click->chadcn--carousel#scrollNext">
    <svg class="lucide lucide-arrow-right" aria-hidden="true">...</svg><span class="sr-only">Next slide</span>
  </button>
</div>
```

- DOM order is the caller's order (Content, Previous, Next in every example). No ids, no `aria-controls`, no `data-state`, no
  `data-orientation` anywhere (the oracle renders none).
- Server state: both buttons `disabled=""` (React's first render: `canScrollPrev`/`canScrollNext` start `false`, tsx:61-62). On
  connect the controller builds the engine and reconciles each button whose `disabled` the caller did not set
  (`disabled = !api.canScrollPrev()` / `!api.canScrollNext()`, tsx:64-68, 96-100), again on every `select` and `reInit`. A button
  whose `disabled:` the caller set carries `data-chadcn--carousel-locked="true"` (ignored by the gate) and is never touched by the
  controller (a string-key `"disabled"` locks like `:disabled`). Without a Content part there is no engine and both buttons stay
  `disabled`. An empty container (Content with no slides) still builds an engine with no snaps, so both buttons are `disabled`;
  `watchSlides` re-initializes the engine when slides are appended later.
- Stimulus-owned DOM (embla parity, compared through the scenario `observe` selector `[data-slot=carousel-content] > div`):
  - the container gets `style.transform = "translate3d(<x>px,0px,0px)"` (vertical `translate3d(0px,<y>px,0px)`) on activation and
    on every rendered frame, value rounded to two decimals and skipped when unchanged (embla:954-985, 1547); not set when
    `active: false`; removed on destroy/reInit (`clear`, the `style` attribute dropped when empty, embla:975-979);
  - with `loop`, each slide that is a loop point gets its own `style.transform` (`translate3d(<contentSize or -contentSize or 0>px,...)`,
    embla:988-1067; set even when 0, so the computed transform is the identity matrix, not `none`);
  - the viewport's `scrollLeft` is reset to 0 on slide focus (embla:903).
- The targets, values and actions (`data-chadcn--carousel-*`, `data-action`, `data-controller`) are ignored by the gate.

## Behavior

States are embla's engine state: the selected snap index, the location (current translate), the target, and per-snap
`canScrollPrev`/`canScrollNext`. Primitives composed: none of the shared primitives apply (no overlay, focus scope, roving
focus, positioning or presence). The engine (measurements, snaps, scroll body, drag, loop) is component code owned by the
carousel controller (`app/javascript/controllers/chadcn/carousel_controller.js`).

### Measurements and snaps (embla:1235-1290)
- `root` = the viewport (carousel-content), `container` = `opts.container` selector or the viewport's first child, `slides` =
  `opts.slides` selector or the container's children (embla:1516-1525). Rects use `offsetLeft/Top/Width/Height` (NodeRects, embla:447-469),
  so CSS transforms do not affect them.
- `viewSize` = the CONTAINER's width (height when vertical), i.e. including the `-ml-4`/`-mt-4` overhang. Alignment
  (embla:64-87): `start` 0, `center` `(viewSize - size) / 2`, `end` `viewSize - size`.
- Slide sizes, start/end gaps (`margin-<endEdge>` of the last slide) (embla:1158-1195); groups from `slidesToScroll` (number:
  chunks; `"auto"`: as many slides as fit in `viewSize + 2px`, embla:1197-1233); `snaps` = `-(slide.start - container.start)`
  per group, `snapsAligned` = snap + alignment (embla:728-753); `contentSize` = `-last(snaps) + last(sizeWithGap)`.
- `containScroll` (embla:632-677): bounds `[-contentSize + viewSize, 0]`; `trimSnaps` clamps every snap into the bounds (first
  snap = max, last = min, within 1px snapped to the bound) and drops duplicates at both ends; `keepSnaps` keeps the clamped
  duplicates; `false` uses the raw aligned snaps (scrolling past the end shows empty space). Content not larger than
  `viewSize + 2` has a single snap. With `loop` snaps are not contained.
- Limit: `[last snap, first snap]`, with loop `[first - contentSize, first]` (embla:679-687).
- RTL (`direction: "rtl"`, horizontal only): start edge `right`, every distance multiplied by -1 (embla:176-211). shadcn does not
  read `dir`; the caller sets `dir="rtl"` on the root and `opts.direction` (scenarios `dir-rtl__*`).

### Scrolling (embla:529-596, 789-888, 1586-1605)
- `scrollNext()` / `scrollPrev()`: target index = `index +/- 1`, constrained to `[0, lastSnap]` (or wrapped with `loop`,
  Counter embla:245-274), direction `-1` / `1` for the loop shortcut; base friction 0.68, duration `opts.duration` (25).
  `canScrollNext()` = `index + 1` (constrained/wrapped) differs from the current index; same for prev. With `loop` and more than
  one snap both are always true.
- Selecting a different index emits `select` immediately (before the animation), which is when the buttons' `disabled` updates.
- Animation: fixed 1000/60 ms steps on `requestAnimationFrame` (embla:116-170); per step `velocity += (target - location) / duration;
  velocity *= friction; location += velocity`; render interpolates by the leftover alpha and writes the transform; stops and
  emits `settle` when `|target - offsetLocation| < 0.001` (and within bounds unless loop), emits `scroll` while moving
  (embla:1306-1332). `duration: 0` (jump) renders in the same call. Visibility `hidden` resets the clock.
- Edge pull-back (no loop, embla:598-630): while the target is beyond the limit, it is pulled back by
  `clamp(distToEdge / 50%view, 0.1, 0.99)`; released (not dragging) within 10% view it snaps to the limit with duration 25.
- Loop (embla:689-711, 988-1067, 1554): when the location passes `limit + 0.1` the location, offset, previous and target
  vectors all shift by `contentSize`; slides that fill the gaps at the start/end are translated by `+/-contentSize` (or 0)
  depending on the location versus their loop point. If the slides cannot fill the view, loop is silently turned off
  (`canLoop`, embla:1526-1535) (scenario `opts-loop__too-few-slides-falls-back`).

### Keyboard (shadcn, tsx:78-89, 122)
Listener in the CAPTURE phase on the root (`onKeyDownCapture`), so it also fires for keys pressed inside slide content (inputs
included):

| Key | Orientation | Action |
|---|---|---|
| `ArrowLeft` | both | `preventDefault()`, `scrollPrev()` |
| `ArrowRight` | both | `preventDefault()`, `scrollNext()` |
| `ArrowUp` / `ArrowDown` / anything else | both | nothing (not prevented) |

There is NO vertical key mapping in the oracle: a vertical carousel also moves with ArrowLeft/ArrowRight, and ArrowDown is
ignored (scenarios `orientation-vertical__keyboard-arrowright`, `orientation-vertical__keyboard-arrowdown-ignored`). Keys are
handled even when the carousel cannot scroll (prevented, no movement). Enter/Space on a focused button = its click. No roving
focus, no tabindex management.

### Focus (embla SlideFocus, embla:890-952)
- With `watchFocus` (default), a `keydown` listener on `document` records the time of the last `event.code === "Tab"`; a
  capture `focus` listener on each slide, when the focus arrives within 10 ms of that Tab: emits `slideFocusStart`, sets
  `root.scrollLeft = 0`, finds the snap group that contains the slide, jumps there with duration 0 (`scrollTo.index(group, 0)`)
  and emits `slideFocus`. Focus by pointer does not scroll. Scenario `tab-into-slides__scrolls-to-focused`.
- Buttons keep focus when they become disabled or enabled; nothing moves focus.

### Pointer drag (embla DragHandler/DragTracker, embla:276-470)
Listeners on the viewport (`root`), only when `watchDrag` and the container has an `offsetParent` and there are slides
(embla:1555). Mouse and touch events (not pointer events): `mousedown`/`touchstart` start, `mousemove`/`mouseup` on `document`
for a mouse, `touchmove` (non-passive)/`touchend` on the root for touch; `touchcancel`/`contextmenu` end; `dragstart` prevented.
- Down: ignored for non-primary mouse buttons and when the target is `INPUT`, `SELECT` or `TEXTAREA`; target = current location,
  friction 0 / duration 0; emits `pointerDown`.
- Move: touch with 2+ fingers ends the drag; for touch, the first non-cancelable move ends it, and the gesture is kept only if the
  movement along the axis exceeds the cross axis (otherwise the page scrolls); `target += delta` (RTL sign applied), friction
  0.3 duration 0.75, `preventDefault()`; moving more than `dragThreshold` (10 px) suppresses the following `click` (capture
  listener on the root).
- Up: velocity from the samples of the last 170 ms (`force = dx / dt`, a flick needs `|force| > 0.1` and the last move within
  170 ms), boosted x300 (mouse) / x400 (touch) (x500/x600 with `dragFree`); if the force is below
  `clamp(20% of viewSize, 50, 225)` px the carousel settles on the nearest snap of the released position; above it, it goes to
  the next/previous index (half the distance when `skipSnaps` and the target changed); `dragFree` keeps the free distance.
  Speed `25 - 10*factor` (43 with dragFree), friction `0.68 + factor/50`; emits `pointerUp`.
- The scenarios hold the mouse for 300 ms before moving so the release has no flick velocity on both sides (deterministic).

### Resize and slide changes (embla:481-527, 1069-1102, 1556-1565)
- `watchResize`: a `ResizeObserver` (attached on the next animation frame) on the container and each slide; a change of at least
  0.5 px along the axis re-initializes the engine keeping the selected index (`reInit`), then `resize`.
- `watchSlides`: a `MutationObserver` (childList) on the container re-initializes on added/removed slides (Turbo Stream appends
  work), then `slidesChanged`.
- `breakpoints`: a `matchMedia` `change` listener per query re-initializes with the merged options.
- `reInit` clears the transforms, rebuilds the engine at the current index and emits `reInit`; the buttons update.

### API object (`controller.api`, embla:1586-1655)
`canScrollNext()`, `canScrollPrev()`, `scrollNext(jump)`, `scrollPrev(jump)`, `scrollTo(index, jump)`, `selectedScrollSnap()`,
`previousScrollSnap()`, `scrollSnapList()` (progress 0..1 per snap), `scrollProgress()`, `slidesInView()`, `slidesNotInView()`
(IntersectionObserver on the slides with `inViewThreshold`, root = viewport, embla:1104-1156), `slideNodes()`, `rootNode()`,
`containerNode()`, `reInit(options)`, `destroy()`, `on(event, cb)`, `off(event, cb)`, `emit(event)`. `init` is emitted one
`setTimeout(0)` after creation (embla:1664). Inactive (`active: false`): the engine is measured (so `canScrollNext()` may be
true and the Next button enabled) but nothing is listened to or translated and scroll calls are no-ops (embla:1546, 1586-1590).

### Lifecycle
`connect()` = create the engine (embla `activate`); `disconnect()` = embla `destroy` (remove every listener and observer,
cancel the frame, clear the container and slide transforms, emit `destroy`), so a reconnect starts from `startIndex` like a fresh
React mount. No timers survive disconnect. Turbo page cache: on `turbo:before-cache` (primitive `turbo_cache.js`) the engine is
destroyed synchronously, so the snapshot holds the server markup (no inline transforms, both unlocked buttons `disabled`), and it
is built again after the snapshot tick (from `startIndex`); until then `api` is null and scroll calls are no-ops. Changing `opts`/`orientation` values re-inits
(embla-carousel-react re-inits when options change).

## Third-party

- Library replaced: `embla-carousel` 8.6.0 via `embla-carousel-react` 8.6.0 (catalog `package.json` `^8.6.0`). No npm package,
  importmap pin or vendor file is added: the behavior above is re-implemented in the Stimulus controller (maintainer
  constraint, like sonner/command).
- DOM mapping: embla `root` = shadcn `CarouselContent` viewport (`data-slot=carousel-content`, the controller's `viewport` target),
  embla `container` = the inner flex div (no data-slot, found as the viewport's first child, like embla), embla `slides` = `CarouselItem`s. The prev/next buttons and the keyboard handler are shadcn's, not embla's.
- Embla writes no attributes or classes, only inline `transform` on the container (and on loop slides); the port writes the same
  values, which is what the observed container and the slide boxes/computed transforms compare.
- CSS scroll-snap is deliberately NOT used: the viewport is `overflow-hidden` (an oracle class, computed `overflow` is compared),
  so native scrolling/swiping is unavailable anyway; a scroll-snap position aligns the item's border box with the viewport, which
  is 16 px off embla's snap (embla aligns the container-relative offset, and the container overhangs by `-ml-4`); and loop
  needs locations before the first slide, which `scrollLeft` cannot express. Positioning by `transform` on the container
  reproduces embla exactly. No CSS class is added.
- `Autoplay` and other embla plugins (`carousel-plugin` example) are separate npm packages, not in the oracle's dependencies;
  not ported (deviation). The `chadcn--carousel:select` events and `api.scrollNext()` let an application drive autoplay itself.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Carousel` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Carousel::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Carousel::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `carousel.content` | `Carousel::Content` | `CarouselContent` |
| `carousel.item` | `Carousel::Item` | `CarouselItem` |
| `carousel.previous` | `Carousel::Previous` | `CarouselPrevious` |
| `carousel.next` | `Carousel::Next` | `CarouselNext` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Chadcn::Button` (Previous/Next render it with `variant`/`size`, registry dependency `button`).
- `Chadcn::Icon` (`arrow-left`, `arrow-right`).
- `Chadcn::Base` (`merge_attrs`, `cn`, the render context, the generated helpers).
- Scenario trees compose `Card` / `CardContent` (`composes: ["card"]`) only because the registry examples do; Carousel does not
  depend on Card.

## Deviations

`dev/port/deviations/carousel.json`, no token allowance:

1. `plugins` (embla plugin objects, React prop) is not supported; `plugins:` raises ArgumentError. Reason: JS objects have no Ruby
   value and the plugins are separate npm packages.
2. `setApi` / `CarouselApi` become the controller's `api` object plus the `chadcn--carousel:api|select|reinit|settle` events.
   Reason: callbacks cannot be passed from Ruby (api-mapping: events for callbacks). The api omits `internalEngine()` and `plugins()`.
3. `opts` takes JSON values only: the function forms of `align`, `watchDrag`, `watchResize`, `watchSlides`, `watchFocus` and
   element values of `container`/`slides` are not supported (selector strings are).
4. A caller `data-action` on `Carousel::Previous`/`Next` is added to the scroll action instead of replacing it as React's `onClick`
   prop does.

Known parity noise: the scenarios `opts-duration__click-next` and `opts-drag-free__drag` can differ by 0.01px of transform while
the animation settles; this reproduces on the original controller and is a settle-timing flap, not a deviation (the scenarios are
not edited to hide it).

Notes on the scenario trees: the `carousel-api` example's "Slide N of M" caption is React state fed by `setApi`; the tree renders
its initial text statically (the API itself is covered by the controller's JS tests). The `carousel-plugin` example renders
without the Autoplay plugin and the mouse-enter/leave handlers (deviation 1).
