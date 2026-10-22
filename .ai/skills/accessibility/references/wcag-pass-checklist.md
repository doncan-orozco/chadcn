# Accessibility Pass Checklist (WCAG 2.2 AA)

Use this checklist during implementation and code review.

## Semantics

- Use native interactive elements (`button`, `a`) instead of clickable non-semantic containers.
- Ensure `nav`, headings, lists, and `time[datetime]` are used where appropriate.
- Ensure form controls have visible labels or accessible names.

## Keyboard and Focus

- Every interactive control is reachable by keyboard.
- Focus indicators are clearly visible.
- Hover-only visual cues are mirrored for keyboard focus (`focus-visible`).
- No keyboard trap is introduced in menus, dialogs, sheets, or modals.

## Labels and ARIA

- Every icon-only control has an accessible name (`aria-label` or sr-only text).
- Menu and dialog triggers expose correct semantics (`aria-haspopup`, `aria-controls`) when applicable.
- ARIA is not used to replace native semantics when native HTML solves the need.

## Color and Contrast

- Body and helper text remains readable against background.
- Interactive text and controls remain readable across hover/focus/disabled states.
- Status communication does not rely on color alone (include text/icon cue).

## Motion and State

- Loading/success/error states are communicated with readable text.
- Dynamic content updates preserve context for keyboard and screen reader users.

## I18n

- New accessible labels are added in both English and Spanish.
- Translation keys are fully qualified and domain appropriate.

## Testing

- Add or update a focused system test for changed accessibility behavior.
- Assert key attributes/classes directly (`aria-label`, `aria-haspopup`, `aria-controls`, focus classes).
- Prefer stable selectors (`:testid`) for asynchronous or structurally volatile UI.
