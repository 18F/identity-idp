# frozen_string_literal: true

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

  def initialize(user:,
                 service_provider:,
                 name_id_format:,
                 authn_request:,
                 decrypted_pii:,
                 user_session:)
    self.user = user
    self.service_provider = service_provider
    self.name_id_format = name_id_format
    self.authn_request = authn_request
    self.decrypted_pii = decrypted_pii
    self.user_session = user_session
  end

  def build
    attrs = default_attrs
    add_email(attrs) if bundle.include? :email
    add_all_emails(attrs) if bundle.include? :all_emails
    add_locale(attrs) if bundle.include? :locale
    add_bundle(attrs) if should_add_proofed_attributes?
    add_verified_at(attrs) if bundle.include?(:verified_at) && ial2_service_provider?
    if authn_request.requested_vtr_authn_contexts.present?
      add_vot(attrs)
    else
      add_aal(attrs)
      add_ial(attrs)
    end

    add_x509(attrs) if bundle.include?(:x509_presented) && x509_data
    user.asserted_attributes = attrs
  end

  private

  attr_accessor :user,
                :service_provider,
                :name_id_format,
                :authn_request,
                :decrypted_pii,
                :user_session

  def should_add_proofed_attributes?
    return false if !user.active_profile.present?
    resolved_authn_context_result.identity_proofing_or_ialmax?
  end

  def ial2_service_provider?
    service_provider.ial.to_i >= ::Idp::Constants::IAL2
  end

  def resolved_authn_context_result
    authn_context_resolver.result
  end

  def authn_context_resolver
    @authn_context_resolver ||= begin
      saml = FederatedProtocols::Saml.new(authn_request)
      AuthnContextResolver.new(
        user: user,
        service_provider: service_provider,
        vtr: saml.vtr,
        acr_values: saml.acr_values,
      )
    end
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
      if attr == :phone
        getter = wrap_with_phone_formatter(getter)
      elsif attr == :zipcode
        getter = wrap_with_zipcode_formatter(getter)
      elsif attr == :dob
        getter = wrap_with_dob_formatter(getter)
      end
      attrs[attr] = { getter: getter }
    end
    add_verified_at(attrs)
  end

  def wrap_with_phone_formatter(getter)
    proc do |principal|
      result = getter.call(principal)

      if result.present?
        Phonelib.parse(result).e164
      else
        result
      end
    end
  end

  def wrap_with_zipcode_formatter(getter)
    proc do |principal|
      getter.call(principal)&.strip&.slice(0, 5)
    end
  end

  def wrap_with_dob_formatter(getter)
    proc do |principal|
      if (date_str = getter.call(principal))
        DateParser.parse_legacy(date_str).to_s
      end
    end
  end

  def add_verified_at(attrs)
    attrs[:verified_at] = { getter: verified_at_getter_function }
  end

  def add_vot(attrs)
    context = resolved_authn_context_result.component_values.map(&:name).join('.')
    attrs[:vot] = { getter: vot_getter_function(context) }
  end

  def add_aal(attrs)
    requested_context = requested_aal_authn_context
    requested_aal_level = Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_AAL[requested_context]
    aal_level = requested_aal_level || service_provider.default_aal || ::Idp::Constants::DEFAULT_AAL
    context = Saml::Idp::Constants::AUTHN_CONTEXT_AAL_TO_CLASSREF[aal_level]
    attrs[:aal] = { getter: aal_getter_function(context) } if context
  end

  def add_ial(attrs)
    asserted_ial = authn_context_resolver.asserted_ial_acr
    attrs[:ial] = { getter: ial_getter_function(asserted_ial) } if asserted_ial
  end

  def sp_ial
    Saml::Idp::Constants::AUTHN_CONTEXT_IAL_TO_CLASSREF[service_provider.ial]
  end

  def add_x509(attrs)
    attrs[:x509_subject] = { getter: ->(_principal) { x509_data.subject } }
    attrs[:x509_issuer] = { getter: ->(_principal) { x509_data.issuer } }
    attrs[:x509_presented] = { getter: ->(_principal) { x509_data.presented } }
  end

  def uuid_getter_function
    lambda do |principal|
      identity = principal.active_identity_for(service_provider)
      AgencyIdentityLinker.new(identity).link_identity.uuid
    end
  end

  def verified_at_getter_function
    ->(principal) { principal.active_profile&.verified_at&.iso8601 }
  end

  def vot_getter_function(vot_authn_context)
    ->(_principal) { vot_authn_context }
  end

  def aal_getter_function(aal_authn_context)
    ->(_principal) { aal_authn_context }
  end

  def ial_getter_function(ial_authn_context)
    ->(_principal) { ial_authn_context }
  end

  def attribute_getter_function(attr)
    ->(_principal) { decrypted_pii[attr] }
  end

  def attribute_getter_function_ascii(attr)
    ->(_principal) { decrypted_pii[attr].to_ascii }
  end

  def add_email(attrs)
    attrs[:email] = {
      getter: ->(principal) {
        principal.active_identity_for(service_provider).email_address_for_sharing.email
      },
      name_format: 'urn:oasis:names:tc:SAML:2.0:attrname-format:basic',
      name_id_format: Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS,
    }
  end

  def add_locale(attrs)
    attrs[:locale] = { getter: ->(principal) { principal.web_language } }
  end

  def add_all_emails(attrs)
    attrs[:all_emails] = {
      getter: ->(principal) { principal.confirmed_email_addresses.map(&:email) },
      name_format: 'urn:oasis:names:tc:SAML:2.0:attrname-format:basic',
      name_id_format: Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS,
    }
  end

  def bundle
    @bundle ||= (
      authn_request_bundle || service_provider.metadata[:attribute_bundle] || []
    ).map(&:to_sym)
  end

  def requested_ial_authn_context
    FederatedProtocols::Saml.new(authn_request).requested_ial_authn_context
  end

  def requested_aal_authn_context
    FederatedProtocols::Saml.new(authn_request).aal
  end

  def authn_request_bundle
    SamlRequestParser.new(authn_request).requested_attributes
  end

  def x509_data
    return @x509_data if defined?(@x509_data)
    @x509_data ||= begin
      x509_hash = user_session[:decrypted_x509]
      X509::Attributes.new_from_json(x509_hash) if x509_hash
    end
  end

  def ascii?
    bundle.include?(:ascii)
  end
end
