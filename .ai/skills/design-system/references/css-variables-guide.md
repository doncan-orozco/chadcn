# CSS Variables Guide (Tailwind v4 + OKLCH)

**Purpose:** Setup guide for shadcn semantic color tokens using OKLCH color space in Tailwind CSS v4.

## Why OKLCH?

OKLCH (Oklch Lightness, Chroma, Hue) is a perceptually uniform color space that:
- Provides consistent perceived brightness across all hues
- Enables smooth gradients and color transitions
- Supports wide color gamut displays
- Is the official color space for shadcn + Tailwind v4

**Format:** `oklch(L C H)` or `oklch(L C H / A)`
- **L** (Lightness): 0 to 1 (0 = black, 1 = white)
- **C** (Chroma): 0 to ~0.4 (0 = grayscale, higher = more saturated)
- **H** (Hue): 0 to 360 degrees (0/360 = red, 120 = green, 240 = blue)
- **A** (Alpha): 0 to 1 (optional, for transparency)

## Complete CSS Variables Setup

### File Location

`app/assets/tailwind/application.css`

### Shadow Color Variable

The `--tw-shadow-color` variable is used by Tailwind's shadow utilities (like `shadow-sm`, `shadow-md`). When you use these utilities, Tailwind references this variable:

```css
.shadow-sm {
    --tw-shadow: 0 1px 3px 0 var(--tw-shadow-color, #0000001a), ...;
    box-shadow: ..., var(--tw-shadow);
}
```

**Light mode:** `oklch(0 0 0 / 10%)` = 10% opaque black (subtle shadows on light backgrounds)  
**Dark mode:** `oklch(0 0 0 / 30%)` = 30% opaque black (darker shadows needed on dark backgrounds)

### Full Configuration

**CRITICAL PATTERN:** Colors must be CSS custom properties in `:root`, then referenced in `@theme` using `var()`. This allows dark mode overrides to work automatically.

```css
@import "tailwindcss";

/* Light mode - CSS custom properties (in :root) */
:root {
  /* Primary (dark gray for buttons/actions) */
  --color-primary: oklch(0.205 0 0);
  --color-primary-foreground: oklch(0.989 0 0);

  /* Destructive (red for errors/warnings) */
  --color-destructive: oklch(0.577 0.245 27.325);
  --color-destructive-foreground: oklch(0.989 0 0);

  /* Secondary (light gray for secondary actions) */
  --color-secondary: oklch(0.97 0 0);
  --color-secondary-foreground: oklch(0.205 0 0);

  /* Muted (subtle backgrounds) */
  --color-muted: oklch(0.97 0 0);
  --color-muted-foreground: oklch(0.462 0.004 256.848);

  /* Accent (highlighted elements) */
  --color-accent: oklch(0.97 0 0);
  --color-accent-foreground: oklch(0.205 0 0);

  /* Background & Foreground (page-level) */
  --color-background: oklch(1 0 0);
  --color-foreground: oklch(0.089 0 0);

  /* Card (elevated surfaces) */
  --color-card: oklch(1 0 0);
  --color-card-foreground: oklch(0.089 0 0);

  /* Popover (floating elements) */
  --color-popover: oklch(1 0 0);
  --color-popover-foreground: oklch(0.089 0 0);

  /* Border (light gray, darker to contrast on white) */
  --color-border: oklch(0.88 0 0);

  /* Input (form controls) */
  --color-input: oklch(0.922 0 0);

  /* Ring (focus indicators) */
  --color-ring: oklch(0.708 0 0);

  /* Shadow color for box-shadow utilities */
  --tw-shadow-color: oklch(0 0 0 / 10%);
}

/* Tailwind @theme references the :root variables */
@theme {
  --color-primary: var(--color-primary);
  --color-primary-foreground: var(--color-primary-foreground);
  --color-destructive: var(--color-destructive);
  --color-destructive-foreground: var(--color-destructive-foreground);
  --color-secondary: var(--color-secondary);
  --color-secondary-foreground: var(--color-secondary-foreground);
  --color-muted: var(--color-muted);
  --color-muted-foreground: var(--color-muted-foreground);
  --color-accent: var(--color-accent);
  --color-accent-foreground: var(--color-accent-foreground);
  --color-background: var(--color-background);
  --color-foreground: var(--color-foreground);
  --color-card: var(--color-card);
  --color-card-foreground: var(--color-card-foreground);
  --color-popover: var(--color-popover);
  --color-popover-foreground: var(--color-popover-foreground);
  --color-border: var(--color-border);
  --color-input: var(--color-input);
  --color-ring: var(--color-ring);
}

/* Dark mode - override base values via html.dark */
html.dark {
    /* Primary (light gray for dark backgrounds) */
    --color-primary: oklch(0.922 0 0);
    --color-primary-foreground: oklch(0.205 0 0);

    /* Destructive (brighter red for visibility) */
    --color-destructive: oklch(0.704 0.191 22.216);
    --color-destructive-foreground: oklch(0.989 0 0);

    /* Secondary (dark gray for contrast) */
    --color-secondary: oklch(0.269 0 0);
    --color-secondary-foreground: oklch(0.989 0 0);

    /* Muted (darker backgrounds) */
    --color-muted: oklch(0.269 0 0);
    --color-muted-foreground: oklch(0.708 0 0);

    /* Accent (highlighted elements) */
    --color-accent: oklch(0.371 0 0);
    --color-accent-foreground: oklch(0.989 0 0);

    /* Background & Foreground (inverted) */
    --color-background: oklch(0.145 0 0);
    --color-foreground: oklch(0.989 0 0);

    /* Card (elevated surfaces) */
    --color-card: oklch(0.205 0 0);
    --color-card-foreground: oklch(0.989 0 0);

    /* Popover (floating elements) */
    --color-popover: oklch(0.269 0 0);
    --color-popover-foreground: oklch(0.989 0 0);

    /* Border (subtle separation) */
    --border: 0.269 0 0;
    --color-border: oklch(var(--border));

    /* Input (form controls) */
    --input: 0.269 0 0;
    --color-input: oklch(var(--input));

    /* Ring (focus indicators) */
    --color-ring: oklch(0.556 0 0);

    /* Shadow color (more opaque on dark backgrounds) */
    --tw-shadow-color: oklch(0 0 0 / 30%);
}
```

