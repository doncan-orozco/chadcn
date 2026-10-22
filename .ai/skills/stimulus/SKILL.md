---
name: stimulus
description: "Stimulus controllers for Papyro (importmap, no bundler). Use when creating or editing files in `app/javascript/controllers/**` in the host or `app/javascript/controllers/studio/**` in the papyro_studio engine, or when adding `data-controller`/`data-action`/targets/values to Phlex views. Covers lifecycle cleanup, declared targets/values/outlets, Turbo compatibility, naming, accessibility, and wiring."
---

# Stimulus Controllers (Papyro)

## Quick Rules
Cite as `stimulus R<n>`. Detail and examples follow below / in references/.

R1. **Behavior only.** Stimulus enhances server-rendered HTML; it never renders pages, builds markup from interpolated data, or fetches HTML (use Turbo Frames/Streams). → detail: Turbo-first
R2. **Clean up in `disconnect()`.** Everything created in `connect()` (listeners, timers, observers, `AbortController`s, Floating UI instances, appended DOM nodes) is released in `disconnect()`. → detail: Lifecycle
R3. **Survive Turbo.** Controllers must tolerate Turbo cache restore and reconnecting; no one-shot setup that assumes a single `connect()`. → detail: Lifecycle
R4. **Declare the surface.** Every `this.xTarget|xValue|xOutlet|xClass` is declared in `static targets/values/outlets/classes`, and every declaration is used. → detail: Declared surface
R5. **Actions in markup.** Prefer `data-action` in the view over `addEventListener`; when a listener is unavoidable, keep a named bound handler so it can be removed. → detail: Declared surface
R6. **Targets over selectors.** Use targets, not `document.querySelector`; reach other controllers via outlets or events (`this.dispatch`), never by importing them. → detail: Declared surface
R7. **No `innerHTML` with data.** Never assign `innerHTML` from interpolated or user-supplied strings (XSS); use `textContent` or DOM APIs. → detail: Security
R8. **State in the DOM.** State lives in values, classes or data attributes, not module-level variables. → detail: Declared surface
R9. **No hardcoded copy.** User-facing strings arrive through values/data attributes rendered from `t(...)` in the view (EN + ES), never literals in JS. → detail: i18n
R10. **Naming and registration.** `foo_bar_controller.js` ↔ `data-controller="foo-bar"`; nested folders use `--` (`studio/articles/autosave_controller.js` ↔ `studio--articles--autosave`). Registration is by eager loading from the importmap; do not hand-register. → detail: Naming
R11. **Accessible widgets.** Custom widgets manage focus on open/close, toggle `aria-expanded`/`aria-controls`, and handle Escape/Enter/arrows; no click-only interactions on non-buttons. → detail: `../accessibility/SKILL.md`
R12. **Reuse existing controllers.** Dialog/overlay/locale/theme behavior already exists (`dialog`, `locale_switcher`, `lightbox`, `search`…); extend it, do not duplicate. → detail: Reuse
R13. **Wiring is bilateral.** Each `data-controller` in a view resolves to a file, and each target/value/action a controller expects exists in the markup that uses it. → detail: Wiring
R14. **Engine parity.** Engine controllers live in `papyro_studio/app/javascript/controllers/studio/**`, are pinned by the engine's `config/importmap.rb`, and follow the same rules. → detail: Repos

## Where controllers live (Repos)
- Host: `app/javascript/controllers/**` (loaded by `eagerLoadControllersFrom("controllers", application)`).
- Studio engine (sibling repo `papyro_studio`): `app/javascript/controllers/studio/**`, identifiers `studio--<folder>--<name>`; the engine's importmap initializer adds its paths to the host importmap. Views that use them are in the engine (`app/views`, `app/components/studio`).

## Lifecycle
`connect()` sets up, `disconnect()` tears down; the existing `lightbox_controller.js` removes its dialog, document listener and scroll lock on disconnect, and `autosave_controller.js` clears its debounce timer. Use the same pattern for anything new.

## Declared surface
Declare `static targets`, `values`, `outlets`, `classes` at the top. Guard optional targets with `this.hasXTarget`. Bind handlers once (`this.handleKeydown = (e) => …`) and remove the same reference.

## Turbo-first
Server responses are HTML via Turbo. Do not `fetch` fragments to inject; do not rely on `DOMContentLoaded`; form submissions go through Turbo with `requestSubmit()` where needed.

## Security
No `innerHTML` with dynamic data; no `eval`/`new Function`; sanitize anything inserted as HTML on the server.

## i18n
Pass copy as values (`data-foo-label-value="<%= t(...) %>"` rendered by Phlex) so locale switching works; dates and numbers use `Intl` with the page locale.

## Naming
Folders map to `--` in identifiers. Domain names, no abbreviations (`naming-conventions`).

## Reuse
Before writing a controller, list `app/javascript/controllers/` (and the engine's `studio/` folder) for existing behavior.

## Wiring
Check both directions when reviewing: view → controller file, controller declarations → markup. Mismatched identifiers fail silently in the browser.

## Related
`../phlex-view-pattern/SKILL.md` (views that carry the data attributes), `../accessibility/SKILL.md`, `../testing/SKILL.md` (system tests for Hotwire flows).
