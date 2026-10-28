# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class OverridesComponentsTest < Minitest::Test
  def test_a_directory_without_its_component_file_is_not_a_component
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "chart/scale"))
      File.write(File.join(dir, "chart/scale/linear.rb"), "")
      File.write(File.join(dir, "button.rb"), "")
      File.write(File.join(dir, "version.rb"), "")

      assert_equal %w[button], Chadcn::Overrides.components(gem_dir: dir)
      assert Chadcn::Overrides.component?("button", gem_dir: dir)
      refute Chadcn::Overrides.component?("chart", gem_dir: dir)
    end
  end
end
