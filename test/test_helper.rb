# frozen_string_literal: true
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require "theme_check"
require "minitest/autorun"
require "minitest/focus"
require "mocha/minitest"
require "pry-byebug"
require "tmpdir"

module Minitest
  class Test
    def parse_liquid(code)
      ThemeCheck::Template.parse(code)
    end

    def analyze_theme(*check_classes, templates)
      analyzer = ThemeCheck::Analyzer.new(make_theme(templates), check_classes)
      analyzer.analyze_theme
      analyzer.offenses
    end

    def make_theme(files = {})
      dir = Pathname.new(Dir.mktmpdir)
      files.each_pair do |name, content|
        path = dir.join(name)
        path.parent.mkpath
        path.write(content)
      end
      at_exit { dir.rmtree }
      ThemeCheck::Theme.new(dir)
    end

    def fix_theme(*check_classes, templates)
      theme = make_theme(templates)
      analyzer = ThemeCheck::Analyzer.new(theme, check_classes, true)
      analyzer.analyze_theme
      analyzer.correct_offenses
      sources = theme.liquid.map { |template| [template.relative_path.to_s, template.path.read] }
      Hash[*sources.flatten]
    end

    def assert_offenses(output, offenses)
      assert_equal(output.chomp, offenses.sort_by(&:location).join("\n"))
    end

    def assert_includes_offense(offenses, output)
      assert_includes(offenses.sort_by(&:location).join("\n"), output.chomp)
    end
  end
end
