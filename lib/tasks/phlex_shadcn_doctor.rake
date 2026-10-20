# frozen_string_literal: true

namespace :phlex_shadcn do
  desc "Check this app's phlex-shadcn setup (non-zero exit on a failure): bin/rails phlex_shadcn:doctor[json] or JSON=1 for JSON " \
       "output, CSS=path for a Tailwind entry file other than the default"
  task :doctor, [ :format ] => :environment do |_task, args|
    context = Phlex::Shadcn::Doctor::Context.new(
      root: Rails.root,
      css: ENV.fetch("CSS", "").then { |css| css.empty? ? Phlex::Shadcn::Doctor::Context::DEFAULT_CSS : css },
      theme_dir: Phlex::Shadcn.config.theme_dir,
      hide_tailwind_stubs: Rails.application.config.phlex_shadcn.hide_tailwind_stubs
    )
    report = Phlex::Shadcn::Doctor.run(context)
    puts(args[:format] == "json" || ENV["JSON"] == "1" ? report.to_json : report.to_text)
    exit(1) unless report.ok?
  end
end
