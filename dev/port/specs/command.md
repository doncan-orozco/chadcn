# Command (shadcn new-york-v4, cmdk 1.1.1)

Sources read: oracle `gems/chadcn/dev/port/oracle/src/command.tsx` (manifest `source_sha` 319e9264567dd46f, cited `src:<part>`), the library it wraps, `gems/chadcn/dev/react-shadcn-catalog/node_modules/cmdk/dist/index.mjs` 1.1.1 (minified to one line; cited as `cmdk:<n>` = line n of `npx esbuild node_modules/cmdk/dist/index.mjs --format=esm`, run in the catalog), its scorer `cmdk/dist/chunk-NZJY6EH4.mjs` (`command-score`), the Phlex Dialog port (`lib/chadcn/dialog.rb`, `dialog/*.rb`, `specs/dialog.md`), the scorer primitive `app/javascript/chadcn/primitives/scorer.js`, React DOM 19.3.0, lucide-react 0.577.0. Registry examples: `command-demo`, `command-dialog` (new-york-v4, fetched from ui.shadcn.com).

Tier `third_party`. Stimulus identifier `chadcn--command` (one controller on the `Command` root). **No third-party JavaScript** (maintainer constraint of the adoption epic, item #178): cmdk is re-implemented in the `chadcn--command` controller, filtering/ranking uses the `scorer` primitive; no importmap pin, vendor file or npm dependency is added (a unit test asserts it).

## API

Every part: `class:` goes through `cn` last (caller wins), except `Command::Empty` (see below); `**attrs` pass through (`data:`/`aria:` deep-merged); booleans are Ruby booleans; string values only (no option tables: the oracle has no cva). Attributes that cmdk spreads AFTER the caller props cannot be overridden by the caller (listed per part in Structure, e.g. an Input `id:`/`type:`/`role:` is replaced like in React, cmdk:216).

```ruby
Chadcn::Command.new(label: nil, value: nil, default_value: nil, should_filter: true, loop: false,
  disable_pointer_selection: false, vim_bindings: true, class: nil, **attrs) { |command| ... }
Chadcn::Command::Dialog.new(title: "Command Palette", description: "Search for a command to run...", show_close_button: true,
  open: nil, default_open: false, modal: true, class: nil, **attrs) { ... }
Chadcn::Command::Input.new(value: nil, class: nil, **attrs)          # attrs (placeholder:, disabled:, autofocus:...) reach the <input>
Chadcn::Command::List.new(label: "Suggestions", class: nil, **attrs) { ... }
Chadcn::Command::Empty.new(**attrs) { "No results found." }
Chadcn::Command::Group.new(heading: nil, value: nil, force_mount: false, class: nil, **attrs) { ... }
Chadcn::Command::Item.new(value: nil, keywords: KEYWORDS, disabled: false, force_mount: false, as_child: false, class: nil, **attrs) { ... }
Chadcn::Command::Shortcut.new(class: nil, **attrs) { "⌘P" }
Chadcn::Command::Separator.new(always_render: false, class: nil, **attrs)
```

| React | Ruby | Notes |
|---|---|---|
| `Command` (`CommandPrimitive` root, props `label`, `value`, `defaultValue`, `onValueChange`, `filter`, `shouldFilter`, `loop`, `disablePointerSelection = false`, `vimBindings = true`, cmdk:12) | `Command.new(...)` | `label:` is the text of the sr-only `<label cmdk-label>` (cmdk:182). `value:` = controlled selected value (trimmed, cmdk:14-18); `default_value:` = uncontrolled initial value (NOT trimmed, cmdk:11). `should_filter: false` disables filtering and sorting (cmdk only checks `=== false`, cmdk:65, 94). `filter` (a JS function) has no Ruby form: see Deviations. The root `yield self`s (generated helpers). |
| `CommandDialog` (src:CommandDialog; `title = "Command Palette"`, `description = "Search for a command to run..."`, `showCloseButton = true`, `className`, `...props` to `Dialog`) | `Command::Dialog.new(...)` | Renders `Chadcn::Dialog.new(open:, default_open:, modal:, **attrs)` (the Dialog root takes the rest props, as `...props` go to Radix `Dialog`), then `Chadcn::Dialog::Header.new(class: "sr-only") { Dialog::Title { title }; Dialog::Description { description } }`, then `Chadcn::Dialog::Content.new(class: cn("overflow-hidden p-0", class), show_close_button:) { Command.new(class: DIALOG_COMMAND_CLASSES) { block } }`. Inside the `Command` namespace `Dialog` resolves to `Command::Dialog`: the builder must write the fully qualified `Chadcn::Dialog`. Events are the Dialog's (`chadcn--dialog:open-change` ...). |
| `CommandInput` (src:CommandInput, `CommandPrimitive.Input`: `value`, `onValueChange`, cmdk:212-218) | `Command::Input.new(value: nil, ...)` | `class:` and `**attrs` go to the `<input>`, never to the wrapper div (src). `value:` given = controlled search: the search is that string and typing does not change it (React restores the controlled value); `nil` = uncontrolled. |
| `CommandList` (`label = "Suggestions"`, cmdk:219-220) | `Command::List.new(label: "Suggestions", ...)` | `label:` is the list's `aria-label`. |
| `CommandEmpty` (src destructures only `...props`: `className="py-6 text-center text-sm" {...props}`) | `Command::Empty.new(**attrs)` | A caller `class:` REPLACES the default classes (React prop spread after `className`, no `cn`); scenario `empty__classname-replaces`. |
| `CommandGroup` (`heading`, `value`, `forceMount`, cmdk:204-208) | `Command::Group.new(heading: nil, value: nil, force_mount: false, ...)` | `heading:` is a String (React nodes have no Ruby form; a block-built heading is not offered). |
| `CommandItem` (`value`, `keywords`, `disabled`, `onSelect`, `forceMount`, cmdk:183-203) | `Command::Item.new(...)` | `keywords:` default is `Command::Item::KEYWORDS`, a frozen constant (`[].freeze`; cmdk's default `[]`, cmdk:270), accepts an Array of Strings. `as_child:` (`false` \| tag symbol \| component instance; `Base#render_as_child`, Radix Slot via cmdk's `Primitive.div`, cmdk:203) is supported on Item only. |
| `CommandShortcut` (src: plain `span`) | `Command::Shortcut.new(...)` | |
| `CommandSeparator` (`alwaysRender`, cmdk:209-211) | `Command::Separator.new(always_render: false, ...)` | |

Root `Command` constants: `Command::DIALOG_COMMAND_CLASSES` = the exact class string `Command` receives inside `CommandDialog` (src:CommandDialog). `ref` has no equivalent.

Events (dispatched with Stimulus `this.dispatch`, prefix `chadcn--command:`, `bubbles: true`, not cancelable):

| Event | React origin | Target | detail | When |
|---|---|---|---|---|
| `value-change` | root `onValueChange` (cmdk:33-36) | root | `{ value }` | the selected value changes AND `value:` is controlled (cmdk calls `onValueChange` only when `value` is defined, cmdk:33; uncontrolled roots do not dispatch it) |
| `search-change` | Input `onValueChange` (cmdk:216-217) | input | `{ value }` | every `input` event, controlled or not |
| `select` | Item `onSelect(value)` (cmdk:194-197) | item | `{ value }` | click on an enabled item, or Enter while it is the selected item |

Example (`command-demo`):

```ruby
render Chadcn::Command.new(class: "rounded-lg border shadow-md md:min-w-[450px]") do
  render Chadcn::Command::Input.new(placeholder: "Type a command or search...")
  render Chadcn::Command::List.new do
    render Chadcn::Command::Empty.new { "No results found." }
    render Chadcn::Command::Group.new(heading: "Suggestions") do
      render Chadcn::Command::Item.new { render Chadcn::Icon.new("calendar"); span { "Calendar" } }
      render Chadcn::Command::Item.new(disabled: true) { render Chadcn::Icon.new("calculator"); span { "Calculator" } }
    end
    render Chadcn::Command::Separator.new
    render Chadcn::Command::Group.new(heading: "Settings") do
      render Chadcn::Command::Item.new(data: { action: "chadcn--command:select->palette#profile" }) do
        render Chadcn::Icon.new("user"); span { "Profile" }; render Chadcn::Command::Shortcut.new { "⌘P" }
      end
    end
  end
end
```

## Structure

Class strings are verbatim from the oracle (set equality is the gate). `""` attributes (`cmdk-root=""`) are rendered as empty-string attributes, exactly like React's `"cmdk-root": ""`. React booleans in `aria-*`/`data-*` render `"true"`/`"false"`.

| Part | Tag | data-slot | Attributes (server-rendered unless noted) | Classes |
|---|---|---|---|---|
| `Command` | `div` | `command` | `tabindex="-1"` (caller can override: it is spread before the caller props, cmdk:142), caller attrs, `cmdk-root=""` (cmdk:142); controller wiring `data-controller="chadcn--command"` + `data-chadcn--command-*-value` (ignored by G2) | `flex h-full w-full flex-col overflow-hidden rounded-md bg-popover text-popover-foreground` |
| sr-only label (first child of the root, cmdk:182) | `label` | none | `cmdk-label="" for=<input id> id=<label id>`, inline style `position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border-width: 0` (cmdk:299 `Te`); text = `label:` (empty element when nil) | none |
| `Command::Input` wrapper | `div` | `command-input-wrapper` | none (it is NOT `cmdk-input-wrapper`; the `[&_[cmdk-input-wrapper]_svg]` tokens of `CommandDialog` match nothing in the oracle either: keep them verbatim) | `flex h-9 items-center gap-2 border-b px-3` |
| search icon (first child of the wrapper) | `svg` | none | `Icon("search", class: "size-4 shrink-0 opacity-50")` -> `class="lucide lucide-search size-4 shrink-0 opacity-50" aria-hidden="true"` | |
| `Command::Input` | `input` | `command-input` | caller attrs, then (cmdk wins, cmdk:216) `cmdk-input="" autocomplete="off" autocorrect="off" spellcheck="false" aria-autocomplete="list" role="combobox" aria-expanded="true" aria-controls=<list id> aria-labelledby=<label id> id=<input id> type="text" value=<search>`; `aria-activedescendant=<selected item id>` set by Stimulus (absent while `selectedItemId` is undefined) | `flex h-10 w-full rounded-md bg-transparent py-3 text-sm outline-hidden placeholder:text-muted-foreground disabled:cursor-not-allowed disabled:opacity-50` |
| `Command::List` | `div` | `command-list` | caller attrs, then `cmdk-list="" role="listbox" tabindex="-1" aria-label=<label:> id=<list id>` (cmdk:233); `aria-activedescendant` (Stimulus, same value as the input); `style="--cmdk-list-height: <sizer offsetHeight toFixed(1)>px"` set by Stimulus from a `ResizeObserver` on the sizer, in a `requestAnimationFrame` (cmdk:221-231) | `max-h-[300px] scroll-py-1 overflow-x-hidden overflow-y-auto` |
| list sizer (only child of the list) | `div` | none | `cmdk-list-sizer=""` (cmdk:233); holds the block | none |
| `Command::Empty` | `div` | `command-empty` | caller attrs then `cmdk-empty="" role="presentation"` (cmdk:237). Mounted only while the filtered count is 0 (cmdk:237): server-rendered inside an inert `<template data-chadcn--command-target="empty">` at its JSX position, mounted right after the template with the `template_mount` primitive (deviation 1) | `py-6 text-center text-sm` (replaced by a caller `class:`) |
| `Command::Group` | `div` | `command-group` | caller attrs, then `cmdk-group="" role="presentation"`, `hidden=""` while filtered out (Stimulus, cmdk:205, 208); `data-value` = `value:`.strip, else `heading:`.strip, else the literal string `"undefined"` (cmdk:270-281: with no value and no heading the ref is null and `setAttribute("data-value", undefined)` writes `"undefined"`) | `overflow-hidden p-1 text-foreground [&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-xs [&_[cmdk-group-heading]]:font-medium [&_[cmdk-group-heading]]:text-muted-foreground` |
| group heading (only when `heading:`) | `div` | none | `cmdk-group-heading="" aria-hidden="true" id=<heading id>`, text = heading (cmdk:208) | none |
| group items (always) | `div` | none | `cmdk-group-items="" role="group"`, `aria-labelledby=<heading id>` only when there is a heading (cmdk:208); holds the block | none |
| `Command::Item` | `div` (or the `as_child` element) | `command-item` | caller attrs, then (cmdk wins, cmdk:203) `id=<item id> cmdk-item="" role="option" aria-disabled="true|false" aria-selected="true|false" data-disabled="true|false" data-selected="true|false"`; `data-value` (see Values); `aria-selected`/`data-selected` are rendered `"false"` by the server and maintained by Stimulus. `value`, `keywords`, `disabled`, `onSelect`, `forceMount` never reach the DOM (cmdk:202); keywords and flags travel as `data-chadcn--command-*` attributes (ignored by G2) | `relative flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-hidden select-none data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50 data-[selected=true]:bg-accent data-[selected=true]:text-accent-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground` |
| `Command::Shortcut` | `span` | `command-shortcut` | caller attrs | `ml-auto text-xs tracking-widest text-muted-foreground` |
| `Command::Separator` | `div` | `command-separator` | caller attrs, then `cmdk-separator="" role="separator"` (cmdk:211). Mounted only while the search is empty or `always_render` (cmdk:210) | `-mx-1 h-px bg-border` |

`data-slot` sits before the caller props in every shadcn part (src), so a caller `data: { slot: }` replaces it, like React.

DOM order (the `command-demo` tree): `div[cmdk-root]` > `label[cmdk-label]`, `div[data-slot=command-input-wrapper]` (> `svg.lucide-search`, `input[cmdk-input]`), `div[cmdk-list]` > `div[cmdk-list-sizer]` > `<template>` (Empty), `div[cmdk-group]` (> heading, `div[cmdk-group-items]` > items), `div[cmdk-separator]`, `div[cmdk-group]` ... . Items keep their children in source order (icon, span, Shortcut).

**Values.** Item `data-value` (cmdk:189, 270-281): `value:`.strip when given (the server renders it); otherwise the item's `textContent.trim()` (React's string child or the ref's textContent: the icon contributes nothing, a Shortcut is concatenated without a space, so `Profile` + `⌘P` -> `"Profile⌘P"`; case is kept). The controller (re)derives it on connect and for items added later. `keywords:` are trimmed (cmdk:280).

**Ids.** The root owns three ids (list, label, input: cmdk:12 `$`, `q`, `_`), each item one (cmdk:185), each group a group id and a heading id (cmdk:205), from a per-render sequence in the Phlex context (`command-<n>-list`, `command-<n>-item-<m>` ...). Only the relations are compared (`for`, `aria-controls`, `aria-labelledby`, `aria-activedescendant`).

**CommandDialog DOM.** Exactly the Phlex Dialog's (`specs/dialog.md`): the Dialog host `<div style="display: contents">` renders, in place, the sr-only `Dialog::Header` (`data-slot="dialog-header"`, classes `flex flex-col gap-2 text-center sm:text-left sr-only`) with `Dialog::Title` (`h2`) and `Dialog::Description` (`p`): this header is in the page even while the dialog is closed, because shadcn renders it as a direct child of Radix `Dialog` (renders no element), outside `DialogContent`. Open: Overlay and Content are portaled to `body`; Content has `aria-labelledby` = title id and `aria-describedby` = description id (both rendered, before Content in source order), classes = dialog Content classes merged with `overflow-hidden p-0` (`p-0` replaces `p-6`), and holds the `Command` root (classes = base + `**:data-[slot=command-input-wrapper]:h-12 [&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:font-medium [&_[cmdk-group-heading]]:text-muted-foreground [&_[cmdk-group]]:px-2 [&_[cmdk-group]:not([hidden])_~[cmdk-group]]:pt-0 [&_[cmdk-input-wrapper]_svg]:h-5 [&_[cmdk-input-wrapper]_svg]:w-5 [&_[cmdk-input]]:h-12 [&_[cmdk-item]]:px-2 [&_[cmdk-item]]:py-3 [&_[cmdk-item]_svg]:h-5 [&_[cmdk-item]_svg]:w-5`) followed by the X close (`show_close_button`). The Command root is inside the Content `<template>` while closed and its controller connects when the Dialog mounts the clone.

## Behavior

State (cmdk:11): `search` (String), `value` (selected item value), `selectedItemId`, `filtered = { count, items: id -> score, groups: Set }`. Registered items = every Item that is not force-mounted (cmdk:186-188; an Item inherits `forceMount` from its Group, cmdk:185).

**Mount (connect).** Register items and groups, derive values, compute the count; if `value` is empty, select the first enabled item in DOM order (cmdk:48-49 `W`, cmdk:88-91) through the value setter below ; at mount `aria-activedescendant` is ABSENT (the oracle reads the selected item before React renders it) and no scroll happens; after a search or an item removal it names the previous selection (one-step lag, as in cmdk), after keyboard, pointer or select it is current. With an initial `value:`/`default_value:` the item whose `data-value` equals it (exact, case-sensitive, cmdk:189) is selected but `selectedItemId` stays undefined, so `aria-activedescendant` is ABSENT until the selection changes (cmdk only computes it inside the value setter, cmdk:30-32); no item matches -> nothing selected. A controlled Input `value:` applies its search on connect.

**Value setter** (`setState("value", v, fromPointerOrSelect)`, cmdk:25-38): no-op when unchanged; if `document.activeElement` is the input or the root, focus the input (or the list when there is no input, cmdk:26-28); after the render set `selectedItemId` = id of the item with `aria-selected="true"` (cmdk:30-32) and write `aria-activedescendant` on input and list; unless it came from pointer/select, `scrollIntoView({ block: "nearest" })` the selected item, first scrolling its group heading into view when the item is the first child of its container (cmdk:110-114); controlled root: dispatch `value-change`. The port updates `aria-activedescendant` together with the selection in both modes (see Deviations).

**Search change** (input `input` event, cmdk:216-217 -> cmdk:24): dispatch `search-change`; controlled Input: restore its value and stop (React re-renders the controlled value). Otherwise, in this order:
1. Score (cmdk:92-109 `J`): empty search or `should_filter: false` -> `count` = number of registered items, nothing hidden. Else every registered item gets `filter(value, search, keywords)` (default: scorer `scoreItem(search, value, keywords)`), `count` = items with score > 0, a group is "matching" when any registered item of it scores > 0.
2. Sort (cmdk:64-87 `z`, only when the search is non-empty and filtering is on): take the CURRENTLY MOUNTED enabled items (`[cmdk-item]:not([aria-disabled="true"])`, DOM order), stable-sort by score descending (missing score = 0), and `appendChild` each, in that order, to its container (`[cmdk-group-items]`, or the sizer for ungrouped items; an item wrapped in another element moves its `[cmdk-group-items] > *` / sizer child wrapper). Disabled items are never moved. Groups are NOT reordered: cmdk looks them up by `[cmdk-group][data-value="<encodeURIComponent(group id)>"]` (cmdk:84), which never matches the heading-derived `data-value`; reproduce the no-op.
3. Mount/unmount like React: an item is present when force-mounted, filtering is off, the search is empty, or its score > 0 (cmdk:189, 201); a group is `hidden` unless force-mounted, filtering is off, the search is empty, or it is matching (cmdk:205); a Separator is present only for an empty search (or `always_render`, cmdk:210); Empty is present only for `count === 0` (cmdk:237). Removed nodes are detached (kept by the controller). A (re)mounted Item/Separator is inserted with React's host-sibling rule: before the next node, in SOURCE order within the same parent, that was already mounted before this update, else appended to the parent; several nodes mounted in one update keep their source order. So after clearing the search the items return next to their stable siblings, not necessarily to source order (exactly React's reconciliation; scenario `filter__clear-restores`).
4. Select the first enabled item in DOM order (cmdk:24 `v(1, W)`) through the value setter (scrolling it into view). When the selected item is unmounted, the same reselection runs (cmdk:51-55).
5. React syncs the `value` attribute of a controlled input (react-dom `updateInput`, attribute syncing on), so the `<input>` `value` attribute always equals the search; the controller writes it on every change.

