module FederatedProtocols
  class Saml
    def initialize(request)
      @request = request
    end

    def issuer
      request.service_provider.identifier
    end

    def loa
      request.requested_authn_context || default_authn_context
    end

    def requested_attributes
      @_attributes ||= SamlRequestPresenter.new(
        request: request, service_provider: current_service_provider,
      ).requested_attributes
    end

    private

    attr_reader :request

    def default_authn_context
      ::Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF
    end

    def current_service_provider
      ServiceProvider.from_issuer(issuer)
    end
  end
end
