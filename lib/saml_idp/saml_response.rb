require 'saml_idp/assertion_builder'
require 'saml_idp/signed_info_builder'
require 'saml_idp/response_builder'
require 'saml_idp/signature_builder'
module SamlIdp
  class SamlResponse
    attr_accessor :assertion_with_signature
    attr_accessor :reference_id
    attr_accessor :response_id
    attr_accessor :issuer_uri
    attr_accessor :name_id
    attr_accessor :audience_uri
    attr_accessor :saml_request_id
    attr_accessor :saml_acs_url
    attr_accessor :algorithm
    attr_accessor :secret_key
    attr_accessor :x509_certificate

    def initialize(reference_id,
          response_id,
          issuer_uri,
          name_id,
          audience_uri,
          saml_request_id,
          saml_acs_url,
          algorithm
          )
      self.reference_id = reference_id
      self.response_id = response_id
      self.issuer_uri = issuer_uri
      self.name_id = name_id
      self.audience_uri = audience_uri
      self.saml_request_id = saml_request_id
      self.saml_acs_url = saml_acs_url
      self.algorithm = algorithm
      self.secret_key = secret_key
      self.x509_certificate = x509_certificate
    end

    def build
      @built ||= begin
                   build_initial_assertion
                   build_signing_info
                   sign_and_attach_signature

                   response_builder.encoded
                 end
    end

    def build_initial_assertion
      raw_assertion
      assertion_digest
    end
    private :build_initial_assertion

    def build_signing_info
      raw_signed_info
      signed_info_signature
    end
    private :build_signing_info

    def sign_and_attach_signature
      assertion_builder.signature = signature
      self.assertion_with_signature = assertion_builder.rebuild
    end
    private :sign_and_attach_signature

    def response_builder
      ResponseBuilder.new(response_id, issuer_uri, saml_acs_url, saml_request_id, assertion_with_signature)
    end
    private :response_builder

    def signature
      @signature ||= SignatureBuilder.new(signed_info_builder).raw
    end
    private :signature

    def signed_info_builder
      @signed_info_builder ||= SignedInfoBuilder.new(reference_id, assertion_digest, algorithm)
    end
    private :signed_info_builder

    def raw_signed_info
      @signed_info ||= signed_info_builder.raw
    end
    private :raw_signed_info

    def signed_info_signature
      @signature_value ||= signed_info_builder.signed
    end
    private :signed_info_signature

    def assertion_builder
      @assertion_builder ||= AssertionBuilder.new reference_id,
        issuer_uri,
        name_id,
        audience_uri,
        saml_request_id,
        saml_acs_url,
        algorithm
    end
    private :assertion_builder

    def raw_assertion
      @raw_assertion ||= assertion_builder.raw
    end
    private :raw_assertion

    def assertion_digest
      @assertion_digest ||= assertion_builder.digest
    end
    private :assertion_digest
  end
end
