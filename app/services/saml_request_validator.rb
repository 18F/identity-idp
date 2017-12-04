class SamlRequestValidator
  include ActiveModel::Model

  validate :authorized_service_provider
  validate :authorized_authn_context
  validate :authorized_email_nameid_format

  ISSUERS_WITH_EMAIL_NAMEID_FORMAT = Figaro.env.issuers_with_email_nameid_format.split(',').freeze

  def call(service_provider:, authn_context:, nameid_format:)
    self.service_provider = service_provider
    self.authn_context = authn_context
    self.nameid_format = nameid_format

    FormResponse.new(success: valid?, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_accessor :service_provider, :authn_context, :nameid_format

  def extra_analytics_attributes
    {
      authn_context: authn_context,
      service_provider: service_provider.issuer,
    }
  end

  def authorized_service_provider
    return if service_provider.active? # live? instead when dashboard approvals matter.

    errors.add(:service_provider, :unauthorized_service_provider)
  end

  def authorized_authn_context
    return if Saml::Idp::Constants::VALID_AUTHN_CONTEXTS.include?(authn_context)

    errors.add(:authn_context, :unauthorized_authn_context)
  end

  def authorized_email_nameid_format
    return unless email_nameid_format?
    return if service_provider_allowed_to_use_email_nameid_format?

    errors.add(:nameid_format, :unauthorized_nameid_format)
  end

  def email_nameid_format?
    nameid_format == 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'
  end

  def service_provider_allowed_to_use_email_nameid_format?
    ISSUERS_WITH_EMAIL_NAMEID_FORMAT.include?(service_provider.issuer)
  end
end
