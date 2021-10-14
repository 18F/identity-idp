module I18nHelpers
  module ClassMethods
    # Wraps I18n.translate to check for unused interpolation arguments
    def translate_with_interpolation_check(
      key = nil,
      throw: false,
      raise: false,
      locale: nil,
      **options
    )
      known_options = [:default, :scope, :count, :base]
      without_interpolation = original_translate(
        key, throw: throw, raise: raise, locale: locale, **options.slice(*known_options)
      )

      if without_interpolation.is_a?(String)
        expected_args = without_interpolation.
          scan(I18n::INTERPOLATION_PATTERN).
          map(&:compact).
          map(&:first).
          map(&:to_sym).
          uniq

        missing_args = expected_args - options.keys
        if missing_args.present?
          raise "missing i18n interpolation args, key=#{key} missing=#{missing_args.join(',')}"
        end
      end

      original_translate(key, throw: throw, raise: raise, locale: locale, **options)
    end
  end

  # Alias method chain... but for class methods :[
  def self.included(mod)
    class << mod
      include ClassMethods
      alias_method :original_translate, :translate
      alias_method :translate, :translate_with_interpolation_check
    end
  end
end
