# frozen_string_literal: true

require "open3"
require "rbconfig"
require "pathname"
require_relative "readme"

module Smoke
  # Plain-Phlex smoke (ruby-gem-conventions R10): a clean child process, Rails never loaded, renders the README's plain-Ruby fence and
  # its Button + Dialog view, then proves no Rails, ActiveSupport or engine code was pulled in. Offline.
  class Plain
    Result = Struct.new(:success?, :output)

    def initialize(gem_root)
      @gem_root = Pathname.new(gem_root)
      @readme = Readme.new(@gem_root.join("README.md"))
    end

    def call
      output, status = Open3.capture2e(RbConfig.ruby, "-I", @gem_root.join("lib").to_s, "-e", script)
      Result.new(status.success?, output)
    end

    def script
      <<~RUBY
        #{@readme.without_rails_source}
        Chadcn::Loader.eager_load

        button = Chadcn::Button.new(variant: "outline") { "Save" }.call
        abort("Button markup changed: \#{button}") unless button.start_with?('<button data-slot="button" data-variant="outline" data-size="default" class="')

        module Views; class Base < Phlex::HTML; end; module Demo; end; end
        #{@readme.view_source}
        html = Views::Demo::Index.new.call
        %w[data-slot="button" data-controller="chadcn--dialog" data-slot="dialog-trigger" data-slot="dialog-content" data-slot="dialog-title"].each do |marker|
          abort("the README view did not render \#{marker}: \#{html}") unless html.include?(marker)
        end

        abort("Rails was loaded in a plain Phlex process") if defined?(Rails)
        abort("the Rails engine was loaded") if defined?(Chadcn::Engine)
        loaded = $LOADED_FEATURES.grep(/active_support/)
        abort("ActiveSupport was loaded: \#{loaded.first(3).inspect}") unless loaded.empty?
        puts "plain smoke ok: Button + Dialog rendered without Rails (\#{html.bytesize} bytes)"
        print html
      RUBY
    end
  end
end
