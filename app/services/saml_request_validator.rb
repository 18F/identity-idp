class SamlRequestValidator
  include ActiveModel::Model

  validate :authorized_service_provider
  validate :authorized_authn_context

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
    if !Saml::Idp::Constants::VALID_AUTHN_CONTEXTS.include?(authn_context) ||
       (authn_context == Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF &&
         service_provider.ial != 2)
      errors.add(:authn_context, :unauthorized_authn_context)
    end
  end
end
