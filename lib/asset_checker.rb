require 'yaml'

class AssetChecker
  attr_reader :files

  def initialize(files)
    @files = files
  end

  # @return [Boolean] true if any files are missing
  def check_files
    assets_file = 'app/assets/javascripts/assets.js.erb'
    translations_file = 'config/js_locale_strings.yml'
    @asset_strings = load_included_strings(assets_file)
    @translation_strings = YAML.load_file(translations_file)
    files.any? { |f| file_has_missing?(f) }
  end

  def file_has_missing?(file)
    data = File.open(file).read
    missing_translations = find_missing(data, /\Wt\s?\(['"]([^'"]*?)['"]\)/, @translation_strings)
    missing_assets = find_missing(data, /\WassetPath=["'](.*?)['"]/, @asset_strings)
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
