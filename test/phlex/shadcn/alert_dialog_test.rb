# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::AlertDialogTest < Phlex::Shadcn::TestCase
  AlertDialog = Phlex::Shadcn::AlertDialog

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
    host = fragment(dialog).at_css("[data-controller=v2--alert-dialog]")

    assert_equal "display: contents", host["style"]
    assert_equal "false", host["data-v2--alert-dialog-open-value"]
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
    assert_raises(ArgumentError) { dialog(content: { size: "lg" }) }
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
    assert_raises(ArgumentError) { dialog(root: { modal: false }) }
  end

  test "every DX helper renders the same HTML as the explicit class" do
    HELPERS.each do |name, klass|
      assert_respond_to AlertDialog.new, name
      via_helper = render_view { render(AlertDialog.new(default_open: true)) { |d| d.public_send(name) { "x" } } }
      explicit = render_view { render(AlertDialog.new(default_open: true)) { render(klass.new) { "x" } } }

      assert_equal explicit, via_helper, name.to_s
    end
  end
end
