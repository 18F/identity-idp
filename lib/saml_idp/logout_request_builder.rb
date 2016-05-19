require 'builder'
module SamlIdp
  class LogoutRequestBuilder
    include Signable

    attr_accessor :response_id
    attr_accessor :issuer_uri
    attr_accessor :saml_slo_url
    attr_accessor :name_id
    attr_accessor :session_index
    attr_accessor :signature_settings

    def initialize(response_id, issuer_uri, saml_slo_url, name_id, session_index, signature_settings)
      self.response_id = response_id
      self.issuer_uri = issuer_uri
      self.saml_slo_url = saml_slo_url
      self.name_id = name_id
      self.session_index = session_index
      self.signature_settings = signature_settings
    end

    def reference_id
      signature_settings[:reference_id] || UUID.generate
    end

    def digest
      algorithm.hexdigest raw
    end

    def algorithm
      signature_settings[:algorithm] || OpenSSL::Digest::SHA256
    end

    def encoded
      @encoded ||= encode
    end 

    def raw 
      build
    end 

    def encode
      Base64.strict_encode64(raw)
    end 
    private :encode

    def response_id_string
      "_#{response_id}"
    end 
    private :response_id_string

    def build
      builder = Builder::XmlMarkup.new
      builder.LogoutRequest ID: response_id_string,
        Version: "2.0",
        IssueInstant: now_iso,
        Destination: saml_slo_url,
        "xmlns" => Saml::XML::Namespaces::PROTOCOL do |request|
          request.Issuer issuer_uri, xmlns: Saml::XML::Namespaces::ASSERTION
          sign request
          request.NameID name_id, xmlns: Saml::XML::Namespaces::ASSERTION,
            Format: Saml::XML::Namespaces::Formats::NameId::PERSISTENT
          request.SessionIndex session_index
        end
    end
    private :build

    def now_iso
      Time.now.utc.iso8601
    end
    private :now_iso
  end
end
