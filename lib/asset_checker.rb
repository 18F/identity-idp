class AssetChecker
  def self.run(argv)
    assets_file = 'app/assets/javascripts/assets.js.erb'
    translations_file = 'app/assets/javascripts/i18n-strings.js.erb'
    @asset_strings = load_included_strings(assets_file)
    @translation_strings = load_included_strings(translations_file)
    exit_code = (argv.map { |f| check_file(f) }).any? ? 1 : 0
    exit exit_code # rubocop:disable Rails/Exit
  end

  def self.check_file(file)
    data = File.open(file).read
    missing_found = false
    missing_translations = find_missing(data, /\Wt\s?\(['"]([^'^"]*)['"]\)/, @translation_strings)
    missing_assets = find_missing(data, /\WassetPath=["'](.*)['"]/, @asset_strings)
    if missing_translations.any? || missing_assets.any?
      missing_found = true
      warn file
      missing_translations.each do |t|
        warn "Missing translation, #{t}"
      end
      missing_assets.each do |a|
        warn "Missing asset, #{a}"
      end
    end
    missing_found
  end

  def self.find_missing(file_data, pattern, source)
    strings = file_data.scan pattern
    strings.reject { |s| source.include? s }
  end

  def self.load_included_strings(file)
    data = File.open(file).read
    key_data = data.split('<% keys = [')[1].split('] %>')[0]
    key_data.scan(/['"](.*)['"]/)
  end
end
