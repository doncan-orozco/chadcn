# Accessibility Pass Checklist (WCAG 2.2 AA)

Use this checklist during implementation and code review of a component part, a primitive or a catalog page.

## Semantics

- Use native interactive elements (`button`, `a`) instead of clickable non-semantic containers; render the tag the oracle renders.
- Ensure `nav`, headings, lists, and `time[datetime]` are used where appropriate.
- Ensure form controls (`Input`, `Textarea`, `Checkbox`, `Switch`, `RadioGroup::Item`, `Select`) have visible labels (`Chadcn::Label` with `for:`) or accessible names.

## Keyboard and Focus

- Every interactive control is reachable by keyboard.
- Focus indicators are clearly visible (the oracle's `focus-visible:` classes, unchanged).
- Hover-only visual cues are mirrored for keyboard focus (`focus-visible`).
- No keyboard trap is introduced in menus, dialogs, sheets, or popovers: `focus_scope.js` traps only while a modal layer is open and releases on close.

## Labels and ARIA

- Every icon-only control has an accessible name (`aria-label` or sr-only text).
- Menu and dialog triggers expose the semantics the oracle has (`aria-haspopup`, `aria-expanded`, `aria-controls`) and nothing it lacks.
- ARIA is not used to replace native semantics when native HTML solves the need.

## Color and Contrast

- Body and helper text remains readable against background.
- Interactive text and controls remain readable across hover/focus/disabled states.
- Status communication does not rely on color alone (`data-state`, text or icon cue).
- A new theme preset passes `chadcn:theme:check` (text contrast of every fg/bg pair; `STRICT=1` makes contrast an error).

## Motion and State

- Loading/success/error states are communicated with readable text.
- Dynamic content updates preserve context for keyboard and screen reader users (focus returns to the trigger on close unless the caller prevents it).
- Animations come from `tw-animate-css` as in the oracle; `presence.js` unmounts at once when the closing element has no animation (`animation-name: none`), so an application that adds `motion-reduce:animate-none` closes in the same frame.

## Localizable defaults

- Default strings shipped by shadcn (sr-only "Close", "More") are kwargs whose default equals the React string; the consuming application passes its own text through the kwarg.

## Testing

- Prove the change with the parity gates (`/shadcn-audit <name>`); add a browser test in `test/javascript/` for behavior a scenario cannot express.
- Assert key attributes directly in unit tests (`aria-label`, `aria-haspopup`, `aria-controls`, `role`, `focus-visible` classes).
- Select elements by `data-slot`, role or accessible name, never by position or class strings.
