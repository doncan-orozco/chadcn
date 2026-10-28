# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::InputOtpTest < Chadcn::TestCase
  InputOtp = Chadcn::InputOtp

  HELPERS = { group: InputOtp::Group, slot: InputOtp::Slot, separator: InputOtp::Separator }.freeze

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def field(root: {}, slots: 0...4, **)
    fragment(render_view do
      render(InputOtp.new(max_length: 4, **root)) do
        render(InputOtp::Group.new) { slots.each { |index| render InputOtp::Slot.new(index: index, **) } }
        render InputOtp::Separator.new
      end
    end)
  end

  test "the input carries the library's attributes and the shadcn data-slot" do
    input = field.at_css("input")

    assert_equal "input-otp", input["data-slot"]
    assert_equal "disabled:cursor-not-allowed", input["class"]
    assert_equal "one-time-code", input["autocomplete"]
    assert_equal "false", input["spellcheck"]
    assert_equal "numeric", input["inputmode"]
    assert_equal "4", input["maxlength"]
    assert_equal "", input["value"]
    assert_equal "true", input["data-input-otp"]
    assert_equal "true", input["data-input-otp-placeholder-shown"]
    assert_nil input["pattern"]
    assert_nil input["aria-placeholder"]
    assert_includes input["style"], "text-align: left"
    assert_includes input["style"], "letter-spacing: -0.5em"
  end

  test "the container wraps the slots and the input wrapper and carries the controller" do
    container = field.at_css("[data-input-otp-container]")

    assert_equal "chadcn--input-otp", container["data-controller"]
    assert_equal "no", container["translate"]
    assert_equal %w[flex items-center gap-2 has-disabled:opacity-50], container["class"].split
    assert_nil container["data-slot"]
    assert_equal "4", container["data-chadcn--input-otp-max-length-value"]
    assert_equal "false", container["data-chadcn--input-otp-controlled-value"]
    assert_equal %w[div div], container.element_children.map(&:name).values_at(0, -1)
    assert_equal "position: absolute; inset: 0px; pointer-events: none", container.element_children.last["style"]
    assert_equal "input", container.element_children.last.element_children.first.name
  end

  test "class goes to the input, container_class_name to the container, both through cn" do
    html = field(root: { class: "disabled:cursor-default", container_class_name: "gap-4" })

    assert_equal "disabled:cursor-default", html.at_css("input")["class"]
    container = html.at_css("[data-input-otp-container]")["class"].split

    assert_includes container, "gap-4"
    refute_includes container, "gap-2"
  end

  test "caller attributes go to the input and the library's own cannot be overridden" do
    input = field(root: { id: "code", name: "otp", aria: { label: "Code" }, data: { testid: "x" }, auto_complete: "off", spell_check: true,
                          style: "color: red", maxlength: 9 }).at_css("input")

    assert_equal %w[code otp Code x off], [ input["id"], input["name"], input["aria-label"], input["data-testid"], input["autocomplete"] ]
    assert_equal "true", input["spellcheck"]
    assert_equal "4", input["maxlength"]
    assert_equal "", input["value"]
    assert_includes input["style"], "position: absolute"
  end

  test "value, default_value and controlled" do
    uncontrolled = field(root: { default_value: "12" })
    controlled = field(root: { value: "123" })

    assert_equal "12", uncontrolled.at_css("input")["value"]
    assert_nil uncontrolled.at_css("input")["data-input-otp-placeholder-shown"]
    assert_equal "false", uncontrolled.at_css("[data-input-otp-container]")["data-chadcn--input-otp-controlled-value"]
    assert_equal "true", controlled.at_css("[data-input-otp-container]")["data-chadcn--input-otp-controlled-value"]
    assert_equal(%w[1 2 3], controlled.css("[data-slot=input-otp-slot]").first(3).map { |slot| slot.children.first.text })
  end

  test "option kwargs accept strings and symbols" do
    root = { input_mode: :text, text_align: :center, push_password_manager_strategy: :experimental_no_flickering, pattern: InputOtp::REGEXP_ONLY_DIGITS,
             placeholder: "1234" }
    html = field(root: root)

    assert_equal "text", html.at_css("input")["inputmode"]
    assert_includes html.at_css("input")["style"], "text-align: center"
    assert_equal "^\\d+$", html.at_css("input")["pattern"]
    assert_equal "1234", html.at_css("input")["aria-placeholder"]
    assert_equal "experimental-no-flickering", html.at_css("[data-input-otp-container]")["data-chadcn--input-otp-push-password-manager-strategy-value"]
  end

  test "disabled gives the container the default cursor" do
    html = field(root: { disabled: true })

    assert_includes html.at_css("[data-input-otp-container]")["style"], "cursor: default"
    assert html.at_css("input").key?("disabled")
    assert_includes field.at_css("[data-input-otp-container]")["style"], "cursor: text"
  end

  test "noscript fallback is rendered unless nil" do
    assert_includes field.at_css("noscript style").text, "--nojs-bg: white"
    assert_nil field(root: { no_script_css_fallback: nil }).at_css("noscript")
    assert_equal "a { b: c }", field(root: { no_script_css_fallback: "a { b: c }" }).at_css("noscript style").text
  end

  test "slots render the char, data-active false, the inert caret template and the index" do
    slot = field(root: { default_value: "12" }).css("[data-slot=input-otp-slot]")

    assert_equal(%w[1 2], slot.first(2).map { |node| node.children.first.text })
    assert_equal(%w[false false false false], slot.map { |node| node["data-active"] })
    assert_equal(%w[0 1 2 3], slot.map { |node| node["data-chadcn--input-otp-index-value"] })
    assert_equal "slot", slot.first["data-chadcn--input-otp-target"]
    caret = slot.first.at_css("template[data-chadcn--input-otp-target=caret]")

    assert_includes caret.inner_html, "animate-caret-blink"
    assert_nil caret["data-slot"]
  end

  test "a slot beyond max_length has no data-active, char or caret" do
    slot = field(root: { default_value: "1234" }, slots: [ 6 ]).at_css("[data-slot=input-otp-slot]")

    assert_nil slot["data-active"]
    assert_equal "", slot.text
    assert_nil slot.at_css("template")
  end

  test "a negative slot index renders like one beyond max_length" do
    slot = field(root: { default_value: "1234" }, slots: [ -1 ]).at_css("[data-slot=input-otp-slot]")

    assert_nil slot["data-active"]
    assert_equal "", slot.text
    assert_nil slot.at_css("template")
  end

  test "pattern, nonce and strategy travel to the controller values" do
    plain = field.at_css("[data-input-otp-container]")
    custom = field(root: { pattern: InputOtp::REGEXP_ONLY_DIGITS, nonce: "abc" }).at_css("[data-input-otp-container]")

    assert_nil plain["data-chadcn--input-otp-pattern-value"]
    assert_nil plain["data-chadcn--input-otp-nonce-value"]
    assert_equal "increase-width", plain["data-chadcn--input-otp-push-password-manager-strategy-value"]
    assert_equal "^\\d+$", custom["data-chadcn--input-otp-pattern-value"]
    assert_equal "abc", custom["data-chadcn--input-otp-nonce-value"]
  end

  test "text_align renders in the input style and unknown options raise" do
    assert_includes field(root: { text_align: :right }).at_css("input")["style"], "text-align: right"
    align = assert_raises(ArgumentError) { InputOtp.new(max_length: 4, text_align: "justify") }
    strategy = assert_raises(ArgumentError) { InputOtp.new(max_length: 4, push_password_manager_strategy: "always") }

    assert_match(/text_align: must be one of left, center, right \(got "justify"\)/, align.message)
    assert_match(/push_password_manager_strategy: must be one of/, strategy.message)
  end

  test "a no_script_css_fallback that would close the style element raises" do
    error = assert_raises(ArgumentError) { InputOtp.new(max_length: 4, no_script_css_fallback: "a{}</style><script>x</script>") }

    assert_match(%r{must not contain "</"}, error.message)
  end

  test "slot classes are verbatim, the caller's win and attrs pass through" do
    slot = field("aria-invalid": true, class: "rounded-none", data: { testid: "s" }).at_css("[data-slot=input-otp-slot]")

    assert_includes slot["class"], "border-input"
    assert_includes slot["class"], "rounded-none"
    assert_equal "true", slot["aria-invalid"]
    assert_equal "s", slot["data-testid"]
  end

  test "group and separator" do
    html = field

    group = html.at_css("[data-slot=input-otp-group]")

    assert_equal %w[flex items-center], group["class"].split
    separator = html.at_css("[data-slot=input-otp-separator]")

    assert_equal "separator", separator["role"]
    assert separator.at_css("svg.lucide-minus")
    custom = fragment(render_view { render InputOtp::Separator.new(role: "presentation", class: "x") }).at_css("div")

    assert_equal %w[presentation x], [ custom["role"], custom["class"] ]
  end

  test "a slot outside InputOtp raises" do
    error = assert_raises(ArgumentError) { render_view { render InputOtp::Slot.new(index: 0) } }
    assert_match(/within InputOtp/, error.message)
  end

  test "InputOTP is the React name of the same class and the pattern constants mirror the library" do
    assert_same InputOtp, Chadcn::InputOTP
    assert_equal [ "^\\d+$", "^[a-zA-Z]+$", "^[a-zA-Z0-9]+$" ],
                 [ InputOtp::REGEXP_ONLY_DIGITS, InputOtp::REGEXP_ONLY_CHARS, InputOtp::REGEXP_ONLY_DIGITS_AND_CHARS ]
  end

  test "every generated helper renders the same HTML as the explicit part" do
    assert_equal HELPERS.keys.sort, InputOtp.instance_methods(false).intersection(HELPERS.keys).sort
    explicit = render_view do
      render(InputOtp.new(max_length: 4)) do
        render(InputOtp::Group.new(class: "g")) { render InputOtp::Slot.new(index: 0, class: "s") }
        render InputOtp::Separator.new(class: "p")
      end
    end
    helpers = render_view do
      render(InputOtp.new(max_length: 4)) do |otp|
        otp.group(class: "g") { otp.slot(index: 0, class: "s") }
        otp.separator(class: "p")
      end
    end

    assert_equal explicit, helpers
  end

  test "no third-party JavaScript is added" do
    root = File.expand_path("../..", __dir__)
    pins = File.read(File.join(root, "config/importmap.rb"))

    refute_match(/input-otp|input_otp/, pins.lines.reject { |line| line.include?("controllers") }.join)
    refute_predicate(Dir[File.join(root, "vendor/**/*input-otp*")], :any?)
  end

  test "InputOTP, the React export name, is autoloadable from its own file" do
    assert_equal File.expand_path("../../lib/chadcn/input_o_t_p.rb", __dir__), Chadcn.const_source_location(:InputOTP).first
    assert_same Chadcn::InputOtp, Chadcn::InputOTP
  end
end
