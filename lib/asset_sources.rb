# frozen_string_literal: true

class AssetSources
  attr_reader :manifest_path
  attr_reader :manifest
  attr_reader :cache_manifest

  def initialize(manifest_path:, cache_manifest:, i18n_locales:)
    @manifest_path = manifest_path
    @cache_manifest = cache_manifest
    @regexp_locale_suffix = %r{\.(#{i18n_locales.join('|')})\.js$}

    if cache_manifest
      @manifest = read_manifest.freeze
    end
  end

  def get_sources(*names)
    # RailsI18nWebpackPlugin will generate additional assets suffixed per locale, e.g. `.fr.js`.
    # See: app/javascript/packages/rails-i18n-webpack-plugin/extract-keys-webpack-plugin.js

    load_manifest_if_needed

    locale_sources, sources = names.flat_map do |name|
      manifest&.dig('entrypoints', name, 'assets', 'js').presence || begin
        [name] if name.match?(URI::ABS_URI)
      end
    end.uniq.compact.partition { |source| @regexp_locale_suffix.match?(source) }

    [
      *locale_sources.filter { |source| source.end_with? ".#{I18n.locale}.js" },
      *sources,
    ]
  end

  def get_assets(*names)
    load_manifest_if_needed

    names.flat_map do |name|
      manifest&.dig('entrypoints', name, 'assets')&.except('js')&.values&.flatten
    end.uniq.compact
  end

  def get_integrity(path)
    load_manifest_if_needed

    manifest&.dig('integrity', path)
  end

  def read_manifest
    return nil if manifest_path.nil?

    begin
      JSON.parse(File.read(manifest_path))
    rescue JSON::ParserError, Errno::ENOENT
      nil
    end
  end

  def load_manifest
    @manifest = read_manifest
  end

  private

  def load_manifest_if_needed
    load_manifest if !manifest || !cache_manifest
  end
end
