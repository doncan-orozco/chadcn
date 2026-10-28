# frozen_string_literal: true

require "chadcn/test_case"
require "nokogiri"

class Chadcn::FormTest < Chadcn::TestCase
  User = Struct.new(:email, :bio, keyword_init: true)

  def render_form(**, &block)
    Chadcn::Form.new(**).call(&block || proc { |_| })
  end

  def doc(html) = Nokogiri::HTML5.fragment(html)

  test "renders the form slot, action, post method and passthrough attrs" do
    out = render_form(scope: :user, action: "/users", class: "gap-2", id: "signup")
    form = doc(out).at_css("form")

    assert_equal "form", form["data-slot"]
    assert_equal "/users", form["action"]
    assert_equal "post", form["method"]
    assert_equal "signup", form["id"]
    assert_includes form["class"], "gap-2"
    assert_nil form.at_css("input[name=_method]")
    assert_nil form.at_css("input[name=authenticity_token]")
  end

  test "a get form renders neither the csrf token nor _method" do
    out = render_form(scope: :user, action: "/search", method: :get, csrf_token: "tok")
    form = doc(out).at_css("form")

    assert_equal "get", form["method"]
    assert_nil form.at_css("input[type=hidden]")
  end

  test "a patch form renders method post and a hidden _method" do
    form = doc(render_form(scope: :user, action: "/users/1", method: "PATCH")).at_css("form")

    assert_equal "post", form["method"]
    assert_equal "patch", form.at_css("input[name=_method]")["value"]
  end

  test "csrf token renders a hidden authenticity_token input" do
    form = doc(render_form(scope: :user, csrf_token: "tok")).at_css("form")

    assert_equal "tok", form.at_css("input[name=authenticity_token]")["value"]
    assert_equal "hidden", form.at_css("input[name=authenticity_token]")["type"]
  end

  test "yields itself" do
    yielded = nil
    render_form(scope: :user) { |f| yielded = f }

    assert_instance_of Chadcn::Form, yielded
  end

  test "model: without scope: raises naming scope:" do
    error = assert_raises(ArgumentError) { Chadcn::Form.new(model: User.new) }

    assert_includes error.message, "scope:"
  end

  test "binding: with any Plain-building kwarg raises" do
    plain = Chadcn::Form::Binding::Plain.new(scope: :user)
    kwargs = { scope: :user, model: User.new, errors: {}, action: "/", method: "get", csrf_token: "t", namespace: "n" }

    kwargs.each do |key, value|
      assert_raises(ArgumentError, key.to_s) { Chadcn::Form.new(binding: plain, key => value) }
    end
  end

  test "an explicit binding is used" do
    plain = Chadcn::Form::Binding::Plain.new(scope: :account, action: "/a")
    out = render_form(binding: plain) { |f| f.field(attribute: :email, &:input) }

    assert_equal "/a", doc(out).at_css("form")["action"]
    assert_equal "account[email]", doc(out).at_css("input[data-slot=input]")["name"]
  end

  test "a bound field renders the id and aria contract" do
    user = User.new(email: "a@b.co")
    out = render_form(scope: :user, model: user, errors: { email: [ "is invalid" ] }) do |f|
      f.field(attribute: :email) do |field|
        field.label
        field.input(type: "email")
        field.description { "Hint" }
        field.error
      end
    end
    page = doc(out)
    input = page.at_css("input[data-slot=input]")

    assert_equal "user[email]", input["name"]
    assert_equal "user_email-form-item", input["id"]
    assert_equal "a@b.co", input["value"]
    assert_equal "email", input["type"]
    assert_equal "true", input["aria-invalid"]
    assert_equal "user_email-form-item-description user_email-form-item-message", input["aria-describedby"]
    assert_equal "true", page.at_css("[data-slot=field]")["data-invalid"]
    label = page.at_css("[data-slot=field-label]")

    assert_equal "user_email-form-item", label["for"]
    assert_equal "true", label["data-error"]
    assert_includes label["class"], "data-[error=true]:text-destructive"
    assert_equal "Email", label.text.strip
    assert_equal "user_email-form-item-description", page.at_css("[data-slot=field-description]")["id"]
    error = page.at_css("[data-slot=field-error]")

    assert_equal "user_email-form-item-message", error["id"]
    assert_equal "is invalid", error.text.strip
  end

  test "without errors the contract is the valid one" do
    out = render_form(scope: :user) do |f|
      f.field(attribute: :email) do |field|
        field.label { "Mail" }
        field.input
        field.error { "Fallback" }
      end
    end
    page = doc(out)
    input = page.at_css("input[data-slot=input]")

    assert_equal "false", input["aria-invalid"]
    assert_equal "user_email-form-item-description", input["aria-describedby"]
    assert_nil page.at_css("[data-slot=field]")["data-invalid"]
    assert_equal "false", page.at_css("[data-slot=field-label]")["data-error"]
    assert_equal "Mail", page.at_css("[data-slot=field-label]").text.strip
    assert_equal "Fallback", page.at_css("[data-slot=field-error]").text.strip
  end

  test "error renders nothing without errors and without a block" do
    out = render_form(scope: :user) { |f| f.field(attribute: :email, &:error) }

    assert_nil doc(out).at_css("[data-slot=field-error]")
  end

  test "errors win over the block and several render a list" do
    out = render_form(scope: :user, errors: { "email" => [ "is blank", "is short" ] }) do |f|
      f.field(attribute: :email) { |field| field.error { "ignored" } }
    end
    page = doc(out)

    assert_equal 2, page.css("[data-slot=field-error] li").size
    assert_not_includes out, "ignored"
  end

  test "control yields the same attrs the input receives" do
    seen = nil
    out = render_form(scope: :user, model: { email: "x@y.z" }, errors: { email: [ "bad" ] }) do |f|
      f.field(attribute: :email) do |field|
        field.control(data: { extra: "1" }) { |attrs| seen = attrs }
        field.input
      end
    end
    input = doc(out).at_css("input")

    assert_equal "user[email]", seen[:name]
    assert_equal "user_email-form-item", seen[:id]
    assert_equal "x@y.z", seen[:value]
    assert_equal "true", seen[:aria][:invalid]
    assert_equal "1", seen[:data][:extra]
    assert_equal seen[:aria][:describedby], input["aria-describedby"]
  end

  test "control can render a custom element" do
    out = render_form(scope: :user) do |f|
      f.field(attribute: :email) { |field| field.control { |attrs| field.render Chadcn::Input.new(**attrs, type: "email") } }
    end

    assert_equal "user[email]", doc(out).at_css("input")["name"]
  end

  test "textarea renders the value as content and caller attrs win" do
    out = render_form(scope: :user, model: User.new(bio: "Hello")) do |f|
      f.field(attribute: :bio) { |field| field.textarea(rows: 3, id: "custom") }
    end
    area = doc(out).at_css("textarea")

    assert_equal "Hello", area.text
    assert_equal "custom", area["id"]
    assert_equal "3", area["rows"]
    assert_equal "user[bio]", area["name"]
  end

  test "input caller attrs win over the bound ones" do
    out = render_form(scope: :user) { |f| f.field(attribute: :email) { |field| field.input(name: "mine", class: "w-1/2") } }
    input = doc(out).at_css("input")

    assert_equal "mine", input["name"]
    assert_includes input["class"], "w-1/2"
  end

  test "namespace prefixes the ids" do
    out = render_form(scope: :user, namespace: "signup") { |f| f.field(attribute: :email, &:input) }

    assert_equal "signup_user_email-form-item", doc(out).at_css("input")["id"]
  end

  test "form.field renders the same HTML as the explicit class" do
    helper = render_form(scope: :user) { |f| f.field(attribute: :email, class: "k", &:input) }
    explicit = render_form(scope: :user) do |f|
      f.render(Chadcn::Form::Field.new(attribute: :email, class: "k"), &:input)
    end

    assert_equal explicit, helper
  end

  test "Form::Field keeps the inherited helpers and the orientation" do
    out = render_form(scope: :user) do |f|
      f.field(attribute: :email, orientation: :horizontal) do |field|
        field.content { field.title { "T" } }
      end
    end
    page = doc(out)

    assert_equal "horizontal", page.at_css("[data-slot=field]")["data-orientation"]
    assert page.at_css("[data-slot=field-content]")
  end

  test "Form::Field outside a Form without binding raises" do
    error = assert_raises(ArgumentError) { Chadcn::Form::Field.new(attribute: :email).call { |_| } }

    assert_includes error.message, "must be rendered inside Chadcn::Form or given binding:"
  end

  test "Form::Field with its own binding works outside a Form" do
    plain = Chadcn::Form::Binding::Plain.new(scope: :user)
    out = Chadcn::Form::Field.new(attribute: :email, binding: plain).call(&:input)

    assert_equal "user[email]", doc(out).at_css("input")["name"]
  end

  test "parts outside a Form::Field raise" do
    %i[Label Control Description Error Input Textarea].each do |part|
      klass = Chadcn::Form::Field.const_get(part)
      assert_raises(ArgumentError, part.to_s) { klass.new.call { |_| } }
    end
  end

  test "nested forms restore the outer binding" do
    seen = []
    render_form(scope: :outer) do |outer|
      outer.render(Chadcn::Form.new(scope: :inner)) { |_| }
      outer.field(attribute: :name) { |field| seen << field.name }
    end

    assert_equal [ "outer[name]" ], seen
  end

  test "the context is restored after a block raises" do
    ctx = {}
    assert_raises(RuntimeError) do
      Chadcn::Form.new(scope: :user).call(context: ctx) { |_| raise "boom" }
    end

    assert_nil ctx[Chadcn::Form::CONTEXT_KEY]
  end

  test "Form::Item Label Control Description and Message are not defined" do
    %i[Item Label Control Description Message].each do |name|
      assert_not Chadcn::Form.const_defined?(name, false), name.to_s
    end
  end
end
