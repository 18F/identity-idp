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
      decode_SAMLRequest(raw_saml_request)
      render nothing: true, status: :forbidden unless valid_service_provider?
    end

    def decode_SAMLRequest(raw_saml_request)
      self.saml_request = Request.from_deflated_request(raw_saml_request)
    end

    def encode_SAMLResponse(name_id, opts = {})
      response_id, reference_id = get_saml_response_id, get_saml_reference_id
      audience_uri = opts[:audience_uri] || saml_acs_url[/^(.*?\/\/.*?\/)/, 1]
      issuer_uri = opts[:issuer_uri] || (defined?(request) && request.url) || "http://example.com"

      SamlResponse.new(
        reference_id,
        response_id,
        issuer_uri,
        name_id,
        audience_uri,
        saml_request_id,
        saml_acs_url,
        algorithm
      ).build
    end

    def valid_service_provider?
      saml_request.service_provider? &&
        saml_request.valid_signature?
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
