# frozen_string_literal: true

# Spike: how a server-drawn chart follows its container (decision: dev/decisions/chart.md, "Resize and re-measure").
#
#   (cd dev/react-shadcn-catalog && npm ci)    # once: esbuild, recharts 3.8, playwright (and `npx playwright install chromium`)
#   env -u BUNDLE_GEMFILE LANG=en_US.UTF-8 bundle exec ruby -Ilib dev/spikes/chart-resize/run.rb
#
# For the two examples of ../chart/examples.tsx (stacked bar, monotone line) and three container sizes (16:9, the `aspect-video` of
# ChartContainer), it renders the recharts oracle in Chromium (browser.mjs) and the gem's markup for each option, then prints, per option,
# chart, font and size: the G2 DOM difference (`ChartSpike::Compare` of ../chart, tolerance 1e-3 px) and the largest on-screen box deviation
# of the observed nodes (what the reader sees). Options:
#
#   fixed     what ships (0.1.0): laid out once at initial_dimension 320x200, drawn at that pixel size in whatever box the host gives it
#   viewbox   the same markup, the wrapper and the inner div of the responsive container at 100% of the container: the svg
#             (which already has viewBox="0 0 320 200") scales uniformly, text included; HTML parts (legend, tooltip) stay at their pixel positions
#   relayout  laid out again at the container's size: the markup a server re-render at the measured size returns, and the markup a JS port
#             of the same layout in chadcn--chart would have to produce (it is the same math; its cost is the code to port, printed below)
#   measured  relayout with the text metrics measured in the page (what the re-measure pass hands the layout) instead of the defaults
#
# The report opens with the check that the gem's markup at 320x200 equals the committed oracle, and ends with the costs: recharts' own
# re-layout time after a resize (an upper bound, quantized by frames), the server render time and payload per re-layout, and the size of
# the Ruby layout code a JavaScript re-layout would duplicate next to today's chart JavaScript. Writes tmp/chart-resize/ (ignored); the
# numbers are in README.md.
require "json"
require "fileutils"
require "zlib"
require_relative "examples"
require_relative "../chart/compare"

