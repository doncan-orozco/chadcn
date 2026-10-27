# MessageScroller (`Chadcn::MessageScroller`)

Oracle: `dev/port/oracle/src/message-scroller.tsx` (style `new-york-v4`, source_sha `9f7580a8c9a59d28`), manifest `dev/port/oracle/manifest/message-scroller.json`. Tier `third_party`: every part wraps `@shadcn/react/message-scroller` (`MessageScrollerPrimitive.{Provider,Root,Viewport,Content,Item,Button}`), version **0.3.1**, installed at `dev/react-shadcn-catalog/node_modules/@shadcn/react/dist/message-scroller/index.js` (one minified line; citations `ms:<line>` refer to `esbuild dist/message-scroller/index.js --format=esm`, which pretty-prints it to 445 lines without renaming anything) and its `useRender` helper `dist/chunk-HBS6WEDP.js` (cited `ur:<line>`, same treatment). Registry dependency: `button` (DONE). Icon: lucide `ArrowDownIcon`. No cva table (`uses_cva: false` on every part), no Radix primitive. Exports: `MessageScrollerProvider`, `MessageScroller`, `MessageScrollerViewport`, `MessageScrollerContent`, `MessageScrollerItem`, `MessageScrollerButton` and the hooks `useMessageScroller`, `useMessageScrollerScrollable`, `useMessageScrollerVisibility`.

## API

```ruby
Chadcn::MessageScroller::Provider.new(auto_scroll: false, default_scroll_position: "end", scroll_edge_threshold: 8,
  scroll_previous_item_peek: 64, scroll_margin: 0, track_visibility: false, **attrs) { ... }        # MessageScrollerProvider
Chadcn::MessageScroller.new(class: nil, **attrs) { ... }                                           # MessageScroller
Chadcn::MessageScroller::Viewport.new(preserve_scroll_on_prepend: true, class: nil, **attrs) { ... } # MessageScrollerViewport
Chadcn::MessageScroller::Content.new(spacer_class_name: nil, class: nil, **attrs) { ... }          # MessageScrollerContent
Chadcn::MessageScroller::Item.new(message_id: nil, scroll_anchor: false, class: nil, **attrs) { ... } # MessageScrollerItem
Chadcn::MessageScroller::Button.new(direction: "end", variant: "secondary", size: "icon-sm", behavior: "smooth",
  render: nil, class: nil, **attrs) { ... }                                                        # MessageScrollerButton
```

Name mapping (api-mapping.md, strip the root prefix once): `MessageScrollerProvider` -> `MessageScroller::Provider`, `MessageScrollerViewport` -> `MessageScroller::Viewport`, `MessageScrollerContent` -> `MessageScroller::Content`, `MessageScrollerItem` -> `MessageScroller::Item`, `MessageScrollerButton` -> `MessageScroller::Button`; `MessageScroller` is the root class itself. (Unlike Dialog, the root here is the styled frame and renders a `div`; the Provider is a nested part that the docs place OUTSIDE the root, see Structure.)

