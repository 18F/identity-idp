class SamlRequestValidator
  include ActiveModel::Model

  validate :authorized_service_provider
  validate :authorized_authn_context

  def call(service_provider:, authn_context:)
    self.service_provider = service_provider
    self.authn_context = authn_context

    @success = valid?

    result
  end

  private

  attr_accessor :service_provider, :authn_context
  attr_reader :success

  def result
    {
      authn_context: authn_context,
      errors: errors.messages.values.flatten,
      service_provider: service_provider.issuer,
      valid: success,
    }
  end

  def authorized_service_provider
    return if service_provider.active? # live? instead when dashboard approvals matter.

    errors.add(:service_provider, 'Unauthorized Service Provider')
  end

  def authorized_authn_context
    return if Saml::Idp::Constants::VALID_AUTHN_CONTEXTS.include?(authn_context)

    errors.add(:authn_context, 'Unauthorized authentication context')
  end
end
