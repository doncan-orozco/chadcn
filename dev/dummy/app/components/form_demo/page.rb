# frozen_string_literal: true

# A Chadcn::Form with Turbo Drive ON for the live-validity browser test (test/javascript/form.test.mjs): two required fields, a
# field with a server error that no constraint contradicts, and a second page to leave and come back from. No scenario JSON.
class FormDemo::Page < Phlex::HTML
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
        title { "form demo #{@page}" }
        stylesheet_link_tag("tailwind")
        javascript_importmap_tags
      end
      body(class: "bg-background text-foreground") do
        div(class: "p-8 space-y-4", id: "form-demo-#{@page}") do
          @page == "one" ? first_page : second_page
        end
      end
    end
  end

  private

  def first_page
    a(href: "/design-system/form-demo/two", id: "to-two") { "Page two" }
    render Chadcn::Form.new(scope: :user, action: "/ignored", id: "signup", errors: { username: [ "is already taken" ] }) do |form|
      form.field(attribute: :email) do |field|
        field.label { "Email" }
        field.input(type: "email", required: true)
        field.description { "We never share it." }
        field.error
      end
      form.field(attribute: :name) do |field|
        field.label { "Name" }
        field.input(required: true)
        field.error
      end
      form.field(attribute: :username) do |field|
        field.label { "Username" }
        field.input
        field.error
      end
      render Chadcn::Button.new(type: "submit") { "Sign up" }
    end
  end

  def second_page
    h1 { "Page two" }
    a(href: "/design-system/form-demo/one", id: "to-one") { "Page one" }
  end
end