| part | kwarg | default (source) | accepted values |
|---|---|---|---|
| `Provider` | `auto_scroll:` | `false` (`autoScroll = false`, ms:189, ms:360) | boolean |
| `Provider` | `default_scroll_position:` | `"end"` (ms:189, ms:360) | `start`, `end`, `last-anchor` (`MessageScrollerDefaultScrollPosition`); strings or symbols (`:last_anchor` == `"last-anchor"`, shadcn-port R4); anything else raises `ArgumentError` |
| `Provider` | `scroll_edge_threshold:` | `8` (`_e`, ms:5) | px number |
| `Provider` | `scroll_previous_item_peek:` | `64` (`Be`, ms:5) | px number |
| `Provider` | `scroll_margin:` | `0` (`Fe`, ms:5) | px number |
| `Provider` | `track_visibility:` | `false` (port only, see Deviations) | boolean; replaces "a component subscribed to `useMessageScrollerVisibility`" |
| `MessageScroller` | `class:` | `nil` | merged via `cn` after the base classes |
| `Viewport` | `preserve_scroll_on_prepend:` | `true` (ms:372) | boolean |
| `Content` | `spacer_class_name:` | `nil` (`spacerClassName`, ms:401) | class string for the internal spacer `div` (plain, not merged: the primitive passes it as `className` alone) |
| `Item` | `message_id:` | `nil` (`messageId`, ms:423) | string; rows that are addressable / tracked / preserved need it |
| `Item` | `scroll_anchor:` | `false` (wrapper `scrollAnchor = false`, tsx; primitive ms:423) | boolean |
| `Button` | `direction:` | `"end"` (wrapper tsx; primitive ms:430) | `start`, `end` (`MessageScrollerButtonDirection`); strings or symbols; else `ArgumentError` |
| `Button` | `variant:` | `"secondary"` (wrapper tsx) | every `Chadcn::Button` variant (`Pick<ButtonProps, "variant">`), validated by `Chadcn::Button` |
| `Button` | `size:` | `"icon-sm"` (wrapper tsx) | every `Chadcn::Button` size (`size: :icon_sm` == `"icon-sm"`) |
| `Button` | `behavior:` | `"smooth"` (`behavior = "smooth"`, ms:430) | `smooth`, `auto`, `instant` (`ScrollBehavior`) |
| `Button` | `render:` | `nil` (wrapper: `render ?? <Button variant size />`) | `nil` (renders `Chadcn::Button.new(variant:, size:)`), a `Chadcn` component instance, or a tag symbol (see Deviations) |
| all rendered parts | `**attrs` | `...props` | any HTML attribute (`id`, `role`, `tab_index:`/`tabindex`, `type`, `style`, `data: {}`, `aria: {}` / `"aria-*":`), merged per shadcn-port R6 |

