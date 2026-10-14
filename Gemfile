# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Only for `rake test:engine`: a Rails app is booted in-process to test the engine and the install generator.
group :engine do
  gem "importmap-rails", require: false
  gem "propshaft", require: false
  gem "rails", "~> 8.1", require: false
  gem "tailwindcss-rails", require: false
end

group :development do
  gem "bundler-audit", require: false
  gem "minitest", "~> 6.0"
  gem "nokogiri"
  gem "rake"
  gem "rubocop", require: false
  gem "rubocop-minitest", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rake", require: false

  # Monorepo only: RuboCop treats the topmost Gemfile (the host's) as the project root and loads the host .rubocop.yml for
  # AllCops/Exclude, which needs the host's lint plugins. Remove these when the gem moves to its own repository.
  if File.exist?(File.expand_path("../../.rubocop.yml", __dir__))
    gem "rubocop-capybara", require: false
    gem "rubocop-rails", require: false
    gem "rubocop-rails-omakase", require: false
  end
end
