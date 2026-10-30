---
name: radix-stimulus
description: "How Radix UI / shadcn behavior is reproduced with Stimulus in the Phlex port: shared primitives (dismissable layer, focus scope, roving focus, positioner, presence, typeahead, scroll lock, Turbo-cache restore), behavior families (overlay, menu, selection, disclosure, slider) and the per-component behavior spec. Use when writing `app/javascript/controllers/chadcn/*` or `app/javascript/chadcn/primitives/*` for the shadcn port, or auditing behavior parity."
---

# Radix behavior -> Stimulus

Complements `stimulus` (lifecycle, targets, Turbo) and `shadcn-port` (API/style/theme). This skill answers: *what must the controller do so keyboard, focus, ARIA and state changes are identical to Radix?*

## Applies to
- when: `app/javascript/**/*.js`
- when: `dev/port/specs/**/*.md`
- companion: `accessibility` always
- levels: method, class, system
- system-review: never
- note: Behavior parity (keyboard, focus, ARIA, `data-state`) is proven by the scenarios through `/shadcn-audit`; the per-component behavior spec is `dev/port/specs/<name>.md` (dev kit, not audited by /audit-feature).

## Quick Rules

Cite as `radix-stimulus R<n>`.

R1. **Behavior spec before code.** Each interactive component has a "Behavior" section in `dev/port/specs/<name>.md` (states, transitions, keys, focus rules, timers) written from the Radix source and the live catalog, not from memory.
R2. **Compose primitives, never copy.** Focus trapping, outside-dismiss, Esc handling, scroll lock, `aria-hidden` siblings, roving focus, typeahead, positioning, presence and the Turbo-cache restore (teardown on `turbo:before-cache`, set-up again once the snapshot is taken) live once in `app/javascript/chadcn/primitives/`. A controller importing floating-ui, adding `keydown` Esc logic directly or arming its own `turbo:before-cache` restore timer is wrong. → references/primitives.md
R3. **State is `data-state` (and friends) on the DOM.** Controllers mutate `data-state/data-highlighted/data-disabled/data-side/data-align/aria-*` exactly as Radix; Tailwind `data-[state=open]:` classes then work unchanged. No class toggling for state.
R4. **Server renders the initial state,** controller reconciles in `connect()` and on `*ValueChanged`. The first paint and the post-connect DOM are identical.
R5. **Events out use `this.dispatch`** with names from `shadcn-port` api-mapping (`open-change`, `value-change`, `checked-change`), `detail` carrying the new value, cancelable where Radix's `onOpenAutoFocus`/`onEscapeKeyDown` are preventable (`prevent-default`).
R6. **Presence.** Closing waits for CSS `animationend`/`transitionend` on `[data-state=closed]` before hiding/removing, exactly like Radix Presence; with `prefers-reduced-motion`/no animation it closes in the same frame.
R7. **Focus rules are part of the contract:** where focus goes on open, on close (return to trigger unless prevented), on select; `Tab` behavior (trap vs. leave); roving tabindex; focus ring only on `:focus-visible`.
R8. **Timing constants copied from Radix** (tooltip 700ms delay and 300ms skip, hover card 700/300, navigation menu 200/150, typeahead 1000ms reset, menu sub-pointer grace). Put them as Stimulus values with the Radix default.
R9. **Pointer details count:** `pointerdown` vs `click` (Select/Menu open on pointerdown), pointer capture (Slider), pointer-grace triangle (sub menus), touch vs mouse, `pointer-events: none` on body while a modal layer is open.
R10. **Cleanup everything** (listeners, observers, timers, floating-ui `autoUpdate`) in `disconnect()`; a Turbo cache restore must not leave a modal open or body scroll-locked. A controller that rewrites its DOM at connect time (mounted templates, portaled parts) uses `turbo_cache.js` to put the server markup back for the snapshot and set itself up again after it.
R11. **Accessibility is verified by the gate,** not assumed: if the DOM snapshot after each key step equals the oracle's, a11y equals Radix's. Do not add extra ARIA the oracle lacks.
R12. **One controller per component, named `chadcn--<name>`,** with values for every controllable prop from `shadcn-port` api-mapping (`open`, `value`, `default-value`, `disabled`, `modal`, `side`, `align`, `side-offset`...).

## Behavior families

| Family | Components | Shared primitives |
|---|---|---|
| Overlay (modal) | dialog, alert-dialog, sheet, drawer | `dismissable-layer`, `focus-scope`, `scroll-lock`, `hide-others`, `presence`, `portal` |
| Overlay (floating) | popover, hover-card, tooltip, select, combobox | + `positioner`, `presence`; tooltip/hover-card add `hover-intent` |
| Menu | dropdown-menu, context-menu, menubar, navigation-menu | + `roving-focus`, `typeahead`, `submenu-grace` |
| Selection | select, radio-group, toggle-group, tabs, command, combobox | `roving-focus`, `typeahead`, `collection` |
| Disclosure | accordion, collapsible | `presence` (+ height css vars) |
| Boolean/value | checkbox, switch, toggle, slider, progress, input-otp | `form-bubble-input` (hidden native input), `pointer-capture` (slider) |
| Media/layout | avatar, scroll-area, resizable, carousel, aspect-ratio | `image-loading-status`, `resize-observer`, library wrappers |
| Third-party wrappers | calendar, carousel, sonner, command, chart, input-otp, resizable, drawer | pinned library behind one controller (shadcn-port R14) |

## Verification mindset

The oracle is the running React catalog. Reading Radix source tells you *why*; the parity runner tells you *whether*. If the snapshot after "Tab, ArrowDown, Enter" differs, the controller is wrong regardless of how reasonable it looks.

## References

- `references/primitives.md`: the primitive modules, their API and which Radix package each replaces.
- `references/js-controller-tests.md`: the browser tests in `test/javascript` (touch, cancelable events, positioner options, layer nesting) and how to add one.
