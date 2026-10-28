# frozen_string_literal: true

# The packaged Chadcn::Catalog::TreeRenderer plus the harness stubs of a parity scenario: c "_Probe", "_ProbeGroup" (underscore + capital)
# are the ShadcnParity classes, the chart nodes (`_BarChart`, ...) are mapped by {ShadcnParity::ChartScope}. Mirror of
# dev/react-shadcn-catalog/src/parity/Harness.tsx; both sides read the tree with the same rules.
class ShadcnParity::TreeRenderer < Chadcn::Catalog::TreeRenderer
  include ShadcnParity::ChartScope

  PARITY_ROOTS = %w[Probe ProbeGroup].freeze

  private

  def harness_scope(bare) = PARITY_ROOTS.include?(bare) ? [ ShadcnParity, bare, PARITY_ROOTS ] : super
end
