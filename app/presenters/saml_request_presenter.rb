class SamlRequestPresenter
  ATTRIBUTE_TO_FRIENDLY_NAME_MAP = {
    email: :email,
    all_emails: :all_emails,
    first_name: :given_name,
    last_name: :family_name,
    dob: :birthdate,
    ssn: :social_security_number,
    phone: :phone,
    address1: :address,
    address2: :address,
    city: :address,
    state: :address,
    verified_at: :verified_at,
    zipcode: :address,
  }.freeze

  # @param [ServiceProvider,nil] service_provider
  def initialize(request:, service_provider:)
    @request = request
    @service_provider = service_provider
  end

  def requested_attributes
    if ial2_authn_context? || ialmax_authn_context?
      bundle.map { |attr| ATTRIBUTE_TO_FRIENDLY_NAME_MAP[attr] }.compact.uniq
    else
      attrs = [:email]
      attrs << :all_emails if bundle.include?(:all_emails)
      attrs << :verified_at if bundle.include?(:verified_at)
      attrs
    end
  end

  private

  attr_reader :request, :service_provider

  def ial2_authn_context?
    ial_context.ial2_requested?
  end

  def ialmax_authn_context?
    ial_context.ialmax_requested?
  end

  def authn_context
    request.requested_authn_contexts
  end

  def ial_context
    @ial_context ||= IalContext.new(
      ial: request.requested_ial_authn_context || default_ial_context,
      service_provider: service_provider,
      authn_context_comparison: request.requested_authn_context_comparison,
    )
  end

  def default_ial_context
    if service_provider&.ial
      Saml::Idp::Constants::AUTHN_CONTEXT_IAL_TO_CLASSREF[service_provider.ial]
    else
      Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
    end
  end

  def bundle
    @bundle ||= (
      authn_request_bundle || service_provider&.attribute_bundle || []
    ).map(&:to_sym)
  end

  def authn_request_bundle
    SamlRequestParser.new(request).requested_attributes
  end
end
