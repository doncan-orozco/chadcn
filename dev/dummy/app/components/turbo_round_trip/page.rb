# frozen_string_literal: true

# Two pages with Turbo Drive ON, for the one browser test that drives a real Turbo.visit away and back (test/javascript/turbo_visit.test.mjs).
# The parity page turns Turbo Drive off (the React twin has none), so this is a page of its own. It has no scenario JSON: the React
# oracle and the parity runs never see it.
class TurboRoundTrip::Page < Phlex::HTML
  include Phlex::Rails::Helpers::StylesheetLinkTag
  include Phlex::Rails::Helpers::JavascriptImportmapTags

  PAGES = %w[one two].freeze

  def initialize(page:)
    @page = page
    super()
  end

  def view_template
    doctype
    html(lang: "en") do
      head do
        meta(charset: "utf-8")
        title { "turbo round trip #{@page}" }
        stylesheet_link_tag("tailwind")
        javascript_importmap_tags
      end
      body(class: "bg-background text-foreground") do
        div(class: "p-8 space-y-4", id: "turbo-round-trip-#{@page}") do
          @page == "one" ? first_page : second_page
        end
      end
    end
  end

  private

  def first_page
    a(href: "/design-system/turbo-round-trip/two", id: "to-two") { "Page two" }
    render Chadcn::Collapsible.new(default_open: true, id: "round-trip-collapsible") do |collapsible|
      collapsible.trigger { "Toggle" }
      collapsible.content { "Collapsible body" }
    end
    render Chadcn::Dialog.new(id: "round-trip-dialog") do |dialog|
      dialog.trigger { "Open dialog" }
      dialog.content do
        dialog.header do
          dialog.title { "Round trip dialog" }
          dialog.description { "Open while Turbo leaves the page" }
        end
      end
    end
  end

  def second_page
    h1 { "Page two" }
    a(href: "/design-system/turbo-round-trip/one", id: "to-one") { "Page one" }
  end
end