- Blocks = `children`. `Provider`, `MessageScroller`, `Viewport`, `Content` and `Item` yield their block. `Button` yields its block as the button content; with no block it renders the default content (Structure).
- The root `yield self`s (DX helpers are appended by `spec_helpers.rb`).
- No `as_child:` on any part (no `asChild` in the tsx; the Button's `render` is a different prop with useRender semantics, below). No class method (nothing like `messageScrollerVariants` is exported).
- Caller-overridable defaults (the primitive destructures them, so `**attrs` wins, ms:372, ms:399, ms:401, ms:421, ms:430-437): `Viewport` `role` (default `"region"`), `aria-label` (default `"Messages"`), `tabindex` (default `0`); `Content` `role` (default `"log"`), `aria-relevant` (default `"additions"`); `Button` `type` (default `"button"`), `tabindex` (used only while active, else `-1`). A caller `data-scroll-anchor` / `data-message-id` on `Item` overrides the kwarg value (`...n` is spread after them, ms:428).
- `ref`: no equivalent. React event props (`onScroll`, `onWheel`, `onKeyDown`, `onTouchMove` on the viewport, `onClick` on the button) are plain DOM events: the caller adds `data: { action: ... }`; the controller's own handlers run as well (Behavior).

Hooks (api-mapping "hooks -> Stimulus value/helper in the owning controller"); everything is dispatched on / handled by the Provider host (`chadcn--message-scroller`), so controls may live anywhere inside the Provider, also outside the `MessageScroller` frame, as in React:

| React | Port |
|---|---|
| `useMessageScroller().scrollToEnd(options)` | Stimulus action `chadcn--message-scroller#scrollToEnd` (params `behavior`), or the controller method `scrollToEnd({ behavior })` returning a boolean (ms:163) |
| `useMessageScroller().scrollToStart(options)` | action `chadcn--message-scroller#scrollToStart` / method `scrollToStart({ behavior })` (ms:162) |
| `useMessageScroller().scrollToMessage(id, options)` | action `chadcn--message-scroller#scrollToMessage` with params `message-id`, `align` (`start`\|`center`\|`end`\|`nearest`, default `start`), `behavior` (default `auto`), `scroll-margin` (default the Provider's `scroll_margin`) / method `scrollToMessage(id, { align, behavior, scrollMargin })` returning a boolean (ms:165, ms:173) |
| `useMessageScrollerScrollable()` -> `{ start, end }` | `data-scrollable` on the root and viewport (the docs' recommended styling hook) plus the event `chadcn--message-scroller:scrollable-change` with `detail: { start, end }`, dispatched on the host whenever the published state changes (store `setSnapshot` only notifies on change, ms:112-113, equality `rt` ms:127) |
| `useMessageScrollerVisibility()` -> `{ currentAnchorId, visibleMessageIds }` | with `track_visibility: true`, the event `chadcn--message-scroller:visibility-change` with `detail: { currentAnchorId, visibleMessageIds }` (camelCase keys like React), dispatched on change (equality `Lt` ms:130) |

Events: `chadcn--message-scroller:scrollable-change`, `chadcn--message-scroller:visibility-change` (both bubble, not cancelable). No `*-change` event corresponds to a React prop callback (the primitive has none).

## Structure

The parts are server-rendered `div`s/`button` exactly as React emits them; the controller (on the Provider host) only sets the attributes listed as "client" below. No ids are generated.

```html
<div style="display: contents" data-controller="chadcn--message-scroller" ...values>          <!-- Provider host (port only) -->
  <div data-slot="message-scroller" data-pending-scroll="" class="group/message-scroller relative flex size-full min-h-0 flex-col overflow-hidden">
    <div role="region" aria-label="Messages" tabindex="0" data-slot="message-scroller-viewport" data-pending-scroll=""
         class="size-full min-h-0 min-w-0 scroll-fade-b scrollbar-thin scrollbar-gutter-stable overflow-y-auto overscroll-contain contain-content data-autoscrolling:scrollbar-none data-pending-scroll:invisible">
      <div role="log" aria-relevant="additions" data-slot="message-scroller-content" class="flex h-max min-h-full flex-col gap-8">
        <div data-message-id="m1" data-scroll-anchor="true" data-slot="message-scroller-item"
             class="min-w-0 shrink-0 [contain-intrinsic-size:auto_10rem] [content-visibility:auto]">...</div>
        ...
        <div aria-hidden="true" data-message-scroller-spacer="" hidden></div>                 <!-- spacer, always last -->
      </div>
    </div>
    <button type="button" inert tabindex="-1" data-active="false" data-direction="end" data-slot="message-scroller-button"
            data-variant="secondary" data-size="icon-sm" class="...merged, see below...">
      <svg class="lucide lucide-arrow-down" aria-hidden="true" ...></svg>
      <span class="sr-only">Scroll to end</span>
    </button>
  </div>
</div>
```

Per part (attribute sources):

- **`MessageScrollerProvider`** (`ms:360-363`): React renders no element (two context providers). The port renders one `div style="display: contents"` host with the controller and its values only: no `data-slot`, no class, no other attribute (Deviations). `**attrs` merge onto the host (e.g. a caller `data: { action: }` for command buttons). The manifest has no data-slot for it (`data_slot: null`).
- **`MessageScroller`** (`ms:368-371`): `div`, `data-slot="message-scroller"`, classes `group/message-scroller relative flex size-full min-h-0 flex-col overflow-hidden` (tsx). Server: `data-pending-scroll=""` when the Provider's `default_scroll_position` is `end` or `last-anchor` (pending store initial value `t === "end" || t === "last-anchor"`, ms:135); `start` renders none. Client: removes `data-pending-scroll` once the default position is applied or there is nothing to apply (ms:137-142, ms:321-322); writes `data-scrollable` (`"start"`, `"end"`, `"start end"`, attribute removed when neither) and toggles the boolean `data-autoscrolling=""` (ms:192-194).
- **`MessageScrollerViewport`** (`ms:372-399`): `div`, `role="region"`, `aria-label="Messages"`, `tabindex="0"` (all caller-overridable), `data-slot="message-scroller-viewport"`, classes `size-full min-h-0 min-w-0 scroll-fade-b scrollbar-thin scrollbar-gutter-stable overflow-y-auto overscroll-contain contain-content data-autoscrolling:scrollbar-none data-pending-scroll:invisible` (tsx). Same server `data-pending-scroll` rule and the same client `data-scrollable` / `data-autoscrolling` writes as the root (`ce` writes both, ms:194). `preserve_scroll_on_prepend: false` renders no DOM attribute in React; the port may carry it as a `data-chadcn--message-scroller-*` attribute (ignored by the parity snapshot).
- **`MessageScrollerContent`** (`ms:401-421`): `div`, `role="log"`, `aria-relevant="additions"` (caller-overridable), `data-slot="message-scroller-content"`, classes `flex h-max min-h-full flex-col gap-8` (tsx); after the caller's children it ALWAYS renders the spacer `<div aria-hidden="true" data-message-scroller-spacer="" hidden class="{spacer_class_name}">` (no `class` attribute when `spacer_class_name` is nil; no data-slot). Client: the spacer's `hidden`, `style.height` and `style.marginTop` (ms:149-152).
- **`MessageScrollerItem`** (`ms:423-429` + tsx): `div`, `data-message-id` (only when `message_id` is given; React omits `undefined`), `data-scroll-anchor="true"|"false"` (always), `data-slot="message-scroller-item"`, classes `min-w-0 shrink-0 [contain-intrinsic-size:auto_10rem] [content-visibility:auto]`. Nothing client-side.
- **`MessageScrollerButton`** (tsx + `ms:430-437` + useRender `ur:2-23`): the primitive merges `{ data-active, data-direction }` (state attributes, `ur:24-39`; `active` mapped to `"true"`/`"false"`, ms:437) with `{ type, inert, tabIndex, children, onClick }` and the wrapper's props, then clones the `render` element (`<Button variant size />`), whose own props win (`ur:7`). `Button` (`button.tsx`) then renders `data-slot="button" data-variant data-size` overridden by the spread props. Result on a `button`:
  - `type="button"` (caller-overridable), `inert=""` while inactive (absent while active), `tabindex="-1"` while inactive / the caller's `tab_index` (or no attribute) while active, `data-active="false"|"true"`, `data-direction="{direction}"`, `data-slot="message-scroller-button"`, `data-variant="{variant}"`, `data-size="{size}"`.
  - `class` = `Chadcn::Button.variants(variant:, size:)` merged (tailwind-merge, `cn(buttonVariants({variant, size, className}))` in button.tsx) with `cn(<scroller classes>, caller class)`, i.e. render `Chadcn::Button.new(variant:, size:, class: cn(SCROLLER_CLASSES, class))`. Scroller classes (tsx, verbatim): `absolute inset-s-1/2 -translate-x-1/2 border-border bg-background text-foreground transition-[translate,scale,opacity] duration-200 hover:bg-muted hover:text-foreground data-[active=false]:pointer-events-none data-[active=false]:scale-95 data-[active=false]:opacity-0 data-[active=false]:duration-400 data-[active=false]:ease-[cubic-bezier(0.7,0,0.84,0)] data-[active=true]:translate-y-0 data-[active=true]:scale-100 data-[active=true]:opacity-100 data-[active=true]:ease-[cubic-bezier(0.23,1,0.32,1)] data-[direction=end]:bottom-4 data-[direction=end]:data-[active=false]:translate-y-full data-[direction=start]:top-4 data-[direction=start]:data-[active=false]:-translate-y-full rtl:translate-x-1/2 data-[direction=start]:[&_svg]:rotate-180`. Computed with tailwind-merge 3.7.0 (catalog): default `secondary`/`icon-sm` drops `transition-all`, `bg-secondary`, `text-secondary-foreground`, `hover:bg-secondary/80`; `outline`/`icon` and `ghost` drop `transition-all`, `hover:bg-accent`, `hover:text-accent-foreground`; `default`/`sm` drops `gap-2`, `transition-all`, `bg-primary`, `text-primary-foreground`, `hover:bg-primary/90`. Caller conflicts: `class: "size-10 rounded-full"` drops `size-8` and `rounded-md` (`api__button-classname`).
  - Children: the block, else `<ArrowDownIcon />` (`Chadcn::Icon` `arrow-down`, the exact lucide svg with no extra class) followed by `<span class="sr-only">Scroll to end</span>` (`direction: "start"` -> `Scroll to start`; tsx). The primitive's own fallback `<span>Scroll to {direction}</span>` (ms:437) is unreachable through the wrapper.
  - `render:` given -> no `Chadcn::Button`: the instance (or tag) renders with the merged attributes, `class` being the PLAIN join of the scroller `cn(...)` string and the render element's class (`ur:19`, no tailwind-merge), the render element's other props winning (`ur:7`); `variant`/`size` then only feed `data-variant`/`data-size`.

Classes on the other parts merge base then caller `class` through `cn`: `MessageScroller class: "overflow-visible rounded-lg border"` drops `overflow-hidden` (`api__root-classname`); `Viewport class: "overflow-y-scroll px-2"` drops `overflow-y-auto` (`api__viewport-classname`); `Content class: "gap-4 p-4"` drops `gap-8` (`api__content-classname`); `Item class: "shrink rounded-md bg-muted p-2"` drops `shrink-0` (`api__item-classname`).

DOM order is the caller's order; `MessageScroller` contains the viewport then the buttons (the docs put `MessageScrollerButton` after the viewport, inside the root, which is `relative` so the `absolute` button sits on the frame); the Provider normally wraps the root and may also wrap other controls (examples render a footer that reads the hooks outside the frame). Styling hooks the port must keep: `group/message-scroller` on the root, `data-pending-scroll:invisible` and `data-autoscrolling:scrollbar-none` on the viewport, `scroll-fade-b` (`app/assets/tailwind/chadcn/vendor/shadcn-tailwind.css`, same `@utility` as `shadcn/dist/tailwind.css`), `inset-s-1/2` + `rtl:translate-x-1/2` for RTL centering.

## Behavior

Source: `@shadcn/react` 0.3.1 `message-scroller` (React hooks; no Radix). The port re-implements it in ONE Stimulus controller `chadcn--message-scroller` on the Provider host (no JS dependency; see Third-party). Constants (ms:5): `scrollEdgeThreshold` 8, `scrollPreviousItemPeek` 64, `scrollMargin` 0, sub-pixel tolerance `J` = 0.5 px, autoscrolling flag duration 180 ms (`je`), user-scroll keys `ArrowDown ArrowUp End Home PageDown PageUp " "` (`Ge`).

Targets (ignored by the parity snapshot): `root` (`MessageScroller`), `viewport`, `content`, `spacer`, `button` (any number). Items are not targets: the content's element children other than the spacer ARE the rows (`ee`, ms:22-24), whether or not they are `Item`s.

### State

- Published scroll state `{ start, end }` (ms:6-10, `Ne`): `start = viewport.scrollTop > threshold`; `end = contentBottom - scrollTop - clientHeight > threshold`, where `contentBottom` (`Re`, ms:81-88) is the max over rows of `row.bottom - viewport.top + scrollTop + contentPaddingEnd`, at least `paddingStart + paddingEnd` (the spacer is NOT counted, so a spacer never makes `end` true). While the mode is `following-bottom`, `end` is published as `false` (ms:201). Commit (`N`, ms:198-203): update mode, write `data-scrollable` / `data-autoscrolling` on root and viewport, publish to the store (dispatch `scrollable-change` on change, update every button). Scheduled commits are coalesced in one `requestAnimationFrame` (`oe`, ms:203-207).
- Mode (`modeRef`, ms:134): `following-bottom` (initial when `auto_scroll`), `free-scrolling` (initial otherwise), `settling-jump` (after a `scrollToMessage`/element jump), `anchored-to-message` (after anchoring a new turn). Transition at commit (`be`, ms:195-197): if `auto_scroll` and not `end` and the mode is neither `settling-jump` nor `anchored-to-message` -> `following-bottom`; else if `following-bottom` and `end` and the user scrolled up by more than 0.5 px since the last commit and no autoscroll is running -> `free-scrolling`.
- Button active state (ms:431-434): `direction == "start" ? state.start : state.end`. On change: `data-active`, `inert` (present iff inactive), `tabindex` (`-1` iff inactive, else the server-rendered caller value or removed).
- Autoscrolling (`Y`, ms:144-147): set by `scrollToEnd` when it actually moves (> 0.5 px): `data-autoscrolling=""` on root and viewport now, removed 180 ms after the LAST such call (timer reset each time); removal triggers a commit.

### Scroll commands

- `scrollTo(top, { behavior, autoscrolling })` (`V`, ms:153-161): clamp at 0; if within 0.5 px, assign `scrollTop` and commit synchronously; else (autoscrolling flag if asked) `viewport.scrollTo({ top, behavior })` and schedule a commit.
- `scrollToStart({ behavior = "auto" })` (ms:162): spacer to 0, forget the anchored turn, mode `free-scrolling`, scroll to 0, schedule a visibility sync; returns `true` iff the viewport exists.
- `scrollToEnd({ behavior = "auto" })` (ms:163-164): spacer to 0, forget the anchored turn, mode `following-bottom` if `auto_scroll` else `free-scrolling`, scroll to `scrollHeight - clientHeight` with the autoscrolling flag; returns `true` iff the viewport exists. Re-engages follow-output (docs "Following the Live Edge").
- `scrollToElement(el, { align = "start", behavior = "auto", scrollMargin = provider }, { keepPreviousPeek })` (ms:165-169): only for an element inside the content. Target (`$e`, ms:57-69, offsets relative to the viewport's scroll origin, minus the content's padding): `start` -> `top - padStart - margin`; `center` -> centered in the padded box; `end` -> `top - clientHeight + height + padEnd + margin`; `nearest` -> unchanged when fully visible, else the nearer edge. With `keepPreviousPeek` the margin is `scrollMargin + scroll_previous_item_peek`. The spacer gets the height needed for that target to be reachable (`Je`, ms:77-80: `target + clientHeight - contentBottom`, `ceil`, min 0); spacer rules (ms:148-152): `hidden` iff 0, `style.height = "<n>px"`, `style.marginTop = "-<row-gap>px"` while > 0 (row gap of the content, `Ze` ms:100-104, so the spacer adds no extra gap), else `""`. Records the element for prepend preservation; mode `anchored-to-message` (and remembers the element as the anchored turn) with `keepPreviousPeek`, else `settling-jump`.
- `scrollToMessage(id, options)` (ms:173-176): look up the registered row with `data-message-id == id`; found -> mark the default position applied and jump (queue it if the jump failed); not found and no rows yet -> queue it, mark applied, return `true`; else `false`. A queued jump is flushed when that row registers (ms:177-181, ms:306-308, one rAF later, ms:224-227) or on the next content change.

### Lifecycle (connect = React mount)

1. Content change handler (`Le`, ms:240-275), run once on connect and on every `childList` mutation of the content (MutationObserver, ms:405-411; Turbo Stream `append`/`prepend`/`remove` on the content go through it):
   - recount rows; flush a queued `scrollToMessage` first (done if it ran);
   - previous count 0 -> apply the default position (step 2), or with rows and `auto_scroll` scroll to end; else commit + visibility sync;
   - `preserve_scroll_on_prepend` and the previous first row moved to index > 0 (prepend) -> restore: shift `scrollTop` by the remembered visible row's displacement (`ve`, ms:211-216, > 0.5 px only);
   - more rows than before and a `data-scroll-anchor="true"` row among the NEW ones (`Ye`, ms:25-31) -> if `auto_scroll`, mode `following-bottom` and MORE than one new anchor (`qe`, ms:36-40): scroll to end; else anchor that row (`scrollToElement(row, { align: "start" }, { keepPreviousPeek: true })`) and mark it handled (WeakSet);
   - same count and an anchor row never handled (`ze`, ms:32-35) -> anchor it likewise;
   - otherwise `following-bottom` + `auto_scroll` -> scroll to end; else commit + visibility sync;
   - finally remember the first `[data-message-id]` row intersecting the viewport and its offset (`We`/`Z`, ms:48-56, ms:216-224) for prepend preservation.
2. Default position (`ue`, ms:228-240), once per value (reset when `default_scroll_position` changes, ms:190-191, then re-applied), only with rows: `start` -> `scrollToStart({ behavior: "auto" })`; `end` -> `scrollToEnd({ behavior: "auto" })`; `last-anchor` -> last anchor row; none -> end; if `contentBottom - anchorTop <= clientHeight` (the last turn fits) -> end; else `scrollToElement(anchor, { align: "start" }, { keepPreviousPeek: true })`. Then `data-pending-scroll` is removed. After step 1 on connect, if nothing was applied and there are no rows, `data-pending-scroll` is removed too (ms:321-322).
3. `auto_scroll` value (ms:325-331, also on `autoScrollValueChanged`): `auto_scroll`, mode `following-bottom` and rows -> scroll to end; else commit.
4. Resize (ResizeObserver on the viewport, ms:390-398, and on the content, ms:412-421, each coalesced in one rAF; `Ce`, ms:276-287): `following-bottom` + `auto_scroll` -> scroll to end; `anchored-to-message` -> re-anchor the remembered turn (spacer recomputed, ms:170-172), and if `auto_scroll` and the spacer just went from > 0 to 0 -> scroll to end (the reply filled the viewport: follow-output takes over from the anchor); else commit + visibility sync.
5. `disconnect()`: cancel the commit / visibility / pending-scroll rAFs and the 180 ms timer, disconnect the Mutation/Resize/IntersectionObservers (ms:323-324).

### Input

- Viewport `scroll` (ms:378-380, `xe` ms:318-320): synchronous commit, visibility sync, remember the visible row.
- User scroll intent (`Oe`, ms:312-314): `wheel`, `touchmove`, and `keydown` of a key in `Ge` on the viewport; if the mode is `following-bottom`, `anchored-to-message` or `settling-jump` -> forget the anchored turn, mode `free-scrolling`. The native scrolling itself (the focused `tabindex=0` region scrolls with the keys) is the browser's.
- Keyboard: the viewport is the first tab stop (`tabindex="0"`); an inactive button is skipped (`inert`, `tabindex=-1`); an active button is a normal tab stop with the Button focus ring (`focus-visible:*`).
- Button click (ms:434-436): ignored while inactive; caller handlers run first (the port appends its own action after the caller's `data-action` tokens); if `event.defaultPrevented` nothing else happens; else `currentTarget.blur()` (focus leaves the button, goes to `body`) and `scrollToStart`/`scrollToEnd({ behavior })` per `direction` (default `smooth`). Enter/Space on a focused active button click it natively.

### Visibility (only with `track_visibility: true`)

IntersectionObserver rooted at the viewport, `rootMargin: "-(scrollMargin + peek)px 0px 0px 0px"`, thresholds `[0, 0.01, 0.5, 1]`, observing rows with `data-message-id` (ms:288-303); every change schedules one rAF that computes (`Ue`, ms:11-21): `visibleMessageIds` = intersecting ids in document order; `currentAnchorId` = the last anchor row (with id) whose top is at or above `viewport.top + scrollMargin + peek + 0.5` (it stays set after the anchor scrolls above the viewport). Without IntersectionObserver, rectangles are used instead. Dispatch `visibility-change` on change; on `track_visibility` false/disconnect, reset to `{ currentAnchorId: null, visibleMessageIds: [] }` (ms:304-305).

### Not applicable

No dismissal, focus trap, scroll lock, Presence, positioning or portal. The button's show/hide is a CSS transition on `data-active` (200 ms in, 400 ms out), not Presence: the button stays mounted.

### Scenario coverage notes

Parity scenarios cannot append rows (no such step), so streaming/anchoring/prepend/`scrollToMessage`/visibility events are exercised by the browser tests of the controller (`bin/test-js`), each case citing the ms: lines above; the scenarios pin every observable static/initial state (all three opening positions, peek, margin, threshold, `auto_scroll`, short/empty content), the button states and transitions (active/inactive, both directions, hover, click with smooth/auto behavior, keyboard tab/Enter, round trip), user keyboard scrolling of the viewport (Home/End/PageUp/ArrowDown) and the API shape.

## Third-party

- Library: `@shadcn/react` 0.3.1 (`dependencies: ["cn", "@shadcn/react"]` in the registry item; React 19 only, renders through React contexts, refs and `useSyncExternalStore`). It has no DOM/vanilla build, so it cannot be pinned behind a Stimulus controller; per the house rule set by sonner (no third-party JavaScript, behavior re-implemented), the port re-implements its hooks (`st`, `lt`, `nt`, ms:133-332) in `app/javascript/controllers/chadcn/message_scroller_controller.js`. No importmap pin, no vendor file, no npm dependency. The library is MIT; add it to `THIRD_PARTY_NOTICES.md` as the source of the ported algorithm.
- DOM mapping (identical, the library is unstyled): `Provider` -> no element (port: display-contents host); `Root` -> `div` (+ `data-pending-scroll`, `data-scrollable`, `data-autoscrolling`); `Viewport` -> `div role=region aria-label=Messages tabindex=0` (+ same three data attributes); `Content` -> `div role=log aria-relevant=additions` + trailing `div[data-message-scroller-spacer][hidden][aria-hidden=true]`; `Item` -> `div[data-message-id][data-scroll-anchor]`; `Button` -> `useRender` over shadcn's `Button` (`data-active`, `data-direction`, `type`, `inert`, `tabindex`).
- CSS utilities used by the wrapper: `scroll-fade-b` (shadcn `@utility`, already vendored in `app/assets/tailwind/chadcn/vendor/shadcn-tailwind.css`), `scrollbar-thin`, `scrollbar-gutter-stable`, `scrollbar-none`, `contain-content`, `inset-s-1/2` (Tailwind 4.3 built-ins, catalog `tailwindcss` 4.3.3). The host Tailwind must be a release that has them (G2 will show `scrollbarWidth`-type drift otherwise; report, do not replace the tokens).

## Dependencies

- `Chadcn::Button` (DONE): `MessageScroller::Button` renders `Chadcn::Button.new(variant:, size:, class:, **attrs)` (registry dependency `button`); its `data-slot` is overridden to `message-scroller-button` (React spreads the props after `data-slot="button"`).
- `Chadcn::Icon` `arrow-down` (lucide `ArrowDownIcon`) for the default button content.
- `Chadcn::Base` for `cn`, `merge_attrs` and the generated DX helpers.
- No shared primitive is required (no dismiss/focus/positioning); the geometry is specific to this component and stays in its controller.

## Deviations

Recorded in `dev/port/deviations/message-scroller.json` (no class token is added or removed):

1. `MessageScroller::Provider` renders one `<div style="display: contents" data-controller="chadcn--message-scroller">` host (React's Provider renders no element; a server-rendered Stimulus port needs one host that also contains controls outside the frame). No data-slot, classes or layout, so the compared DOM is unchanged.
2. `track_visibility:` on the Provider replaces "a component subscribed to `useMessageScrollerVisibility`" (React starts the IntersectionObserver on the first subscription, ms:356-358; a DOM event listener cannot be detected).
3. `MessageScroller::Button` `render:` takes a `Chadcn` component instance or a tag symbol instead of a React element (merge per useRender, `ur:2-23`).
4. Parts rendered without an enclosing Provider render (no error) so a Turbo Stream can append a lone `MessageScroller::Item` into the content; React throws ("useMessageScroller must be used within a MessageScroller." / "MessageScrollerItem must be used within a MessageScroller.", ms:338-347). `MessageScroller` and `Viewport` rendered outside a Provider omit `data-pending-scroll`.

Scenario-level substitutions (identical on both harnesses, not component deviations): the upstream examples (`apps/v4/examples/radix/message-scroller-{demo,anchoring,animation,commands,group-chat,load-history,opening-position,previous-context,scrollable,streaming,visibility}.tsx`; the `/r/styles/new-york-v4/message-scroller-*.json` endpoints return 404) drive the transcript with `useChat`, `motion`, Tabs/Slider controls and hooks, and compose `Card`, `Message`, `Bubble`, `Marker`, `Tooltip`, `DropdownMenu`, `InputGroup` and `Empty`, which are not registry dependencies of `message-scroller`. Each `example__*` scenario keeps the example's `MessageScroller*` structure and Provider props (`autoScroll`, `defaultScrollPosition`, `scrollMargin={12}`, `scrollPreviousItemPeek={64}`, Content `className` with `p-(--card-spacing)` replaced by `p-6`, since `--card-spacing` is only defined inside a `Card`), the initial transcript text and `scrollAnchor` roles, and replaces the frame by a `_div` (`flex h-140 w-full max-w-sm flex-col overflow-hidden rounded-xl border`) and each message by a plain `_p` (`text-sm whitespace-pre-wrap`). Interactive controls that read the hooks become steps (`commands`: keyboard Home on the viewport; `scrollable`: click the button).