**Keyboard** (keydown on the root, bubbling from the input; ignored when `defaultPrevented`, `isComposing` or `keyCode === 229`, cmdk:142-146). `enabled` = mounted items not `aria-disabled="true"`, DOM order (cmdk:119-122).

| Key | Effect | Source |
|---|---|---|
| ArrowDown | preventDefault; next enabled item (none selected -> the first); at the end: stays, or wraps to the first with `loop` | cmdk:137-138, 127-131 |
| ArrowUp | preventDefault; previous enabled item (none selected -> nothing, or the last with `loop`); at the start: stays, or wraps to the last with `loop` | cmdk:139-140, 127-131 |
| Meta+ArrowDown / Meta+ArrowUp | last / first enabled item | cmdk:137-140 |
| Alt+ArrowDown / Alt+ArrowUp | first enabled item of the next / previous `[cmdk-group]` sibling that has one; none -> plain next/previous (loop rules apply) | cmdk:132-136, 241-254 |
| Ctrl+n, Ctrl+j / Ctrl+p, Ctrl+k | same as ArrowDown / ArrowUp (including the Meta/Alt variants) when `vim_bindings` (default true); otherwise nothing and the key is NOT prevented | cmdk:147-160 |
| Home / End | preventDefault; first / last enabled item | cmdk:165-172 |
| Enter | preventDefault (no form submit); dispatch the item-select on the selected item: if it is enabled, set the value (no scroll) and dispatch `select` `{ value }` | cmdk:173-180, 190-199 |
| Escape, Tab, characters | not handled (characters reach the input) | |

