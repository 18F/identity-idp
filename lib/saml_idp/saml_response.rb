require 'saml_idp/assertion_builder'
require 'saml_idp/response_builder'
module SamlIdp
  class SamlResponse
    attr_accessor :assertion_with_signature, :reference_id, :response_id, :issuer_uri, :principal,
                  :audience_uri, :saml_request_id, :saml_acs_url, :algorithm,
                  :authn_context_classref, :name_id_format, :x509_certificate, :secret_key,
                  :expiry, :encryption_opts

    # rubocop:disable Metrics/ParameterLists
    def initialize(
      reference_id,
      response_id,
      issuer_uri,
      principal,
      audience_uri,
      saml_request_id,
      saml_acs_url,
      algorithm,
      authn_context_classref,
      name_id_format,
      x509_certificate = nil,
      secret_key = nil,
      expiry = 60 * 60,
      encryption_opts = nil
    )
      # rubocop:enable Metrics/ParameterLists
      self.reference_id = reference_id
      self.response_id = response_id
      self.issuer_uri = issuer_uri
      self.principal = principal
      self.audience_uri = audience_uri
      self.saml_request_id = saml_request_id
      self.saml_acs_url = saml_acs_url
      self.algorithm = algorithm
      self.secret_key = secret_key
      self.x509_certificate = x509_certificate
      self.authn_context_classref = authn_context_classref
      self.name_id_format = name_id_format
      self.expiry = expiry
      self.encryption_opts = encryption_opts
    end

    def build
      @built ||= response_builder.encoded
    end

    def signed
      @signed ||= response_builder.signed_and_encoded
    end

    def signed_assertion
      if encryption_opts
        assertion_builder.encrypt(sign: true)
      else
        assertion_builder.signed
      end
    end
    private :signed_assertion

    def response_builder
      ResponseBuilder.new(
        response_id,
        issuer_uri,
        saml_acs_url,
        saml_request_id,
        signed_assertion,
        algorithm,
        x509_certificate,
        secret_key,
      )
    end
    private :response_builder

    def assertion_builder
      @assertion_builder ||= AssertionBuilder.new(
        reference_id,
        issuer_uri,
        principal,
        audience_uri,
        saml_request_id,
        saml_acs_url,
        algorithm,
        authn_context_classref,
        name_id_format,
        x509_certificate,
        secret_key,
        expiry,
        encryption_opts
      )
    end
    private :assertion_builder
  end
end
