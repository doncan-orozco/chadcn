# Decision: ejected components live in an override directory that shadows the gem

Status: proposed by the spike (item #169), productionized by the eject-generator item (#179).
Proof: `dev/spikes/eject/override_test.rb` (see the test count in the Gate output, run with the Gate command of #169).

## Decision

A host overrides a gem component by putting a file with the same Zeitwerk path in an **override directory**. The file reopens
the same constant (`class Phlex::Shadcn::Button < Phlex::Shadcn::Base`); the gem does not load its own file for that constant.

- Directory: `app/components/phlex_shadcn/` in a Rails app, mounted as a root with `namespace: Phlex::Shadcn`
  (so `app/components/phlex_shadcn/button.rb` is `Phlex::Shadcn::Button`, not `PhlexShadcn::Button`).
- Config key: `Phlex::Shadcn.configure { |c| c.override_dir = "..." }`, forwarded from `config.phlex_shadcn.override_dir`
  by the engine. Default `Rails.root.join("app/components/phlex_shadcn")` in Rails, `nil` (off) in a plain Phlex app.
- Where it may be set: in Rails only `config.phlex_shadcn.override_dir` in `config/application.rb` or `config/environments/*.rb`.
  `config/initializers/*.rb` load after `set_autoload_paths`, too late. #179 makes `Configuration#override_dir=` raise once the
  gem `Loader` is set up, so a late setting fails loudly instead of being ignored.
- Unit of ejection: a leaf (`button.rb`) is one file. A compound component is ejected **as a unit**: `dialog.rb` plus the
  whole `dialog/` directory. A single nested part (`dialog/content.rb` only) may also be ejected, and then `Dialog` and its
  other parts keep loading from the gem.

## What the spike proved (all in lazy autoload and in `Loader.eager_load`)

| Case | Result |
|---|---|
| Leaf (`Button`) | override wins; `Dialog::Footer` (gem file) renders the ejected `Button`; untouched components load from the gem |
| Compound root (`Dialog`, with `dialog/`) | override wins for the root and every part, Button and Card still from the gem |
| Nested part (`Dialog::Content`) | override wins for that part only; `Dialog` and `Dialog::Title` stay in the gem |
| `Loader.ignore` called after `setup` for a top-level file | has no effect: the gem's `Button` still wins (test `test_ignoring_after_setup_...`) |
| `reload` of both loaders | override still wins after reload |

Mechanism that works, in this order:

1. Know the override directory **before** the gem loader's `setup`.
2. Give the gem loader `ignore(<every gem path the override directory shadows>)`. For a root override (`dialog.rb` present
   in the override directory) the ignored paths are the gem's `dialog.rb` **and** `dialog/`; for a nested part, only that file.
3. A second Zeitwerk loader owns the override directory: `push_dir(override_dir, namespace: Phlex::Shadcn)`.
   Zeitwerk lets it add children to a namespace the gem loader defines (nested case) because the constants do not collide.

Without step 2 the first loader to register the autoload wins and the second is skipped silently (no error): the gem
always wins and the override is dead code (tests `test_without_ignore_...`). With a compound root, the gem also autovivifies
a module `Dialog` from `dialog/`, which is why the directory is ignored together with the file (Zeitwerk reasoning; no test ignores only the file).

## When the gem's loader learns about the directory

`lib/phlex/shadcn.rb` runs `Loader.setup` at `require` time, which in a Rails app is `Bundler.require`, before
`config/application.rb` bodies, initializers or `config.phlex_shadcn` exist. Step 1 is therefore impossible with the current
file. Production change (made by #179, not here):

- Rails: the engine calls `Loader.setup` from an initializer that runs before Rails' `set_autoload_paths` and after the
  host config is loaded (`initializer "phlex_shadcn.loader", before: :set_autoload_paths`), computes the ignore list from
  `override_dir`, and hands the directory to `Rails.autoloaders.main.push_dir(dir, namespace: Phlex::Shadcn)`. `lib/phlex/shadcn.rb`
  then skips `Loader.setup` when `Rails::Engine` is defined. The directory is read at boot, so ejecting a new component needs a restart.
- Plain Phlex: `Loader.setup` stays at require time with the directory taken from `ENV["PHLEX_SHADCN_OVERRIDE_DIR"]`
  (documented), or an explicit `Phlex::Shadcn.setup(override_dir:)` for apps that want to control the order (then
  `require "phlex/shadcn/lazy"` skips the automatic setup). The spike's harness is the reference model.
- Keep `Zeitwerk::Loader.for_gem_extension(Phlex)` and only move `setup` later. The spike's plain `Loader.new` rooted at
  `lib/phlex/shadcn` is a harness simplification; the `Version` eager-load error it hit came from that alone.

## Dev reload

In Rails the override directory belongs to the main (reloadable) autoloader, so editing an ejected file reloads it like any
app code; the gem loader is not reloadable and `Phlex::Shadcn` itself never reloads. The spike's reload tests prove that
reloading both loaders, and reloading only the override loader (production layout, gem loader not reloadable), keeps the
override in force for a leaf and for a nested part under a gem-owned `Dialog`. Adding or removing an ejected file needs a restart:
otherwise a new file is skipped silently and a removed one raises `NameError` (Zeitwerk reasoning, not exercised by the spike; #179's engine test verifies it); the `Ejected` doctor check also reports override files that shadow no gem file. The Rails integration (main autoloader + `bin/dev` edit/reload) is
verified in the eject-generator item's engine test, which is not possible here: this item owns only `dev/spikes` and this note.
Constraint to document: a gem class that holds a reference to an ejected class in a constant survives a reload; the gem does not do this today
(Pagination, ButtonGroup, Dialog::Footer, AlertDialog::ActionButton look the constant up at render time).

## Gem upgrade and stale copies

An ejected file is a snapshot of the gem file at eject time. The generator writes a header comment with the gem version
and a checksum of the source it copied (`# phlex-shadcn 0.1.0 sha256:...`). `phlex_shadcn:doctor` gets an `Ejected` check
(#179 owns `doctor/checks/ejected.rb`) that compares it with the installed gem's file and reports `changed upstream` per component,
and `rails g phlex:shadcn:eject --diff` shows the change. A new compound part added upstream to an ejected unit
(`dialog/new_part.rb`) is missing from the override: the check reports "gem has parts the ejected unit lacks" because the
whole `dialog/` directory is ignored in the gem loader. This is the cost of unit ejection and the reason a nested single-part eject exists.

## Alternatives considered

- **Subclass in a separate namespace** (`class MyButton < Phlex::Shadcn::Button`): gem components that render `Button`
  internally (Dialog::Footer, Pagination, ButtonGroup, AlertDialog) would not use it, so the host would have to override every consumer. Rejected.
- **Ignore the gem file and let the host define the constant anywhere** (`Loader.ignore` alone, host file required by hand):
  no autoload, no reload, no eager-load coverage, and a name-mangled path per host. It is the mechanism of step 2, not a design, on its own. Rejected as the only mechanism.
- **Monkey-patch / `prepend` into the gem class**: patches survive upgrades silently, cannot remove behaviour, and defeat the
  "copy and own the file" model of shadcn. Rejected.
- **Copy into the gem's own directory** (`bundle open`): breaks on every `bundle update`. Rejected.

## Not blocked

The override directory works cleanly; no human decision is needed beyond approving the Rails initializer order above.
