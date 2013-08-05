require 'saml_idp/name_id_formatter'
require 'saml_idp/attribute_decorator'
require 'saml_idp/algorithmable'
require 'saml_idp/signable'
module SamlIdp
  class MetadataBuilder
    include Algorithmable
    include Signable
    attr_accessor :configurator

    def initialize(configurator)
      self.configurator = configurator
    end

    def raw
      @raw ||= fresh
    end

    def fresh
      builder = Builder::XmlMarkup.new
      builder.instruct!
      builder.EntityDescriptor xmlns: "urn:oasis:names:tc:SAML:2.0:metadata",
        "xmlns:saml" => "urn:oasis:names:tc:SAML:2.0:assertion",
        "xmlns:ds" => "http://www.w3.org/2000/09/xmldsig#",
        ID: reference_string,
        entityID: "https://idp.example.org/SAML2" do |entity|
          sign entity
          build_organization entity
          build_contact entity

          entity.IDPSSODescriptor protocolSupportEnumeration: protocol_enumeration do |descriptor|
            build_key_descriptor descriptor
            build_name_id_formats descriptor
            descriptor.SingleSignOnService Binding: "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST",
              Location: single_service_post_location
            build_attribute descriptor
          end

          entity.AttributeAuthorityDescriptor ID: reference_string,
            protocolSupportEnumeration: protocol_enumeration do |authority_descriptor|
            build_key_descriptor authority_descriptor
            build_organization authority_descriptor
            build_contact authority_descriptor
            authority_descriptor.AttributeService Binding: "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST",
              Location: attribute_service_location
            build_name_id_formats authority_descriptor
            build_attribute authority_descriptor
          end
        end
    end
    alias_method :rebuild, :fresh

    def build_key_descriptor(el)
      el.KeyDescriptor use: "signing" do |key_descriptor|
        key_descriptor.KeyInfo xmlns: "http://www.w3.org/2000/09/xmldsig#" do |key_info|
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
        contact.Company technical_contact.company
        contact.GivenName technical_contact.given_name
        contact.SurName technical_contact.sur_name
        contact.TelephoneNumber technical_contact.telephone
        contact.EmailAddress technical_contact.mail_to_string
      end
    end
    private :build_contact

    def reference_id
      @reference_id ||= reference_id_generator.call
    end
    private :reference_id

    def reference_string
      "_#{reference_id}"
    end
    private :reference_string

    def entity_id
      config.base_saml_location
    end
    private :entity_id

    def protocol_enumeration
      "urn:oasis:names:tc:SAML:2.0:protocol"
    end
    private :protocol_enumeration

    def attributes
      @attributes ||= configurator.attributes.inject([]) do |(key,opts), list|
        opts[:friendly_name] = key
        list << AttributeDecorator.new(opts)
        list
      end
    end
    private :attributes

    def name_id_formats
      @name_id_formats ||= NameIdFormatter.new(configurator.name_id_formats).samlize
    end

    %w[
      x509_certificate
      support_email
      organization_name
      organization_url
      attribute_service_location
      single_service_post_location
      reference_id_generator
      technical_contact
    ].each do |delegatable|
      define_method(delegatable) do
        configurator.public_send delegatable
      end
      private delegatable
    end
  end
end
