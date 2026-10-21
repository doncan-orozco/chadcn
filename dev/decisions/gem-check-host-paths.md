# Intentional host paths and `gem_check` (GEM_ESCAPES_ROOT)

Status: decided (epic phlex-shadcn-adoption-followups, item #206); aligned with the hardened script in epic phlex-shadcn-hardening (items #240, #257). Whether the allowlist itself stays is an open maintainer decision (#223); this note does not change its semantics. Applies to `.claude/scripts/gem/gem_check.rb` and the `ruby-gem-conventions` skill.

## Problem

`GEM_ESCAPES_ROOT` (R1) rejects hard-coded host paths such as `"app/assets/..."` (see "What the script detects") in gem Ruby files outside the Rails integration files (`lib/**/engine.rb`, `railtie.rb`, `lib/generators/**`, `lib/tasks/**`), because a hard-coded host path is how a gem silently stops being standalone. The doctor (`lib/phlex/shadcn/doctor/**`) exists precisely to inspect host files, so it legitimately names `app/assets/tailwind/application.css` and the host `bundle` files. PR #187 passed the rule, as it then was, by building the path with `File.join("app", "assets", ...)`; #177 keeps the Sprockets manifest path in `lib/generators/phlex/shadcn/install/sprockets_manifest.rb`.

Two facts frame the choice:

- Generator files are already exempt (they are Rails integration files), so the generator case needs nothing new.
- The `File.join` form was an evasion of a regex, not a statement of intent: nothing marks the path as deliberate, the next author copies the trick into core code, and a reviewer cannot grep for it.

## What the script detects

Since #240 (PR #249) `gem_check` no longer greps the line text: it lexes the file with Ripper, blanks the comments, and looks for host paths (`app/assets`, `app/javascript`, `app/views`, `app/components`) in the string literals. In a file that is not Rails integration, each of these spellings is a `GEM_ESCAPES_ROOT` finding, reported on the line of the first piece of the path:

- `%w[app/assets/x]` (multi-line lists too);
- `File.join("app", "assets", "x")`, `.join("app").join("assets")`, `Pathname("app") / "assets"`, `%w[app assets].join("/")`;
- interpolation: `"#{root}/app/assets/x"`, `"#@ivar/app/assets/x"`;
- concatenation: `"app/" + "assets/x"`, `<<`, adjacent literals, backslash continuation;
- `"./app/javascript/y"` and a bare `"app/assets"`;
- a heredoc body whose text starts with the path.

Findings from a scratch gem outside the repository (`ruby .claude/scripts/gem/gem_check.rb --gem-dir <scratch>/gems/phlex-x --host-dir <scratch>`, which prints JSON), condensed to `code file:line detail` and limited to `lib/phlex/shadcn/core.rb`, which holds `A = %w[app/assets/x]` (line 1), `B = File.join("app", "assets", "x")` (2), `C = Pathname("app").join("assets")` (3), `D = "#{root}/app/assets/x"` (4), `E = "app/" + "assets/x"` (5), `F = "./app/javascript/y"` (6), `G = "app/assets"` (7), a heredoc whose body line is `app/assets/tailwind.css` (reported on the body line, 10):

```
GEM_ESCAPES_ROOT lib/phlex/shadcn/core.rb:1 hard-coded host path (app/... or Rails.root); only doctor files may allow it, with `# gem_check:allow GEM_ESCAPES_ROOT -- <reason>` on the same line
... the same finding on lines 2, 3, 4, 5, 6, 7 and 10
```

Not findings: prose that merely mentions a path (`"edit app/assets/x then save"`), a path inside a comment (`# K = "app/assets/x"`, blanked by Ripper), and `Rails.root` on its own (that is `GEM_RAILS_REFERENCE`, a different rule). A path the gem builds from its own root is indistinguishable from a host path, so it belongs in the Rails integration files.

Known gaps (not exhaustive; the first three are in the script header, the syntax-error one comes from a scratch run):

- A paren-less `File.join "app", "assets"` is not seen (scratch run: `H = File.join "app", "assets"` produced no finding).
- A heredoc whose body text starts with a path is flagged (every body line of a `<<~` heredoc; only the first line of a `<<-`/plain one) and cannot carry a marker (a `#` there is text); write the path as a quoted literal.
- A path inside a multi-line `%w[]` list cannot carry a marker either (a `#` there is a word); write quoted literals.
- Only `lib/**/*.rb` and `app/**/*.rb` are scanned (`.rake` files, `config/`, `bin/` and the gemspec are not), and a `require`/`require_relative` argument is skipped by the lexer check (the line-text check for a quoted `app/<dir>/...` and the escape check still apply).
- A syntax error gets no finding of its own (scratch run on `def (` : only the other findings of that file appeared); `ruby -c` and RuboCop are the gates for that.

A gap is not a licence: a spelling the script cannot see still violates R15 and reviewers cite it.

## Options

The comparison below is kept as history. It was written when `File.join` and `%w[]` were invisible to the script; they no longer are, which makes option A moot (see Decision).

### A. Sanction the `File.join("app", "assets", ...)` form in the skill

- No tooling change.
- The rule keeps matching only a spelling; any file anywhere can dodge it the same way, so the gate stops being a gate for host paths.
- No scope: nothing says "doctor only"; no reason is recorded; not greppable. The convention would read "you may defeat the check by writing it differently".

### B. Narrow explicit allowlist in `gem_check` (chosen)

A marker on the same line, honored only in the doctor:

```ruby
DEFAULT_CSS = "app/assets/tailwind/application.css" # gem_check:allow GEM_ESCAPES_ROOT -- the doctor reads the host stylesheet
```

- exact rule id (only the hard-coded host path check of `GEM_ESCAPES_ROOT`; `require_relative` leaving the gem is never allowable);
- a reason after `--` is required, a bare marker does not count;
- scope: files matching `HOST_PATH_ALLOW_GLOBS` (`lib/phlex/shadcn/doctor/**/*.rb`); the marker anywhere else is inert and the literal still fails;
- for a path split over several lines the marker sits on the line of its first piece;
- the marker is the line's trailing comment and its reason holds no quotes, so marker text inside a string literal never counts; since #240 it must also be a real comment token for the lexer, so a `#` inside a `%w[]` list or heredoc is not a marker;
- same line only, so the exemption cannot drift away from the literal it covers.

Costs: one constant and a few lines in the script, and the doctor files had to be switched from `File.join` to the marked literal (done in #241).

## Decision

B. The point of the rule is that deliberate host knowledge is visible and bounded. A marker is greppable, carries a reason, is limited to the one directory whose job is to read the host, and is tested both ways (allowed in the doctor; the same literal elsewhere, unmarked, marked without a reason, marked for another rule, marker on another line, marker text inside a string, the root `doctor.rb` or another namespace's `doctor/`, or a `require_relative` escape still fail). Option A would keep the rule passing while removing what it protects.

With the hardened script option A is moot: `File.join` and `%w[]` are findings like any literal, so there is no spelling left to sanction, and the allowlist marker is the only sanctioned way for the doctor to name a host path (the Rails integration files need none). Splitting a path into pieces, `%w[]`, interpolation or any other trick to get past the check is not sanctioned anywhere; where the script cannot see it (the gaps above or any other) reviewers cite `ruby-gem-conventions R15`. The marker is honoured only for host-path literals in `doctor/**/*.rb`; real scratch results: a marked literal in `doctor/` passes; a bare marker (no reason), a reason containing quotes and `require_relative` leaving the gem (`require_relative leaves the gem directory (5 levels up from depth 4)`) are findings even there; the same marked lines in a non-doctor file are all findings. Whether the allowlist should exist at all is open in #223.

## Rollout

- Done in #241: `doctor/context.rb` (`DEFAULT_CSS`), `doctor/checks/engine_bundle.rb` (`BUNDLE`) and `doctor/checks/stimulus.rb` (`FILES`, formerly a `%w[]` list) name their paths as quoted literals with the marker, so the hardened script passes on main with no evasion in the doctor.
- #240 (PR #249) made the script see `File.join`, `%w[]`, interpolation and concatenation; the allowlist semantics are unchanged except that the marker must be a real comment.

## Related: the process-wide state of `Phlex::Shadcn::Base`

The skill's R4 says "no global mutable state". Two process-wide objects in `Phlex::Shadcn::Base` are a recorded exception (skill `ruby-gem-conventions`, section Namespacing), under explicit conditions: pure, bounded, safe under threads, `@api private`, and holding no configuration or request state.

- The `Base#cn` result memo (PR #189): `CN_CACHE`, bounded by `CN_CACHE_LIMIT` (cleared when full), read and written only while holding `CN_CACHE_LOCK`, a `Mutex` created when `base.rb` loads.
- `Base.tw_merger` (item #242, PR #254): one default-configuration `TailwindMerge::Merger` in `TW_MERGER`, also created when `base.rb` loads. It is thread-safe through its own internal `LruRedux::ThreadSafeCache`, so it does not use `CN_CACHE_LOCK`.

All four constants (`TW_MERGER`, `CN_CACHE`, `CN_CACHE_LIMIT`, `CN_CACHE_LOCK`) are private constants of `Base`, not class-level instance variables: constants are looked up through inheritance, so every subclass shares the single instance on purpose and `Subclass.tw_merger` cannot see an empty per-class variable. Nothing is built lazily: a `||=` on first use can create two mergers or two locks when threads race. Outside `cn` and its helper `cn_cached`, the memo is reached only through `@api private` test hooks: `cn_cache` returns a frozen snapshot taken under the lock (never the live hash) and `clear_cn_cache` empties the memo under the lock. `test/phlex/shadcn/base_cache_test.rb` proves in a fresh process that exactly one merger is built at load and that racing first uses share it and the cache.

Earlier this note recorded `Base.tw_merger` as a lazy, unlocked memo with a revisit condition; that condition was met by #242 and nothing is left to revisit. A new memo that does not meet these conditions violates R4 and needs its own entry in the skill with a removal or revisit condition.
