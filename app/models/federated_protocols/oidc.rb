module FederatedProtocols
  class Oidc
    def initialize(request)
      @request = request
    end

    def issuer
      request.client_id
    end

    def ial
      case context
      when Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
        1
      when Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
        2
      end
    end

    def requested_attributes
      OpenidConnectAttributeScoper.new(request.scope).requested_attributes
    end

    private

    def context
      vals = request.acr_values
      return vals if vals.is_a? String
      vals.sort.max
    end

    attr_reader :request
  end
end
