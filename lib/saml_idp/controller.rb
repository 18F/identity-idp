# encoding: utf-8
require 'openssl'
require 'base64'
require 'time'
require 'uuid'
require 'saml_idp/request'
module SamlIdp
  module Controller
    extend ActiveSupport::Concern

    included do
      helper_method :saml_acs_url if respond_to? :helper_method
    end

    attr_accessor :algorithm
    attr_accessor :saml_request

    protected

    def validate_saml_request(raw_saml_request = params[:SAMLRequest])
      decode_request(raw_saml_request)
      render nothing: true, status: :forbidden unless valid_saml_request?
    end

    def decode_request(raw_saml_request)
      self.saml_request = Request.from_deflated_request(raw_saml_request)
    end

    def authn_context_classref
      Saml::XML::Namespaces::AuthnContext::ClassRef::PASSWORD
    end

    def encode_response(principal, opts = {})
      response_id, reference_id = get_saml_response_id, get_saml_reference_id
      audience_uri = opts[:audience_uri] || saml_request.issuer || saml_acs_url[/^(.*?\/\/.*?\/)/, 1]
      opt_issuer_uri = opts[:issuer_uri] || issuer_uri

      SamlResponse.new(
        reference_id,
        response_id,
        opt_issuer_uri,
        principal,
        audience_uri,
        saml_request_id,
        saml_acs_url,
        algorithm,
        authn_context_classref
      ).build
    end

    def issuer_uri
      (SamlIdp.config.base_saml_location.present? && SamlIdp.config.base_saml_location) ||
        (defined?(request) && request.url.to_s.split("?").first) ||
        "http://example.com"
    end

    def valid_saml_request?
      saml_request.valid?
    end

    def saml_request_id
      saml_request.request_id
    end

    def saml_acs_url
      saml_request.acs_url
    end

    def get_saml_response_id
      UUID.generate
    end

    def get_saml_reference_id
      UUID.generate
    end
  end
end
