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
      request.vtr
    end

    def requested_attributes
      OpenidConnectAttributeScoper.new(request.scope).requested_attributes
    end

    def service_provider
      request.service_provider
    end

    private

    attr_reader :request
  end
end
