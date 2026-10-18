# frozen_string_literal: true

# Stub component that proves the parity harness before any real component uses it. React twin: src/parity/probes.tsx.
# Broken-probe self-test: while the file named by ENV["SHADCN_PARITY_BREAK_FLAG"] (set by servers.rb to <repo>/tmp/shadcn-port/_harness/break-probe)
# exists, an extra class is rendered (the runner must fail).
class ShadcnParity::Probe < Phlex::Shadcn::Base
  VARIANTS = {
    "default" => "bg-primary text-primary-foreground",
    "outline" => "border bg-background text-foreground"
  }.freeze
  BREAK_FLAG_ENV = "SHADCN_PARITY_BREAK_FLAG"

  def initialize(variant: "default", as_child: false, **attrs)
    @variant = variant.to_s
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    attrs = merge_attrs({
      class: [ "inline-flex items-center gap-1 rounded-md px-2 py-1 text-sm font-medium [&_svg:not([class*='size-'])]:size-4", VARIANTS[@variant], broken_class ],
      data: { slot: "probe", variant: @variant }
    }, @attrs)
    return render_as_child(@as_child, **attrs, &) if @as_child

    span(**attrs, &)
  end

  private

  def broken_class
    "underline" if ENV[BREAK_FLAG_ENV].to_s != "" && File.exist?(ENV[BREAK_FLAG_ENV])
  end
end
