# frozen_string_literal: true

# The packaged Chadcn::Catalog::TreeRenderer plus the harness stubs of a parity scenario: c "_Probe", "_ProbeGroup" (underscore + capital)
# are the ShadcnParity classes. The chart nodes (`_BarChart`, ...) are the gem's own ({Chadcn::Catalog::ChartScope}); the harness adds only
# the text height of its page. Mirror of dev/react-shadcn-catalog/src/parity/Harness.tsx; both sides read the tree with the same rules.
class ShadcnParity::TreeRenderer < Chadcn::Catalog::TreeRenderer
  PARITY_ROOTS = %w[Probe ProbeGroup].freeze
  # The height of one line of text in the harness page: recharts measures a tick label in a span under `body` (the page font, not the
  # chart's `text-xs`), the server has to assume it (`Chart::Container text_height:`); it decides how far the last tick of a vertical
  # axis is pulled inside the plot (recharts:cartesian/getTicks.js, `getTicksEnd`).
  PAGE_TEXT_HEIGHT = 18

  private

  # A chart part is the gem's; every other `_Name` is a stub of the harness (`_ProbeGroupItem` is a part of `_ProbeGroup`).
  def harness_scope(bare) = Chadcn::Catalog::ChartScope.resolvable_node?("_#{bare}") ? super : [ ShadcnParity, bare, PARITY_ROOTS ]

  def render_node(node, roots)
    return super unless node["c"] == "ChartContainer"

    props = node["props"] || {}
    super(node.merge("props" => props.key?("textHeight") ? props : props.merge("textHeight" => PAGE_TEXT_HEIGHT)), roots)
  end
end
