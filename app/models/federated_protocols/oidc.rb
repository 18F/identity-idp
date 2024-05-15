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
      request.ial_values.sort.max
    end

    def aal
      request.aal_values.sort.max
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

    def biometric_comparison_required?
      request.biometric_comparison_required?
    end

    def service_provider
      request.service_provider
    end

    def enhanced_ipp_required?
      request.enhanced_ipp_required?
    end

    private

    attr_reader :request
  end
end
