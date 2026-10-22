# Stimulus Interactive Components (shadcn → Phlex)

**Purpose:** Guide for converting interactive shadcn Radix UI components to Phlex with custom Stimulus controllers. This pattern enables full JavaScript interactivity while maintaining type-safety and Rails conventions.

**Applies to:** Switch, Tabs, Accordion, Dropdown, Select, Tooltip, Dialog, and all complex interactive components.

## Pattern Overview

**Level 1: Phlex Component** (`app/components/ui/`)
- Pure markup + semantic tokens
- NO event handlers or JavaScript
- Receives Stimulus `data-*` attributes via `**attrs`
- Stateless — values come via props or data attributes

**Level 2: Stimulus Controller** (`app/javascript/controllers/ui/`)
- Manages state (`values`), targets, and actions
- Responds to user input (click, keyboard, hover)
- Updates DOM attributes for styling via `data-state`, `data-open`, etc.
- Dispatches custom events for integration
- Keyboard navigation (Tab, Arrow keys, Escape)
- Floating UI positioning (for Tooltip/Dropdown)

**Level 3: Design System View** (`app/views/design_system/index.rb`)
- Fully wired interactive examples for documentation
- Data attributes demonstrate integration pattern
- Copy-paste ready for production use

## File Organization

```
app/components/ui/
  switch.rb                            # Switch + nested thumb helper
  tabs.rb                              # Tabs + nested list/trigger/content helpers
  accordion.rb                         # Accordion compound component
  dropdown_menu.rb                     # Dropdown compound component
  select.rb                            # Select + nested trigger/content/item/value helpers
  tooltip.rb                           # Tooltip + nested trigger/content helpers
  dialog.rb (+ dialog_* child files)

app/javascript/controllers/ui/
  base_controller.js                    # Shared utilities
  switch_controller.js                  # Toggle on/off
  tabs_controller.js                    # Tab switching
  accordion_controller.js                # Expand/collapse
  dropdown_controller.js                 # Menu navigation
  select_controller.js                   # Listbox selection
  tooltip_controller.js                  # Smart positioning
  dialog_controller.js                   # Modal management

config/importmap.rb
  pin "controllers/ui/base_controller"   # Explicit pin (doesn't follow naming convention)
  pin "@floating-ui/dom"                 # For positioning
```

## Critical Patterns (From Implementation Experience)

### JavaScript Syntax in Controllers
- ✅ NO escaped newlines (`\n`) in multi-line comments — write comments naturally
- ✅ Multi-line comment strings use actual line breaks, not escape sequences
- ❌ ❌ DO NOT write: `* Values:\n *   - item` in JSDoc — write actual newlines instead

### Phlex Component Initialization (Critical)
- ✅ EVERY component class needs `def initialize(**attrs)` method
- ✅ Applies to ROOT component AND all nested/child components
- ✅ Without this: `Component.new(data: {...})` throws `ArgumentError (wrong number of arguments)`
- ✅ Pattern: `def initialize(**attrs); @attrs = attrs; end`
- ✅ Pass keyword args on instantiation: `Calendar.new(mode: :single, open: false, data: {...})`

### Data Attribute Merging (Critical)
- ✅ If a component sets internal `data-*` attributes (for example `data-value` in Select items), merge internal and external data hashes
- ✅ Preserve internal required keys while allowing caller-provided Stimulus attributes/targets/actions
- ❌ Do not pass `data:` twice or overwrite internal keys with `**attrs` expansion

Example:
```ruby
merged_data = (@attrs[:data] || {}).merge(value: @value)
div(data: merged_data, **attrs_without_class.except(:data))
```

### Asset Pipeline Registration
- Pin base controller explicitly: `pin "controllers/ui/base_controller"`
- All other UI controllers auto-register if named `app/javascript/controllers/ui/*_controller.js`
- Syntax errors in ANY controller prevent it from loading — check console for "Failed to register"

## Implementation Steps

### Step 1: Create Stimulus Base Controller

**File:** `app/javascript/controllers/ui/base_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Shared utilities for all UI controllers
  toggleState(el, state) {
    el.dataset.state = state
    el.setAttribute('aria-selected', state === 'active')
  }

  findFocusable(container) {
    return container?.querySelector(
      'button, [href], input, textarea, [tabindex]:not([tabindex="-1"])'
    )
  }

  trapFocus(event, container) {
    // Standard focus trap pattern
  }

  preventBodyScroll() { document.body.style.overflow = 'hidden' }
  restoreBodyScroll() { document.body.style.overflow = '' }
}
```

### Step 2: Create Component-Specific Controller

