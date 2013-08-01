# encoding: utf-8
module SamlIdp
  module Controller
    require 'openssl'
    require 'base64'
    require 'time'
    require 'uuid'

    attr_accessor :algorithm
    attr_accessor :saml_acs_url

    protected

    def validate_saml_request(saml_request = params[:SAMLRequest])
      decode_SAMLRequest(saml_request)
    end

    def decode_SAMLRequest(saml_request)
      zstream  = Zlib::Inflate.new(-Zlib::MAX_WBITS)
      @saml_request = zstream.inflate(Base64.decode64(saml_request))
      zstream.finish
      zstream.close
      @saml_request_id = @saml_request[/ID=['"](.+?)['"]/, 1]
      @saml_acs_url = @saml_request[/AssertionConsumerServiceURL=['"](.+?)['"]/, 1]
    end

    def get_saml_response_id
      UUID.generate
    end

    def get_saml_reference_id
      UUID.generate
    end

    def encode_SAMLResponse(name_id, opts = {})
      response_id, reference_id = get_saml_response_id, get_saml_reference_id
      audience_uri = opts[:audience_uri] || saml_acs_url[/^(.*?\/\/.*?\/)/, 1]
      issuer_uri = opts[:issuer_uri] || (defined?(request) && request.url) || "http://example.com"

      response = SamlResponse.new reference_id,
        response_id,
        issuer_uri,
        name_id,
        audience_uri,
        @saml_request_id,
        @saml_acs_url,
        algorithm

      response.build
    end
  end
end
