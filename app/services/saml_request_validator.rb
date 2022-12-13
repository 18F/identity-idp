class SamlRequestValidator
  include ActiveModel::Model

  validate :authorized_service_provider
  validate :authorized_authn_context
  validate :authorized_email_nameid_format

  def call(service_provider:, authn_context:, nameid_format:, authn_context_comparison: nil)
    self.service_provider = service_provider
    self.authn_context = Array(authn_context)
    self.authn_context_comparison = authn_context_comparison || 'exact'
    self.nameid_format = nameid_format

    FormResponse.new(success: valid?, errors: errors, extra: extra_analytics_attributes)
  end

  private

  attr_accessor :service_provider, :authn_context, :authn_context_comparison, :nameid_format

  def extra_analytics_attributes
    {
      nameid_format: nameid_format,
      authn_context: authn_context,
      authn_context_comparison: authn_context_comparison,
      service_provider: service_provider&.issuer,
    }
  end

  # This checks that the SP matches something in the database
  # SamlIdpAuthConcern#check_sp_active checks that it's currently active
  def authorized_service_provider
    return if service_provider
    errors.add(
      :service_provider,
      :unauthorized_service_provider,
      type: :unauthorized_service_provider,
    )
  end

  def authorized_authn_context
    if !valid_authn_context? ||
       (ial2_context_requested? && service_provider&.ial != 2)
      errors.add(:authn_context, :unauthorized_authn_context, type: :unauthorized_authn_context)
    end
  end

  def valid_authn_context?
    valid_contexts = Saml::Idp::Constants::VALID_AUTHN_CONTEXTS.dup
    valid_contexts += Saml::Idp::Constants::PASSWORD_AUTHN_CONTEXT_CLASSREFS if step_up_comparison?

    authn_contexts = authn_context.reject do |classref|
      classref.include?(Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF)
    end
    authn_contexts.all? do |classref|
      valid_contexts.include?(classref)
    end
  end

  def step_up_comparison?
    %w[minimum better].include? authn_context_comparison
  end

  def ial2_context_requested?
    case authn_context
    when Array
      authn_context.any? do |classref|
        Saml::Idp::Constants::IAL2_AUTHN_CONTEXTS.include?(classref)
      end
    else
      Saml::Idp::Constants::IAL2_AUTHN_CONTEXTS.include?(authn_context)
    end
  end

  def authorized_email_nameid_format
    return unless email_nameid_format?
    return if service_provider&.email_nameid_format_allowed

    errors.add(:nameid_format, :unauthorized_nameid_format, type: :unauthorized_nameid_format)
  end

  def email_nameid_format?
    [
      'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
      'urn:oasis:names:tc:SAML:2.0:nameid-format:emailAddress',
    ].include?(nameid_format)
  end
end
