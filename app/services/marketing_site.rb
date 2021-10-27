class MarketingSite
  BASE_URL = URI('https://www.login.gov').freeze

  def self.locale_segment
    active_locale = I18n.locale
    active_locale == I18n.default_locale ? '/' : "/#{active_locale}/"
  end

  def self.base_url
    URI.join(BASE_URL, locale_segment).to_s
  end

  def self.security_and_privacy_practices_url
    URI.join(BASE_URL, locale_segment, 'policy').to_s
  end

  def self.privacy_act_statement_url
    URI.join(BASE_URL, locale_segment, 'policy/our-privacy-act-statement/').to_s
  end

  def self.rules_of_use_url
    URI.join(BASE_URL, locale_segment, 'policy/rules-of-use/').to_s
  end

  def self.messaging_practices_url
    URI.join(BASE_URL, locale_segment, 'policy/messaging-terms-and-conditions/').to_s
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
    URI.join(BASE_URL, locale_segment, 'help/creating-an-account/authentication-application/').to_s
  end

  def self.help_idv_supported_documents_url
    URI.join(
      BASE_URL,
      locale_segment,
      'help/verify-your-identity/accepted-state-issued-identification/',
    ).to_s
  end

  def self.help_idv_verify_by_mail_url
    URI.join(
      BASE_URL,
      locale_segment,
      'help/verify-your-identity/verify-your-address-by-mail/',
    ).to_s
  end

  def self.help_idv_verify_by_phone_url
    URI.join(
      BASE_URL,
      locale_segment,
      'help/verify-your-identity/phone-number-and-phone-plan-in-your-name/',
    ).to_s
  end

  def self.help_which_authentication_method_url
    URI.join(
      BASE_URL,
      locale_segment,
      'help/authentication-methods/which-authentication-method-should-i-use/',
    ).to_s
  end

  def self.help_hardware_security_key_url
    URI.join(BASE_URL, locale_segment, 'help/signing-in/what-is-a-hardware-security-key/').to_s
  end

  def self.help_document_capture_tips_url
    URI.join(
      BASE_URL,
      locale_segment,
      'help/verify-your-identity/how-to-add-images-of-your-state-issued-id/',
    ).to_s
  end

  def self.security_url
    URI.join(BASE_URL, locale_segment, 'security/').to_s
  end
end