For opacity-aware borders, keep base values and apply opacity in base styles:

```css
@layer base {
  * {
    --tw-border-opacity: 1;
    border-color: oklch(var(--border) / var(--tw-border-opacity, 1));
  }
}
```

## How Dark Mode Works

**The magic:** When app toggles `dark` class on `<html>`:
1. `html.dark` overrides base token values (`--border`, `--primary`, etc.)
2. Wrapped semantic tokens (`--color-*`) resolve from those base values
3. `@theme` references wrapped variables via `var()`
4. All Tailwind classes automatically use the new colors

Example:
- Light: `--color-card: oklch(1 0 0)` = white card
- Dark: `--color-card: oklch(0.205 0 0)` = dark gray card
- Both use the same `bg-card` class, colors change automatically

## Semantic Token Usage

### In Tailwind Classes

```ruby
# Primary actions (buttons, links)
"bg-primary text-primary-foreground"

# Destructive actions (delete, cancel)
"bg-destructive/10 text-destructive"  # Subtle background with /10 opacity
"hover:bg-destructive/20"  # Hover with /20 opacity

# Secondary actions
"bg-secondary text-secondary-foreground"

# Muted/subtle elements
"bg-muted text-muted-foreground"

# Borders
"border-border"

# Cards/elevated surfaces
"bg-card text-card-foreground"

# Focus rings
"focus-visible:ring-ring"
```

### Opacity Modifiers

Tailwind automatically applies opacity to color tokens using `/` syntax:

```ruby
# 10% opacity (very subtle)
"bg-destructive/10"

# 20% opacity (subtle)
"bg-destructive/20"

# 40% opacity (more visible)
"ring-destructive/40"

# 90% opacity (nearly full)
"hover:bg-primary/90"
```

## Color Token Reference

### Primary Tokens

