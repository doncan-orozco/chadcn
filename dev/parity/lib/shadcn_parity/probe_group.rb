# frozen_string_literal: true

# Compound-root stub: exercises the DX helper mode (`group.item { ... }`) of the parity harness.
class ShadcnParity::ProbeGroup < Chadcn::Base
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    div(**merge_attrs({ class: "flex flex-col gap-2 rounded-lg border p-4", data: { slot: "probe-group" } }, @attrs)) do
      yield self if block_given?
    end
  end

  class Item < Chadcn::Base
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ class: "text-sm text-muted-foreground", data: { slot: "probe-group-item" } }, @attrs), &)
    end
  end
end
