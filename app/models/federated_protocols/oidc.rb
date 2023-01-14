module FederatedProtocols
  class Oidc
    def initialize(request)
      @request = request
    end

    def issuer
      request.client_id
    end

    def ial
      request.ial_values.sort.max
    end

    def aal
      request.aal_values.sort.max
    end

    def service_provider
      request.service_provider
    end

    def requested_attributes
      OpenidConnectAttributeScoper.new(request.scope).requested_attributes
    end

    private

    attr_reader :request
  end
end
