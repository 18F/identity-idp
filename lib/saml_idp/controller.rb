# encoding: utf-8
module SamlIdp
  module Controller
    require 'openssl'
    require 'base64'
    require 'time'
    require 'uuid'

    attr_accessor :algorithm
    attr_accessor :saml_acs_url, :saml_request_id, :saml_request

    protected

    def validate_saml_request(saml_request = params[:SAMLRequest])
      decode_SAMLRequest(saml_request)
    end

    def decode_SAMLRequest(saml_request)
      self.saml_request = inflate_request saml_request
      self.saml_request_id = authn_request_hash["ID"]
      self.saml_acs_url = authn_request_hash["AssertionConsumerServiceURL"]
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

    def inflate_request(raw_request)
      zstream  = Zlib::Inflate.new(-Zlib::MAX_WBITS)
      zstream.inflate(Base64.decode64(raw_request)).tap do
        zstream.finish
        zstream.close
      end
    end

    def authn_request_hash
      saml_request_hash.fetch("AuthnRequest") { {} }
    end

    def saml_request_hash
      if saml_request
        @saml_request_hash ||= Hash.from_xml(saml_request)
      else
        {}
      end
    rescue REXML::ParseException
      nil
    end

    def get_saml_response_id
      UUID.generate
    end

    def get_saml_reference_id
      UUID.generate
    end
  end
end
