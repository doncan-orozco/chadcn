# frozen_string_literal: true

namespace :chadcn do
  desc "Check this app's chadcn setup (non-zero exit on a failure): bin/rails chadcn:doctor[json] or JSON=1 for JSON " \
       "output, CSS=path for a Tailwind entry file other than the default (the install generator's --css)"
  task :doctor, [ :format ] => :environment do |_task, args|
    output_format = args[:format].to_s
    unless output_format.empty? || Chadcn::Doctor::Report::FORMATS.include?(output_format)
      warn("unknown format #{output_format.inspect}\n#{Chadcn::Doctor::Report::USAGE}")
      exit(1)
    end

    context = Chadcn::Doctor::Context.new(
      root: Rails.root,
      css: ENV.fetch("CSS", "").then { |css| css.empty? ? Chadcn::Doctor::Context::DEFAULT_CSS : css },
      theme_dir: Chadcn.config.theme_dir,
      hide_tailwind_stubs: Rails.application.config.chadcn.hide_tailwind_stubs
    )
    report = Chadcn::Doctor.run(context)
    puts(output_format == "json" || ENV["JSON"] == "1" ? report.to_json : report.to_text)
    exit(1) unless report.ok?
  end
end
