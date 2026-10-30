---
name: stimulus
description: "Stimulus controllers of the chadcn gem (importmap pins, no bundler at development time; esbuild hosts get managed copies from the install generator). Use when creating or editing files in `app/javascript/controllers/chadcn/**` or `app/javascript/chadcn/primitives/**`, or when a Phlex part in `lib/chadcn/*` adds `data-controller`/`data-action`/targets/values. Covers lifecycle cleanup, declared targets/values/outlets, Turbo compatibility, naming, accessibility, and wiring between the Ruby part and the controller."
---

# Stimulus Controllers (chadcn)

## Applies to
- when: `app/javascript/**/*.js`
- companion: `accessibility` always
- levels: method, class, system
- system-review: when-touched
- note: Controllers (`app/javascript/controllers/chadcn/<name>_controller.js`) and primitives (`app/javascript/chadcn/primitives/<name>.js`); each file is audited as one unit (brick + room) by `stimulus-controller-auditor`.
- note: A Phlex part that renders `data-controller`, targets or values is not routed here; the part <-> controller wiring is the `STIMULUS_WIRING` mechanical check.

## Quick Rules
Cite as `stimulus R<n>`. Detail and examples follow below / in references/.

R1. **Behavior only.** Stimulus enhances the server-rendered part; it never renders pages, builds markup from interpolated data, or fetches HTML. Content that Radix keeps unmounted ships in an inert `<template>` and is mounted through `template_mount.js`. → detail: Turbo-first
R2. **Clean up in `disconnect()`.** Everything created in `connect()` (listeners, timers, observers, `AbortController`s, floating-ui `autoUpdate`, portaled or mounted nodes, primitive handles) is released in `disconnect()`. → detail: Lifecycle
R3. **Survive Turbo.** Controllers must tolerate Turbo cache restore and reconnecting; no one-shot setup that assumes a single `connect()`; a cached page never comes back with an open overlay or a locked body. → detail: Lifecycle
R4. **Declare the surface.** Every `this.xTarget|xValue|xOutlet|xClass` is declared in `static targets/values/outlets/classes`, and every declaration is used. → detail: Declared surface
R5. **Actions in markup.** Prefer `data-action` rendered by the Phlex part over `addEventListener`; when a listener is unavoidable (document, window, a mounted template), keep a named bound handler or an `AbortController` so it can be removed. → detail: Declared surface
R6. **Targets over selectors.** Use targets, not `document.querySelector`; reach other controllers via outlets or events (`this.dispatch`), never by importing them. → detail: Declared surface
R7. **No `innerHTML` with data.** Never assign `innerHTML` from interpolated or caller-supplied strings (XSS); use `textContent` or DOM APIs. → detail: Security
R8. **State in the DOM.** State lives in values, `data-state` and friends or data attributes, not module-level variables (the only module state allowed is the explicit stacks of the primitives, reset by their `release()`). → detail: Declared surface
R9. **No hardcoded copy.** User-facing strings arrive through values or data attributes rendered by the Phlex part from its kwargs (defaults equal the React strings, `design-system` R13); never literals in JS. → detail: Copy
R10. **Naming and registration.** `<name>_controller.js` in `app/javascript/controllers/chadcn/` ↔ `data-controller="chadcn--<name>"`; the gem's `config/importmap.rb` pins the directory and the host's `eagerLoadControllersFrom("controllers", application)` registers it; esbuild hosts register the managed copies through the generated `controllers/chadcn/index.js`. Do not hand-register. → detail: Naming
R11. **Accessible widgets.** Custom widgets manage focus on open/close, toggle `aria-expanded`/`aria-controls`, and handle Escape/Enter/arrows; no click-only interactions on non-buttons. → detail: `../accessibility/SKILL.md`
R12. **Reuse the primitives and sibling controllers.** Focus trapping, outside dismiss, Escape, scroll lock, positioning, presence, roving focus and typeahead already exist in `app/javascript/chadcn/primitives/` (`radix-stimulus` R2); behavior shared by two components (sheet and dialog) is imported, never copied. → detail: Reuse
R13. **Wiring is bilateral.** Each `data-controller` a part renders resolves to a file, and each target/value/action a controller expects exists in the markup the part renders. → detail: Wiring
R14. (dropped: host-only, engine parity described the controllers of the Papyro application's Studio engine; this gem has one controller directory, pinned by its own importmap)

## Where controllers live
- Controllers: `app/javascript/controllers/chadcn/<name>_controller.js`, identifiers `chadcn--<name>`, one per interactive component (`radix-stimulus` R12), plus `theme_controller.js` (`chadcn--theme`, toggles `.dark`).
- Shared primitives: `app/javascript/chadcn/primitives/<name>.js`, plain ES modules imported as `chadcn/primitives/<name>`.
- Pins: the gem's `config/importmap.rb` (`pin_all_from` both directories and the vendored `@floating-ui/dom`); `Chadcn::Engine` adds that file to the host importmap. Hosts without an importmap receive managed copies from `rails g chadcn:install --js esbuild` (README, "JavaScript pipelines"); the copies are regenerated, never edited.
- The dev kit's dummy app (`dev/dummy`) and the browser tests (`test/javascript`) load the same files through the same pins.

## Lifecycle
`connect()` sets up, `disconnect()` tears down. The overlay controllers keep the handles the primitives return and release every one of them in `disconnect()` (dismissable layer, focus scope, scroll lock, hide-others, presence, mounted template nodes); `tooltip_controller.js` releases its hover-intent handle. Use the same pattern for anything new, and reconcile the DOM with the values in `connect()` so a reconnect after a Turbo restore is idempotent (`radix-stimulus` R4, R10).

## Declared surface
Declare `static targets`, `values`, `outlets`, `classes` at the top. Values exist for every controllable prop of the React API (`open`, `value`, `default-value`, `disabled`, `modal`, `side`, `align`, `side-offset`...) with the Radix default. Guard optional targets with `this.hasXTarget`. Bind handlers once (`this.handleKeydown = (event) => …`) and remove the same reference.

## Turbo-first
The part is rendered on the server with its initial `data-state`; the controller never fetches fragments or relies on `DOMContentLoaded`. A Turbo cache snapshot is taken from the live DOM, so a controller must leave a closed, unlocked, un-portaled DOM behind when it disconnects and must tolerate being connected on a snapshot that still carries runtime attributes.

## Security
No `innerHTML` with dynamic data; no `eval`/`new Function`; everything the caller passes arrives as an attribute Phlex has already escaped.

## Copy
Pass copy as values or data attributes rendered by the Phlex part (`data-chadcn--<name>-<prop>-value`), whose kwarg defaults equal the React strings; the consuming application overrides the kwarg. Dates and numbers use `Intl` with the page locale.

## Naming
Domain names, no abbreviations (`naming-conventions`); value and target names mirror the React props (camelCase in JS, kebab-case in the attribute).

## Reuse
Before writing behavior, list `app/javascript/chadcn/primitives/` and the sibling controllers of the same behavior family (`radix-stimulus`, "Behavior families"). A second implementation of dismiss, focus trap, positioning, presence or typeahead is wrong even when it is shorter.

## Wiring
Check both directions when reviewing: the Phlex part (`lib/chadcn/<name>.rb`) → controller file, controller declarations → the markup the part renders (`data-chadcn--<name>-target`, `data-action`, values). Mismatched identifiers fail silently in the browser; the parity gates (G3) and the browser tests catch the symptom, the review catches the cause.

## Related
`../radix-stimulus/SKILL.md` (what the controller must do to equal Radix), `../design-system/SKILL.md` (the Phlex side that carries the data attributes), `../accessibility/SKILL.md`, `../testing/SKILL.md` (`bin/test-js`, `test/javascript`).
