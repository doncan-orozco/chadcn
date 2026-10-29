# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Cartesian::CssStyleTest < Chadcn::TestCase
  Css = Chadcn::Chart::Cartesian::CssStyle

  test "text writes the base then the caller's Hash with CSS names, numbers in px except unitless properties" do
    assert_equal "position: absolute; z-index: 3; margin-left: 4px; opacity: 0.5;",
                 Css.text({ position: "absolute" }, { zIndex: 3, margin_left: 4, opacity: 0.5 })
  end

  test "text lets the caller's Hash replace a base property and appends a String" do
    assert_equal "visibility: visible;", Css.text({ visibility: "hidden" }, { visibility: "visible" })
    assert_equal "top: 0px; color: red;", Css.text({ top: "0px" }, "color: red;")
  end

  test "declarations are CSS name to String value, from a Hash or from the declarations of a String" do
    assert_equal({ "z-index" => "3", "background-color" => "red", "--gap" => "2px", "-webkit-transition" => "none" },
                 Css.declarations({ zIndex: 3, backgroundColor: "red", "--gap": "2px", WebkitTransition: "none" }))
    assert_equal({ "color" => "red", "background" => "url(a:b)" }, Css.declarations("color: red; background: url(a:b); junk"))
    assert_equal({}, Css.declarations(nil))
  end
end
