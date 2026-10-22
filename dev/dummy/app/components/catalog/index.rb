# frozen_string_literal: true

# The demo page: every ported component with its scenario rendered live, category-free alphabetical nav and a link to the
# theme panel. Knows nothing of a host application (no host i18n, layout or components).
class Catalog::Index < Phlex::HTML
  include Phlex::Rails::Helpers::StylesheetLinkTag
  include Phlex::Rails::Helpers::JavascriptImportmapTags
  include Phlex::Rails::Helpers::T
  include Phlex::Rails::Helpers::ImagePath
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::Routes

  UPSTREAM_URL = "https://ui.shadcn.com"
  # Wordmark file variant -> classes that show it only in its own theme (light unless `.dark`, dark only under `.dark`).
  WORDMARK_VARIANTS = { "light" => "h-12 w-auto dark:hidden", "dark" => "hidden h-12 w-auto dark:block" }.freeze
  # Stands in for the upstream link inside a translated sentence, so each sentence stays one key per locale.
  UPSTREAM_SLOT = "\u0000"
  # Intrinsic size of the BRAND.md wordmark SVGs, so the browser reserves the box.
  WORDMARK_SIZE = { width: 352, height: 96 }.freeze

  def initialize(entries:)
    @entries = entries
    super()
  end

  def view_template
    doctype
    html(lang: I18n.locale) do
      head do
        meta(charset: "utf-8")
        meta(name: "viewport", content: "width=device-width,initial-scale=1")
        meta(name: "turbo-visit-control", content: "reload")
        title { t("catalog.title") }
        favicons
        stylesheet_link_tag("tailwind")
        javascript_importmap_tags
      end
      body(class: "bg-background text-foreground") do
        div(class: "min-h-screen") do
          header_section
          div(class: "max-w-7xl mx-auto px-4 py-8 lg:grid lg:grid-cols-[14rem_1fr] lg:gap-8") do
            nav_section
            main(class: "min-w-0 space-y-8") { @entries.each { |entry| entry_card(entry) } }
          end
          footer_section
        end
      end
    end
  end

  private

  def header_section
    header(class: "border-b border-border bg-card") do
      div(class: "max-w-7xl mx-auto px-4 py-6 flex items-center justify-between gap-4") do
        div do
          h1 { wordmark }
          p(class: "text-sm font-medium mt-2") { upstream_sentence("catalog.tagline") }
          p(class: "text-muted-foreground mt-2") { t("catalog.subtitle", count: @entries.size) }
        end
        link_to(t("catalog.theme_panel"), theme_panel_path, class: "text-sm underline underline-offset-4")
      end
    end
  end

  # The mascot as favicon, light or dark by the OS color scheme (a favicon cannot follow the `.dark` class).
  def favicons
    WORDMARK_VARIANTS.each_key do |scheme|
      link(
        rel: "icon", type: "image/svg+xml", href: image_path("brand/mascot-#{scheme}.svg"),
        media: "(prefers-color-scheme: #{scheme})"
      )
    end
  end

  # Light and dark variants of the brand guide's wordmark; the theme's `.dark` class picks one (BRAND.md, Assets).
  def wordmark
    alt = t("catalog.wordmark_alt")
    WORDMARK_VARIANTS.each do |variant, classes|
      img(src: image_path("brand/wordmark-#{variant}.svg"), alt:, **WORDMARK_SIZE, class: classes)
    end
  end

  def footer_section
    footer(class: "border-t border-border") do
      p(class: "max-w-7xl mx-auto px-4 py-6 text-xs text-muted-foreground") do
        upstream_sentence("catalog.disclaimer")
      end
    end
  end

  # A translated sentence whose %{upstream} slot becomes the shadcn/ui link (BRAND.md: link on first mention).
  def upstream_sentence(key)
    lead_in, slot, trailing_text = t(key, upstream: UPSTREAM_SLOT).partition(UPSTREAM_SLOT)
    plain lead_in
    unless slot.empty?
      link_to(t("catalog.upstream_name"), UPSTREAM_URL, class: "underline underline-offset-4")
    end
    plain trailing_text
  end

  def nav_section
    nav(aria_label: t("catalog.nav"), class: "hidden lg:block sticky top-4 self-start max-h-[calc(100vh-2rem)] overflow-auto") do
      ul(class: "space-y-1 text-sm") do
        @entries.each do |entry|
          li { a(href: "##{entry.anchor}", class: "block rounded-md px-2 py-1 hover:bg-muted") { entry.title } }
        end
      end
    end
  end

  def entry_card(entry)
    section(id: entry.anchor, class: "scroll-mt-4 rounded-lg border border-border bg-card text-card-foreground") do
      div(class: "flex flex-wrap items-baseline justify-between gap-2 border-b border-border px-6 py-4") do
        h2(class: "text-xl font-semibold") { entry.title }
        p(class: "text-xs text-muted-foreground") { t("catalog.scenario", id: entry.scenario_id, count: entry.scenario_count) }
      end
      # contain-layout makes this box the containing block of fixed descendants (sidebar, sheet layers stay inside it).
      div(class: "p-6 overflow-auto max-h-[32rem] contain-layout") { preview(entry) }
    end
  end

  def preview(entry)
    render ShadcnParity::TreeRenderer.new(tree: entry.tree, component: entry.component)
  rescue StandardError => e
    Rails.logger.error("[catalog] #{entry.component}: #{e.class}: #{e.message}")
    p(class: "text-sm text-destructive") { t("catalog.unavailable", error: e.class.name) }
  end
end