Every keyboard move goes through the value setter (scrolls, may refocus the input when the root has focus).

**Pointer.** `pointermove` on an enabled item selects it (value setter, no scroll) unless `disable_pointer_selection` (cmdk:203). Click on an enabled item: select + `select` event (cmdk:203, 194-197). Disabled items have no handlers and `pointer-events: none` (class). A click on an item lets the browser focus the nearest focusable ancestor (the list, `tabindex="-1"`); nothing refocuses the input.

**CommandDialog.** All dialog behavior is `Chadcn::Dialog` (`chadcn--dialog`: portal, presence, dismissable layer, focus scope, focus guards, hide-others, scroll lock; Escape, overlay click and the X close the dialog; `open:` controlled only dispatches `open-change`). On open the Dialog focuses the first tabbable (the cmdk input, text selected) and the Command controller connects on the mounted clone (fresh state each open: empty search, first item selected). cmdk does not handle Escape, so it reaches the Dialog.

**Cleanup** (radix-stimulus R10): `disconnect()` disconnects the ResizeObserver, cancels the pending frame and drops detached nodes, so a Turbo cache restore renders the server state.

Timers: none (one `requestAnimationFrame` for `--cmdk-list-height`). Positioning: none. Primitives composed: `scorer` (default filter), `template_mount` (Empty), `ids` (client-added items); the Dialog primitives through `Chadcn::Dialog`. Controller values: `value`, `controlled`, `should-filter`, `loop`, `vim-bindings`, `disable-pointer-selection` (root); Input controlled search via `data-chadcn--command-search` on the input; item/group flags `data-chadcn--command-keywords` (JSON), `data-chadcn--command-force-mount`, separator `data-chadcn--command-always-render`.