Example: **Switch Controller** (`app/javascript/controllers/ui/switch_controller.js`)

```javascript
import BaseController from "controllers/ui/base_controller"

export default class extends BaseController {
  static values = {
    checked: Boolean,
    disabled: Boolean,
    name: String,
    value: { type: String, default: 'on' }
  }
  static targets = ["thumb", "input"]

  connect() {
    this.updateUI()
  }

  toggle(event) {
    event.preventDefault()
    if (this.disabledValue) return
    
    this.checkedValue = !this.checkedValue
    this.updateUI()
    this.dispatchStateChange()
  }

  updateUI() {
    this.element.dataset.state = this.checkedValue ? 'checked' : 'unchecked'
    this.element.setAttribute('aria-checked', this.checkedValue)
    
    if (this.hasThumbTarget) {
      this.thumbTarget.dataset.state = this.checkedValue ? 'checked' : 'unchecked'
    }

    if (this.hasInputTarget) {
      this.inputTarget.checked = this.checkedValue
      this.inputTarget.value = this.valueValue
    }
  }

  dispatchStateChange() {
    this.element.dispatchEvent(new CustomEvent('ui:switch:changed', {
      detail: { checked: this.checkedValue },
      bubbles: true
    }))
  }
}
```

### Step 3: Create Static Phlex Component

**File:** `app/components/ui/switch.rb`

```ruby
module Components
  module Ui
    class Switch < Components::Base
      def initialize(**attrs)
        @attrs = attrs
      end

      def view_template
        button(
          type: :button,
          role: :switch,
          class: merged_classes,
          **attrs_without_class.except(:checked)
        ) do
          yield if block_given?
        end
      end

      private

      def classes
        [
          "peer inline-flex h-5 w-9 shrink-0 cursor-pointer",
          "items-center rounded-full border-2 border-transparent shadow-sm",
          "transition-colors focus-visible:outline-none focus-visible:ring-2",
          "focus-visible:ring-ring focus-visible:ring-offset-2",
          "focus-visible:ring-offset-background disabled:cursor-not-allowed",
          "disabled:opacity-50",
          "data-[state=checked]:bg-primary data-[state=unchecked]:bg-input"
        ].join(" ")
      end
    end
  end
end
```

### Step 4: Update Importmap Configuration

**File:** `config/importmap.rb`

```ruby
# Pin explicit base controller (doesn't follow *_controller.js naming)
pin "controllers/ui/base_controller", to: "controllers/ui/base_controller.js"

# Floating UI for positioning (Tooltip, Dropdown)
pin "@floating-ui/core"
pin "@floating-ui/dom"

# Component controllers auto-registered via *_controller.js pattern
```

## Key Implementation Patterns

### 1. Data Attributes for State
```javascript
// Controller updates data-state for styling
//
// Dialog (modal) controllers should *not* animate manually. instead use
// Tailwind's data-state helpers and flip the state on the next animation frame:
//
//     showElement(el) {
//       el.hidden = false
//       requestAnimationFrame(() => { el.dataset.state = 'open' })
//     }
//
//     hideElement(el) {
//       el.addEventListener('animationend', e => el.hidden = true, { once: true })
//       el.dataset.state = 'closed'
//     }
//
// the animation durations are controlled in the Ruby components via
// `data-[state=open]:duration-500` / `data-[state=closed]:duration-300` etc.
this.element.dataset.state = 'open'  // or 'checked', 'active', etc.

// CSS responds to state changes (no additional classes needed)
// data-[state=open]:bg-primary, data-[state=checked]:translate-x-4
```

### 2. Stimulus Target Naming Convention
```ruby
# Phlex component passes target attribute
render Components::Ui::Dialog.new do |dialog|
  dialog.trigger { "Open" }
  dialog.content(hidden: true) { "Dialog body" }
end

# Controller declares targets
static targets = ["overlay", "content", "trigger"]

# Template accesses: this.overlayTarget, this.contentTarget, this.triggerTarget
```

⚠️ **Critical:** Stimulus target naming uses DOUBLE HYPHENS to match controller identifier:
- Controller: `data-controller="ui--dialog"`
- Target: `data-ui--dialog-target="overlay"` (NOT `ui__dialog_target`)

### 3. Values for Settings
```javascript
static values = {
  placement: { type: String, default: 'top' },
  delay: { type: Number, default: 200 },
  trigger: { type: String, default: 'click' }
}

// Access in template: data-ui--tooltip-placement-value="top"
// Access in code: this.placementValue
```

### 4. Floating UI for Positioning

For Tooltip/Dropdown with smart positioning:

