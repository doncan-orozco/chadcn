# frozen_string_literal: true

# shadcn `ChartStyle`: the `<style>` element that defines `--color-<key>` for every config entry that has a `color` or a `theme`,
# once under `[data-chart=<id>]` and once under `.dark [data-chart=<id>]`. Renders nothing when no entry has a color.
#
# Like React's `ChartStyle` it takes no `class:` or attributes (the one R6 exception of the chart, dev/port/deviations/chart.json).
# `id` and the config are validated (see {Chadcn::Chart::Config}) because they are written into the stylesheet.
#
# @example
#   render Chadcn::Chart::Style.new(id: "chart-1", config: { desktop: { color: "var(--chart-1)" } })
class Chadcn::Chart::Style < Chadcn::Base
  ID = /\A[A-Za-z0-9_-]+\z/
  private_constant :ID

  # @param id [String] the chart id, the value of `data-chart` (`chart-<id>` for a {Chadcn::Chart::Container})
  # @param config [Hash, Chadcn::Chart::Config]
  # @raise [ArgumentError] when the id or the config cannot be written into a style
  def initialize(id:, config:)
    @id = id.to_s
    raise ArgumentError, "chart style id #{id.inspect} must be letters, digits, _ and -" unless ID.match?(@id)

    @config = Chadcn::Chart::Config.new(config)
    super()
  end

  # @return [void]
  def view_template
    colors = @config.color_entries
    return if colors.empty?

    css = Chadcn::Chart::Config::THEMES.map { |theme, prefix| rule(theme: theme, prefix: prefix, colors: colors) }.join("\n")
    style { raw safe(css) }
  end

  private

  # `chart.tsx`: a null entry (no color for this theme) joins as an empty line.
  def rule(theme:, prefix:, colors:)
    lines = colors.map do |key, entry|
      color = entry.theme ? entry.theme[theme] : entry.color
      color ? "  --color-#{key}: #{color};" : ""
    end
    "\n#{prefix} [data-chart=#{@id}] {\n#{lines.join("\n")}\n}\n"
  end
end
