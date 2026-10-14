# frozen_string_literal: true

# Theme tooling of phlex-shadcn. The theme directory (theme.css + presets/) is `config.phlex_shadcn.theme_dir`, by default
# app/assets/tailwind/theme of the host. Short `theme:*` aliases are in phlex_shadcn_aliases.rake.
namespace :phlex_shadcn do
  namespace :theme do
    # Prints a theme error (or a missing file) as a one-line message instead of a stack trace, and exits non-zero.
    run = lambda do |&body|
      body.call
    rescue Phlex::Shadcn::Theme::Error, Errno::ENOENT => e
      abort e.message
    end

    desc "List theme presets"
    task list: :environment do
      run.call { puts Phlex::Shadcn::Theme.presets }
    end

    desc "Switch the app colors to a preset: bin/rails phlex_shadcn:theme:use[slate]"
    task :use, [ :name ] => :environment do |_task, args|
      run.call do
        abort "usage: bin/rails phlex_shadcn:theme:use[name] (#{Phlex::Shadcn::Theme.presets.join(', ')})" if args[:name].to_s.strip.empty?

        result = Phlex::Shadcn::Theme.use(args[:name])
        puts "theme.css now uses preset #{args[:name]}"
        result[:warnings].each { |warning| warn "warning: #{warning}" }
      end
    end

    desc "Import a pasted shadcn theme: bin/rails phlex_shadcn:theme:import[path|url|-]  (use - to read stdin)"
    task :import, [ :source ] => :environment do |_task, args|
      run.call do
        abort "usage: bin/rails phlex_shadcn:theme:import[file.css|https://...|-]" if args[:source].to_s.strip.empty?

        result = Phlex::Shadcn::Theme.import(args[:source])
        puts "theme.css updated from #{args[:source]}"
        result[:filled].each { |filled| puts "filled: #{filled}" }
        result[:warnings].each { |warning| warn "warning: #{warning}" }
      end
    end

    desc "Validate theme.css: variables complete in light and dark, valid format, text contrast (STRICT=1 fails on contrast)"
    task check: :environment do
      run.call do
        result = Phlex::Shadcn::Theme.check(strict: ENV["STRICT"] == "1")
        result[:warnings].each { |warning| warn "warning: #{warning}" }
        if result[:errors].any?
          result[:errors].each { |error| warn "error: #{error}" }
          abort "theme check failed"
        end
        puts "theme OK (#{result[:warnings].size} warnings)"
      end
    end
  end
end