```javascript
import { computePosition, offset, flip, shift } from "@floating-ui/dom"

async positionContent() {
  const { x, y } = await computePosition(
    this.triggerTarget,
    this.contentTarget,
    {
      placement: this.placementValue,
      middleware: [
        offset(this.offsetValue),
        flip(),
        shift({ padding: 8 })
      ]
    }
  )
  
  Object.assign(this.contentTarget.style, {
    left: `${x}px`,
    top: `${y}px`
  })
}
```

For Dropdown/Select overlays:
- Use `strategy: 'fixed'`
- Keep content hidden while computing position
- Use opacity-only transitions (not `transition-all`) to avoid animated jumps between old and new coordinates

### 5. Keyboard Navigation
- **Tab key:** Focus management, focus trap (Dialog)
- **Arrow keys:** Menu navigation (Dropdown, Tabs, Accordion)
- **Escape key:** Close (Dialog, Dropdown, Tooltip)
- **Space/Enter:** Activate (Switch, Button)

```javascript
keydown(event) {
  if (event.key === 'Escape' && this.openValue) {
    this.close()
  }
  if (event.key === 'ArrowDown') {
    this.focusNextItem()
  }
}
```

## Testing the Pattern

### 1. Verify DOM Updates
Inspect that `data-state`, `aria-*` attributes update on interaction:
```javascript
// In browser DevTools, expand element and verify:
// data-state="checked" | data-state="unchecked"
// aria-selected="true"
// aria-expanded="false"
```

### 2. Check Imports
If controllers don't load:
```bash
# Verify importmap pins are correct
node --check app/javascript/controllers/ui/switch_controller.js

# Check browser console for 404 errors on module imports
# Common issue: base_controller import uses wrong path
# Fix: Use importmap path, not relative path
# ❌ import BaseController from "./base_controller"
# ✅ import BaseController from "controllers/ui/base_controller"
```

## Complete Working Example (Switch)

```ruby
# app/components/ui/switch.rb
class Switch < Components::Base
  def view_template(&block)
    # Switch injects required controller/actions as defaults
    button(type: :button, role: :switch, class: "... semantic tokens ...") do
      yield self if block
    end
  end

  def thumb(**attrs, &block)
    # Thumb helper injects required target as default
    render Thumb.new(**attrs), &block
  end
end

# app/javascript/controllers/ui/switch_controller.js
export default class extends BaseController {
  static values = { checked: Boolean }
  toggle() { this.checkedValue = !this.checkedValue }
  // Updates data-state on value change
}

# app/views/design_system/index.rb
render Components::Ui::Switch.new(checked: false) do |switch|
  switch.thumb
end
```

## What's Included in Controllers

✅ **Fully Implemented:**
- Toggle/state management (Switch, Accordion, Dialog, Tabs)
- Keyboard navigation (Arrow keys, Tab, Escape, Space/Enter)
- Floating UI positioning (Tooltip, Dropdown)
- Focus trap and scroll lock (Dialog)
- ARIA attribute updates
- Custom event dispatching

✅ **Ready for Production:**
- All state changes verified in DOM
- All keyboard shortcuts tested
- All focus management patterns implemented

## Generating More Interactive Components

This pattern applies to **all** shadcn interactive components:

1. **Stateless UI:** Use pure Phlex components (Button, Card, Badge, Input, etc.)
2. **Simple Toggle:** Use Switch pattern (Switch, Checkbox, Radio)
3. **Navigation:** Use Tabs/Accordion pattern
4. **Menus:** Use Dropdown pattern
5. **Popups:** Use Tooltip pattern
6. **Modals:** Use Dialog pattern

**No additional learning required** — the pattern is consistent across all component types. Copy the pattern, adjust for component-specific behavior, and you're done.

## Common Issues & Fixes

### Issue: "Failed to register controller"
**Cause:** Import path is relative (`.`) instead of importmap path  
**Fix:** Use `import Name from "controllers/ui/controller_name"`

### Issue: Targets not found (404 error)
**Cause:** Module not pinned in importmap  
**Fix:** Add explicit pin for base_controller: `pin "controllers/ui/base_controller", to: "controllers/ui/base_controller.js"`

### Issue: Data attributes not updating
**Cause:** Wrong key shape in Phlex data hash  
**Fix:** In Ruby component calls, use underscore key form (for example `ui__dialog_target: "content"`), which renders as `data-ui--dialog-target="content"` in HTML

### Issue: Stimulus values not working
**Cause:** Attribute name doesn't match value declaration  
**Fix:** Match naming: `ui__dialog_open_value` in HTML → `openValue` in controller
