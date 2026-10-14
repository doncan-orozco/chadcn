# phlex-shadcn

shadcn/ui components for [Phlex](https://www.phlex.fun): the shadcn API, class strings and behavior, as Phlex views with Stimulus.

> Status: pre-release. The component API is being audited family by family; the Rails integration below is complete.

## Rails

```ruby
# Gemfile
gem "phlex-shadcn"
```

```bash
bin/rails g phlex:shadcn:install   # needs tailwindcss-rails; idempotent
bin/rails tailwindcss:build
```

The generator writes one managed block after `@import "tailwindcss";` in `app/assets/tailwind/application.css` (`--css` to change
it): the `@source` for the gem's Ruby files, the engine bundle and your theme file. It copies `theme.css` and `presets/` into
`app/assets/tailwind/theme` (or `config.phlex_shadcn.theme_dir`, or `--theme-dir`) and never overwrites them. Edits inside the
markers are overwritten on the next run.

The engine pins the Stimulus controllers (`controllers/shadcn/*`, registered as `shadcn--*` by
`eagerLoadControllersFrom("controllers")`), the primitives (`shadcn/primitives/*`) and floating-ui.

### Configuration (config/application.rb)

```ruby
config.phlex_shadcn.theme_dir = "app/assets/tailwind/theme"  # relative to the app root
config.phlex_shadcn.theme_task_aliases = true                 # false if the app defines its own theme:* tasks
```

Precedence at boot: `config.phlex_shadcn.theme_dir`, then a value set with `Phlex::Shadcn.configure` before the app initializes, then the default.
In Rails apps use `config.phlex_shadcn.theme_dir`: a `configure` call in `config/initializers` runs later and overrides it (a relative path
there is not rooted at the app).

### Theme tasks

```bash
bin/rails phlex_shadcn:theme:list
bin/rails phlex_shadcn:theme:use[slate]
bin/rails phlex_shadcn:theme:import[path|https://...|-]
STRICT=1 bin/rails phlex_shadcn:theme:check
```

`theme:list|use|import|check` are short aliases.

## Without Rails

```ruby
require "phlex/shadcn"
Phlex::Shadcn.configure { |config| config.theme_dir = "/path/to/theme" }  # only for Phlex::Shadcn::Theme
```

Add an `@source` for `Phlex::Shadcn.root.join("lib")` to your Tailwind entry and import the gem's
`app/assets/tailwind/phlex-shadcn/engine.css` and your `theme.css`.

## Development

```bash
cd gems/phlex-shadcn
bundle install
bin/check   # rake test, rubocop and the gem gate
```

## License

MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) (shadcn/ui, Radix UI, Lucide).
