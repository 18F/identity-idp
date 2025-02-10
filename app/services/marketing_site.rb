# frozen_string_literal: true

class MarketingSite
  class UnknownArticleException < StandardError; end

  BASE_URL = URI('https://www.login.gov').freeze

  HELP_CENTER_ARTICLES = %w[
    get-started/authentication-methods
    manage-your-account/add-or-change-your-authentication-method
    manage-your-account/personal-key
    trouble-signing-in/face-or-touch-unlock
    trouble-signing-in/security-check-failed
    verify-your-identity/accepted-identification-documents
    verify-your-identity/how-to-add-images-of-your-state-issued-id
    verify-your-identity/verify-your-identity-in-person
    verify-your-identity/phone-number
    verify-your-identity/verify-your-address-by-mail
    verify-your-identity/overview
    verify-your-identity/verify-your-identity-in-person/find-a-participating-post-office
  ].to_set.freeze

  def self.locale_segment
    active_locale = I18n.locale
    active_locale == I18n.default_locale ? '/' : "/#{active_locale}/"
  end

  def self.base_url
    URI.join(BASE_URL, locale_segment).to_s
  end

  def self.security_and_privacy_practices_url
    URI.join(BASE_URL, locale_segment, 'policy/').to_s
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
    URI.join(BASE_URL, locale_segment, 'contact/').to_s
  end

  def self.nice_help_url
    help_url.to_s.gsub('https://www.', '')
  end

  def self.help_url
    URI.join(BASE_URL, locale_segment, 'help/').to_s
  end

  def self.accessibility_statement_url
    URI.join(BASE_URL, locale_segment, 'accessibility/').to_s
  end

  def self.help_center_article_url(category:, article:, article_anchor: '')
    if !HELP_CENTER_ARTICLES.include?("#{category}/#{article}")
      raise UnknownArticleException, "Unknown help center article category #{category}/#{article}"
    end
    anchor_text = article_anchor.present? ? "##{article_anchor}" : ''
    URI.join(BASE_URL, locale_segment, "help/#{category}/#{article}/#{anchor_text}").to_s
  end

  def self.valid_help_center_article?(category:, article:, article_anchor: '')
    !!help_center_article_url(category:, article:, article_anchor:)
  rescue URI::InvalidURIError, UnknownArticleException
    false
  end
end