| Token | Light Mode | Dark Mode | Usage |
|-------|-----------|-----------|-------|
| `primary` | Dark gray (#0f172a-ish) | Light gray (#f1f5f9-ish) | Main actions, CTAs |
| `primary-foreground` | White (#fafafa) | Dark gray (#0f172a) | Text on primary |
| `destructive` | Red (#ef4444-ish) | Bright red | Errors, warnings, delete |
| `destructive-foreground` | White (#fafafa) | White | Text on destructive |
| `secondary` | Light gray (#f8fafc) | Dark gray (#1e293b) | Secondary actions |
| `secondary-foreground` | Dark gray (#0f172a) | White (#fafafa) | Text on secondary |

### Surface Tokens

| Token | Light Mode | Dark Mode | Usage |
|-------|-----------|-----------|-------|
| `background` | White (#ffffff) | Near black (#0f172a) | Page background |
| `foreground` | Near black (#020617) | White (#fafafa) | Page text |
| `card` | White (#ffffff) | Near black (#0f172a) | Elevated surfaces |
| `card-foreground` | Near black (#020617) | White (#fafafa) | Text on cards |
| `muted` | Light gray (#f8fafc) | Dark gray (#1e293b) | Subtle backgrounds |
| `muted-foreground` | Medium gray | Medium gray | Subtle text |

### Border & Input Tokens

| Token | Light Mode | Dark Mode | Usage |
|-------|-----------|-----------|-------|
| `border` | Light gray (#e2e8f0) | Dark gray + 10% opacity | Default borders |
| `input` | Gray (#e5e7eb) | Dark gray + 15% opacity | Form inputs |
| `ring` | Dark gray (#0f172a) | Medium gray | Focus indicators |

### Shadow Tokens

| Token | Light Mode | Dark Mode | Usage |
|-------|-----------|-----------|-------|
| `tw-shadow-color` | Black 10% opacity | Black 30% opacity | Shadow color fallback for utilities like `shadow-sm`, `shadow-md` |

## Color Space Comparison

### OKLCH vs Hex

```css
/* OKLCH (perceptually uniform) */
--color-primary: oklch(0.205 0 0);

/* Hex (device-dependent) */
--color-primary: #0f172a;
```

**Why OKLCH is better:**
- Consistent perceived brightness (0.205 = ~20% lightness)
- Easy to adjust lightness without changing hue
- Supports wider color gamut
- Official shadcn standard

### OKLCH vs LAB

```css
/* OKLCH (cylindrical, hue in degrees) */
--color-destructive: oklch(0.577 0.245 27.325);
/*                            ↑     ↑     ↑
                           Light Chroma Hue */

/* LAB (rectangular, no hue angle) */
--color-destructive: lab(57.7% 61.4 50.8);
/*                        ↑    ↑    ↑
                        Light  a    b */
```

**OKLCH advantages over LAB:**
- Hue is explicit (27.325° = red-orange)
- Easier to create color variations (adjust hue angle)
- Better for designers (matches HSL mental model)

## Adding New Colors

### Step 1: Choose Base Color

Use OKLCH color picker: https://oklch.com

Or convert from hex: https://colorjs.io/apps/convert/

```
Hex #ef4444 → oklch(0.627 0.258 14.463)
```

### Step 2: Create Light/Dark Variants

**Light mode:** Original color
```css
--color-custom: oklch(0.627 0.258 14.463);
```

**Dark mode:** Adjust lightness (increase for visibility on dark backgrounds)
```css
--color-custom: oklch(0.704 0.258 14.463);
/*                     ↑ Increased from 0.627 to 0.704 (+12% lightness) */
```

### Step 3: Create Foreground Color

**Light mode:** High contrast text (usually white or near-white)
```css
--color-custom-foreground: oklch(0.989 0 0);  /* White */
```

**Dark mode:** Inverted contrast (usually dark)
```css
--color-custom-foreground: oklch(0.205 0 0);  /* Dark gray */
```

### Step 4: Add Base + Wrapped Tokens

```css
:root {
  --custom: 0.627 0.258 14.463;
  --custom-foreground: 0.989 0 0;

  --color-custom: oklch(var(--custom));
  --color-custom-foreground: oklch(var(--custom-foreground));
}

html.dark {
  --custom: 0.704 0.258 14.463;
  --custom-foreground: 0.205 0 0;

  --color-custom: oklch(var(--custom));
  --color-custom-foreground: oklch(var(--custom-foreground));
}

@theme {
  --color-custom: var(--color-custom);
  --color-custom-foreground: var(--color-custom-foreground);
}
```

### Step 5: Use in Components

```ruby
# In Tailwind classes
"bg-custom text-custom-foreground"
"hover:bg-custom/90"
"border-custom/20"
```

## Troubleshooting

### Colors Not Showing

**Problem:** CSS variables not applied

**Solution:**
1. Verify `@import "tailwindcss";` is at the top of the file
2. Check `@theme` blocks are properly closed
3. Run `bin/dev` to rebuild Tailwind
4. Hard refresh browser (Cmd+Shift+R)

### Wrong Color Space

**Problem:** Browser shows hex instead of OKLCH

**Solution:**
```css
/* WRONG - Hex value */
--color-primary: #0f172a;

/* CORRECT - OKLCH format */
--color-primary: oklch(0.205 0 0);
```

### Dark Mode Not Working

**Problem:** Colors don't change in dark mode

**Solution:**
1. Verify `html.dark` override block exists
2. Check `html.dark` is toggled on `<html>`
3. Ensure both light and dark sections define the same base tokens
4. Test with browser DevTools dark mode toggle

### Opacity Not Working

**Problem:** `/10` syntax not applying opacity

**Solution:**
```ruby
# WRONG - Opacity in CSS variable
"--color-destructive: oklch(0.577 0.245 27.325 / 0.1)"

# CORRECT - Opacity in Tailwind class
"--color-destructive: oklch(0.577 0.245 27.325)"
# Then use: "bg-destructive/10"
```

For borders, keep opacity outside the token and use `--tw-border-opacity`.

### Color Looks Different Than shadcn

**Problem:** Visual mismatch with shadcn documentation

**Solution:**
1. Copy exact OKLCH values from https://ui.shadcn.com/docs/theming
2. Verify no HSL/hex conversion errors
3. Check browser supports OKLCH (all modern browsers do)
4. Inspect computed value in DevTools (should show `oklch(...)`)

## Converting Existing Colors

### From Hex to OKLCH

Use: https://colorjs.io/apps/convert/

```
Input:  #ef4444 (red)
Output: oklch(0.627 0.258 14.463)
```

### From HSL to OKLCH

```javascript
// In browser console
const hsl = 'hsl(4, 86%, 59%)';
const rgb = /* convert HSL to RGB */;
const oklch = /* convert RGB to OKLCH */;
console.log(oklch);
```

Or use online converter: https://oklch.com

### Batch Conversion Script

```ruby
# lib/tasks/convert_colors.rake
namespace :colors do
  desc "Convert hex colors to OKLCH"
  task convert: :environment do
    colors = {
      "#0f172a" => "primary",
      "#ef4444" => "destructive",
      "#f8fafc" => "secondary"
    }
    
    colors.each do |hex, name|
      # Use colorjs.io API or gem
      oklch = convert_hex_to_oklch(hex)
      puts "#{name}: oklch(#{oklch})"
    end
  end
end
```

## Troubleshooting

### Dark Mode Not Changing Components

**Problem:** Components stay the same color in light/dark mode

**Causes:**
1. Colors defined in `@theme` directly instead of `:root`
2. Missing `html.dark` override block
3. Dark mode base values not set in `html.dark`
4. Browser cache not cleared

**Solution:**
```css
/* WRONG - won't switch */
@theme {
  --color-card: oklch(1 0 0);  /* Only light mode */
}

/* CORRECT */
:root {
  --color-card: oklch(1 0 0);  /* Light mode */
}

@theme {
  --color-card: var(--color-card);  /* Reference variable */
}

html.dark {
  --card: 0.205 0 0;                  /* Dark mode base */
  --color-card: oklch(var(--card));   /* Wrapped token */
}
```

### Borders Not Visible

**Problem:** Border color blends into background

**Causes:**
1. Border lightness too similar to background
2. Light mode: border `oklch(0.922 0 0)` is too light on white card
3. Dark mode: border opacity too low

**Solution:**
- Light mode: Use `oklch(0.88 0 0)` for darker border on white
- Dark mode: Use `oklch(1 0 0 / 15%)` for visible separator

### Shadows Not Appearing

**Problem:** `shadow-sm`, `shadow-md` classes have no visible shadow

**Causes:**
1. `--tw-shadow-color` defined in `@theme` instead of `:root`
2. Missing shadow color variable entirely
3. Overridden by `box-shadow: none` in parent styles

**Solution:**
```css
:root {
  --tw-shadow-color: oklch(0 0 0 / 10%);  /* Light mode */
}

html.dark {
  --tw-shadow-color: oklch(0 0 0 / 30%);
}
```

### Browser DevTools Check

```javascript
// In browser console, verify CSS variables are set
console.log(getComputedStyle(document.documentElement).getPropertyValue('--color-card'))
console.log(getComputedStyle(document.documentElement).getPropertyValue('--tw-shadow-color'))

// Should output OKLCH values like:
// "oklch(1 0 0)"
// "oklch(0 0 0 / 0.1)"
```

## Reference

- **Official shadcn Theming:** https://ui.shadcn.com/docs/theming
- **OKLCH Color Space:** https://oklch.com
- **Color Converter:** https://colorjs.io/apps/convert/
- **Tailwind v4 @theme:** https://tailwindcss.com/docs/theme
- **CSS Color Module Level 4:** https://www.w3.org/TR/css-color-4/
