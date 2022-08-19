class AssetSources
  class << self
    attr_accessor :manifest_path
    attr_accessor :manifest
    attr_accessor :cache_manifest

    def get_sources(*names)
      # RailsI18nWebpackPlugin will generate additional assets suffixed per locale, e.g. `.fr.js`.
      # See: app/javascript/packages/rails-i18n-webpack-plugin/extract-keys-webpack-plugin.js
      regexp_locale_suffix = %r{\.(#{I18n.available_locales.join('|')})\.js$}

      load_manifest_if_needed

      locale_sources, sources = names.flat_map do |name|
        manifest&.dig('entrypoints', name, 'assets', 'js')
      end.uniq.compact.partition { |source| regexp_locale_suffix.match?(source) }

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
      manifest&.dig('integrity', path)
    end

    def load_manifest
      self.manifest = begin
        JSON.parse(File.read(manifest_path))
      rescue JSON::ParserError, Errno::ENOENT
        nil
      end
    end

    private

    def load_manifest_if_needed
      load_manifest if !manifest || !cache_manifest
    end
  end
end
