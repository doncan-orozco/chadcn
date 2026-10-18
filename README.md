# phlex-shadcn

[shadcn/ui](https://ui.shadcn.com) for [Phlex](https://www.phlex.fun): the same component API, the same Tailwind class strings and
the same Radix behavior, as Phlex views with Stimulus controllers. Fifty components (`Button`, `Dialog`, `Select`, `Sidebar`...),
each one checked against the React original in a browser.

> Status: pre-release (0.x). The public API follows semantic versioning from the first release; see [CHANGELOG.md](CHANGELOG.md).

- One Ruby class per React export: `Dialog` is `Phlex::Shadcn::Dialog`, `DialogContent` is `Phlex::Shadcn::Dialog::Content`.
- Props are keyword arguments (`variant: "outline"`, `default_open: true`), `className` is `class:`, children are the block.
- Behavior lives in Stimulus controllers named `shadcn--<component>`; they ship in the gem with the shared primitives they use.
- Colors come from one shadcn-format theme file you own; anything pasted from ui.shadcn.com/themes works unchanged.

## Requirements

- Ruby 3.2 or newer, [Phlex](https://www.phlex.fun) 2.3 or newer.
- Tailwind CSS 4 (the components use Tailwind utility classes; with Rails, `tailwindcss-rails`).
- For the interactive components: Stimulus 3 (`@hotwired/stimulus`). With Rails, `importmap-rails` (the gem's engine adds its pins).
- With Rails, `phlex-rails` renders Phlex views from controllers; the gem itself depends only on `phlex`, `tailwind_merge` and `zeitwerk`.

## Rails: from zero to a Button and a Dialog

Add the gem and run the install generator (it needs `tailwindcss-rails` to be installed already, `bin/rails tailwindcss:install`):

```ruby
# Gemfile
gem "phlex-rails"
gem "phlex-shadcn"
```

```bash
bundle install
bin/rails g phlex:shadcn:install
bin/rails tailwindcss:build
```

The generator writes one managed block right after `@import "tailwindcss";` in `app/assets/tailwind/application.css` (`--css` to
point at another entry file):

```css
@import "tailwindcss";
/* phlex-shadcn:start (managed by rails g phlex:shadcn:install) */
@source "../../../../path/to/phlex-shadcn/lib";
@import "../builds/tailwind/phlex-shadcn";
@import "./theme/theme.css";
/* phlex-shadcn:end */
```

- `@source` points Tailwind at the gem's Ruby files: Tailwind 4 only generates the classes it finds in scanned files, so without this
  line the components render unstyled. The path is relative to your entry file; the engine bundle carries its own self-relative
  `@source`, so a moved gem keeps working. Re-run the generator to refresh this line.
- `../builds/tailwind/phlex-shadcn` is the engine bundle `tailwindcss-rails` builds from the gem's `engine.css` (Tailwind variant
  plugins, the token mapping from theme variables to utilities, the vendored animations).
- `theme/theme.css` and `theme/presets/` are copied into `app/assets/tailwind/theme/` (or `--theme-dir`) once and never
  overwritten: the theme is yours to edit.

The generator is idempotent: a second run rewrites the same block and skips the files that already exist. Edits inside the markers
are lost on the next run; everything outside them is left alone.

Stimulus needs nothing from you when the app uses the default `app/javascript/controllers/index.js`
(`eagerLoadControllersFrom("controllers", application)`): the engine pins the gem's controllers under `controllers/shadcn/`, so they
register as `shadcn--dialog`, `shadcn--select`, and so on. An app that registers controllers by hand imports and registers them
itself:

```js
// app/javascript/controllers/index.js
import DialogController from "controllers/shadcn/dialog_controller"
application.register("shadcn--dialog", DialogController)
```

Now render a Button and a Dialog from a Phlex view (`phlex-rails`; `bin/rails g phlex:install` sets up `app/views` and
`app/components` if you have not done it yet):

```ruby
# app/views/demo/index.rb
class Views::Demo::Index < Views::Base
  def view_template
    render Phlex::Shadcn::Button.new(variant: "outline") { "Save" }

    render Phlex::Shadcn::Dialog.new do |dialog|
      dialog.trigger(as_child: Phlex::Shadcn::Button.new) { "Edit profile" }
      dialog.content do
        dialog.header do
          dialog.title { "Edit profile" }
          dialog.description { "Make changes to your profile here." }
        end
        dialog.footer { render Phlex::Shadcn::Button.new(type: "submit") { "Save changes" } }
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

### Configuration (`config/application.rb`)

```ruby
config.phlex_shadcn.theme_dir = "app/assets/tailwind/theme"  # where theme.css and presets/ live; relative to the app root
config.phlex_shadcn.theme_task_aliases = true                 # false when the app defines its own theme:* rake tasks
```

`theme_dir` precedence at boot: `config.phlex_shadcn.theme_dir`, then a value set with `Phlex::Shadcn.configure` before the app
initializes, then the default. In a Rails app set it in `config/application.rb`, not in an initializer: a `configure` call in
`config/initializers` runs after the engine and overrides the app setting with a path that is not rooted at the app.

## Without Rails

```ruby
require "phlex/shadcn"

Phlex::Shadcn::Button.new(variant: "outline") { "Save" }.call
# => "<button data-slot=\"button\" data-variant=\"outline\" data-size=\"default\" class=\"...\">Save</button>"
```

Any Phlex component can `render` the gem's components; `Phlex::Shadcn.root` is the installed gem directory.

Tailwind: import the gem's entry point and your theme from your Tailwind entry file. `engine.css` carries its own `@source` for the
gem's Ruby files (relative to itself, so it follows the gem), the token mapping and the vendored animations:

```css
@import "tailwindcss";
@import "<gem root>/app/assets/tailwind/phlex-shadcn/engine.css";
@import "./theme/theme.css";
```

Copy `app/assets/tailwind/phlex-shadcn/theme.css` (and `presets/`) out of the gem into your project; that copy is the file you edit.
`ruby -e 'require "phlex/shadcn"; puts Phlex::Shadcn.root'` prints the gem root.

Stimulus: the controllers are ES modules under `<gem root>/app/javascript/controllers/shadcn/<name>_controller.js` and the shared
primitives live under `<gem root>/app/javascript/shadcn/primitives/<name>.js`. They import each other by bare, extensionless
specifiers: `controllers/shadcn/<name>_controller` (`alert_dialog_controller` and `sheet_controller` import the dialog controller,
`context_menu_controller` imports the dropdown menu controller), `shadcn/primitives/<name>` (`typeahead` imports `collection`; `roving_focus` imports
`direction`, `ids` and `collection`; `collapsible_content` imports `presence`), `@hotwired/stimulus` and, for the positioned overlays and menus, `@floating-ui/dom` (imported by `positioner`). The vendored copy in
`<gem root>/vendor/javascript/@floating-ui--*.js` imports `@floating-ui/core`, `@floating-ui/utils` and `@floating-ui/utils/dom`
in turn (or take `@floating-ui/dom` from npm). You have to resolve all of those specifiers yourself, in one of two ways.

1. A browser import map with one entry per file. A prefix entry such as `"shadcn/"` does not work: the specifiers carry no `.js`, so
   the browser would request a URL without an extension. For the Dialog the controller and the primitives it imports (it needs
   no Floating UI) are:

   ```html
   <script type="importmap">
   {
     "imports": {
       "@hotwired/stimulus": "/vendor/stimulus.js",
       "controllers/shadcn/dialog_controller": "/shadcn/controllers/shadcn/dialog_controller.js",
       "shadcn/primitives/dismissable_layer": "/shadcn/primitives/dismissable_layer.js",
       "shadcn/primitives/focus_guards": "/shadcn/primitives/focus_guards.js",
       "shadcn/primitives/focus_scope": "/shadcn/primitives/focus_scope.js",
       "shadcn/primitives/hide_others": "/shadcn/primitives/hide_others.js",
       "shadcn/primitives/presence": "/shadcn/primitives/presence.js",
       "shadcn/primitives/scroll_lock": "/shadcn/primitives/scroll_lock.js",
       "shadcn/primitives/template_mount": "/shadcn/primitives/template_mount.js"
     }
   }
   </script>
   ```

   Serve the two gem directories at those URLs. For other controllers add one line per file in both directories (and the four
   `@floating-ui--*.js` files for the positioned ones).

2. A bundler alias: map `controllers/shadcn` to `<gem root>/app/javascript/controllers/shadcn` and `shadcn` to
   `<gem root>/app/javascript/shadcn`, and install `@floating-ui/dom` from npm.

Rails users need none of this: the gem's engine pins everything through importmap-rails (`config/importmap.rb`). Then register each
controller under its `shadcn--<name>` identifier:

```js
import { Application } from "@hotwired/stimulus"
import DialogController from "controllers/shadcn/dialog_controller"

const application = Application.start()
application.register("shadcn--dialog", DialogController)
```

The theme tooling works too once the directory is configured: `Phlex::Shadcn.configure { |config| config.theme_dir = "/path/to/theme" }`,
then `Phlex::Shadcn::Theme.use("slate")`, `Theme.import(path_or_url)` and `Theme.check(strict: true)`.

## Using the components

The 1:1 classes are the canonical API; a compound root also yields itself with one generated helper per part. Both forms render the
same HTML and can be mixed:

```ruby
# explicit classes, one per React export
render Phlex::Shadcn::Card.new do
  render Phlex::Shadcn::Card::Header.new { render Phlex::Shadcn::Card::Title.new { "Settings" } }
  render Phlex::Shadcn::Card::Content.new { "..." }
end

# generated helpers on the yielded root (card.header is exactly render Card::Header.new(**attrs), &block)
render Phlex::Shadcn::Card.new do |card|
  card.header { card.title { "Settings" } }
  card.content { "..." }
end
```

- Every class takes `**attrs`: `class:` is merged last through tailwind-merge (your classes win on conflicts), `data:` and `aria:`
  hashes deep-merge with the component's own, React DOM prop names are accepted (`tab_index:`, `html_for:`), and flat `"aria-label":` /
  `"data-state":` keys are folded into those hashes.
- Variant-like options take strings or symbols: `variant: "outline"` and `variant: :outline`, `size: "icon-sm"` and `size: :icon_sm`.
  An unknown value raises `ArgumentError`.
- `as_child:` is React's `asChild`: `false` (the default element), a tag symbol (`as_child: :a`) or a component instance
  (`as_child: Phlex::Shadcn::Button.new(variant: "outline")`), merged with Radix Slot semantics. Never put a `Button` inside a trigger
  as content; pass it to `as_child:`.
- `buttonVariants(...)` and the other cva helpers are class methods returning the class string: `Phlex::Shadcn::Button.variants(variant: "link")`.
- Controlled state follows React: `open:` / `value:` / `checked:` render that state and the controller only dispatches the change
  event; `default_open:` / `default_value:` / `default_checked:` start uncontrolled. Change callbacks are DOM events named
  `shadcn--<component>:<event>` (`shadcn--dialog:open-change`, `shadcn--select:value-change`, `shadcn--slider:value-commit`...) with
  the new value in `event.detail`.
- Icons: `render Phlex::Shadcn::Icon.new("check")` renders the Lucide SVG (lucide-react 0.577.0 markup), sized by the parent
  component's selectors like in shadcn.
- Dark mode is the `.dark` class on an ancestor (`<html>`); `data-controller="shadcn--theme"` with the actions `setLight`,
  `setDark`, `setSystem` and `toggle` manages it and remembers the choice.

The API of every component is in the YARD documentation (`bundle exec yard server` in the gem, or rubydoc.info once released) and,
per family, in [`docs/`](docs/): [conventions](docs/api-conventions.md), [display](docs/display.md), [form controls](docs/form-controls.md),
[disclosure and navigation](docs/disclosure-and-navigation.md), [overlays](docs/overlays.md), [menus and select](docs/menus-and-select.md).

## Theme

`theme.css` is the only file you edit to restyle everything. Between its `theme:colors:start` / `theme:colors:end` markers sits a plain
shadcn theme (`:root { --background: ...; }` and `.dark { ... }`), so a theme copied from ui.shadcn.com/themes pastes in unchanged.
Components read the variables through `tokens.css` (`bg-primary`, `text-muted-foreground`, `rounded-md`...), which ships inside the
engine bundle and is never edited.

```bash
bin/rails phlex_shadcn:theme:list                       # neutral, gray, zinc, zinc-radius0, slate, stone
bin/rails phlex_shadcn:theme:use[slate]                 # switch the colors block to a preset
bin/rails phlex_shadcn:theme:import[path-or-url]        # paste a theme (file, https URL, or - for stdin); missing variables are kept
STRICT=1 bin/rails phlex_shadcn:theme:check             # variables complete in light and dark, valid format, text contrast
```

`theme:list|use|import|check` are short aliases (`config.phlex_shadcn.theme_task_aliases = false` turns them off). Older themes with
bare HSL triplets (`240 10% 3.9%`) are wrapped on import. Run `bin/rails tailwindcss:build` after a change.

## Upgrade notes

Pre-1.0 releases may still change the API between minor versions; every change is in [CHANGELOG.md](CHANGELOG.md) (Keep a Changelog)
and removals are deprecated for one minor version first.

- From the in-app port (`Components::V2::*`): the constants are `Phlex::Shadcn::*` with the same nesting (`Components::V2::Dialog::Content`
  is `Phlex::Shadcn::Dialog::Content`); Stimulus identifiers `v2--<name>` are `shadcn--<name>` (`data-v2--dialog-part` is
  `data-shadcn--dialog-part`, events `v2--dialog:open-change` are `shadcn--dialog:open-change`); the controllers moved from
  `controllers/v2/` to `controllers/shadcn/` and the primitives from `v2/primitives/` to `shadcn/primitives/`.
- The gem no longer depends on `activesupport`; code that relied on it being loaded by the gem has to require it itself.
- Replace a host-side bridge (asset paths and importmap pins for the gem's JavaScript) by the engine: remove the bridge and run
  `bin/rails g phlex:shadcn:install`.

## Development

```bash
cd gems/phlex-shadcn
bundle install
bin/check                      # rake test, rake test:engine, rubocop, bundler-audit and the gem gate
bundle exec yard stats --list-undoc   # the public API has to be 100% documented
```

The plain suite (`rake test`) never loads Rails; `rake test:engine` boots a minimal Rails application in-process to test the engine
and the install generator. The parity gates that compare every component to the React original in a browser live in the port's
dev kit and are not packaged with the gem.

## License

MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md): the class strings, structure and behavior derive from
shadcn/ui (MIT) and Radix UI (MIT); the icons are Lucide (ISC).
