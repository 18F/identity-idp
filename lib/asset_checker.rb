class AssetChecker
  def self.run(argv)
    assets_file = 'app/assets/javascripts/assets.js.erb'
    translations_file = 'app/assets/javascripts/i18n-strings.js.erb'
    @asset_strings = load_included_strings(assets_file)
    @translation_strings = load_included_strings(translations_file)
    argv.map { |f| check_file(f) }
  end

  def self.check_file(file)
    data = File.open(file).read
    missing_translations = find_missing(data,/\Wt\(['"](.*)['"]\)/, @translation_strings)
    missing_assets = find_missing(data, /\WassetPath=["'](.*)['"]/, @asset_strings)
    if missing_translations.any? || missing_assets.any?
      warn file
      missing_translations.each do |t|
        warn "Missing translation, #{t}"
      end
      missing_assets.each do |a|
        warn "Missing asset, #{a}"
      end
    end
  end

  def self.find_missing(file_data, pattern, source)
    missing = []
    strings = file_data.scan pattern
    strings.each do |s|
      missing.push(s) unless source.include? s
    end
    missing
  end

  def self.load_included_strings(file)
    data = File.open(file).read
    key_data = data.split('<% keys = [')[1].split('] %>')[0]
    key_data.scan(/['"](.*)['"]/)
  end
end
