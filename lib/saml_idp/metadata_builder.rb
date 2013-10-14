require 'saml_idp/name_id_formatter'
require 'saml_idp/attribute_decorator'
require 'saml_idp/algorithmable'
require 'saml_idp/signable'
module SamlIdp
  class MetadataBuilder
    include Algorithmable
    include Signable
    attr_accessor :configurator

    def initialize(configurator = SamlIdp.config)
      self.configurator = configurator
    end

    def fresh
      builder = Builder::XmlMarkup.new
      generated_reference_id do
        builder.EntityDescriptor ID: reference_string,
          xmlns: Saml::XML::Namespaces::METADATA,
          "xmlns:saml" => Saml::XML::Namespaces::ASSERTION,
          "xmlns:ds" => Saml::XML::Namespaces::SIGNATURE,
          entityID: entity_id do |entity|
            sign entity

            entity.IDPSSODescriptor protocolSupportEnumeration: protocol_enumeration do |descriptor|
              build_key_descriptor descriptor
              build_name_id_formats descriptor
              descriptor.SingleSignOnService Binding: "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect",
                Location: single_service_post_location
              build_attribute descriptor
            end

            entity.AttributeAuthorityDescriptor protocolSupportEnumeration: protocol_enumeration do |authority_descriptor|
              build_key_descriptor authority_descriptor
              build_organization authority_descriptor
              build_contact authority_descriptor
              authority_descriptor.AttributeService Binding: "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect",
                Location: attribute_service_location
              build_name_id_formats authority_descriptor
              build_attribute authority_descriptor
            end

            build_organization entity
            build_contact entity
          end
      end
    end
    alias_method :raw, :fresh

    def build_key_descriptor(el)
      el.KeyDescriptor use: "signing" do |key_descriptor|
        key_descriptor.KeyInfo xmlns: Saml::XML::Namespaces::SIGNATURE do |key_info|
          key_info.X509Data do |x509|
            x509.X509Certificate x509_certificate
          end
        end
      end
    end
    private :build_key_descriptor

    def build_name_id_formats(el)
      name_id_formats.each do |format|
        el.NameIDFormat format
      end
    end
    private :build_name_id_formats

    def build_attribute(el)
      attributes.each do |attribute|
        el.tag! "saml:Attribute",
          NameFormat: attribute.name_format,
          Name: attribute.name,
          FriendlyName: attribute.friendly_name do |attribute_xml|
            attribute.values.each do |value|
              attribute_xml.tag! "saml:AttributeValue", value
            end
          end
      end
    end
    private :build_attribute

    def build_organization(el)
      el.Organization do |organization|
        organization.OrganizationName organization_name, "xml:lang" => "en"
        organization.OrganizationDisplayName organization_name, "xml:lang" => "en"
        organization.OrganizationURL organization_url, "xml:lang" => "en"
      end
    end
    private :build_organization

    def build_contact(el)
      el.ContactPerson contactType: "technical" do |contact|
        contact.Company technical_contact.company if technical_contact.company.present?
        contact.GivenName technical_contact.given_name if technical_contact.given_name.present?
        contact.SurName technical_contact.sur_name if technical_contact.sur_name.present?
        contact.TelephoneNumber technical_contact.telephone if technical_contact.telephone.present?
        contact.EmailAddress technical_contact.mail_to_string if technical_contact.mail_to_string.present?
      end
    end
    private :build_contact

    def reference_string
      "_#{reference_id}"
    end
    private :reference_string

    def entity_id
      configurator.base_saml_location
    end
    private :entity_id

    def protocol_enumeration
      Saml::XML::Namespaces::PROTOCOL
    end
    private :protocol_enumeration

    def attributes
      @attributes ||= configurator.attributes.inject([]) do |list, (key, opts)|
        opts[:friendly_name] = key
        list << AttributeDecorator.new(opts)
        list
      end
    end
    private :attributes

    def name_id_formats
      @name_id_formats ||= NameIdFormatter.new(configurator.name_id.formats).all
    end
    private :name_id_formats

    def raw_algorithm
      configurator.algorithm
    end
    private :raw_algorithm

    def x509_certificate
      SamlIdp.config.x509_certificate
      .to_s
      .gsub(/-----BEGIN CERTIFICATE-----/,"")
      .gsub(/-----END CERTIFICATE-----/,"")
      .gsub(/\n/, "")
    end

    %w[
      support_email
      organization_name
      organization_url
      attribute_service_location
      single_service_post_location
      technical_contact
    ].each do |delegatable|
      define_method(delegatable) do
        configurator.public_send delegatable
      end
      private delegatable
    end
  end
end
