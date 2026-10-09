# frozen_string_literal: true

# Localized plain-text content for the delegated-access consent screen, stored as jsonb keyed by
# locale (`{ "en" => "...", "es" => "..." }`).
#
# Every column using this concern must have an `en` value; rendering falls back to `en` when the
# current locale is missing. Values are rendered escaped: nothing here is HTML, because this is
# partner-authored text shown on a Login.gov screen and must not be able to alter the page.
module DelegationLocalizedContent
  extend ActiveSupport::Concern

  DEFAULT_LOCALE = 'en'

  class_methods do
    # Defines `<name>_for(locale = I18n.locale)` for each column, returning the value in that
    # locale with the `en` fallback.
    def localized_content(*names)
      names.each do |name|
        define_method(:"#{name}_for") do |locale = I18n.locale|
          DelegationLocalizedContent.lookup(public_send(name), locale)
        end
      end
    end
  end

  # @param hash [Hash, nil] the stored jsonb value
  # @param locale [String, Symbol] the locale to read
  # @return [String, Array, nil] the value for the locale, the `en` value, or nil
  def self.lookup(hash, locale)
    return nil unless hash.is_a?(Hash)

    hash = hash.with_indifferent_access
    value = hash[locale.to_s]
    value = hash[DEFAULT_LOCALE] if value.blank?
    value
  end

  # True when the stored value carries the required English text.
  def self.english_present?(hash)
    lookup(hash, DEFAULT_LOCALE).present?
  end
end
