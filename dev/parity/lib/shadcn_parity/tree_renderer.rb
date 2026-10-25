# frozen_string_literal: true

# The packaged Chadcn::Catalog::TreeRenderer plus the harness stubs of a parity scenario: c "_Probe", "_ProbeGroup" (underscore + capital)
# are the ShadcnParity classes. Mirror of dev/react-shadcn-catalog/src/parity/Harness.tsx; both sides read the tree with the same rules.
class ShadcnParity::TreeRenderer < Chadcn::Catalog::TreeRenderer
  PARITY_ROOTS = %w[Probe ProbeGroup].freeze

  private

  def harness_scope(bare) = [ ShadcnParity, bare, PARITY_ROOTS ]
end
