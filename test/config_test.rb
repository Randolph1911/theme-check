# frozen_string_literal: true
require "test_helper"

class ConfigTest < Minitest::Test
  def test_load_file_uses_provided_config
    theme = make_theme(".theme-check.yml" => <<~END)
      TemplateLength:
        enabled: false
    END
    config = ThemeCheck::Config.from_path(theme.root).to_h
    assert_equal({ "TemplateLength" => { "enabled" => false } }, config)
  end

  def test_load_file_in_parent_dir
    theme = make_theme(
      ".theme-check.yml" => <<~END,
        TemplateLength:
          enabled: false
      END
      "dist/templates/index.liquid" => "",
    )
    config = ThemeCheck::Config.from_path(theme.root.join("dist")).to_h
    assert_equal({ "TemplateLength" => { "enabled" => false } }, config)
  end

  def test_missing_file
    theme = make_theme
    config = ThemeCheck::Config.from_path(theme.root).to_h
    assert_equal({}, config)
  end

  def test_from_path_uses_empty_config_when_config_file_is_missing
    ThemeCheck::Config.expects(:new).with('theme/')
    ThemeCheck::Config.from_path('theme/')
  end

  def test_enabled_checks_excludes_disabled_checks
    config = ThemeCheck::Config.new(".", "MissingTemplate" => { "enabled" => false })
    refute(check_enabled?(config, ThemeCheck::MissingTemplate))
  end

  def test_root
    config = ThemeCheck::Config.new(".", "root" => "dist", "MissingTemplate" => { "enabled" => false })
    assert_equal(Pathname.new("dist"), config.root)
    refute(check_enabled?(config, ThemeCheck::MissingTemplate))
  end

  def test_empty_file
    theme = make_theme(".theme-check.yml" => "")
    config = ThemeCheck::Config.from_path(theme.root)
    assert_equal({}, config.to_h)
  end

  def test_root_from_config
    theme = make_theme(
      ".theme-check.yml" => <<~END,
        root: dist
      END
      "dist/templates/index.liquid" => "",
    )
    config = ThemeCheck::Config.from_path(theme.root)
    assert_equal(theme.root.join("dist"), config.root)
  end

  def test_picks_nearest_config
    theme = make_theme(
      ".theme-check.yml" => <<~END,
        TemplateLength:
          enabled: false
      END
      "src/.theme-check.yml" => <<~END,
        TemplateLength:
          enabled: true
      END
    )
    config = ThemeCheck::Config.from_path(theme.root.join("src"))
    assert_equal(theme.root.join("src"), config.root)
    assert(check_enabled?(config, ThemeCheck::TemplateLength))
  end

  def test_respects_provided_root
    config = ThemeCheck::Config.from_path(__dir__)
    assert_equal(Pathname.new(__dir__), config.root)
  end

  def test_enabled_checks_returns_default_checks_for_empty_config
    YAML.expects(:load_file)
      .with { |path| path.end_with?('config/default.yml') }
      .returns("SyntaxError" => { "enabled" => true })
    config = ThemeCheck::Config.new(".")
    assert(check_enabled?(config, ThemeCheck::SyntaxError))
  end

  def test_config_overrides_default_config
    YAML.expects(:load_file)
      .with { |path| path.end_with?('config/default.yml') }
      .returns("SyntaxError" => { "enabled" => true })
    config = ThemeCheck::Config.new(".", "SyntaxError" => { "enabled" => false })
    refute(check_enabled?(config, ThemeCheck::SyntaxError))
  end

  def test_custom_check
    theme = make_theme(
      ".theme-check.yml" => <<~END,
        require:
          - ./checks/custom_check.rb
        CustomCheck:
          enabled: true
      END
      "checks/custom_check.rb" => <<~END,
        module ThemeCheck
          class CustomCheck < Check
          end
        end
      END
    )
    config = ThemeCheck::Config.from_path(theme.root)
    assert(check_enabled?(config, ThemeCheck::CustomCheck))
  end

  def test_only_category
    config = ThemeCheck::Config.new(".")
    config.only_categories = [:liquid]
    assert(config.enabled_checks.any?)
    assert(config.enabled_checks.all? { |c| c.category == :liquid })
  end

  def test_exclude_category
    config = ThemeCheck::Config.new(".")
    config.exclude_categories = [:liquid]
    assert(config.enabled_checks.any?)
    assert(config.enabled_checks.none? { |c| c.category == :liquid })
  end

  private

  def check_enabled?(config, klass)
    config.enabled_checks.map(&:class).include?(klass)
  end
end
