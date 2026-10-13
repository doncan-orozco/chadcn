# frozen_string_literal: true

require_relative "lib/phlex/shadcn/version"

Gem::Specification.new do |spec|
  spec.name = "phlex-shadcn"
  spec.version = Phlex::Shadcn::VERSION
  spec.authors = [ "Doncan Orozco" ]
  spec.email = [ "doncan.orozco@gmail.com" ]

  spec.summary = "shadcn/ui components for Phlex."
  spec.description = "A 1:1 port of the shadcn/ui component library to Phlex views with Stimulus behavior, " \
                     "Tailwind classes taken verbatim from shadcn/ui and shadcn-format theme variables."
  spec.homepage = "https://github.com/doncan-orozco/papyro/tree/main/gems/phlex-shadcn"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "app/**/*", "LICENSE", "README.md", "CHANGELOG.md", "THIRD_PARTY_NOTICES.md"].select { |f| File.file?(f) }
  spec.require_paths = [ "lib" ]

  spec.add_dependency "phlex", "~> 2.3"
  spec.add_dependency "tailwind_merge", "~> 1.4"
  spec.add_dependency "zeitwerk", "~> 2.7"
end