Not expressible in the parity runner (covered in `test/javascript/command.test.mjs`): the three events and their detail, a JS `filter` function, IME composition, items appended by a Turbo Stream, Turbo cache cleanup.

## Third-party

shadcn wraps `cmdk` 1.1.1 (`CommandPrimitive`, `.Input`, `.List`, `.Empty`, `.Group`, `.Item`, `.Separator`; `CommandPrimitive.Dialog`/`Loading` are not used by shadcn). Chosen JS library: **none**; the port is a hand-written Stimulus controller reproducing cmdk's DOM and state machine (above) plus our `scorer` primitive.

Mapping cmdk -> port: root `me` (cmdk:8-182) -> `Command` + controller; `Se` input (cmdk:212-218) -> `Command::Input`; `Ce` list + sizer + `--cmdk-list-height` (cmdk:219-233) -> `Command::List` (the "sizer" is the `div[cmdk-list-sizer]`; cmdk 1.1.1 injects no `<style>` element); `Ie` empty (cmdk:237) -> `Command::Empty` (template); `Ee` group (cmdk:204-208) -> `Command::Group`; `he` item (cmdk:183-203) -> `Command::Item`; `ye` separator (cmdk:209-211) -> `Command::Separator`; the `cmdk-item-select` custom event (cmdk:8 `Z`, 177-178) -> an internal call plus the `chadcn--command:select` event; React mount/unmount -> detach/re-insert with the host-sibling rule; shadcn's `CommandDialog` (Radix Dialog) -> `Chadcn::Dialog`.

