# frozen_string_literal: true

class GooglePolicySite
  BASE_URL = URI('https://policies.google.com').freeze

  def self.locale_segment
    active_locale = I18n.locale
    active_locale == I18n.default_locale ? '' : "?hl=#{active_locale}"
  end

  def self.base_url
    URI.join(BASE_URL, locale_segment).to_s
  end

  def self.privacy_url
    URI.join(BASE_URL, "/privacy#{locale_segment}").to_s
  end

  def self.terms_url
    URI.join(BASE_URL, "/terms#{locale_segment}").to_s
  end
end
