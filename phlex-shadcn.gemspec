# frozen_string_literal: true

require_relative "lib/phlex/shadcn/version"

# The one place the repository location is written: a split into its own repository changes these lines (the metadata URIs derive from them).
repository = "https://github.com/doncan-orozco/papyro"
gem_path = "gems/phlex-shadcn" # "" once the gem has its own repository
ref = "main"
at = ->(kind, *rest) { [ repository, kind, ref, gem_path, *rest ].reject(&:empty?).join("/") }

Gem::Specification.new do |spec|
  spec.name = "phlex-shadcn"
  spec.version = Phlex::Shadcn::VERSION
  spec.authors = [ "Doncan Orozco" ]
  spec.email = [ "doncan.orozco@gmail.com" ]

  spec.summary = "shadcn/ui components for Phlex."
  spec.description = "A 1:1 port of the shadcn/ui component library to Phlex views with Stimulus behavior, " \
                     "Tailwind classes taken verbatim from shadcn/ui and shadcn-format theme variables."
  spec.homepage = at.call("tree")
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = at.call("blob", "CHANGELOG.md")
  spec.metadata["rubygems_mfa_required"] = "true"

  # docs/ and .yardopts ship because the README links the docs and `yard` reads .yardopts; the dev kit (dev/), tests and the dummy app do not.
  packaged = %w[lib/**/* app/**/* config/**/* vendor/**/* docs/*.md .yardopts LICENSE README.md CHANGELOG.md THIRD_PARTY_NOTICES.md]
  spec.files = Dir[*packaged].select { |f| File.file?(f) }
  spec.require_paths = [ "lib" ]

  spec.add_dependency "phlex", "~> 2.3"
  spec.add_dependency "tailwind_merge", "~> 1.4"
  spec.add_dependency "zeitwerk", "~> 2.7"
end
