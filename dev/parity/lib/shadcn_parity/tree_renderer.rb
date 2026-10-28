# frozen_string_literal: true

# The packaged Chadcn::Catalog::TreeRenderer plus the harness stubs of a parity scenario: c "_Probe", "_ProbeGroup" (underscore + capital)
# are the ShadcnParity classes, the chart nodes (`_BarChart`, ...) are mapped by {ShadcnParity::ChartScope}. Mirror of
# dev/react-shadcn-catalog/src/parity/Harness.tsx; both sides read the tree with the same rules.
class ShadcnParity::TreeRenderer < Chadcn::Catalog::TreeRenderer
  include ShadcnParity::ChartScope

  PARITY_ROOTS = %w[Probe ProbeGroup].freeze

  private

  # A chart part is {ShadcnParity::ChartScope}'s; every other `_Name` is a stub of the harness (`_ProbeGroupItem` is a part of `_ProbeGroup`).
  def harness_scope(bare) = ShadcnParity::ChartScope::RECHARTS_PARTS.include?(bare) ? super : [ ShadcnParity, bare, PARITY_ROOTS ]
end
