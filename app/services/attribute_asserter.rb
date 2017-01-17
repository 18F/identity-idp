class AttributeAsserter
  VALID_ATTRIBUTES = [
    :first_name,
    :middle_name,
    :last_name,
    :address1,
    :address2,
    :city,
    :state,
    :zipcode,
    :dob,
    :ssn,
    :phone
  ].freeze

  URI_PATTERN = Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF

  def initialize(user:, service_provider:, authn_request:, decrypted_pii:)
    self.user = user
    self.service_provider = service_provider
    self.authn_request = authn_request
    self.decrypted_pii = decrypted_pii
  end

  def build
    attrs = default_attrs
    add_email(attrs) if bundle.include? :email
    add_bundle(attrs) if user.active_profile.present? && loa3_authn_context?
    user.asserted_attributes = attrs
  end

  private

  attr_accessor :user, :service_provider, :authn_request, :decrypted_pii

  def default_attrs
    {
      uuid: {
        getter: uuid_getter_function,
        name_format: Saml::XML::Namespaces::Formats::NameId::PERSISTENT,
        name_id_format: Saml::XML::Namespaces::Formats::NameId::PERSISTENT
      }
    }
  end

  def add_bundle(attrs)
    bundle.each do |attr|
      next unless VALID_ATTRIBUTES.include? attr
      attrs[attr] = { getter: attribute_getter_function(attr) }
    end
    attrs[:verified_at] = { getter: verified_at_getter_function }
  end

  def uuid_getter_function
    ->(principal) { principal.decorate.active_identity_for(service_provider).uuid }
  end

  def verified_at_getter_function
    ->(principal) { principal.active_profile.verified_at.iso8601 }
  end

  def attribute_getter_function(attr)
    ->(_principal) { decrypted_pii[attr] }
  end

  def add_email(attrs)
    attrs[:email] = {
      getter: :email,
      name_format: Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS,
      name_id_format: Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS
    }
  end

  def bundle
    @_bundle ||= (
      authn_request_bundle || service_provider.metadata[:attribute_bundle] || []
    ).map(&:to_sym)
  end

  def authn_request_bundle
    return unless authn_context_attr_nodes.any?
    authn_context_attr_nodes.join(':').gsub(URI_PATTERN, '').split(/\W+/).compact.uniq
  end

  def authn_context_attr_nodes
    @_attr_node_contents ||= begin
      doc = Saml::XML::Document.parse(authn_request.raw_xml)
      doc.xpath(
        '//samlp:AuthnRequest/samlp:RequestedAuthnContext/saml:AuthnContextClassRef',
        samlp: Saml::XML::Namespaces::PROTOCOL,
        saml: Saml::XML::Namespaces::ASSERTION
      ).select do |node|
        node.content =~ /#{Regexp.escape(URI_PATTERN)}/
      end
    end
  end

  def loa3_authn_context?
    authn_context == Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF
  end

  def authn_context
    authn_request.requested_authn_context
  end
end
