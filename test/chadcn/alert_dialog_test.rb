# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::AlertDialogTest < Chadcn::TestCase
  AlertDialog = Chadcn::AlertDialog

  HELPERS = {
    trigger: AlertDialog::Trigger, content: AlertDialog::Content, header: AlertDialog::Header,
    footer: AlertDialog::Footer, title: AlertDialog::Title, description: AlertDialog::Description,
    media: AlertDialog::Media, action: AlertDialog::Action, cancel: AlertDialog::Cancel
  }.freeze

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def dialog(root: {}, content: {}, action: {})
    render_view do
      render(AlertDialog.new(**root)) do
        render(AlertDialog::Trigger.new) { "Open" }
        render(AlertDialog::Content.new(**content)) do
          render(AlertDialog::Title.new) { "Title" }
          render(AlertDialog::Description.new) { "Description" }
          render(AlertDialog::Cancel.new) { "Cancel" }
          render(AlertDialog::Action.new(**action)) { "Continue" }
        end
      end
    end
  end

  test "host carries the controller and the closed parts live in a template" do
    host = fragment(dialog).at_css("[data-controller=shadcn--alert-dialog]")

    assert_equal "display: contents", host["style"]
    assert_equal "false", host["data-shadcn--alert-dialog-open-value"]
    assert host.at_css("template [data-slot=alert-dialog-overlay]")
    assert_equal "alert-dialog-trigger", host.at_css("button")["data-slot"]
  end

  test "content is an alertdialog with size, ids and no close button" do
    content = fragment(dialog(root: { default_open: true },
                              content: { size: :sm,
                                         role: "dialog" })).at_css("[data-slot=alert-dialog-content]")

    assert_equal "dialog", content["role"]
    assert_equal "sm", content["data-size"]
    assert_equal content["aria-labelledby"], content.at_css("h2")["id"]
    assert_equal content.at_css("p")["id"], content["aria-describedby"]
    assert_nil content.at_css("[data-slot=alert-dialog-content] > button:last-child.absolute")
    error = assert_raises(ArgumentError) { dialog(content: { size: "lg" }) }

    assert_match(/size must be one of default, sm, got "lg"/, error.message)
  end

  test "action and cancel join the caller class without merging" do
    doc = fragment(dialog(root: { default_open: true }, action: { class: "rounded-full", variant: :destructive }))
    action = doc.at_css("[data-slot=alert-dialog-action]")
    cancel = doc.at_css("[data-slot=alert-dialog-cancel]")

    assert_equal "destructive", action["data-variant"]
    assert_includes action["class"], "rounded-md"
    assert_includes action["class"], "rounded-full"
    assert_equal "outline", cancel["data-variant"]
    assert_equal "button", cancel["type"]
  end

  test "modal is not accepted" do
    error = assert_raises(ArgumentError) { dialog(root: { modal: false }) }

    assert_match(/unknown keyword: :modal/, error.message)
  end

  test "every DX helper renders the same HTML as the explicit class" do
    HELPERS.each do |name, klass|
      assert_respond_to AlertDialog.new, name
      via_helper = render_view { render(AlertDialog.new(default_open: true)) { |d| d.public_send(name) { "x" } } }
      explicit = render_view { render(AlertDialog.new(default_open: true)) { render(klass.new) { "x" } } }

      assert_equal explicit, via_helper, name.to_s
    end
  end

  test "root attributes and options land on the host" do
    host = fragment(dialog(root: { default_open: true, class: "x-root", data: { foo: "bar" } })).at_css("[data-controller=shadcn--alert-dialog]")

    assert_includes host["class"], "x-root"
    assert_equal "bar", host["data-foo"]
    assert_equal "true", host["data-shadcn--alert-dialog-open-value"]
  end

  test "portal forwards force_mount and container to the controller" do
    html = render_view do
      render(AlertDialog.new) { render(AlertDialog::Portal.new(force_mount: true, container: "#c")) { "" } }
    end
    options = JSON.parse(fragment(html).at_css("template[data-shadcn--dialog-options]")["data-shadcn--dialog-options"])

    assert_equal({ "forceMount" => true, "container" => "#c" }, options)
  end

  test "force_mount is accepted and ignored on content and overlay" do
    plain = render_view { render(AlertDialog.new) { render(AlertDialog::Content.new) { render(AlertDialog::Overlay.new) } } }
    forced = render_view do
      render(AlertDialog.new) { render(AlertDialog::Content.new(force_mount: true)) { render(AlertDialog::Overlay.new(force_mount: true)) } }
    end

    assert_equal plain, forced
  end

  test "cancel and action take their variant and size" do
    doc = fragment(dialog(root: { default_open: true }, action: { variant: "destructive", size: "lg" }))
    action = doc.at_css("[data-slot=alert-dialog-action]")

    assert_equal "destructive", action["data-variant"]
    assert_equal "lg", action["data-size"]

    cancel = fragment(render_view do
      render(AlertDialog.new(default_open: true)) { render(AlertDialog::Cancel.new(variant: :ghost, size: "sm")) { "C" } }
    end).at_css("[data-slot=alert-dialog-cancel]")

    assert_equal "ghost", cancel["data-variant"]
    assert_equal "sm", cancel["data-size"]
  end

  test "parts merge their class" do
    html = render_view do
      render(AlertDialog.new(default_open: true)) do
        render(AlertDialog::Content.new(class: "x-content")) do
          render(AlertDialog::Header.new(class: "x-header")) { "H" }
          render(AlertDialog::Media.new(class: "x-media")) { "M" }
          render(AlertDialog::Title.new(class: "x-title")) { "T" }
          render(AlertDialog::Description.new(class: "x-description")) { "D" }
          render(AlertDialog::Footer.new(class: "x-footer")) { "F" }
        end
      end
    end
    doc = fragment(html)

    %w[content header media title description footer].each do |slot|
      assert_includes doc.at_css("[data-slot=alert-dialog-#{slot}]")["class"], "x-#{slot}", slot
    end
  end

  test "parts raise a clear ArgumentError outside the root" do
    %i[Trigger Content Overlay Portal Title Description Cancel].each do |part|
      error = assert_raises(ArgumentError, part.to_s) { render_view { render(AlertDialog.const_get(part).new) } }

      assert_match(/must be used within AlertDialog/, error.message, part.to_s)
    end
  end

  test "as_child renders the trigger onto the given element" do
    out = render_view do
      render(AlertDialog.new) do
        render(AlertDialog::Trigger.new(as_child: :a, href: "/x", class: "t")) { "Open" }
      end
    end
    trigger = Nokogiri::HTML5.fragment(out).at_css("[data-slot*=trigger]")

    assert_equal "a", trigger.name
    assert_equal "/x", trigger["href"]
    assert_includes trigger["class"], "t"
  end
end
