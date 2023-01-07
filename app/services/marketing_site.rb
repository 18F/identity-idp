require 'set'

class MarketingSite
  BASE_URL = URI('https://www.login.gov').freeze

  HELP_CENTER_ARTICLES = %w[
    authentication-methods/which-authentication-method-should-i-use
    creating-an-account/authentication-application
    signing-in/what-is-a-hardware-security-key
    verify-your-identity/accepted-state-issued-identification
    verify-your-identity/how-to-add-images-of-your-state-issued-id
    verify-your-identity/verify-your-identity-in-person
    verify-your-identity/phone-number-and-phone-plan-in-your-name
    verify-your-identity/verify-your-address-by-mail
    get-started/authentication-options
  ].to_set.freeze

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

  def self.security_and_privacy_how_it_works_url
    URI.join(BASE_URL, locale_segment, 'policy/how-does-it-work/').to_s
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
    self.help_url.to_s.gsub('https://www.', '')
  end

  def self.help_url
    URI.join(BASE_URL, locale_segment, 'help').to_s
  end

  def self.help_authentication_app_url
    help_center_article_url(
      category: 'creating-an-account',
      article: 'authentication-application',
    )
  end

  def self.help_which_authentication_method_url
    help_center_article_url(
      category: 'authentication-methods',
      article: 'which-authentication-method-should-i-use',
    )
  end

  def self.help_hardware_security_key_url
    help_center_article_url(
      category: 'signing-in',
      article: 'what-is-a-hardware-security-key',
    )
  end

  def self.security_url
    URI.join(BASE_URL, locale_segment, 'security/').to_s
  end

  def self.help_center_article_url(category:, article:)
    if !valid_help_center_article?(category: category, article: article)
      raise ArgumentError.new("Unknown help center article category #{category}/#{article}")
    end

    URI.join(BASE_URL, locale_segment, "help/#{category}/#{article}/").to_s
  end

  def self.valid_help_center_article?(category:, article:)
    HELP_CENTER_ARTICLES.include?("#{category}/#{article}")
  end
end
