# frozen_string_literal: true

class ServiceProviderRequest
  # WARNING - Modification of these params requires particular care
  # since these objects are serialized to/from Redis and may be present
  # upon deployment
  attr_accessor :uuid, :issuer, :url, :ial, :aal, :requested_attributes,
                :biometric_comparison_required, :acr_values, :vtr

  def initialize(
    uuid: nil,
    issuer: nil,
    url: nil,
    ial: nil,
    aal: nil,
    requested_attributes: [],
    biometric_comparison_required: false,
    acr_values: nil,
    vtr: nil
  )
    @uuid = uuid
    @issuer = issuer
    @url = url
    @ial = ial
    @aal = aal
    @requested_attributes = requested_attributes&.map(&:to_s)
    @biometric_comparison_required = biometric_comparison_required
    @acr_values = acr_values
    @vtr = vtr
  end

  def ==(other)
    to_json == other.to_json
  end
end