Filtering: cmdk's default `command-score` (`chunk-NZJY6EH4.mjs`, value and keywords joined with spaces) is replaced by `scorer.js` `scoreItem(search, value, keywords)` (keywords weighted 0.9). Both return 0 for "no match" and order by score, but the numbers differ and the match set differs for some queries (command-score's skip rules: `"app"` also matches `"Apricot"`; whitespace in the query is ignored by our scorer). This is not a DOM deviation; the scenarios use queries where both rank identically (verified with both scorers for every typed prefix: `cal`, `set`, `bil`, `ing`, `zzz`, `ap`, `agenda`, `math`), and the rest is a known divergence of the scorer primitive. A force-mounted item keeps the score computed when its value was registered (against the then-current search; for an empty search command-score gives 0.99, the scorer `EMPTY_QUERY_SCORE` 1), like cmdk (cmdk:45, 100-103 only rescore registered items).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Command` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Command::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Command::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `command.dialog` | `Command::Dialog` | `CommandDialog` |
| `command.input` | `Command::Input` | `CommandInput` |
| `command.list` | `Command::List` | `CommandList` |
| `command.empty` | `Command::Empty` | `CommandEmpty` |
| `command.group` | `Command::Group` | `CommandGroup` |
| `command.item` | `Command::Item` | `CommandItem` |
| `command.shortcut` | `Command::Shortcut` | `CommandShortcut` |
| `command.separator` | `Command::Separator` | `CommandSeparator` |

Names that shadow a Phlex HTML element inside `Command`'s OWN `view_template` (use `tag(:dialog)` there, never the bare method): `dialog`, `input`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Chadcn::Dialog`, `Dialog::Header`, `Dialog::Title`, `Dialog::Description`, `Dialog::Content` (and through it `Dialog::Overlay`, `Dialog::Portal`, `Dialog::Close`): `Command::Dialog`.
- `Chadcn::Icon`: `search` in `Command::Input`; scenarios also use `calendar`, `smile`, `calculator`, `user`, `credit-card`, `settings`, `mail`, `file` (`smile` and `calculator` are not yet in `icons/catalog.rb`: the orchestrator runs `icons_sync.rb`, which reads the scenario `<icon:...>` names).
- `Chadcn::Base`: `cn`, `merge_attrs`, `render_as_child`, context ids, generated helpers.
- JavaScript: Stimulus and `chadcn/primitives/{scorer,template_mount,ids}.js`; no new pin.

## Deviations

Recorded in `gems/chadcn/dev/port/deviations/command.json` (API only; no class-token allowance, G1 unchanged):

1. `Command::Empty` is server-rendered inside an inert `<template>` (no `data-slot`) at its JSX position and mounted by the controller while the filtered count is 0: React renders it only then, and the server cannot know the count before the items render. Template content is not in the document, so the compared DOM is unchanged.
2. `filter` is a JS function: it is assigned from JavaScript on the controller (`controller.filter = (value, search, keywords) => number`), not passed from Ruby.
3. `onSelect` and the Input's `onValueChange` are the events `chadcn--command:select` and `chadcn--command:search-change` (the second renamed because the root's `onValueChange` already maps to `value-change`).
4. `as_child:` is supported on `Command::Item` only; cmdk's `asChild` on the root, Input, List and Group (cmdk:296-298 clones the child around the internal wrapper) is not offered.
5. Controlled `value:`: `aria-activedescendant` follows the selection immediately; cmdk 1.1.1 lags one step when the caller does not feed the new value back (it computes `selectedItemId` before the items re-render, cmdk:30-39).
