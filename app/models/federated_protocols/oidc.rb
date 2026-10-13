# frozen_string_literal: true

module FederatedProtocols
  class Oidc
    def initialize(request)
      @request = request
    end

    def issuer
      request.client_id
    end

    def ial
      request.ial_values.first
    end

    def aal
      request.aal_values.first
    end

    def acr_values
      [aal, ial].compact.join(' ')
    end

    def vtr
      nil
    end

    def requested_attributes
      OpenidConnectAttributeScoper.new(request.scope).requested_attributes
    end

    # Bare delegation scope values, carried in the stored request and the session so the consent
    # screen knows which applications were requested.
    def requested_delegation_scopes
      request.requested_delegation_scopes
    end

    def service_provider
      request.service_provider
    end

    private

    attr_reader :request
  end
end
