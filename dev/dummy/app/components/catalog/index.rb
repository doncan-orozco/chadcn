# frozen_string_literal: true

# The demo page: every ported component with its scenario rendered live, category-free alphabetical nav and a link to the
# theme panel. Knows nothing of a host application (no host i18n, layout or components).
class Catalog::Index < Phlex::HTML
  include Phlex::Rails::Helpers::StylesheetLinkTag
  include Phlex::Rails::Helpers::JavascriptImportmapTags
  include Phlex::Rails::Helpers::T

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
        end
      end
    end
  end

  private

  def header_section
    header(class: "border-b border-border bg-card") do
      div(class: "max-w-7xl mx-auto px-4 py-6 flex items-center justify-between gap-4") do
        div do
          h1(class: "text-3xl font-bold") { t("catalog.title") }
          p(class: "text-muted-foreground mt-2") { t("catalog.subtitle", count: @entries.size) }
        end
        a(href: "/design-system/theme-panel", class: "text-sm underline underline-offset-4") { t("catalog.theme_panel") }
      end
    end
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
