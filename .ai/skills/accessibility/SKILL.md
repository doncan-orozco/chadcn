---
name: accessibility
description: "WCAG 2.2 AA accessibility for the chadcn components (Phlex parts in `lib/chadcn/*`, Stimulus controllers in `app/javascript/controllers/chadcn/*`) and the dev kit's catalog pages. Use when editing a component's markup or behavior for focus states, contrast, keyboard navigation, accessible names of icon-only controls, overlay trigger semantics, or when proving an accessibility change with the parity gates and the browser tests."
---

# Accessibility (WCAG 2.2 AA)

The port reproduces Radix, which is accessible by construction: when the DOM after each scenario step equals the oracle's, the
ARIA, focus order and keyboard handling equal Radix's (`radix-stimulus` R11). This skill covers what that equality does not
decide: what a component must still do for keyboard and screen-reader users, and what the examples, defaults and catalog pages
of this repository must look like.

## Quick Rules

Cite as `accessibility R<n>`. Detail and examples follow below / in references/.

R1. **Keyboard reachable.** All interactive controls are keyboard reachable and visibly focusable (`focus-visible:` ring classes come verbatim from the oracle). → detail: Non-Negotiable Rules
R2. **Focus parity.** Every hover affordance on links/buttons has a matching `focus-visible` one (e.g. `hover:underline` + `focus-visible:underline`). → detail: Common Fix Patterns
R3. **Not color alone.** State is never communicated by color alone: `data-state`, text or an icon carries it too. → detail: Non-Negotiable Rules
R4. **Icon-only names.** Icon-only controls expose an accessible name via `aria-label` or adjacent sr-only text; the shadcn defaults (the sr-only "Close" of `Dialog::Content`) are kwargs the caller can override. → detail: Common Fix Patterns
R5. **Semantic first.** Use `button`, `a`, `nav`, `time[datetime]`, lists and headings before adding ARIA; render the tag the oracle renders. → detail: Non-Negotiable Rules
R6. **Readable secondary text.** Body/help/metadata text is not excessively muted (`text-muted-foreground` where the oracle uses it, never a fainter opacity of your own). → detail: Common Fix Patterns
R7. **Overlay triggers carry the oracle's semantics.** Modal/sheet/dialog/menu triggers carry exactly the `aria-haspopup`, `aria-expanded` and `aria-controls` the Radix output has, wired to the ids the controller sets; no extra ARIA the oracle lacks. → detail: Common Fix Patterns
R8. (dropped: host-only, bilingual EN/ES labels were a rule of the consuming application's locale files; the gem ships no translations, see R4 and `design-system` R13 for localizable defaults)
R9. **Proven, not eyeballed.** A changed accessible surface is proven by the parity gates (`/shadcn-audit <name>`, DOM equal to the oracle after each key step) and, for what a scenario cannot express (focus return after a cancelable event, nested layers, touch), by a browser test in `test/javascript/<name>.test.mjs` asserting `aria-*`, `data-state` and the focused element. → detail: Testing Guidance


Use this skill to enforce accessible UI behavior while implementing or reviewing a component, a primitive or a catalog page.

## Non-Negotiable Rules

- Keep all interactive controls keyboard reachable and visibly focusable.
- Match hover affordances with `focus-visible` affordances on links and buttons.
- Do not rely on color alone to communicate state.
- Ensure icon-only controls expose an accessible name via `aria-label` or adjacent sr-only text.
- Use semantic elements first (`button`, `a`, `nav`, `time[datetime]`, lists, headings).
- Keep text contrast readable for secondary content; the theme's contrast check (`chadcn:theme:check`) covers every fg/bg pair of a preset.
- Keep overlay triggers explicit with the ARIA the oracle emits; the controller sets the ids (`ids.js`) that `aria-controls` and `aria-labelledby` point at.
- Default strings are kwargs whose default equals the React string; components never translate (the consuming app passes its own text).

## Practical Workflow

1. Identify the part and its interaction model (link, button, menu trigger, modal trigger, status text) in `dev/port/specs/<name>.md` (Structure and Behavior sections).
2. Render the tag and ARIA the oracle renders; add nothing it lacks.
3. Add or correct accessible names for icon-only controls and unlabeled triggers (kwarg with the React default).
4. Add focus-visible parity for hover-only styles (the oracle's class string already has it; a deviation here needs `dev/port/deviations/<name>.json`).
5. Keep secondary text at the oracle's token.
6. Validate with the gates, then a browser test for what the gates cannot express.

## Common Fix Patterns

- Link styles:
  - Add `hover:underline` and `focus-visible:underline` together.
- Icon-only menu/button triggers:
  - `Chadcn::Button.new(size: "icon", aria: { label: "Open menu" })`; keep sr-only text where the oracle has it (`span(class: "sr-only") { close_label }`).
- Menu/dialog trigger semantics:
  - The Trigger part renders `aria-haspopup`/`aria-expanded`/`aria-controls` as Radix does; the controller updates `aria-expanded` with `data-state`.
- Secondary text readability:
  - Use the semantic token the oracle uses (`text-muted-foreground`), never a lower opacity of your own.

## Testing Guidance

- The parity gates compare the whole DOM (attributes, focus, `data-state`) with the React oracle after each scenario step: a passing G2/G3 run is the accessibility proof for everything a scenario can express.
- For the rest, add a browser test in `test/javascript/<name>.test.mjs` (`radix-stimulus` references/js-controller-tests.md): assert `aria-expanded`, `aria-controls` resolving to an existing id, the focused element after open/close, and Escape/arrow handling.
- Unit tests in `test/chadcn/<name>_test.rb` assert the server-rendered ARIA (`role`, `aria-checked`, `aria-label` default and override).

## Reference Map

- **[references/wcag-pass-checklist.md](references/wcag-pass-checklist.md)**
  Use for implementation-time and review-time acceptance checks.
- Pair with **[../design-system/SKILL.md](../design-system/SKILL.md)** for part structure, `**attrs` and localizable defaults.
- Pair with **[../radix-stimulus/SKILL.md](../radix-stimulus/SKILL.md)** for focus rules, keyboard tables and the primitives that implement them.
- Pair with **[../radix-stimulus/references/js-controller-tests.md](../radix-stimulus/references/js-controller-tests.md)** when adding a browser test for an accessibility behavior.
