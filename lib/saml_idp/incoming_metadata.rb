require 'set'
require 'saml_idp/hashable'
module SamlIdp
  class IncomingMetadata
    include Hashable
    attr_accessor :raw

    delegate :xpath, to: :document
    private :xpath

    def initialize(raw = "")
      self.raw = raw
    end

    def document
      @document ||= Saml::XML::Document.parse raw
    end

    def sign_assertions
      doc = xpath(
        "//md:SPSSODescriptor",
        ds: signature_namespace,
        md: metadata_namespace
      ).first
      doc ? !!doc["WantAssertionsSigned"] : false
    end
    hashable :sign_assertions

    def display_name
      role_descriptor_document.present? ? role_descriptor_document["ServiceDisplayName"] : ""
    end
    hashable :display_name

    def contact_person
      {
        given_name: given_name,
        surname: surname,
        company: company,
        telephone_number: telephone_number,
        email_address: email_address
      }
    end
    hashable :contact_person

    def signing_certificate
      xpath(
        "//md:SPSSODescriptor/md:KeyDescriptor[@use='signing']/ds:KeyInfo/ds:X509Data/ds:X509Certificate",
        ds: signature_namespace,
        md: metadata_namespace
      ).first.try(:content).to_s
    end
    hashable :signing_certificate

    def encryption_certificate
      xpath(
        "//md:SPSSODescriptor/md:KeyDescriptor[@use='encryption']/ds:KeyInfo/ds:X509Data/ds:X509Certificate",
        ds: signature_namespace,
        md: metadata_namespace
      ).first.try(:content).to_s
    end
    hashable :encryption_certificate

    def single_logout_services
      xpath(
        "//md:SPSSODescriptor/md:SingleLogoutService",
        md: metadata_namespace
      ).reduce({}) do |hash, el|
        hash[el["Binding"].to_s.split(":").last] = el["Location"]
        hash
      end
    end
    hashable :single_logout_services

    def name_id_formats
      xpath(
        "//md:SPSSODescriptor/md:NameIDFormat",
        md: metadata_namespace
      ).reduce(Set.new) do |set, el|
        props = el.content.to_s.match /urn:oasis:names:tc:SAML:(?<version>\S+):nameid-format:(?<name>\S+)/
        set << props[:name].to_s.underscore if props[:name].present?
        set
      end
    end
    hashable :name_id_formats

    def assertion_consumer_services
      xpath(
        "//md:SPSSODescriptor/md:AssertionConsumerService",
        md: metadata_namespace
      ).sort_by { |el| el["index"].to_i }.reduce([]) do |array, el|
        props = el["Binding"].to_s.match /urn:oasis:names:tc:SAML:(?<version>\S+):bindings:(?<name>\S+)/
        array << { binding: props[:name], location: el["Location"], default: !!el["isDefault"] }
        array
      end
    end
    hashable :assertion_consumer_services

    def given_name
      contact_person_document.xpath("//md:GivenName", md: metadata_namespace).first.try(:content).to_s
    end

    def surname
      contact_person_document.xpath("//md:SurName", md: metadata_namespace).first.try(:content).to_s
    end

    def company
      contact_person_document.xpath("//md:Company", md: metadata_namespace).first.try(:content).to_s
    end

    def telephone_number
      contact_person_document.xpath("//md:TelephoneNumber", md: metadata_namespace).first.try(:content).to_s
    end

    def email_address
      contact_person_document.xpath("//md:EmailAddress", md: metadata_namespace).first.try(:content).to_s.gsub("mailto:", "")
    end

    def role_descriptor_document
      @role_descriptor ||= xpath("//md:RoleDescriptor", md: metadata_namespace).first
    end

    def service_provider_descriptor_document
      @service_provider_descriptor ||= xpath("//md:SPSSODescriptor", md: metadata_namespace).first
    end

    def idp_descriptor_document
      @idp_descriptor ||= xpath("//md:IDPSSODescriptor", md: metadata_namespace).first
    end

    def contact_person_document
      @contact_person_document ||= xpath("//md:ContactPerson", md: metadata_namespace).first
    end

    def metadata_namespace
      Saml::XML::Namespaces::METADATA
    end
    private :metadata_namespace

    def signature_namespace
      Saml::XML::Namespaces::SIGNATURE
    end
    private :signature_namespace
  end
end
