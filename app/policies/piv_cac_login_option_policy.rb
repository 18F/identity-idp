class PivCacLoginOptionPolicy
  def initialize(user)
    @user = user
  end

  def configured?
    FeatureManagement.piv_cac_enabled? && user.x509_dn_uuid.present?
  end

  def enabled?
    configured?
  end

  def available?
    enabled? || available_for_email? || user.identities.any?(&:piv_cac_available?)
  end

  private

  attr_reader :user

  def available_for_email?
    piv_cac_email_domains = Figaro.env.piv_cac_email_domains
    return if piv_cac_email_domains.blank?

    domain_list = JSON.parse(piv_cac_email_domains)
    (_, email_domain) = user.email.split(/@/, 2)
    domain_list.any? { |supported_domain| domain_match?(email_domain, supported_domain) }
  end

  def domain_match?(given, matcher)
    if matcher[0] == '.'
      given.end_with?(matcher)
    else
      given == matcher
    end
  end
end
