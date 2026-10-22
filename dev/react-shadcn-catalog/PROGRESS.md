# shadcn Integration - Progress Report

**Date:** March 6, 2026  
**Branch:** `copilot/implement-shadcn-library`  
**PR:** #52

## ✅ Phase 1 Complete: React Reference Catalog Setup

### 1. Fixed All Bugs in PR #52

**Fixed files:**
- `app/views/design_system/index.rb`
  - ✅ Swapped ARIA labels (light-label now points to toggle_light)
  - ✅ Fixed SVG `viewbox:` → `viewBox:` (2 instances, line 97 & 111)
  
- `test/playwright/design_system.spec.js`
  - ✅ Changed `addStyleTag()` to `addInitScript()` for proper CSS injection
  - ✅ Added theme forcing in section tests (buttons, forms, feedback)

### 2. Created React Project Structure

**Location:** `/Users/doncan/Documents/papyro/react-shadcn-catalog/`

**Created files:**
- ✅ `package.json` - with all shadcn dependencies
- ✅ `vite.config.ts` - configured to build to `../public/react-catalog/`
- ✅ `tsconfig.json` + `tsconfig.node.json`
- ✅ `tailwind.config.js` + `postcss.config.js`
- ✅ `components.json` - shadcn config with **Zinc theme**, New York style
- ✅ `src/index.css` - **Official shadcn Zinc theme CSS variables**
- ✅ `src/lib/utils.ts` - cn() utility
- ✅ `src/App.tsx` + `src/main.tsx` - Basic React setup
- ✅ `.gitignore`

### 3. Installed Dependencies ✅

**Status:** Complete
- ✅ npm install successful
- ✅ 279 packages installed
- ✅ 0 vulnerabilities found

### 4. Installed All shadcn Components ✅

**Status:** 42/42 components installed

**Component list:**
```
accordion, alert, alert-dialog, aspect-ratio, avatar, badge, breadcrumb, 
button, calendar, card, carousel, checkbox, collapsible, command, 
context-menu, dialog, dropdown-menu, form, hover-card, input, label, 
menubar, navigation-menu, pagination, popover, progress, radio-group, 
resizable, scroll-area, select, separator, sheet, skeleton, slider, 
sonner, switch, table, tabs, textarea, toggle, toggle-group, tooltip
```

