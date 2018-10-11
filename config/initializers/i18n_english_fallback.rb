I18n.module_eval do
  class << self
    def translate(*args)
      original_translation = super(*args)
      return original_translation unless original_translation == 'NOT TRANSLATED YET'
      fallback_to_english(*args)
    end

    alias_method :t, :translate

    private

    def fallback_to_english(*args)
      key = args.shift
      options = args.last.is_a?(Hash) ? args.last : {}
      options.delete(:locale)

      config.backend.translate(:en, key, options)
    end
  end
end
