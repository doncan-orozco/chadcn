# Tabs

Oracle: `gems/chadcn/dev/port/oracle/src/tabs.tsx` (manifest `source_sha` e1df6e2f95ece373, tier `radix_stateful`), wrapping `TabsPrimitive.Root` / `.List` / `.Trigger` / `.Content` from `radix-ui` 1.7.0 -> `@radix-ui/react-tabs` 1.1.22 (`gems/chadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-tabs/dist/index.mjs`, cited `tabs:<line>`), built on `@radix-ui/react-roving-focus` 1.1.20 (`rf:<line>`), `@radix-ui/react-collection` 1.1.16 (`col:<line>`), `@radix-ui/react-presence` 1.1.11 (`pr:<line>`), `@radix-ui/react-direction` 1.1.5, `@radix-ui/react-id` 1.1.4 (`id:<line>`), `@radix-ui/react-use-controllable-state` 1.2.6 (`ucs:<line>`), `@radix-ui/react-slot` 1.4.0 (`slot:<line>`). React 19.3. Examples read live (network): registry `tabs-demo` (the only `tabs-*` item in `r/styles/new-york-v4/registry.json`) and the docs page `ui.shadcn.com/docs/components/radix/tabs.md` (docs demo, Line, Vertical, Disabled, Icons, RTL). Radix docs link: `https://www.radix-ui.com/docs/primitives/components/tabs`.

Exports: `Tabs`, `TabsList`, `TabsTrigger`, `TabsContent` (parts) and `tabsListVariants` (cva, class method).

## API

