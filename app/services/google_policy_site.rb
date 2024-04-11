# frozen_string_literal: true

class GooglePolicySite
  BASE_URL = URI('https://policies.google.com').freeze

  def self.locale_params
    active_locale = I18n.locale
    active_locale == I18n.default_locale ? {} : { hl: active_locale }
  end

  def self.privacy_url
    UriService.add_params(URI.join(BASE_URL, '/privacy'), locale_params)
  end

  def self.terms_url
    UriService.add_params(URI.join(BASE_URL, '/terms'), locale_params)
  end
end
