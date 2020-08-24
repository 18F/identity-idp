require 'yaml'

class AssetChecker
  ASSETS_FILE = 'app/assets/javascripts/assets.js.erb'.freeze
  TRANSLATIONS_FILE = 'config/js_locale_strings.yml'.freeze

  attr_reader :files, :assets_file, :translations_file

  def initialize(files, assets_file: ASSETS_FILE, translations_file: TRANSLATIONS_FILE)
    @files = files
    @assets_file = assets_file
    @translations_file = translations_file
  end

  # @return [Boolean] true if any files are missing
  def check_files
    @asset_strings = load_included_strings(assets_file)
    @translation_strings = YAML.load_file(translations_file)
    files.any? { |f| file_has_missing?(f) }
  end

  def file_has_missing?(file)
    data = File.open(file).read
    missing_translations = find_missing(data, /\Wt\s?\(['"]([^'"]*?)['"]\)/, @translation_strings)
    missing_assets = find_missing(data, /\WgetAssetPath\(["'](.*?)['"]\)/, @asset_strings)
    has_missing = (missing_translations.any? || missing_assets.any?)
    if has_missing
      warn file
      missing_translations.each do |t|
        warn "Missing translation, #{t}"
      end
      missing_assets.each do |a|
        warn "Missing asset, #{a}"
      end
    end
    has_missing
  end

  def find_missing(file_data, pattern, source)
    strings = (file_data.scan pattern).flatten
    strings.reject { |s| source.include? s }
  end

  def load_included_strings(file)
    data = File.open(file).read
    key_data = data.split('<% keys = [').last.split('] %>').first
    key_data.scan(/['"](.*)['"]/).flatten
  end
end
