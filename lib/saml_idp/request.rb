require 'saml_idp/xml_security'
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
    delegate :xpath, to: :document

    def initialize(raw_xml = "")
      self.raw_xml = raw_xml
    end

    def request_id
      authn_request["ID"]
    end

    def acs_url
      authn_request["AssertionConsumerServiceURL"]
    end

    def authn_request
      xpath("//samlp:AuthnRequest", samlp: samlp).first
    end

    def valid_signature?
      signed_document.validate fingerprint, true
    end

    def signed_document
      @signed_document ||= XMLSecurity::SignedDocument.new(raw_xml)
    end

    def document
      @document ||= Nokogiri::XML::Document.parse(raw_xml)
    end

    def fingerprint
      if service_provider.respond_to?(:fingerprint)
        service_provider.fingerprint
      elsif service_provider.respond_to?(:[])
        service_provider[:fingerprint] || service_provider["fingerprint"]
      end
    end

    def service_provider
      @service_provider ||= service_provider_finder[issuer] # TODO Wrap
    end

    def service_provider_finder
      config.service_provider_finder.call(issuer)
    end

    def samlp
      Saml::XML::Namespaces::PROTOCOL
    end

    def assertion
      Saml::XML::Namespaces::ASSERTION
    end

    def issuer
      xpath("//saml:Issuer", saml: assertion).first.try :content
    end
  end
end
