# frozen_string_literal: true

# Live theme preview for developers (parity dummy app): preset select, radius slider, light/dark, contrast badges
# and "Copy CSS" (a block `bin/rails theme:import` accepts). Nothing is persisted. Behavior: Stimulus `chadcn--theme-panel`;
# light/dark is the existing `chadcn--theme` controller. See .ai/skills/shadcn-port/references/theme-contract.md.
class ShadcnParity::ThemePanel < Phlex::HTML
  PAIRS = Chadcn::Theme::CONTRAST_PAIRS

  def view_template
    div(
      class: "mx-auto flex max-w-2xl flex-col gap-6 rounded-xl border bg-card p-6 text-card-foreground",
      data: {
        controller: "chadcn--theme chadcn--theme-panel",
        action: "chadcn--theme:changed->chadcn--theme-panel#refresh",
        chadcn__theme_panel_presets_value: presets.to_json,
        chadcn__theme_panel_pairs_value: PAIRS.to_json,
        chadcn__theme_panel_current_value: current_preset
      }
    ) do
      h2(class: "text-lg font-semibold") { "Theme" }
      controls
      swatches
      div(class: "flex items-center gap-3") do
        button(type: "button", class: button_class, data: { action: "chadcn--theme-panel#copy" }) { "Copy CSS" }
        span(class: "text-sm text-muted-foreground", data: { chadcn__theme_panel_target: "status" })
      end
      ul(class: "grid grid-cols-1 gap-1 text-sm sm:grid-cols-2", data: { chadcn__theme_panel_target: "contrast" })
    end
  end

  private

  def controls
    div(class: "flex flex-wrap items-end gap-4") do
      label(class: "flex flex-col gap-1 text-sm font-medium") do
        plain "Preset"
        select(class: "h-9 rounded-md border border-input bg-transparent px-3 text-sm", data: { chadcn__theme_panel_target: "preset", action: "change->chadcn--theme-panel#applyPreset" }) do
          presets.each_key { |name| option(value: name, selected: name == current_preset) { name } }
        end
      end
      label(class: "flex flex-col gap-1 text-sm font-medium") do
        plain "Radius"
        input(type: "range", min: "0", max: "1.5", step: "0.025", value: "0.625", data: { chadcn__theme_panel_target: "radius", action: "input->chadcn--theme-panel#applyRadius" })
      end
      div(class: "flex gap-2") do
        %w[Light Dark System].each do |mode|
          button(type: "button", class: button_class, data: { action: "chadcn--theme##{"set#{mode}"}" }) { mode }
        end
      end
    end
  end

  def swatches
    div(class: "grid grid-cols-2 gap-2 sm:grid-cols-4") do
      %w[background primary secondary muted accent destructive card popover].each do |name|
        div(class: "rounded-md border p-3 text-xs", style: "background: var(--#{name}); color: var(--#{name}-foreground, var(--foreground))") { name }
      end
    end
  end

  def button_class = "inline-flex h-9 items-center rounded-md border border-input bg-background px-3 text-sm font-medium hover:bg-accent hover:text-accent-foreground"

  def current_preset = "zinc"

  # { "slate" => { "root" => {var => value}, "dark" => {...} } } from the presets directory (same files `theme:use` reads).
  def presets
    @presets ||= Chadcn::Theme.presets.to_h do |name|
      palette = Chadcn::Theme.parse(File.read(File.join(Chadcn::Theme.presets_dir, "#{name}.css")))
      [ name, { root: palette.root, dark: palette.dark } ]
    end
  end
end
