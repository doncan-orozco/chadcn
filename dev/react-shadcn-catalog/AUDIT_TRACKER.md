# shadcn → Phlex Component Audit Tracker

**Last Updated:** March 6, 2026  
**Total Components:** 42  
**Status:** 0/42 Complete (0%)

---

## Audit Process

This tracker can be driven manually or automated via the visual regression
suite included in `test/playwright/design_system.spec.js`.  Running

```bash
npm install        # install node dependencies, including Playwright
npm run test:visual
```

will visit both the Phlex and React catalogs, take screenshots for every
section and category, and surface differences.  The images are saved next
to the specs and can be compared against the audit tracker screenshots.
Use the generated output to inform updates to the Phlex components.

**Note:** the Phlex catalog has been refactored to mirror the React layout
— a top navigation bar with five categories (Foundation, Forms, Feedback,
Overlays, Complex) is now present, and sections are shown/hidden using a
Stimulus controller (`design-system`).  Playwright tests include assertions
that the category buttons toggle the appropriate sections.

For each component (manual or assisted):

1. ✅ **Open Comparison View** at `/design-system-compare`
2. ✅ **Navigate to component** in both React and Phlex catalogs (use the
   new category nav if helpful)
3. ✅ **Compare:**
   - Base classes and structure
   - All variants (default, secondary, destructive, outline, ghost, link)
   - Size modifiers (xs, sm, default, lg, xl)
   - State classes (hover, focus, active, disabled)
   - ARIA attributes and accessibility
   - Interactive behavior (clicks, keyboard nav, etc.)
4. ✅ **Update Phlex** if needed (in `app/components/ui/[component].rb`)
5. ✅ **Run Playwright tests to capture screenshots**
6. ✅ **Mark complete** and document findings

---

## Priority 1: Foundation (5 components) - ~2-3 hours

High-usage, simple components. Start here.

| Component | React File | Phlex File | Classes | Structure | Variants | Behavior | Status | Notes |
|-----------|-----------|-----------|---------|-----------|----------|----------|--------|-------|
| badge | badge.tsx | badge.rb | ⬜ | ⬜ | ⬜ | ⬜ | � In Progress | Started audit; checking variants || separator | separator.tsx | separator.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | move to foundation |
| skeleton | skeleton.tsx | skeleton.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | move to foundation || button | button.tsx | button.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | 6 variants, 4+ sizes, icon support |
| card | card.tsx | card.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | CardHeader, CardContent, CardFooter, CardTitle, CardDescription |
| separator | separator.tsx | separator.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Horizontal/vertical orientation |
| skeleton | skeleton.tsx | skeleton.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Loading placeholder animation |
### Badge Audit Notes

**Date:** 2026-03-06
**Auditor:** Doncan
**Time Spent:** 0h 15m

#### Findings:
- [ ] Base classes match? Yes
- [ ] Structure/markup identical? Reviewing container and span
- [ ] All variants implemented: default, secondary, destructive, outline
- [ ] Size modifiers not applicable (badge only has default size)
- [ ] States (hover/focus) present
- [ ] ARIA attributes: none needed
- [ ] Keyboard navigation: not interactive

#### Changes Made:
1. None yet; component already matches React

#### Playwright Tests:
- [ ] Visual regression test added? (pending)
- [ ] Behavior test added? (n/a)
- [ ] All tests passing
**Foundation Total:** 0/5 complete

---

## Priority 2: Forms (7 components) - ~4-5 hours

High-interaction components. Critical for user input.

| Component | React File | Phlex File | Classes | Structure | Variants | Behavior | Status | Notes |
|-----------|-----------|-----------|---------|-----------|----------|----------|--------|-------|
| input | input.tsx | input.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Text input, types (text, email, password, etc.) |
| label | label.tsx | label.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Form labels with htmlFor |
| checkbox | checkbox.tsx | checkbox.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Checkmark icon, checked/unchecked states |
| radio-group | radio-group.tsx | radio.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | RadioGroup + RadioGroupItem |
| switch | switch.tsx | switch.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Toggle with thumb animation |
| select | select.tsx | select.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | SelectTrigger, SelectContent, SelectItem |
| textarea | textarea.tsx | textarea.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Multi-line text input, resize behavior |

**Forms Total:** 0/7 complete

---

## Priority 3: Feedback (3 components) - ~2-3 hours

Status and messaging components.

| Component | React File | Phlex File | Classes | Structure | Variants | Behavior | Status | Notes |
|-----------|-----------|-----------|---------|-----------|----------|----------|--------|-------|
| alert | alert.tsx | alert.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Alert, AlertTitle, AlertDescription, variants |
| tabs | tabs.tsx | tabs.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Tabs, TabsList, TabsTrigger, TabsContent |
| progress | progress.tsx | progress.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Progress bar with indicator |

**Feedback Total:** 0/3 complete

---

## Priority 4: Overlays (5 components) - ~4-5 hours

Modal and popup components with complex behavior.

| Component | React File | Phlex File | Classes | Structure | Variants | Behavior | Status | Notes |
|-----------|-----------|-----------|---------|-----------|----------|----------|--------|-------|
| dialog | dialog.tsx | dialog.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Dialog, DialogTrigger, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter |
| alert-dialog | alert-dialog.tsx | alert_dialog.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | AlertDialog, AlertDialogAction, AlertDialogCancel |
| sheet | sheet.tsx | sheet.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Sheet, SheetTrigger, SheetContent, side variations |
| tooltip | tooltip.tsx | tooltip.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | TooltipProvider, Tooltip, TooltipTrigger, TooltipContent |
| popover | popover.tsx | popover.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Popover, PopoverTrigger, PopoverContent |