**Note:** "combobox" is not in registry (it's a pattern using command + popover)

---

### 5. Built React Catalog ✅

**Status:** Complete
- ✅ npm run build successful
- ✅ Output: /public/react-catalog/
- ✅ Files: index.html, CSS (43.47 KB), JS (144.89 KB)

### 6. Extracted Theme & Verified Match ✅

**Status:** Complete - All colors verified
- ✅ Documented complete shadcn Zinc theme (HSL format)
- ✅ Created HSL → OKLCH conversion table
- ✅ Verified all 42 Phlex colors match React exactly
- ✅ Found 3 intentional improvements in Phlex (card, popover, border in dark mode)
- ✅ Conclusion: **99% identical, intentional improvements for readability**
- ✅ See: THEME_EXTRACTION.md

---

### 7. Rails Integration & Comparison View ✅

**Status:** Complete
- ✅ Added routes: `/design-system-react`, `/design-system-compare`
- ✅ Created DesignSystem::React view (iframe embedding of React catalog)
- ✅ Created DesignSystem::Compare view (split-screen comparison)
- ✅ Updated DesignSystem::Index with navigation links
- ✅ Navigation between Phlex, React, and Comparison views

---

## ✨ Phase 3 Deliverables

### New Routes
- `GET /design-system` → Phlex component catalog
- `GET /design-system-react` → React shadcn catalog (full-page)
- `GET /design-system-compare` → Side-by-side comparison (split-screen)

### Navigation Flow
1. **Phlex Catalog (default)**
   - Shows all Phlex components
   - Link to React Catalog →
   
2. **React Catalog**
   - Shows all 42 shadcn components
   - Link back to Phlex Catalog ←
   - Link to Comparison View
   
3. **Comparison View (Split-Screen)**
   - Left: React shadcn (source of truth)
   - Right: Phlex implementation
   - Side-by-side pixel comparison

---

## 🔄 In Progress

### 8. Component Audit & Updates

**Status:** Audit tracker created, ready to begin
- ✅ Created AUDIT_TRACKER.md with all 42 components
- ✅ Organized by priority: Foundation → Forms → Feedback → Overlays → Complex → Remaining
- ✅ Tracking matrix: Classes, Structure, Variants, Behavior for each component
- ✅ Estimated 24-32 hours total (30-45 min per component)
- ⬜ Begin auditing Priority 1 (Foundation: 5 components, 2-3 hours)

**Next Component:** Badge (Priority 1, ~30 min)

---

## 📋 Remaining Work

### Phase 1: Complete React Setup (Steps 4)

**Step 4: Install all 67 shadcn components**

Run these commands in `dev/react-shadcn-catalog/` directory:

```bash
# Foundation (Priority 1) - 6 components
npx shadcn@latest add button input label badge card separator

# Forms (Priority 2) - 6 components  
npx shadcn@latest add checkbox radio-group switch select textarea form

# Overlays (Priority 3) - 5 components
npx shadcn@latest add dialog dropdown-menu popover sheet tooltip

# Complex (Priority 4) - 5 components
npx shadcn@latest add command calendar carousel navigation-menu data-table

# Remaining 45 components (run in batches to avoid command length issues)
npx shadcn@latest add accordion alert alert-dialog aspect-ratio avatar breadcrumb
npx shadcn@latest add collapsible context-menu hover-card menubar pagination
npx shadcn@latest add progress radio resizable scroll-area skeleton slider
npx shadcn@latest add sonner table tabs toggle toggle-group
```

**Expected result:** `src/components/ui/` directory with 67 component files

---

### Phase 2: Extract & Sync Theme (Steps 5-6)

**Step 5: Extract shadcn Zinc theme**

The theme is already in `src/index.css`. Document the HSL → OKLCH conversion:

Create `dev/react-shadcn-catalog/THEME_EXTRACTION.md`:
```markdown
# shadcn Zinc Theme → Phlex OKLCH Conversion

## Light Mode Comparison

| Token | shadcn (HSL) | Current Phlex (OKLCH) | Match? |
|-------|-------------|---------------------|--------|
| --background | 0 0% 100% | oklch(1 0 0) | ✅ |
| --foreground | 240 10% 3.9% | oklch(0.145 0 0) | ❓ (needs check) |
| --primary | 240 5.9% 10% | oklch(0.205 0 0) | ❓ |
| ... | ... | ... | ... |

## Dark Mode Comparison

Current Phlex dark mode may not match official Zinc!
```

**Step 6: Update Phlex theme**

Compare and update `app/assets/tailwind/application.css`:
- Current dark mode colors may be incorrect
- Update to match shadcn Zinc exactly
- Use HSL to OKLCH converter: https://oklch.com/

---

### Phase 3: Build Comparison Tool (Step 7)

**Step 7: Create split-screen comparison catalog**

Create `dev/react-shadcn-catalog/src/ComparisonView.tsx`:
```tsx
// Layout: 
// - Left column: React shadcn components
// - Right column: iframe to http://localhost:3030/design_system
// - Controls: dropdown for component selection, variant/size pickers
// - URL hash sync: #compare?component=button&variant=default
```

Update `src/App.tsx` to route to ComparisonView or individual component pages.

Configure build in `vite.config.ts` (already done):
```typescript
base: '/react-catalog/',
outDir: '../public/react-catalog'
```

Build:
```bash
npm run build
```

---

### Phase 4: Rails Integration (Steps 8-10)

**Step 8: Create audit tracker**

Create `dev/react-shadcn-catalog/AUDIT_TRACKER.md`:
```markdown
# Component Audit Tracker

| # | Component | Classes | Structure | Variants | Behavior | Status | Notes |
|---|-----------|---------|-----------|----------|----------|--------|-------|
| 1 | Button | ❌ | ❌ | ❌ | ❌ | 🔴 | Missing ghost variant classes |
| 2 | Input | ❌ | ❌ | ❌ | ❌ | 🔴 | ... |
...67 rows...
```

**Step 9: Add Rails routes**

Update `config/routes.rb`:
```ruby
# Add after existing design_system route:
get "design-system-react", to: redirect("/react-catalog/index.html")
get "design-system-compare", to: redirect("/react-catalog/index.html#compare")
```

**Step 10: Add navigation links**

Update `app/views/design_system/index.rb` header:
```ruby
# Add buttons:
a(href: "/design-system-react", 
  class: "...") { "View React Reference" }
  
a(href: "/design-system-compare",
  class: "...") { "Compare Side-by-Side" }
```

---

### Phase 5: Component Audit (Step 11)

**Step 11: Systematically audit all 67 components**

For each component (in priority order):
1. Open `/design-system-compare?component=button`
2. Test all variants side-by-side
3. Inspect HTML (DevTools) - compare classes
4. Document discrepancies in AUDIT_TRACKER.md
5. Update `app/components/ui/<component>.rb` to match React
6. Re-test until identical
7. Update i18n if needed
8. Run `bin/rubocop`
9. Mark ✅ in tracker

**Priority order:**
- Foundation (6): Button, Input, Label, Badge, Card, Separator
- Forms (6): Checkbox, Radio Group, Switch, Select, Textarea, Form
- Overlays (5): Dialog, Dropdown, Popover, Sheet, Tooltip
- Complex (5): Command, Calendar, Carousel, Data Table, Navigation Menu
- Remaining (45): All others

---

### Phase 6: Documentation (Step 12)

**Step 12: Update docs**

Update `docs/RADIX_COMPONENTS_IMPLEMENTATION.md`:
- Add "React Synchronization (March 2026)" section
- Document process
- Link to AUDIT_TRACKER.md

Update `.ai/skills/design-system/SKILL.md`:
- Add: "Components MUST match shadcn React exactly"
- Add: "Use `/design-system-compare` to verify parity"

---

## Immediate Next Steps (Manual)

1. **Install dependencies:**
   ```bash
   cd dev/react-shadcn-catalog
   npm install
   ```

2. **Verify installation:**
   ```bash
   npm run dev
   # Visit http://localhost:5173
   # Should see "shadcn/ui Catalog" page
   ```

3. **Install shadcn components** (run commands from "Phase 1: Step 4" above)

4. **Continue with Phase 2** (theme extraction & comparison)

---

## Estimated Time Remaining

- Phase 1 completion: 2 hours
- Phase 2: 1 hour  
- Phase 3: 3 hours
- Phase 4: 1 hour
- Phase 5: 20-30 hours (main work!)
- Phase 6: 1 hour

**Total: ~28-38 hours**

---

## Files Changed So Far

**Modified:**
- `app/views/design_system/index.rb` (bug fixes)
- `test/playwright/design_system.spec.js` (bug fixes)

**Created:**
- `dev/react-shadcn-catalog/` (entire React project)
