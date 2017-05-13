class SamlRequestPresenter
  ATTRIBUTE_TO_FRIENDLY_NAME_MAP = {
    email: :email,
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
    zipcode: :address,
  }.freeze

  def initialize(request:, service_provider:)
    @request = request
    @service_provider = service_provider
  end

  def requested_attributes
    return [:email] unless loa3_authn_context?
    bundle.map { |attr| ATTRIBUTE_TO_FRIENDLY_NAME_MAP[attr] }.compact.uniq
  end

  private

  attr_reader :request, :service_provider

  def loa3_authn_context?
    authn_context == Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF
  end

  def authn_context
    request.requested_authn_context
  end

  def bundle
    @_bundle ||= (
      authn_request_bundle || service_provider.attribute_bundle || []
    ).map(&:to_sym)
  end

  def authn_request_bundle
    SamlRequestParser.new(request).requested_attributes
  end
end
