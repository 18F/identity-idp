module FederatedProtocols
  class Saml
    def initialize(request)
      @request = request
    end

    def issuer
      request.service_provider.identifier
    end

    def ial
      case context
      when ::Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
        1
      when ::Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
        2
      end
    end

    def requested_attributes
      @_attributes ||= SamlRequestPresenter.new(
        request: request, service_provider: current_service_provider,
      ).requested_attributes
    end

    private

    def context
      ctx = request.requested_authn_context || default_authn_context
      return ctx if ctx.is_a? String
      ctx.sort.max
    end

    attr_reader :request

    def default_authn_context
      ::Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
    end

    def current_service_provider
      ServiceProvider.from_issuer(issuer)
    end
  end
end