Name rule: root `Tabs`, strip the prefix. Every part accepts `class:` (merged LAST through `cn`/tailwind_merge, caller wins) and `**attrs` (spread after the Radix attributes, so caller `id`, `role`, `aria-*`, `data-*`, `title`, `dir`, `style` win over Radix's, exactly like `{...props}` after the Radix props, tabs:62, tabs:90, tabs:125, tabs:178). `data:`/`aria:` hashes deep-merge. Strings and symbols are accepted for every option (shadcn-port R4); an unknown option raises `ArgumentError`. `ref` has no equivalent.

### `Tabs` -> `Components::V2::Tabs`

```ruby
Components::V2::Tabs.new(
  value: nil,                    # controlled value (String; symbols/other -> to_s). nil = uncontrolled (ucs:20 isControlled = prop !== undefined)
  default_value: nil,            # uncontrolled initial value; nil -> "" (tabs:44 `defaultValue ?? ""`): no trigger active, every panel hidden
  orientation: "horizontal",     # "horizontal" | "vertical"; shadcn default (tabs.tsx) == Radix default (tabs:35)
  dir: nil,                      # "ltr" | "rtl" | nil; use_direction(dir): dir || nearest Direction::Provider || "ltr" (tabs:40). Never html[dir]
  activation_mode: "automatic",  # "automatic" | "manual" (tabs:17-20, tabs:37)
  as_child: false,               # false | tag symbol | V2 component instance (Primitive.div, tabs:58; Slot merge per api-mapping)
  class: nil,                    # cn("group/tabs flex gap-2 data-[orientation=horizontal]:flex-col", class)
  **attrs
) { list + contents + any other markup }
```

- Controlled (`value:` given): no user action changes the DOM state; every request dispatches the event and the server (or the caller's controller) renders the next state. Uncontrolled: the controller owns the value after connect.
- Event `chadcn--tabs:value-change`, `detail: { value: "<trigger value>" }`, dispatched from the root element, not cancelable (`onValueChange` is not preventable).
  - Uncontrolled: once per actual change, after the DOM update (ucs:63-68 effect, `prevValueRef !== value`); never when the requested value equals the current one.
  - Controlled: once per request whose value differs from the controlled value (ucs:38-41), with NO dedupe across requests. A mouse press on an inactive trigger in automatic mode therefore dispatches TWICE (the explicit `focus()` in the mousedown handler fires the focus-activation request, then the mousedown handler's own request, tabs:127-130 + tabs:143-147); a press on an already-focused inactive trigger dispatches once (no focus event).
- `value:` / `default_value:` are compared with `===` after `to_s` to each Trigger/Content `value:` (tabs:106, tabs:162). `value: ""` is valid and matches no trigger (scenario `controlled-value-empty`).

### `TabsList` -> `Components::V2::Tabs::List`

```ruby
Components::V2::Tabs::List.new(
  variant: "default",   # "default" | "line" (tabsListVariants), default = defaultVariants
  loop: true,           # Radix TabsList prop (tabs:74, default true; RovingFocusGroup's own default is false, rf:46)
  as_child: false,
  class: nil,           # cn(tabsListVariants(variant:), class)
  **attrs               # e.g. aria-label, dir (only an attribute: keyboard direction comes from the Tabs context, tabs:83)
) { triggers }
```

`Components::V2::Tabs.list_variants(variant: "default")` returns the cva class string (`tabsListVariants`):
- base: `group/tabs-list inline-flex w-fit items-center justify-center rounded-lg p-[3px] text-muted-foreground group-data-[orientation=horizontal]/tabs:h-9 group-data-[orientation=vertical]/tabs:h-fit group-data-[orientation=vertical]/tabs:flex-col data-[variant=line]:rounded-none`
- `default`: `bg-muted`; `line`: `gap-1 bg-transparent`. No compoundVariants.

### `TabsTrigger` -> `Components::V2::Tabs::Trigger`

```ruby
Components::V2::Tabs::Trigger.new(
  value:,               # required (to_s); used for ids and selection, NOT rendered as an attribute (destructured, tabs:101)
  disabled: false,      # tabs:101
  as_child: false,      # Primitive.button (tabs:115)
  class: nil,
  **attrs
) { label, icons }
```

### `TabsContent` -> `Components::V2::Tabs::Content`

```ruby
Components::V2::Tabs::Content.new(
  value:,               # required (to_s), tabs:158
  force_mount: false,   # Radix `forceMount` (tabs:158, tabs:168): always present (not hidden, children rendered) while inactive
  as_child: false,      # Primitive.div (tabs:169)
  class: nil,           # cn("flex-1 outline-none", class)
  **attrs
) { panel content }
```

List, Trigger and Content must be rendered inside a `Components::V2::Tabs` (Radix context error otherwise, tabs:75/102/159): Ruby raises `ArgumentError` when no enclosing Tabs is found in the Phlex render context.

Consumer handlers (`data: { action: "mousedown->x#y" }`) run before the Radix logic and, if they call `preventDefault()`, suppress it (`composeEventHandlers`, tabs:127/135/143); the controller checks `event.defaultPrevented` before acting.

## Structure

Final DOM (after React mount / after Stimulus connect), uncontrolled, `default_value: "account"`, two triggers:

```html
<div dir="ltr" data-orientation="horizontal" data-slot="tabs" class="group/tabs flex gap-2 data-[orientation=horizontal]:flex-col" data-controller="chadcn--tabs">
  <div role="tablist" aria-orientation="horizontal" tabindex="0" data-orientation="horizontal" style="outline: none;"
       data-slot="tabs-list" data-variant="default" class="<list classes>">
    <button type="button" role="tab" aria-selected="true" aria-controls="radix-1-content-account" data-state="active"
            id="radix-1-trigger-account" tabindex="-1" data-orientation="horizontal" data-radix-collection-item=""
            data-slot="tabs-trigger" class="<trigger classes>">Account</button>
    <button type="button" role="tab" aria-selected="false" aria-controls="radix-1-content-password" data-state="inactive"
            id="radix-1-trigger-password" tabindex="-1" data-orientation="horizontal" data-radix-collection-item=""
            data-slot="tabs-trigger" class="<trigger classes>">Password</button>
  </div>
  <div data-state="active" data-orientation="horizontal" role="tabpanel" aria-labelledby="radix-1-trigger-account"
       id="radix-1-content-account" tabindex="0" style="animation-duration: 0s;" data-slot="tabs-content" class="flex-1 outline-none">...</div>
  <div data-state="inactive" data-orientation="horizontal" role="tabpanel" aria-labelledby="radix-1-trigger-password"
       hidden="" id="radix-1-content-password" tabindex="0" data-slot="tabs-content" class="flex-1 outline-none"></div>
</div>
```

### Part `Tabs` (`data-slot="tabs"`)

`Primitive.div` (tabs:57-65).
- tag `div` (or the `as_child` element). No role, no tabindex.
- `dir="ltr" | "rtl"`: ALWAYS present, value of `use_direction(dir)` (tabs:60).
- `data-orientation="<orientation>"`: always (shadcn passes it AND Radix sets it, tabs:61; same value).
- `data-slot="tabs"`, `class` = `cn("group/tabs flex gap-2 data-[orientation=horizontal]:flex-col", class)` (tabs.tsx).
- Children: exactly the block, in order.
- Ids: the root computes `base_id` once per render (Radix `useId`, id:9-15, renders `radix-<reactId>`); the port uses a deterministic per-render counter (`radix-<n>`, or derived from the caller's `id:` when given). The runner normalizes ids by first reference, so only the relations matter. `base_id`, value, orientation, dir and activation mode are passed to List/Trigger/Content through the Phlex render context (like `Direction::Provider`), saved and restored around the block so nested Tabs work.

### Part `TabsList` (`data-slot="tabs-list"`)

`RovingFocusGroup.Root asChild` (rf:42-131) slotted onto `Primitive.div` (tabs:77-94); Slot merge, child props win.
- tag `div` (or the `as_child` element).
- `role="tablist"` (tabs:88); `aria-orientation="<orientation>"` ALWAYS (context orientation, default horizontal, tabs:89).
- `data-orientation="<orientation>"` always (rf:101; RovingFocusGroup receives `orientation: context.orientation`, tabs:82).
- `tabindex`: `"0"` when at least one trigger is focusable (not disabled), `"-1"` when none is (`focusableItemsCount === 0`, rf:100) or transiently during Shift+Tab out (`isTabbingBackOut`, rf:64/88/100/126). Server renders the post-mount value.
- `style="outline: none;"` (rf:104), merged with caller `style` (caller keys win).
- `data-slot="tabs-list"`, `data-variant="<variant>"` (tabs.tsx), `class` = `cn(tabsListVariants({ variant }), class)`.
- `dir` attribute only when the caller passes it (`**attrs`, docs RTL example); it does NOT affect keyboard direction.

### Part `TabsTrigger` (`data-slot="tabs-trigger"`)

`Collection.ItemSlot` (col:50) > `RovingFocusGroup.Item asChild` (rf:133-211, `Primitive.span` slotted) > `Primitive.button` (tabs:107-151).
- tag `button` (or the `as_child` element, which still receives every attribute below, including `type="button"`), `type="button"`, `role="tab"` (tabs:117-118).
- `aria-selected="true" | "false"` always (tabs:119).
- `aria-controls="<base>-content-<value>"` always, even when no matching Content exists (tabs:120, tabs:193-195).
- `data-state="active" | "inactive"` (tabs:121).
- `data-disabled=""` and `disabled=""` only when disabled (tabs:122-123; React omits `disabled={false}`).
- `id="<base>-trigger-<value>"` (tabs:124, tabs:189-191); a caller `id:` wins (and then the panel's `aria-labelledby` dangles, as in React).
- `tabindex="0" | "-1"`: `0` only for the current roving tab stop (rf:147, rf:175). Tabs passes no `defaultCurrentTabStopId` (tabs:77-85), so initially EVERY trigger renders `tabindex="-1"` and the list (`tabindex="0"`) is the Tab entry point. The stop becomes the trigger that last received focus or a non-prevented mousedown (rf:179-183) and stays after focus leaves.
- `data-orientation="<orientation>"` always (rf:176).
- `data-radix-collection-item=""` always (col:50).
- `data-slot="tabs-trigger"`; `class` = `cn(` the four verbatim strings of tabs.tsx in order `, class)`:
  1. `relative inline-flex h-[calc(100%-1px)] flex-1 items-center justify-center gap-1.5 rounded-md border border-transparent px-2 py-1 text-sm font-medium whitespace-nowrap text-foreground/60 transition-all group-data-[orientation=vertical]/tabs:w-full group-data-[orientation=vertical]/tabs:justify-start hover:text-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1 focus-visible:outline-ring disabled:pointer-events-none disabled:opacity-50 group-data-[variant=default]/tabs-list:data-[state=active]:shadow-sm group-data-[variant=line]/tabs-list:data-[state=active]:shadow-none dark:text-muted-foreground dark:hover:text-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4`
  2. `group-data-[variant=line]/tabs-list:bg-transparent group-data-[variant=line]/tabs-list:data-[state=active]:bg-transparent dark:group-data-[variant=line]/tabs-list:data-[state=active]:border-transparent dark:group-data-[variant=line]/tabs-list:data-[state=active]:bg-transparent`
  3. `data-[state=active]:bg-background data-[state=active]:text-foreground dark:data-[state=active]:border-input dark:data-[state=active]:bg-input/30 dark:data-[state=active]:text-foreground`
  4. `after:absolute after:bg-foreground after:opacity-0 after:transition-opacity group-data-[orientation=horizontal]/tabs:after:inset-x-0 group-data-[orientation=horizontal]/tabs:after:bottom-[-5px] group-data-[orientation=horizontal]/tabs:after:h-0.5 group-data-[orientation=vertical]/tabs:after:inset-y-0 group-data-[orientation=vertical]/tabs:after:-right-1 group-data-[orientation=vertical]/tabs:after:w-0.5 group-data-[variant=line]/tabs-list:data-[state=active]:after:opacity-100`
- No `value` attribute, no `aria-disabled`.
- Children: the block (text, `Components::V2::Icon`, ...).

### Part `TabsContent` (`data-slot="tabs-content"`)

`Presence` (render-function children, so the element is ALWAYS rendered, pr:20-27) > `Primitive.div` (tabs:168-186).
- tag `div` (or the `as_child` element, see below).
- `data-state="active" | "inactive"` (tabs:171), `data-orientation="<orientation>"` (tabs:172), `role="tabpanel"` (tabs:173), `aria-labelledby="<base>-trigger-<value>"` (tabs:174), `id="<base>-content-<value>"` (tabs:176), `tabindex="0"` (tabs:177; also on hidden panels).
- `hidden=""` iff not present (`present = force_mount || selected`, or still exiting under Presence, tabs:168/175).
- Children rendered only while present (`present && children`, tabs:184): an inactive, non-force-mounted panel is an EMPTY element.
- `style`: caller style, plus `animation-duration: 0s` while `isMountAnimationPreventedRef` is true (tabs:163-167, tabs:180-183). The ref is true only for the panel that is selected on first render and turns false after one animation frame without re-rendering, so that panel keeps `style="animation-duration: 0s;"` until the first value change; from that re-render on the declaration is removed (React leaves `style=""`). Panels inactive at mount never get the declaration. Port: server renders `animation-duration: 0s;` on the initially selected panel; the controller removes the property on the first value change. (`style` is ignored by the runner's attribute diff but `animation-duration` affects a caller's enter animation.)
- `data-slot="tabs-content"`, `class` = `cn("flex-1 outline-none", class)`.
- `as_child`: Slot merges onto the single child element. When not present, `children` is `false`, so Slot returns `false` and NOTHING is rendered (slot:42-49): an inactive `as_child` panel has no element at all; it appears (merged onto the child) when it becomes active.

### Server vs Stimulus

Server renders every attribute above for the initial state: `dir`, orientations, list `tabindex`, all trigger `tabindex="-1"`, `aria-selected`/`data-state`, ids, `hidden`, the initial `animation-duration`.

Inactive panel children (React does not mount them): the server renders the children of every inactive, non-force-mounted Content inside a `<template data-chadcn--tabs-target="deferred">` as the panel's only child (no `data-slot`, inert, so ids and inputs inside are not in the document, as in React). For an inactive `as_child` Content the server renders only that `<template>` (containing the merged element) in its place. In `connect()` the controller takes each template's content into memory and removes the template (for `as_child`, it leaves a comment node as the position anchor), so the post-connect DOM equals React's. It also stores a pristine clone of the active panel's children taken before any interaction.

Stimulus (`chadcn--tabs`, ONE controller on the root element; list, triggers and contents are targets, no per-part controller) updates: `aria-selected` / `data-state` on triggers, `data-state` / `hidden` / children on contents (mounting a FRESH clone of the pristine children on activation and dropping them on deactivation, so form fields inside reset exactly like a React remount, scenario `example__tabs-demo__interact`), roving `tabindex`, list `tabindex`, the `animation-duration` removal. `disconnect()` restores the server shape (re-inserts the `<template>`s for inactive panels) so a Turbo cache restore reconnects to equivalent markup.

## Behavior

States: per trigger/panel `active` / `inactive`; trigger `disabled` orthogonal. The value is one string ("" = none). Primitives composed: `roving_focus` (orientation/dir/loop key mapping, `setTimeout` focusFirst, tab-stop `tabindex`, list `tabindex` with focusable-count and Shift+Tab back-out, entry focus with click-focus guard), `collection` (DOM-ordered triggers by `data-radix-collection-item`, honoring disabled), `direction` (reads the root's own `dir`), `presence` (panels), `ids`. Same roving-focus contract as RadioGroup (see `radio-group.md`), with Tabs' own activation rules instead of RadioGroup's arrow-select.

### Selection requests (`onValueChange(value)`)

1. **mousedown** on a trigger (tabs:127-134, composed with rf:179-182 via Slot: the Tabs handler runs first, the roving handler only if not prevented): if not disabled AND `event.button === 0` AND `ctrlKey === false`: `trigger.focus()` (synchronously fires the focus rule 3), then request its value; the trigger becomes the tab stop. Otherwise `preventDefault()` (no focus, no select, tab stop unchanged): right/middle button, Ctrl+click. Selection is on mousedown, not click. Disabled buttons receive no mouse events at all.
2. **keydown** Space or Enter on the trigger itself (`event.target === currentTarget`, not disabled, tabs:135-142): request its value (the only way to select in manual mode with the keyboard). No `preventDefault`; the native button click that follows has no handler.
3. **focus** (any cause: Tab entry, arrow roving, programmatic `focus()`, mousedown) in `automatic` mode, when not selected and not disabled: request its value (tabs:143-147). In `manual` mode focus never selects.

Uncontrolled: request -> update DOM (all triggers and panels) -> dispatch `value-change` if the value changed. Controlled: request -> dispatch only (see API).

### Keyboard (focus on a trigger; RovingFocusGroup rf:184-204)

| Key | Result |
|---|---|
| ArrowRight / ArrowDown | focus next enabled trigger, wrapping (`loop: true`); in automatic mode that focus selects it |
| ArrowLeft / ArrowUp | focus previous enabled trigger, wrapping; selects in automatic mode |
| Home / PageUp | focus first enabled trigger (selects in automatic mode, unlike RadioGroup, since selection is focus-driven) |
| End / PageDown | focus last enabled trigger (selects in automatic mode) |
| `orientation: "horizontal"` (default) | ArrowUp/ArrowDown ignored, no preventDefault (rf:232-234) |
| `orientation: "vertical"` | ArrowLeft/ArrowRight ignored (rf:229-231) |
| `dir: "rtl"` | ArrowLeft/ArrowRight swap (rf:222-226); Up/Down unchanged |
| any arrow/Home/End/Page with Meta/Ctrl/Alt/Shift | ignored, no preventDefault (rf:192) |
| `loop: false` | Next at the last / Prev at the first does nothing (rf:200 `slice`) |
| Enter / Space | select the focused trigger (rule 2); no-op when already selected |
| Tab | leaves the list (other triggers are `tabindex=-1`), normally to the active panel (`tabindex=0`) |
| Shift+Tab | `isTabbingBackOut` -> list `tabindex="-1"` before default navigation so focus skips the list div; the list's `blur`/`focusout` resets it to `0` (rf:185-188, 126) |

Mechanics: only when `event.target === event.currentTarget` (Shift+Tab is checked before that); on a focus intent `preventDefault()`, candidates = enabled triggers in DOM order (reversed for prev/last, rotated after the current index for prev/next, rf:194-201, `wrapArray` rf:247-249), then `setTimeout(() => focusFirst(candidates))` (rf:202, macrotask). `focusFirst` (rf:238-245) focuses candidates until `document.activeElement` changes, stopping at the previously focused element. Keyboard direction is the Tabs context `dir` (tabs:83), never the List's own `dir` attribute.

### Focus entry (list, rf:105-125)

- List `mousedown` (bubbling, after the trigger's handler) sets `isClickFocus = true`; it is reset to `false` ONLY by the list's next `focus`/`focusin` handler (rf:124). So after a trigger mousedown the flag stays `true`: a later keyboard Tab back onto the list div does NOT redirect, focus stays on the list div (outline none) and resets the flag (scenario `click__reentry-quirk`). Reproduce, do not fix.
- List `focus` with `target === list`, not click focus, not tabbing back out: dispatch cancelable non-bubbling `CustomEvent("rovingFocusGroup.onEntryFocus")` on the list (Tabs adds no listener), then focus the first of [active trigger, current tab-stop trigger, ...enabled triggers] after filtering out disabled ones (rf:113-121), `preventScroll: false`. A disabled active trigger is skipped, so entry lands on the tab stop or the first enabled trigger, which then becomes selected in automatic mode (scenario `tab__entry-disabled-active`). With no value, entry focuses the first enabled trigger (automatic: selects it).
- All triggers disabled: list `tabindex="-1"`, Tab skips the whole list.
- Panels have `tabindex="0"`: Tab from the tab stop focuses the active panel (no ring: `outline-none`), then its inner focusables. Hidden panels are not focusable.
- Focus ring only on `:focus-visible` (keyboard); mousedown focus shows none.

### Presence (panels, pr:28-130)

Activation mounts immediately (`hidden` removed, children inserted). Deactivation: if the panel's computed `animation-name` is `none` (shadcn: no animation classes) or `display: none`, unmount at once (`hidden=""`, children removed); otherwise keep it present with `data-state="inactive"` until `animationend`/`animationcancel` on the panel itself, then hide (pr:56-116). Use the `presence` primitive; with the oracle classes it degenerates to an immediate hide.

### Not applicable

Timers: none besides the `setTimeout(0)` focus hop. No dismissal, scroll lock, portal, positioning, typeahead. No hidden form input.

Turbo: `disconnect()` cancels pending focus timeouts, removes listeners and restores templates (see Structure).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Tabs` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Tabs::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Tabs::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `tabs.list` | `Tabs::List` | `TabsList` |
| `tabs.trigger` | `Tabs::Trigger` | `TabsTrigger` |
| `tabs.content` | `Tabs::Content` | `TabsContent` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- No other V2 component is rendered by Tabs (`registry_dependencies: []`, manifest `icons: []`).
- `Components::V2::Direction` (`Consumer` mixin / `use_direction`) for the root `dir` attribute and keyboard direction (spec `direction.md`).
- Examples use Card, Input, Label, Button and lucide `app-window` / `code` icons (`Components::V2::Icon` in real use); in the scenario trees they are raw `_div`/`_label`/`_input`/`_button` elements carrying the verbatim oracle classes and `data-slot`s of those components, because the coverage check only admits Tabs exports.

## Deviations

None. Every part, attribute and state is reproduced; the deferred-children `<template>` exists only before `connect()` and has no `data-slot`, so the post-connect DOM equals the oracle's. Not covered by scenarios because the step vocabulary cannot express it: Ctrl+click (no modifier on `click`); it is still part of the contract (rule 1).
