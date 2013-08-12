require 'saml_idp/xml_security'
require 'saml_idp/service_provider'
module SamlIdp
  class Request
    def self.from_deflated_request(raw)
      zstream  = Zlib::Inflate.new(-Zlib::MAX_WBITS)
      inflated = zstream.inflate(Base64.decode64(raw)).tap do
        zstream.finish
        zstream.close
      end
      new(inflated)
    end

    attr_accessor :raw_xml

    delegate :config, to: :SamlIdp
    private :config
    delegate :xpath, to: :document
    private :xpath

    def initialize(raw_xml = "")
      self.raw_xml = raw_xml
    end

    def request_id
      authn_request["ID"]
    end

    def acs_url
      authn_request["AssertionConsumerServiceURL"]
    end

    def valid_signature?
      service_provider.valid_signature? document
    end

    def service_provider?
      service_provider.valid?
    end

    def service_provider
      @service_provider ||= ServiceProvider.new((service_provider_finder[issuer] || {}).merge(identifier: issuer))
    end

    def issuer
      xpath("//saml:Issuer", saml: assertion).first.try :content
    end

    def document
      @document ||= Saml::XML::Document.parse(raw_xml)
    end
    private :document

    def authn_request
      xpath("//samlp:AuthnRequest", samlp: samlp).first
    end
    private :authn_request

    def samlp
      Saml::XML::Namespaces::PROTOCOL
    end
    private :samlp

    def assertion
      Saml::XML::Namespaces::ASSERTION
    end
    private :assertion

    def signature_namespace
      Saml::XML::Namespaces::SIGNATURE
    end
    private :signature_namespace

    def service_provider_finder
      config.service_provider.finder
    end
    private :service_provider_finder
  end
end