**Overlays Total:** 0/5 complete

---

## Priority 5: Complex (8 components) - ~6-8 hours

Advanced components with significant logic.

| Component | React File | Phlex File | Classes | Structure | Variants | Behavior | Status | Notes |
|-----------|-----------|-----------|---------|-----------|----------|----------|--------|-------|
| accordion | accordion.tsx | accordion.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Accordion, AccordionItem, AccordionTrigger, AccordionContent |
| calendar | calendar.tsx | calendar.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Date picker with react-day-picker |
| carousel | carousel.tsx | carousel.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Carousel with navigation, embla-carousel |
| command | command.tsx | command.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Command palette, search, keyboard nav |
| navigation-menu | navigation-menu.tsx | navigation_menu.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | NavigationMenu with dropdown |
| pagination | pagination.tsx | pagination.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Pagination with page numbers |
| slider | slider.tsx | slider.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Range slider with track and thumb |
| table | table.tsx | table.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Table, TableHeader, TableBody, TableRow, TableCell |

**Complex Total:** 0/8 complete

---

## Priority 6: Remaining (14 components) - ~6-8 hours

Additional components as needed.

| Component | React File | Phlex File | Classes | Structure | Variants | Behavior | Status | Notes |
|-----------|-----------|-----------|---------|-----------|----------|----------|--------|-------|
| aspect-ratio | aspect-ratio.tsx | aspect_ratio.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Container with fixed aspect ratio |
| avatar | avatar.tsx | avatar.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Avatar, AvatarImage, AvatarFallback |
| breadcrumb | breadcrumb.tsx | breadcrumb.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Breadcrumb navigation |
| collapsible | collapsible.tsx | collapsible.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Collapsible with trigger and content |
| context-menu | context-menu.tsx | context_menu.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Right-click context menu |
| dropdown-menu | dropdown-menu.tsx | dropdown_menu.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | DropdownMenu with items |
| form | form.tsx | form.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Form wrapper with validation |
| hover-card | hover-card.tsx | hover_card.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | HoverCard with trigger and content |
| menubar | menubar.tsx | menubar.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Menubar with menus |
| scroll-area | scroll-area.tsx | scroll_area.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Custom scrollable area |
| sonner | sonner.tsx | sonner.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Toast notifications |
| toggle | toggle.tsx | toggle.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Toggle button with variants |
| toggle-group | toggle-group.tsx | toggle_group.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Group of toggle buttons |
| form | form.tsx | form.rb | ⬜ | ⬜ | ⬜ | ⬜ | 🔴 Not Started | Form validation wrapper |

**Remaining Total:** 0/14 complete

---

## Overall Progress Summary

| Priority | Components | Complete | Percentage | Est. Hours | Status |
|----------|-----------|----------|------------|------------|--------|
| P1: Foundation | 5 | 0 | 0% | 2-3h | 🔴 Not Started |
| P2: Forms | 7 | 0 | 0% | 4-5h | 🔴 Not Started |
| P3: Feedback | 3 | 0 | 0% | 2-3h | 🔴 Not Started |
| P4: Overlays | 5 | 0 | 0% | 4-5h | 🔴 Not Started |
| P5: Complex | 8 | 0 | 0% | 6-8h | 🔴 Not Started |
| P6: Remaining | 14 | 0 | 0% | 6-8h | 🔴 Not Started |
| **TOTAL** | **42** | **0** | **0%** | **24-32h** | 🔴 Not Started |

---

## Status Legend

- 🔴 **Not Started** - Component not yet audited
- 🟡 **In Progress** - Currently auditing/updating
- 🟢 **Complete** - Verified and matches React exactly
- ⚠️ **Needs Update** - Phlex component requires changes
- ✅ **Verified** - Already matches perfectly

## Checklist Legend

- ⬜ Not checked
- ✅ Verified match
- ⚠️ Needs update
- ❌ Missing/broken

---

## Audit Notes Template

When auditing a component, document:

```markdown
### [Component Name]

**Date:** [Date]
**Auditor:** [Name]
**Time Spent:** [Duration]

#### Findings:
- [ ] Base classes match
- [ ] Structure/markup identical
- [ ] All variants implemented
- [ ] Size modifiers correct
- [ ] States (hover/focus/disabled) match
- [ ] ARIA attributes present
- [ ] Keyboard navigation works
- [ ] Animations/transitions match

#### Changes Made:
1. [Description of change 1]
2. [Description of change 2]

#### Screenshots:
- Before: [path/to/before.png]
- After: [path/to/after.png]

#### Playwright Tests:
- [ ] Visual regression test added
- [ ] Behavior test added
- [ ] All tests passing

#### Status: ✅ Complete
```

---

## Quick Start

1. **Start Rails server:** `bin/dev`
2. **Open comparison view:** http://localhost:3030/design-system-compare
3. **Pick first component** from Priority 1 (Badge)
4. **Compare side-by-side** React vs Phlex
5. **Update Phlex file** in `app/components/ui/badge.rb` if needed
6. **Run checks:** classes, variants, behavior, ARIA
7. **Mark complete** in this tracker
8. **Move to next component**

Estimated total time: **24-32 hours**
Average per component: **30-45 minutes**
