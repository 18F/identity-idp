class SamlRequestPresenter
  ATTRIBUTE_TO_FRIENDLY_NAME_MAP = {
    email: :email,
    all_emails: :all_emails,
    first_name: :given_name,
    middle_name: :name,
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
      attrs << :verified_at if bundle.include?(:verified_at)
      attrs
    end
  end

  private

  attr_reader :request, :service_provider

  def ial2_authn_context?
    (Saml::Idp::Constants::IAL2_AUTHN_CONTEXTS & authn_context).present?
  end

  def ialmax_authn_context?
    authn_context.include? Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF
  end

  def authn_context
    request.requested_authn_contexts
  end

  def bundle
    @_bundle ||= (
      authn_request_bundle || service_provider&.attribute_bundle || []
    ).map(&:to_sym)
  end

  def authn_request_bundle
    SamlRequestParser.new(request).requested_attributes
  end
end
