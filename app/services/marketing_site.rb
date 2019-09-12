class MarketingSite
  BASE_URL = URI('https://www.login.gov').freeze

  def self.locale_segment
    active_locale = I18n.locale
    active_locale == I18n.default_locale ? '/' : "/#{active_locale}/"
  end

  def self.base_url
    URI.join(BASE_URL, locale_segment).to_s
  end

  def self.privacy_url
    URI.join(BASE_URL, locale_segment, 'policy').to_s
  end

  def self.contact_url
    URI.join(BASE_URL, locale_segment, 'contact').to_s
  end

  def self.nice_help_url
    URI.join(BASE_URL, locale_segment, 'help').to_s.gsub('https://', '')
  end

  def self.help_url
    URI.join(BASE_URL, locale_segment, 'help').to_s
  end

  def self.help_authentication_app_url
    URI.join(BASE_URL, locale_segment, 'help/signing-in/what-is-an-authentication-app/').to_s
  end

  def self.help_hardware_security_key_url
    URI.join(BASE_URL, locale_segment, 'help/signing-in/what-is-a-hardware-security-key/').to_s
  end

  def self.help_privacy_and_security_url
    URI.join(
      BASE_URL,
      locale_segment,
      'help',
      'privacy-and-security',
      'how-does-logingov-protect-my-data',
    ).to_s
  end
end