module ResizeSpike
  ROOT = File.expand_path("../../..", __dir__)
  OUT = File.join(ROOT, "tmp/chart-resize")
  CATALOG = File.join(ROOT, "dev/react-shadcn-catalog")
  SIZES = [ [ 320, 180 ], [ 560, 315 ], [ 800, 450 ] ].freeze
  FONTS = %w[mono sans].freeze
  TICK_TEXT = ".recharts-cartesian-axis-tick-value"
  # The two fixed style strings of the markup the viewbox option rewrites (the inner `width: 0px; height: 0px; overflow: visible` div of the
  # responsive container, and the `.recharts-wrapper` at the 320x200 initial dimension).
  INNER_STYLE = "width: 0px; height: 0px; overflow: visible;"
  WRAPPER_SIZE = /(class="recharts-wrapper" style="[^"]*?)width: 320px; height: 200px;/
  FLUID_STYLE = "width: 100%; height: 100%;"
  CHART_JAVASCRIPT = %w[app/javascript/controllers/chadcn/chart_controller.js app/javascript/chadcn/primitives/chart_*.js].freeze
  DEFAULT_METRICS = { text_height: 16, text_char_width: 0.6 }.freeze
  # The Ruby layout code that depends on the size of the plot (ranges, positions, paths, tick collision) and the code that does not (domains,
  # nice ticks, stacks, formatters, tooltip content, config): a JavaScript re-layout ports the first; the second can travel as data.
  LAYOUT_CODE = {
    "size-dependent" => %w[scale/band.rb scale/point.rb scale/linear.rb shape/curve.rb shape/curve shape/path.rb shape/arc.rb shape/arc
                           shape/polar.rb shape/pie.rb shape/area.rb shape/js_math.rb shape/number.rb cartesian/layout.rb
                           cartesian/tick_layout.rb cartesian/bar_positions.rb cartesian/bar_shapes.rb cartesian/rectangle.rb
                           cartesian/line_points.rb cartesian/label_position.rb cartesian/text.rb cartesian/surface.rb polar/layout.rb
                           polar/canvas.rb polar/view_box.rb polar/pie_sectors.rb polar/radial_bar_sectors.rb polar/radar_points.rb
                           polar/polygon.rb polar/label_position.rb polar/legend_offset.rb polar/surface.rb polar/drawer.rb polar/drawer],
    "size-independent" => %w[scale/nice_ticks.rb scale/nice_ticks shape/stack.rb shape/stack cartesian/axis.rb cartesian/axis_settings.rb
                             cartesian/stacks.rb cartesian/series.rb cartesian/formatter.rb cartesian/value.rb cartesian/tooltip_plan.rb
                             cartesian/tooltip_templates.rb cartesian/overlays.rb polar/axis.rb polar/axis_settings.rb polar/series.rb
                             polar/tooltip_plan.rb polar/overlays.rb polar/label_entries.rb]
  }.freeze

  module_function

  def run
    FileUtils.rm_rf(OUT)
    FileUtils.mkdir_p(File.join(OUT, "phlex"))
    browser("oracle", OUT, JSON.generate(SIZES))
    oracle = JSON.parse(File.read(File.join(OUT, "oracle.json")))
    variants = write_variants(oracle["charts"])
    browser("boxes", OUT)
    boxes = JSON.parse(File.read(File.join(OUT, "phlex.json")))
    report(oracle, variants, boxes)
  end

  def browser(*)
    system("node", "../spikes/chart-resize/browser.mjs", *, chdir: CATALOG, exception: true)
  end

  # { "bar-mono-560x315-relayout" => html }
  def write_variants(charts)
    variants = {}
    charts.each do |key, entry|
      name, font, size = key.split("-")
      width, height = size.split("x").map(&:to_i)
      variants["#{key}-fixed"] = Examples.render(name.to_sym, width: 320, height: 200)
      variants["#{key}-viewbox"] = fluid(variants["#{key}-fixed"])
      variants["#{key}-relayout"] = Examples.render(name.to_sym, width: width, height: height)
      variants["#{key}-measured"] = Examples.render(name.to_sym, width: width, height: height, **metrics(entry["metrics"])) if font == "sans"
    end
    variants.each { |file, html| File.write(File.join(OUT, "phlex", "#{file}.html"), html) }
    variants
  end

  def metrics(measured) = measured.slice("text_height", "text_char_width", "legend_height").transform_keys(&:to_sym)

  # The viewBox option: the wrapper and the inner div of the responsive container (the outer shell div is already at 100%) follow the
  # container; the svg keeps its 320x200 viewBox and scales (meet). Raises when the markup no longer has what it rewrites.
  def fluid(html)
    inner = html.sub(INNER_STYLE, FLUID_STYLE)
    raise "the inner div style #{INNER_STYLE.inspect} is not in the markup" if inner == html

    wrapper = inner.sub(WRAPPER_SIZE, "\\1#{FLUID_STYLE}")
    raise "the .recharts-wrapper at 320x200 is not in the markup" if wrapper == inner

    wrapper
  end

  # Examples at 320x200 against the committed oracle of ../chart (the README cites this line).
  def initial_check
    puts "gem markup at 320x200 against ../chart/oracle (G2 Compare):"
    Examples::NAMES.each do |name|
      oracle = File.read(File.join(__dir__, "../chart/oracle/#{name}.html"))
      dom = ChartSpike::Compare.new(oracle, Examples.render(name, width: 320, height: 200))
      puts "  #{name}: #{dom.errors.size} differences, #{dom.compared_attributes} numeric attributes"
    end
    puts
  end

  def report(oracle, variants, boxes)
    initial_check
    puts "DOM = G2 Compare against recharts at that size (errors, largest numeric deviation px); boxes = largest on-screen deviation px " \
         "of the observed nodes (count mismatches in brackets); text = tick label width on screen / recharts' (the glyph scale)"
    puts "chart-font-size          option                 DOM          boxes   text"
    variants.each_key do |variant|
      key, option = variant.split(/-(?=[a-z]+\z)/)
      expected = oracle["charts"][key]
      dom = ChartSpike::Compare.new(expected["html"], variants[variant])
      worst = dom.max_deviation
      dom_text = dom.errors.empty? ? "0 errors, #{worst&.amount || 0}" : "#{dom.errors.size} errors"
      row = { chart: key, option: option, dom: dom_text, boxes: box_deviation(expected["boxes"], boxes[variant]),
              text: text_scale(expected["boxes"], boxes[variant]) }
      puts format("%<chart>-24s %<option>-9s %<dom>16s %<boxes>14s %<text>6.2f", row)
    end
    puts "\nmeasured text metrics (default #{DEFAULT_METRICS}):"
    oracle["charts"].each { |key, entry| puts "  #{key}: #{entry['metrics']}" if key.include?("-sans-") }
    costs(oracle)
  end

  def box_deviation(expected, actual)
    missing = 0
    worst = expected.sum([]) do |selector, rects|
      others = actual.fetch(selector, [])
      missing += (rects.size - others.size).abs
      rects.zip(others).filter_map do |expected_rect, actual_rect|
        actual_rect && expected_rect.zip(actual_rect).map { |expected_edge, actual_edge| (expected_edge - actual_edge).abs }.max
      end
    end.max || 0
    missing.zero? ? worst.round(3).to_s : "#{worst.round(3)} [#{missing}]"
  end

  def text_scale(expected, actual)
    mean = lambda do |rects|
      raise "no #{TICK_TEXT} boxes" if rects.empty?

      rects.sum { |rect| rect[2] }.fdiv(rects.size)
    end
    mean.call(actual.fetch(TICK_TEXT)) / mean.call(expected.fetch(TICK_TEXT))
  end

  def costs(oracle)
    puts "\nrecharts re-layout after a resize from #{SIZES.first.join('x')} (ms, settled DOM, an upper bound: 2-frame granularity):"
    oracle["charts"].each { |key, entry| puts "  #{key}: #{entry['resize_ms']}" if entry["resize_ms"] }
    puts "recharts + react bundle of the two examples: #{oracle['bundle_bytes']} bytes (esbuild iife, production React, not minified or gzipped)"
    puts "\nserver re-layout (relayout markup rendered by the gem, mean of 50, this machine):"
    Examples::NAMES.each do |name|
      SIZES.each do |width, height|
        html = Examples.render(name, width: width, height: height)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        50.times { Examples.render(name, width: width, height: height) }
        ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000 / 50
        row = { name: name, width: width, height: height, ms: ms, bytes: html.bytesize, gzipped: Zlib.gzip(html).bytesize }
        puts format("  %<name>-4s %<width>dx%<height>d: %<ms>.2f ms, %<bytes>d bytes (%<gzipped>d gzipped)", row)
      end
    end
    puts "\nRuby layout code a JavaScript re-layout duplicates (lines, comments and blanks excluded, lib/chadcn/chart/):"
    LAYOUT_CODE.each { |kind, paths| puts "  #{kind}: #{code_lines(paths)}" }
    puts "  whole chart (lib/chadcn/chart.rb and lib/chadcn/chart/**): #{code_lines([ '../chart.rb', '.' ])}"
    ruby = code_lines(LAYOUT_CODE.fetch("size-dependent"))
    javascript = javascript_lines
    puts "today's chart JavaScript (chart_controller.js and primitives/chart_*.js, same counting): #{javascript}"
    puts "port cost: #{ruby} lines of Ruby to port against #{javascript} lines of chart JavaScript today (#{ruby.fdiv(javascript).round(1)}x)"
  end

  def code_lines(paths)
    base = File.join(ROOT, "lib/chadcn/chart")
    files = paths.flat_map { |path| File.directory?(File.join(base, path)) ? Dir[File.join(base, path, "**/*.rb")] : [ File.join(base, path) ] }.uniq
    files.sum { |file| File.readlines(file).count { |line| !line.strip.empty? && !line.strip.start_with?("#") } }
  end

  # Non-blank, non-comment lines of today's chart JavaScript (a line starting with `//`, `/*` or `*` is a comment).
  def javascript_lines
    CHART_JAVASCRIPT.flat_map { |pattern| Dir[File.join(ROOT, pattern)] }.uniq.sum do |file|
      File.readlines(file).count { |line| !line.strip.empty? && !line.strip.start_with?("//", "/*", "*") }
    end
  end
end

ResizeSpike.run if $PROGRAM_NAME == __FILE__
