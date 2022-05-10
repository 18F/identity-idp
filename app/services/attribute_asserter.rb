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
    add_bundle(attrs) if user.active_profile.present? && ial_context.ial2_or_greater?
    add_verified_at(attrs) if bundle.include?(:verified_at) && ial_context.ial2_service_provider?
    add_aal(attrs)
    add_ial(attrs) if authn_request.requested_ial_authn_context || !service_provider.ial.nil?
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

  def ial_context
    @ial_context ||= IalContext.new(
      ial: authn_context,
      service_provider: service_provider,
      user: user,
      authn_context_comparison: authn_request&.requested_authn_context_comparison,
    )
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

  def add_aal(attrs)
    requested_context = authn_request.requested_aal_authn_context
    requested_aal_level = Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_AAL[requested_context]
    aal_level = requested_aal_level || service_provider.default_aal || ::Idp::Constants::DEFAULT_AAL
    context = Saml::Idp::Constants::AUTHN_CONTEXT_AAL_TO_CLASSREF[aal_level]
    attrs[:aal] = { getter: aal_getter_function(context) } if context
  end

  def add_ial(attrs)
    requested_context = authn_request.requested_ial_authn_context
    context = if ial_context.ialmax_requested? && ial_context.ial2_requested?
                sp_ial # IAL2 since IALMAX only works for IAL2 SPs
              else
                requested_context.presence || sp_ial
              end
    attrs[:ial] = { getter: ial_getter_function(context) } if context
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
      getter: ->(principal) { EmailContext.new(principal).last_sign_in_email_address.email },
      name_format: 'urn:oasis:names:tc:SAML:2.0:attrname-format:basic',
      name_id_format: Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS,
    }
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

  def authn_request_bundle
    SamlRequestParser.new(authn_request).requested_attributes
  end

  def authn_context
    authn_request.requested_ial_authn_context
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
