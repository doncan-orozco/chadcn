# Shared primitives (`app/javascript/chadcn/primitives/`)

Built in **wave 0** (before any overlay), pinned in `config/importmap.rb` with `pin_all_from "app/javascript/chadcn", under: "chadcn"`. Each primitive is a plain ES module (no Stimulus dependency), exports small functions that return a `release()` cleanup, and is covered by a harness page `/design-system/parity/_primitives/<name>` + scenario file `dev/port/scenarios/_primitives-<name>.json` compared against the same primitive in React (Radix package used raw in `dev/react-shadcn-catalog/src/parity/primitives/`).

| Module | API sketch | Replaces (Radix) |
|---|---|---|
| `presence.js` | `presence(el, { onExited })` waits for animation/transition end after `data-state=closed` | `@radix-ui/react-presence` |
| `template_mount.js` | `mountTemplate(templateEl, { into: document.body \| "after" })` clones the inert `<template>` content, inserts it (portal to `body`, or in place right after the template) and returns `{ nodes, unmount() }`; remounting after `unmount()` yields a fresh copy. Used by EVERY part whose Radix counterpart is unmounted while closed/hidden/unloaded (18 specs: dialog, alert-dialog, sheet, popover, tooltip, hover-card, select, menus, navigation-menu, avatar, scroll-area, collapsible, accordion, tabs, sidebar...). The `data-*` names on the `<template>` are the spec's own; the primitive only receives the element | `react-presence` / conditional rendering |
| `portal.js` | `portal(el, container = document.body)` + restore on release | `react-portal` |
| `dismissable_layer.js` | `dismissable(el, { onEscape, onPointerDownOutside, onFocusOutside, onDismiss, disableOutsidePointerEvents })`; layer stack so only the top layer reacts | `react-dismissable-layer` |
| `focus_scope.js` | `focusScope(el, { trapped, loop, onMountAutoFocus, onUnmountAutoFocus })` | `react-focus-scope` |
| `focus_guards.js` | sentinel spans at body edges while a modal layer is open | `react-focus-guards` |
| `hide_others.js` | `aria-hidden` on siblings of the modal content; restore | `aria-hidden` package |
| `scroll_lock.js` | body `overflow:hidden` + scrollbar-width padding compensation, ref-counted | `react-remove-scroll` |
| `positioner.js` | floating-ui `computePosition/autoUpdate` with Radix's REAL middleware order (react-popper 104-127): offset(sideOffset+arrow, alignOffset), shift (mainAxis only, optional limitShift when `sticky=partial`), flip, size (sets `--radix-popper-available-width/height`, `--radix-popper-anchor-width/height`), arrow, transformOrigin (sets `--radix-popper-transform-origin`), hide (referenceHidden); the whole stack uses the same `collisionPadding`/`collisionBoundary` detectOverflow options; writes `data-side`, `data-align` | `react-popper` |
| `roving_focus.js` | `rovingFocus(container, { orientation, loop, dir, currentTabStopId })` arrow/Home/End, `tabindex` swapping | `react-roving-focus` |
| `typeahead.js` | buffer with 1000 ms reset, repeated-letter cycling, `matchItem(items, search, current)` | internal in menu/select |
| `hover_intent.js` | open/close delays with skip-delay provider state | tooltip/hover-card/navigation-menu |
| `submenu_grace.js` | pointer-grace polygon for sub menus | `react-menu` |
| `collection.js` | ordered item registry from DOM (`[data-radix-collection-item]`, the attribute Radix uses) honoring disabled | `react-collection` |
| `ids.js` | stable id helpers; reads server ids first | `react-id` |
| `direction.js` | `dir` prop, then a direction provider, then `"ltr"`; NEVER `html[dir]` (Radix `useDirection`) | `react-direction` |
| `form_bubble_input.js` | hidden native input kept in sync (checkbox/switch/radio/select) so forms submit | internal BubbleInput |
| `pointer_capture.js` | slider/resizable drag | native |
| `collapsible_content.js` | the open/closed content mechanics shared by Collapsible and Accordion: `data-state`, `hidden`, `--radix-collapsible-content-height/width` measured for the height animation, Presence on close | `react-collapsible` |

## Rules for primitives

- No global mutable state except explicit stacks (`dismissable` layers, `scroll_lock` counter, `hide_others` registry) that are reset by the returned `release()`.
- Radix constants (z-index is NOT set by Radix; `shadcn` uses `z-50`) are copied verbatim.
- Floating content uses the same wrapper contract as Radix: `div[data-radix-popper-content-wrapper]` with `position: fixed; left:0; top:0; transform: translate(x,y); min-width: max-content; z-index` copied from the content. The runner compares the content box in viewport coordinates, so the wrapper must resolve to identical coordinates.
- Each primitive has a "known divergences" list at the top of its file; empty is the goal.
