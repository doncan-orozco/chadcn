<h1 align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/doncan-orozco/chadcn/main/dev/brand/wordmark-dark.svg">
    <img src="https://raw.githubusercontent.com/doncan-orozco/chadcn/main/dev/brand/wordmark-light.svg" alt="chadcn" width="352" height="96">
  </picture>
</h1>

<p align="center"><strong>chadcn go brrrrrr</strong></p>

[shadcn/ui](https://ui.shadcn.com) for [Phlex](https://www.phlex.fun): the same component API, the same Tailwind class strings and
the same behavior as the React originals (Radix, and the libraries shadcn wraps), as Phlex views with Stimulus controllers. 54 components (`Button`, `Dialog`, `Select`, `Sidebar`,
`Toaster`, `Command`, `Combobox`, `Calendar`...), each one checked against the React original in a browser.

> Status: pre-release (0.x). The public API follows semantic versioning from the first release; see [CHANGELOG.md](CHANGELOG.md).
>
> chadcn is the Ruby gem (`gem "chadcn"`, on RubyGems). The `chadcn` package on npm is an unrelated project.

- One Ruby class per React export: `Dialog` is `Chadcn::Dialog`, `DialogContent` is `Chadcn::Dialog::Content`.
- Props are keyword arguments (`variant: "outline"`, `default_open: true`), `className` is `class:`, children are the block.
- Behavior lives in Stimulus controllers named `chadcn--<component>`; they ship in the gem with the shared primitives they use.
- Colors come from one shadcn-format theme file you own; anything pasted from ui.shadcn.com/themes works unchanged.

## Why chadcn

| The virgin hand-rolled UI | The chad chadcn |
|---|---|
| Copies component files into the app, one by one | `bundle add chadcn` and one generator: `bin/rails g chadcn:install` |
| Re-applies upstream fixes to every copied file by hand | Upgrades are a `bundle update` |
| Ships a React runtime for one dropdown | Radix behavior as Stimulus controllers, zero React |
| Eyeballs the dialog and hopes it matches | 54 components checked against the React original in a browser |
| Pulls in a framework's worth of gems to render a button | Three runtime dependencies: `phlex`, `tailwind_merge`, `zeitwerk` |
| Re-types the theme colors by hand | Pastes a theme from ui.shadcn.com/themes, unchanged |
| Greps the app to find out why the styles are missing | `bin/rails chadcn:doctor` says why |
| Renders every page through a stack of partials | Phlex: 5x faster (benchmark: trust me bro) |

The facts behind the right column (all but the last row, which is a joke):

- **The shadcn markup, verbatim.** Class strings, structure, `data-slot` attributes and variants are copied from the shadcn/ui
  registry, so the HTML follows the React original (each deliberate difference is recorded in `dev/port/DEVIATIONS.md` and
  `dev/port/deviations/` of the repository) and shadcn's documentation, themes and examples apply.
- **Radix-equivalent behavior.** Dialogs, menus, selects, tooltips and the rest are Stimulus controllers on shared primitives
  (dismissable layer, focus scope, roving focus, positioning, scroll lock...). In the repository's dev kit (not packaged), browser
  parity tests render every component next to the React original and compare DOM, styles and behavior.
- **Small runtime.** The only runtime dependencies are `phlex`, `tailwind_merge` and `zeitwerk`: no Active Support, no Nokogiri, and no
  new JavaScript library for `Toaster`, `Command`, `Combobox` or `Calendar` (besides Stimulus, the only JavaScript dependency is
  `@floating-ui/dom` for positioning, vendored for importmap apps and added from npm for esbuild apps).
- **Upgrades are a `bundle update`** (and your usual `tailwindcss:build`). The components, controllers and CSS live in the gem, not copied into your app (the two
  exceptions you opt into: [ejected components](#eject-a-component) and, with esbuild, the managed JavaScript copies).
- **An escape hatch.** [Eject](#eject-a-component) one component into your app when you need to change its markup, and keep the rest
  upgrading with the gem.

## Requirements

- Ruby 3.3 or newer and [Phlex](https://www.phlex.fun) 2.x from 2.3 (`~> 2.3`; Phlex 3 is not supported). CI runs the gem suite
  on Ruby 3.3, 3.4 and 4.0, each against the current Phlex 2.x and against Phlex 2.3.
- Tailwind CSS 4 (the components use Tailwind utility classes). With Rails, `tailwindcss-rails` 4.3.0 or newer: 4.3.0 is the first release that
  bundles an engine's CSS (`tailwindcss:engines`), which is how the gem's styles reach your app. `chadcn:doctor` reports an older one as a failure.
- For the interactive components: Stimulus 3 (`@hotwired/stimulus`). With Rails, `importmap-rails` (the gem's engine adds its pins) or
  `jsbundling-rails` with esbuild (see [JavaScript pipelines](#javascript-pipelines)).
- With Rails, `phlex-rails` renders Phlex views from controllers; the gem itself depends only on `phlex`, `tailwind_merge` and
  `zeitwerk` (no Nokogiri, no Active Support).
- The supported versions of Ruby, Phlex, Rails and the asset pipelines, what CI proves and the Phlex 3 policy are in
  [docs/compatibility.md](docs/compatibility.md).

## Rails: from zero to a Button and a Dialog

Add the gem and run the install generator (it needs `tailwindcss-rails` to be installed already, `bin/rails tailwindcss:install`):

```ruby
# Gemfile
gem "phlex-rails"
gem "chadcn"
```

```bash
bundle install
bin/rails g chadcn:install
bin/rails tailwindcss:build
```

The generator writes one managed block right after `@import "tailwindcss";` in `app/assets/tailwind/application.css` (`--css` to
point at another entry file):

```css
@import "tailwindcss";
/* chadcn:start (managed by rails g chadcn:install) */
@import "../builds/tailwind/chadcn";
@import "./theme/theme.css";
/* chadcn:end */
```

- `../builds/tailwind/chadcn` is the engine bundle `tailwindcss-rails` builds from the gem's `engine.css` (Tailwind variant
  plugins, the token mapping from theme variables to utilities, the vendored animations). `engine.css` also carries a self-relative
  `@source` for the gem's Ruby files: Tailwind 4 only generates the classes it finds in scanned files, and this is how it finds the
  components' classes. The block is the same on every machine, so a `bundle update` that moves the gem cannot unstyle the app.
- `theme/theme.css` and `theme/presets/` are copied into `app/assets/tailwind/theme/` (or `--theme-dir`) once and never
  overwritten: the theme is yours to edit.

The generator is idempotent: a second run rewrites the same block and skips the files that already exist. Edits inside the markers
are lost on the next run; everything outside them is left alone.

Stimulus needs nothing from you when the app uses the default `app/javascript/controllers/index.js`
(`eagerLoadControllersFrom("controllers", application)`): the engine pins the gem's controllers under `controllers/chadcn/`, so they
register as `chadcn--dialog`, `chadcn--select`, and so on. An app that registers controllers by hand imports and registers them
itself:

```js
// app/javascript/controllers/index.js
import DialogController from "controllers/chadcn/dialog_controller"
application.register("chadcn--dialog", DialogController)
```

Now render a Button and a Dialog from a Phlex view (`phlex-rails`; `bin/rails g phlex:install` sets up `app/views` and
`app/components` if you have not done it yet):

```ruby
# app/views/demo/index.rb
class Views::Demo::Index < Views::Base
  def view_template
    render Chadcn::Button.new(variant: "outline") { "Save" }

    render Chadcn::Dialog.new do |dialog|
      dialog.trigger(as_child: Chadcn::Button.new) { "Edit profile" }
      dialog.content do
        dialog.header do
          dialog.title { "Edit profile" }
          dialog.description { "Make changes to your profile here." }
        end
        dialog.footer { render Chadcn::Button.new(type: "submit") { "Save changes" } }
      end
    end
  end
end
```

```ruby
# app/controllers/demo_controller.rb
class DemoController < ApplicationController
  def index = render Views::Demo::Index.new
end
```

The Button renders `<button data-slot="button" data-variant="outline" data-size="default" class="...">Save</button>` with the exact
shadcn class string; clicking the trigger opens a modal dialog with the overlay, focus trap, Escape and outside-click dismissal
of Radix Dialog.

### JavaScript pipelines

`rails g chadcn:install --js auto|importmap|esbuild` chooses how the gem's Stimulus controllers reach the browser. The default,
`auto`, detects the pipeline: a `config/importmap.rb` means importmap; otherwise a `package.json` together with `jsbundling-rails` in the
bundle (or an `esbuild` build script in `package.json`) means esbuild. `--js importmap` or `--js esbuild` overrides the detection (any jsbundling-rails app is treated as esbuild; only esbuild is smoke-tested);
when neither is found the generator says so and writes no JavaScript.

- **importmap** (Rails' default and the setup above): nothing is written, the engine pins the controllers, the primitives and the
  vendored `@floating-ui/dom`.
- **esbuild** (no importmap, so nothing pins the gem's files): the generator copies the gem's controllers into
  `app/javascript/controllers/chadcn/` and its primitives into `app/javascript/chadcn/primitives/` (managed copies with relative
  imports and a "managed by" header; edits are overwritten), writes `app/javascript/controllers/chadcn/index.js` (it registers every
  controller as `chadcn--<name>` with your `application`), adds `import "./controllers/chadcn"` to `app/javascript/application.js`
  and adds `@floating-ui/dom` to `package.json` with your package manager (yarn, pnpm or bun when their lock file is present,
  npm otherwise). Run `bin/rails javascript:build` afterwards. The copies are the only part of the gem that can go stale: run the
  generator again after every gem update (it is idempotent and prints `identical` for current files), and `bin/rails chadcn:doctor`
  fails when a copy is missing or differs. The reasoning is in `dev/decisions/js-bundlers.md` of the repository (not packaged).

### Asset pipelines

| Rails | Assets | JavaScript | Status |
|---|---|---|---|
| 8.1 | Propshaft | importmap | supported, the default setup; covered by the clean-app smoke in CI |
| 8.1 | Propshaft | esbuild (jsbundling-rails) | supported; covered by a CI smoke (`bin/smoke --app --js esbuild`, job `clean-app-variants`) |
| 8.1 | Sprockets 4 (sprockets-rails 3.5) | importmap | supported; covered by a CI smoke (`bin/smoke --app --assets sprockets`, job `clean-app-variants`) |
| 8.1 | Sprockets | esbuild | not covered: no smoke proves it |
| any | Sprockets below 4, or Sass/SCSS instead of the Tailwind CLI | any | not supported |

On Sprockets 4 the engine declares the gem's JavaScript precompiled itself (sprockets-rails refuses assets that are not declared, and
your `manifest.js` cannot link files inside a gem). Your `app/assets/config/manifest.js` has to link the Tailwind build
(`//= link_tree ../builds`, which `tailwindcss-rails` writes, or `//= link tailwind.css`) and the layout uses
`stylesheet_link_tag "tailwind"`. The Propshaft-only
`hide_tailwind_stubs` option does nothing under Sprockets. The doctor names the pipeline and checks the manifest. Details:
`dev/decisions/sprockets.md` in the repository.

### Check the setup: the doctor

```bash
bin/rails chadcn:doctor                # one PASS / WARN / FAIL line per check, a "fix:" line under each problem
JSON=1 bin/rails chadcn:doctor         # the same as JSON, for CI and agents (bin/rails "chadcn:doctor[json]" does the same)
CSS=app/assets/tailwind/admin.css bin/rails chadcn:doctor   # a Tailwind entry file other than app/assets/tailwind/application.css
```

The task exits 1 when any check fails (warnings do not fail it), so it can gate a CI job. The checks, one file each under
`lib/chadcn/doctor/checks/`:

| Check | Looks at |
|---|---|
| `asset pipeline` | Propshaft or Sprockets (below 4 warns), and for Sprockets that `manifest.js` links the Tailwind build |
| `ejected components` | stale or incomplete ejected copies (see [Eject](#eject-a-component)) |
| `engine bundle` | the managed block imports the engine bundle and `tailwindcss:build` has built it |
| `javascript pipeline` | importmap-rails, or the esbuild copies being present, registered and current |
| `phlex versions` | Phlex inside `~> 2.3`, and phlex-rails on the same major |
| `propshaft stub filter` | the hook that hides the Tailwind stubs works (not applicable without Propshaft) |
| `source block` | the managed block exists and imports the engine bundle, whose `engine.css` carries the `@source` for the gem's Ruby files (a leftover `@source` line from an older generator warns) |
| `stimulus controllers` | the gem's `chadcn--*` controllers get registered |
| `tailwind` | `tailwindcss-rails` 4.3.0 or newer (a 4.x below it fails with `tailwindcss-rails X found, it cannot bundle an engine's CSS before 4.3.0`, a 3.x with `tailwindcss-rails X found, the engine bundle needs tailwindcss-rails 4`) and Tailwind 4, and `@import "tailwindcss"` in the entry file |
| `theme files` | `theme.css` and `presets/` in the theme directory |
| `theme import` | the managed block imports `theme.css` |

A run on a healthy app (paths shortened):

```
[PASS] asset pipeline: Propshaft 1.3.2
[PASS] ejected components: nothing ejected (every component loads from the gem)
[PASS] engine bundle: app/assets/builds/tailwind/chadcn is imported and built
[PASS] javascript pipeline: importmap-rails 2.2.3: the gem's controllers and primitives are pinned by its engine
[PASS] phlex versions: phlex 2.4.1 (~> 2.3), phlex-rails 2.4.0
[PASS] propshaft stub filter: the Tailwind stubs are hidden from the served assets
[PASS] source block: the engine bundle carries the @source for the gem's Ruby files
[PASS] stimulus controllers: app/javascript/controllers/index.js registers the controllers namespace, where the gem's chadcn--* controllers are
[PASS] tailwind: tailwindcss-rails 4.6.0, Tailwind 4.3.3
[PASS] theme files: theme.css and presets/ in app/assets/tailwind/theme
[PASS] theme import: the block imports app/assets/tailwind/theme/theme.css

11 passed, 0 warnings, 0 failed
```

### Configuration (`config/application.rb`)

```ruby
config.chadcn.theme_dir = "app/assets/tailwind/theme"  # where theme.css and presets/ live; relative to the app root
config.chadcn.theme_task_aliases = true                 # false when the app defines its own theme:* rake tasks
config.chadcn.hide_tailwind_stubs = true                # false to leave the tailwindcss-rails stubs to Propshaft
config.chadcn.override_dir = "app/components/chadcn"  # ejected components; see Eject a component
```

`hide_tailwind_stubs` keeps the stubs tailwindcss-rails writes to `app/assets/builds/tailwind/` (Tailwind input, not browser
stylesheets) out of `stylesheet_link_tag :app` through a guarded hook into Propshaft's private file filter. When a Propshaft release
drops that hook the engine logs a warning at boot and serves the stubs again: link `"tailwind"` explicitly instead of `:app`, or set
the option to `false` to silence the warning. Like `theme_task_aliases`, set it in `config/application.rb`.

`theme_dir` precedence at boot: `config.chadcn.theme_dir`, then a value set with `Chadcn.configure` before the app
initializes, then the default. In a Rails app set it in `config/application.rb`, not in an initializer: a `configure` call in
`config/initializers` runs after the engine and overrides the app setting with a path that is not rooted at the app.

## Without Rails

```ruby
require "chadcn"

Chadcn::Button.new(variant: "outline") { "Save" }.call
# => "<button data-slot=\"button\" data-variant=\"outline\" data-size=\"default\" class=\"...\">Save</button>"
```

Any Phlex component can `render` the gem's components; `Chadcn.root` is the installed gem directory.

Tailwind: import the gem's entry point and your theme from your Tailwind entry file. `engine.css` carries its own `@source` for the
gem's Ruby files (relative to itself, so it follows the gem), the token mapping and the vendored animations:

```css
@import "tailwindcss";
@import "<gem root>/app/assets/tailwind/chadcn/engine.css";
@import "./theme/theme.css";
```

Copy `app/assets/tailwind/chadcn/theme.css` (and `presets/`) out of the gem into your project; that copy is the file you edit.
`ruby -e 'require "chadcn"; puts Chadcn.root'` prints the gem root.

Stimulus: the controllers are ES modules under `<gem root>/app/javascript/controllers/chadcn/<name>_controller.js` and the shared
primitives live under `<gem root>/app/javascript/chadcn/primitives/<name>.js`. They import each other by bare, extensionless
specifiers: `controllers/chadcn/<name>_controller` (`alert_dialog_controller` and `sheet_controller` import the dialog controller,
`context_menu_controller` imports the dropdown menu controller), `chadcn/primitives/<name>` (`typeahead` imports `collection`; `roving_focus` imports
`direction`, `ids` and `collection`; `collapsible_content` imports `presence`), `@hotwired/stimulus` and, for the positioned overlays and menus, `@floating-ui/dom` (imported by `positioner`). The vendored copy in
`<gem root>/vendor/javascript/@floating-ui--*.js` imports `@floating-ui/core`, `@floating-ui/utils` and `@floating-ui/utils/dom`
in turn (or take `@floating-ui/dom` from npm). You have to resolve all of those specifiers yourself, in one of two ways.

1. A browser import map with one entry per file. A prefix entry such as `"chadcn/"` does not work: the specifiers carry no `.js`, so
   the browser would request a URL without an extension. For the Dialog the controller and the primitives it imports (it needs
   no Floating UI) are:

   ```html
   <script type="importmap">
   {
     "imports": {
       "@hotwired/stimulus": "/vendor/stimulus.js",
       "controllers/chadcn/dialog_controller": "/chadcn/controllers/chadcn/dialog_controller.js",
       "chadcn/primitives/dismissable_layer": "/chadcn/primitives/dismissable_layer.js",
       "chadcn/primitives/focus_guards": "/chadcn/primitives/focus_guards.js",
       "chadcn/primitives/focus_scope": "/chadcn/primitives/focus_scope.js",
       "chadcn/primitives/hide_others": "/chadcn/primitives/hide_others.js",
       "chadcn/primitives/presence": "/chadcn/primitives/presence.js",
       "chadcn/primitives/scroll_lock": "/chadcn/primitives/scroll_lock.js",
       "chadcn/primitives/template_mount": "/chadcn/primitives/template_mount.js"
     }
   }
   </script>
   ```

   Serve the two gem directories at those URLs. For other controllers add one line per file in both directories (and the four
   `@floating-ui--*.js` files for the positioned ones).

2. A bundler alias: map `controllers/chadcn` to `<gem root>/app/javascript/controllers/chadcn` and `chadcn` to
   `<gem root>/app/javascript/chadcn`, and install `@floating-ui/dom` from npm.

Rails apps on importmap-rails need none of this (the engine pins everything in `config/importmap.rb`); esbuild apps use the generator, see [JavaScript pipelines](#javascript-pipelines). Then register each
controller under its `chadcn--<name>` identifier:

```js
import { Application } from "@hotwired/stimulus"
import DialogController from "controllers/chadcn/dialog_controller"

const application = Application.start()
application.register("chadcn--dialog", DialogController)
```

The theme tooling works too once the directory is configured: `Chadcn.configure { |config| config.theme_dir = "/path/to/theme" }`,
then `Chadcn::Theme.use("slate")`, `Theme.import(path_or_url)` and `Theme.check(strict: true)`.

Generated ids are numbered per top-level render (`Chadcn::Dialog.new.call` always starts at `dialog-1`). A page assembled from
several `call`s repeats them, so either pass `id:` to the roots or give the gem a store that lives for the request: a callable
answering a Hash, for example from a Rack middleware that sets a thread-local Hash for the request:

```ruby
Chadcn.configure { |config| config.sequence_store = -> { Thread.current[:chadcn_sequences] } }
# in the middleware: Thread.current[:chadcn_sequences] = {} before the request, nil after it
```

The Rails engine does this itself, with a store the Rails executor resets when every request completes.

## Using the components

The 1:1 classes are the canonical API; a compound root also yields itself with one generated helper per part. Both forms render the
same HTML and can be mixed:

```ruby
# explicit classes, one per React export
render Chadcn::Card.new do
  render Chadcn::Card::Header.new { render Chadcn::Card::Title.new { "Settings" } }
  render Chadcn::Card::Content.new { "..." }
end

# generated helpers on the yielded root (card.header is exactly render Card::Header.new(**attrs), &block)
render Chadcn::Card.new do |card|
  card.header { card.title { "Settings" } }
  card.content { "..." }
end
```

- Every class takes `**attrs`: `class:` is merged last through tailwind-merge (your classes win on conflicts), `data:` and `aria:`
  hashes deep-merge with the component's own, React DOM prop names are accepted (`tab_index:`, `html_for:`), and flat `"aria-label":` /
  `"data-state":` keys are folded into those hashes. A `data-controller` or `data-action` you pass is appended after the component's own, not
  replacing them, and the component's own controller cannot be removed (`dev/decisions/data-controller-merge.md` of the repository, not packaged).
- Variant-like options take strings or symbols: `variant: "outline"` and `variant: :outline`, `size: "icon-sm"` and `size: :icon_sm`.
  An unknown value raises `ArgumentError`.
- `as_child:` is React's `asChild`: `false` (the default element), a tag symbol (`as_child: :a`) or a component instance
  (`as_child: Chadcn::Button.new(variant: "outline")`), merged with Radix Slot semantics. Never put a `Button` inside a trigger
  as content; pass it to `as_child:`.
- `buttonVariants(...)` and the other cva helpers are class methods returning the class string: `Chadcn::Button.variants(variant: "link")`.
- Generated ids (`aria-controls`, `aria-labelledby`, the portal templates) are numbered per request in a Rails app and per render
  elsewhere. Pass `id:` to a root to choose them: `Chadcn::Sheet.new(id: "article-settings")` renders the content with that id
  (`article-settings-title` for its title), `Chadcn::Accordion.new(id: "faq")` keeps the id on the element and numbers its items
  `faq-item-1-trigger`; the rule is in [docs/api-conventions.md](docs/api-conventions.md#generated-ids). Markup a later request adds to the page
  (a lazy or navigated Turbo Frame, a Turbo Stream) numbers from 1 again, so give its roots an `id:`.
- Controlled state follows React: `open:` / `value:` / `checked:` render that state and the controller only dispatches the change
  event; `default_open:` / `default_value:` / `default_checked:` start uncontrolled. Change callbacks are DOM events named
  `chadcn--<component>:<event>` (`chadcn--dialog:open-change`, `chadcn--select:value-change`, `chadcn--slider:value-commit`...) with
  the new value in `event.detail`.
- Icons: `render Chadcn::Icon.new("check")` renders the Lucide SVG (lucide-react 0.577.0 markup), sized by the parent
  component's selectors like in shadcn.
- Dark mode is the `.dark` class on an ancestor (`<html>`); `data-controller="chadcn--theme"` with the actions `setLight`,
  `setDark`, `setSystem` and `toggle` manages it and remembers the choice in `localStorage` under `shadcn-theme`
  (`data-chadcn--theme-storage-key-value="my-key"` changes it; blocked storage falls back to the system preference). A script that
  sets the class before first paint has to read the same key.
- Turbo: the overlay, disclosure, avatar and scroll-area controllers handle `turbo:before-cache`, so a cached page has no open
  modal, scroll lock or `aria-hidden` siblings.
- Default texts (`Previous`, `Next`, `More pages`, `More`, `Close`, the sidebar trigger and mobile sheet, the slider thumb labels...)
  are keyword arguments: pass translated strings, for example `Chadcn::Pagination::Previous.new(label: t(".previous"))`.
  Fixed landmark labels (`Spinner`, `NavigationMenu`, `Sidebar::Rail`...) take `aria: { label: ... }`; see
  [docs/api-conventions.md](docs/api-conventions.md).

The API of every component is in the YARD documentation (`bundle exec yard server` in the gem) and,
per family, in [`docs/`](docs/): [conventions](docs/api-conventions.md), [display](docs/display.md), [form controls](docs/form-controls.md),
[disclosure and navigation](docs/disclosure-and-navigation.md), [overlays](docs/overlays.md), [menus and select](docs/menus-and-select.md), [catalog](docs/catalog.md) (an example of every component, for a gallery page).
[Compatibility](docs/compatibility.md) lists the supported Ruby, Phlex, Rails and Tailwind versions and the Phlex 3 policy.

### Toaster, Command, Combobox, Calendar and the date picker

Four components port libraries that shadcn wraps (sonner, cmdk, Base UI's combobox, react-day-picker) without taking those libraries
as dependencies: the behavior is rewritten as Stimulus controllers on shared primitives, and the markup follows shadcn's.

```ruby
# Toaster (sonner): render it once in the layout; the flash becomes toasts
render Chadcn::Toaster.new(flash: { notice: "Saved", alert: "Could not send" }, position: "top-center")

# Command (cmdk): a searchable palette; Command::Dialog puts the same list in a dialog
render Chadcn::Command.new do |command|
  command.input(placeholder: "Type a command or search...")
  command.list do
    command.empty { "No results found." }
    command.group(heading: "Suggestions") do
      command.item(value: "calendar") { "Calendar" }
      command.item(value: "search") { "Search" }
    end
  end
end

# Combobox (Base UI): an input with a filtered list, submits the selected item, e.g. framework=next.js
render Chadcn::Combobox.new(items: %w[next.js sveltekit astro], name: "framework") do |combobox|
  combobox.input(placeholder: "Select a framework")
  combobox.content do
    combobox.empty { "No items found." }
    combobox.list { |item| combobox.item(value: item) { item } }
  end
end

# Calendar (react-day-picker): native Date and Intl, hidden ISO inputs with name:
render Chadcn::Calendar.new(mode: :single, selected: Date.new(2026, 3, 15), name: "starts_on")
```

- **Toaster.** Toasts come from the flash (`Toaster.new(flash:)`), from a Turbo Stream that appends a `Sonner::Toast` to the Toaster
  (`turbo_stream.append "toaster", Chadcn::Sonner::Toast.new(type: :success, title: "Saved")`) and from JavaScript
  (`window.Toaster.success("Saved")`). Compared with sonner, there are no React elements: `window.Toaster.custom` takes a DOM node (or a function returning one),
  `window.Toaster.promise` works as in sonner, and the flash and Turbo Stream toasts are server-rendered `<template>`s with text only.
  `error` toasts are also announced through an assertive live region.
  See [display](docs/display.md#toasts-the-toaster).
- **Command.** The built-in `scorer` primitive replaces cmdk's `command-score`, and it is not the same algorithm: the scores are
  different numbers. The parity scenarios use queries where both rank identically, but that is not guaranteed in general: items cmdk
  scores equally (a tie) can come out in another order, `command-score` matches `"app"` against `"Apricot"` and the scorer does not,
  and whitespace in the query is ignored instead of matched. This difference is accepted on purpose (#225): porting `command-score` is reconsidered if users report rankings that matter to them. See [menus and select](docs/menus-and-select.md#command-and-combobox).
- **Combobox.** The default `filter:` is `"fuzzy"` (the same scorer, so `"nxt"` finds `next.js`). Pass `filter: :contains` for Base
  UI's own substring matching and `filter: nil` for no filtering. Single and multiple (chips) selection, grouped items and a clear
  button are supported, and `name:` submits through hidden inputs.
- **Calendar.** Single, multiple and range modes. Month and weekday names and the labels are exact for English and Spanish
  (`locale: :es`); other locales are `Intl` approximations with English labels. `name:` renders ISO 8601 (`YYYY-MM-DD`) hidden inputs.
  See [form controls](docs/form-controls.md#example-a-calendar-and-a-date-picker).
- **Date picker.** There is no `DatePicker` class: shadcn's date picker is a block (an example), not a registry component. It is a
  composition of `Popover`, a `Button` trigger and a `Calendar` with an external hidden input, using the `Calendar` keywords `input:`
  (the hidden ISO input to read and write), `label:` (the element that shows the formatted date) and `close_on_select:`. The full,
  tested recipe is in [form controls](docs/form-controls.md#example-a-calendar-and-a-date-picker).

## Eject a component

When a component's markup has to change, copy it into your app. The copy replaces the gem's file, and every other component keeps
loading from the gem:

```bash
bin/rails g chadcn:eject button                # app/components/chadcn/button.rb
bin/rails g chadcn:eject alert-dialog          # a compound component is ejected as a unit: alert_dialog.rb and every part under alert_dialog/
bin/rails g chadcn:eject dialog/content        # one part only; Dialog and its other parts keep loading from the gem
bin/rails g chadcn:eject --list                # what can be ejected, and what already is
bin/rails g chadcn:eject button --diff         # the gem's current file against your copy
```

Names can be written `button`, `Button`, `alert-dialog` or `dialog/content`. Options: `--list`, `--diff`, `--force` (overwrite; without it
nothing is written when any target exists), `--skip` (leave existing files alone), `--pretend` (print what would happen) and
`--dir` (the override directory, relative to the app root). Each copy starts with two comment lines recording the gem version and the
SHA-256 of the file it came from. Edit the copy: it defines the same constant (`Chadcn::Button`) and the gem's own file is not
loaded for it. Tailwind scans it like any file of your app.

The override directory is `app/components/chadcn` by default (used when it exists). To move it, set it **before the app boots**,
in `config/application.rb` or `config/environments/*.rb`:

```ruby
# config/application.rb
config.chadcn.override_dir = "app/components/shadcn"
```

The directory is read once, when the gem's components are set up. Setting `override_dir` later (from `config/initializers`, or with
`Chadcn.configure` after the components loaded) raises `Chadcn::Configuration::LateSettingError` instead of being ignored.
Without Rails, set the environment variable `CHADCN_OVERRIDE_DIR` before `require "chadcn"`.

- Restart the server after ejecting. Editing an ejected file reloads like the rest of your app code, but adding or removing an ejected
  file needs a restart.
- Some gem classes include code from `direction`, `direction/consumer`, `dropdown_menu` and any `<component>/support` part when they
  load, so an edit to those copies reaches the gem's classes only after a restart. The generator prints a warning when you eject them.
- `bin/rails chadcn:doctor` warns about stale copies (check `ejected components`): the gem's file changed since you ejected
  (compare with `--diff`), a part of an ejected unit is missing, or a copy lost its header. Updating the gem does not update your copy.
- Ejecting `sonner` (or `sonner/toaster`) also ejects `toaster.rb`, the `Toaster` alias.
- Infrastructure files (`base`, `configuration`, `doctor`, `engine`, `icons`, `js_bundle`, `overrides`, `theme`, `values`, `version`) cannot be ejected. The design notes are in
  `dev/decisions/eject-override.md` of the repository (not packaged).

## Performance

`bin/bench` (in the gem directory; plain Phlex, no Rails) renders representative components and prints microseconds and Ruby object
allocations per render. Allocation counts are deterministic and are what `bin/bench --check` compares with `dev/bench/baseline.json` (run it by hand: it is not part of `bin/check` or CI, and it skips with a warning on another Ruby or Phlex version); times vary from run to run and are
informational only. Merged class strings are memoized in `Base`, which cut allocations per render (Ruby 4.0.0, Phlex 2.4.1; the "before" column is `dev/bench/baseline.json` as committed
with the benchmark in `18c4cbd`, the "after" column is the current file):

| Scenario | Allocations per render before the cache | after |
|---|---|---|
| `button` (one outline Button) | 57 | 41 |
| `card` (Card with header, title, description, content, footer) | 197 | 119 |
| `select` | 882 | 597 |
| `dialog` | 540 | 378 |
| `table` | 7115 | 4339 |

`reference`, the same Button hand-written in plain Phlex, is 13 allocations. A run on Ruby 4.0.0 and Phlex 2.4.1 (arm64 macOS)
printed 8.2 microseconds for `button` against 2.9 for `reference`, 29.7 for `card`, 196.0 for `select`, 105.5 for `dialog` and
1084.7 for `table`. Absolute times depend on the machine; the allocation counts depend on the Ruby and Phlex versions. The benchmark
makes no comparison with other libraries.

## For AI assistants

`llms.txt`, `llms-full.txt` and `skills/chadcn/SKILL.md` ship with the gem. They are generated from the YARD documentation and
the Stimulus controllers, so they list every component with its constructor keywords, variants, parts, controller values and events,
plus short usage rules, and a drift fails `rake llms:check` and `rake test` (through `test/llms_drift_test.rb`): `rake llms:generate` regenerates them. Change a component's
keywords, parts or Stimulus API, then run `rake llms:generate` and commit the result.

## The demo

`bin/demo` (in the gem directory, `bin/demo --port 3100` for a port) builds the Tailwind CSS of the dummy app in `dev/dummy` and serves
its component catalog on a free local port, so you can try every component and the theme. It is part of the repository's dev kit and
is not packaged with the gem: run it from a checkout.

## Theme

`theme.css` is the only file you edit to restyle everything. Between its `theme:colors:start` / `theme:colors:end` markers sits a plain
shadcn theme (`:root { --background: ...; }` and `.dark { ... }`), so a theme copied from ui.shadcn.com/themes pastes in unchanged.
Components read the variables through `tokens.css` (`bg-primary`, `text-muted-foreground`, `rounded-md`...), which ships inside the
engine bundle and is never edited.

```bash
bin/rails chadcn:theme:list                       # neutral, gray, zinc, zinc-radius0, slate, stone
bin/rails chadcn:theme:use[slate]                 # switch the colors block to a preset
bin/rails chadcn:theme:import[path-or-url]        # paste a theme (file, https URL, or - for stdin); missing variables are kept
STRICT=1 bin/rails chadcn:theme:check             # variables complete in light and dark, valid format, text contrast
```

A URL source of `import` must be `https` (timeouts, three redirects at most, 256 KiB at most), and values that could break out of
the CSS block are rejected; a failure prints its message (the list of errors for an invalid theme), without a backtrace.
`theme:list|use|import|check` are short aliases (`config.chadcn.theme_task_aliases = false` turns them off). Older themes
with bare HSL triplets (`240 10% 3.9%`) are wrapped on import. Run `bin/rails tailwindcss:build` after a change.

## Upgrade notes

Pre-1.0 releases may still change the API between minor versions; every change is in [CHANGELOG.md](CHANGELOG.md) (Keep a Changelog)
and removals are deprecated for one minor version first.

- From the in-app port (`Components::V2::*`): the constants are `Chadcn::*` with the same nesting (`Components::V2::Dialog::Content`
  is `Chadcn::Dialog::Content`); Stimulus identifiers `v2--<name>` are `chadcn--<name>` (`data-v2--dialog-part` is
  `data-chadcn--dialog-part`, events `v2--dialog:open-change` are `chadcn--dialog:open-change`); the controllers moved from
  `controllers/v2/` to `controllers/chadcn/` and the primitives from `v2/primitives/` to `chadcn/primitives/`.
- The default key of the `chadcn--theme` controller is `shadcn-theme` (it was `papyro-theme`); set
  `data-chadcn--theme-storage-key-value="papyro-theme"` to keep stored choices. The probe controllers and `theme_panel_controller.js`
  are no longer shipped: remove any pin or registration of `chadcn--_probe-*` or `chadcn--theme-panel`.
- `Direction::Provider` without `dir:` or `direction:` keeps the outer direction instead of resetting to `ltr`.
- The gem no longer depends on `activesupport`; code that relied on it being loaded by the gem has to require it itself.
- The gem's Zeitwerk loader is no longer set up when the gem is required. In a Rails app the engine sets it up in an initializer that
  runs before Rails sets its autoload paths (after `config/application.rb` and `config/environments/*.rb`), so the override directory
  of [ejected components](#eject-a-component) is known first; without Rails it still happens at require time. A component referenced
  before the app initializes (in `config/application.rb`, say) sets the loader up on first lookup, and the app then refuses to boot
  with `LateSettingError` if that dropped an existing override directory.
- Replace a host-side bridge (asset paths and importmap pins for the gem's JavaScript) by the engine: remove the bridge and run
  `bin/rails g chadcn:install`.

## Development

```bash
bundle install
bin/check                      # rake test, rake test:engine, rubocop, bundler-audit and the gem gate
bundle exec yard stats --list-undoc   # the public API has to be 100% documented
bin/smoke --docs               # every Ruby example of this README and docs/ renders in a plain process
bin/bench                      # allocations and time per render (bin/bench --check compares allocations with dev/bench/baseline.json)
bundle exec rake llms:generate # regenerate llms.txt, llms-full.txt and the agent skill (rake llms:check fails on drift)
bin/demo                       # the component catalog of dev/dummy on a free local port
```

Run these with `env -u BUNDLE_GEMFILE` if your shell exports a `BUNDLE_GEMFILE` for another project.

The browser tests of the Stimulus controllers run with `bin/test-js` (Playwright; it starts the dev servers; the CI job `js-tests`
runs the same suite).

The plain suite (`rake test`) never loads Rails; `rake test:engine` boots a minimal Rails application in-process to test the engine
and the install generator. The parity gates that compare every component to the React original in a browser live in the port's
dev kit and are not packaged with the gem.

## License

chadcn is an independent, community-maintained port of [shadcn/ui](https://ui.shadcn.com) to Phlex. It is not affiliated
with, endorsed by or sponsored by shadcn or the shadcn/ui project. Component structure, class strings and behavior derive
from shadcn/ui (MIT License, Copyright (c) 2023 shadcn); accessibility behavior follows Radix UI (MIT) and icons are
Lucide (ISC). Every third-party notice is in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). chadcn itself is MIT licensed.

See [LICENSE](LICENSE).
