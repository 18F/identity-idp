module FederatedProtocols
  class Oidc
    def initialize(request)
      @request = request
    end

    def issuer
      request.client_id
    end

    def ial
      context = request.acr_values.sort.max
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

    attr_reader :request
  end
end
