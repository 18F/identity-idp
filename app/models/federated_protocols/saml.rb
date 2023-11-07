module FederatedProtocols
  class Saml
    def initialize(request)
      @request = request
    end

    def issuer
      request.service_provider.identifier
    end

    def ial
      request.requested_ial_authn_context || default_authn_context
    end

    def aal
      request.requested_aal_authn_context
    end

    def requested_attributes
      @requested_attributes ||= SamlRequestPresenter.new(
        request:, service_provider: current_service_provider,
      ).requested_attributes
    end

    def service_provider
      current_service_provider
    end

    private

    attr_reader :request

    def default_authn_context
      if current_service_provider&.ial
        ::Saml::Idp::Constants::AUTHN_CONTEXT_IAL_TO_CLASSREF[current_service_provider.ial]
      else
        ::Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
      end
    end

    def current_service_provider
      return @current_service_provider if defined?(@current_service_provider)
      @current_service_provider = ServiceProvider.find_by(issuer:)
    end
  end
end
