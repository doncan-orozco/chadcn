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
  gem "yard", require: false
end
