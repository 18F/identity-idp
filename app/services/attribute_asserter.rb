require 'stringex/unidecoder'
require 'stringex/core_ext'

class AttributeAsserter
  VALID_ATTRIBUTES = %i[
    first_name
    middle_name
    last_name
    address1
    address2
    city
    state
    zipcode
    dob
    ssn
    phone
  ].freeze

  def initialize(user:, service_provider:, name_id_format:, authn_request:, decrypted_pii:)
    self.user = user
    self.service_provider = service_provider
    self.name_id_format = name_id_format
    self.authn_request = authn_request
    self.decrypted_pii = decrypted_pii
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def build
    attrs = default_attrs
    add_email(attrs) if bundle.include? :email
    add_bundle(attrs) if user.active_profile.present? && ial_context.ial2_or_greater?
    add_verified_at(attrs) if bundle.include?(:verified_at) && ial_context.ial2_service_provider?
    add_aal(attrs) if authn_request.requested_aal_authn_context || !service_provider.aal.nil?
    user.asserted_attributes = attrs
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  private

  attr_accessor :user, :service_provider, :name_id_format, :authn_request, :decrypted_pii

  def ial_context
    @ial_context ||= IalContext.new(ial: authn_context, service_provider: service_provider)
  end

  def default_attrs
    {
      uuid: {
        getter: uuid_getter_function,
        name_format: 'urn:oasis:names:tc:SAML:2.0:attrname-format:basic',
        name_id_format: Saml::XML::Namespaces::Formats::NameId::PERSISTENT,
      },
    }
  end

  def add_bundle(attrs)
    bundle.each do |attr|
      next unless VALID_ATTRIBUTES.include? attr
      getter = ascii? ? attribute_getter_function_ascii(attr) : attribute_getter_function(attr)
      attrs[attr] = { getter: getter }
    end
    add_verified_at(attrs)
  end

  def add_verified_at(attrs)
    attrs[:verified_at] = { getter: verified_at_getter_function }
  end

  def add_aal(attrs)
    context = authn_request.requested_aal_authn_context
    context ||= Saml::Idp::Constants::AUTHN_CONTEXT_AAL_TO_CLASSREF[service_provider.aal]
    attrs[:aal] = { getter: aal_getter_function(context) } if context
  end

  def uuid_getter_function
    lambda do |principal|
      identity = principal.decorate.active_identity_for(service_provider)
      AgencyIdentityLinker.new(identity).link_identity.uuid
    end
  end

  def verified_at_getter_function
    ->(principal) { principal.active_profile&.verified_at&.iso8601 }
  end

  def aal_getter_function(aal_authn_context)
    ->(_principal) { aal_authn_context }
  end

  def attribute_getter_function(attr)
    ->(_principal) { decrypted_pii[attr] }
  end

  def attribute_getter_function_ascii(attr)
    ->(_principal) { decrypted_pii[attr].to_ascii }
  end

  def add_email(attrs)
    attrs[:email] = {
      getter: ->(principal) { EmailContext.new(principal).last_sign_in_email_address.email },
      name_format: 'urn:oasis:names:tc:SAML:2.0:attrname-format:basic',
      name_id_format: Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS,
    }
  end

  def bundle
    @_bundle ||= (
      authn_request_bundle || service_provider.metadata[:attribute_bundle] || []
    ).map(&:to_sym)
  end

  def authn_request_bundle
    SamlRequestParser.new(authn_request).requested_attributes
  end

  def ial2_authn_context?
    Saml::Idp::Constants::IAL2_AUTHN_CONTEXTS.include?(authn_context) ||
      (authn_context == Saml::Idp::Constants::IAL2_STRICT_AUTHN_CONTEXT_CLASSREF)
  end

  def authn_context
    authn_request.requested_ial_authn_context
  end

  def ascii?
    bundle.include?(:ascii)
  end
end
