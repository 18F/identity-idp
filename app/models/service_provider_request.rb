# frozen_string_literal: true

class ServiceProviderRequest
  # WARNING - Modification of these params requires particular care
  # since these objects are serialized to/from Redis and may be present
  # upon deployment
  attr_accessor :uuid, :issuer, :url, :requested_attributes, :acr_values, :vtr

  # Deprecated attributes to remove
  attr_accessor :ial, :aal, :biometric_comparison_required

  def initialize(
    uuid: nil,
    issuer: nil,
    url: nil,
    requested_attributes: [],
    acr_values: nil,
    vtr: nil,
    # Deprecated attributes to remove
    # rubocop:disable Lint/UnusedMethodArgument
    ial: nil,
    aal: nil,
    biometric_comparison_required: false
    # rubocop:enable Lint/UnusedMethodArgument
  )
    @uuid = uuid
    @issuer = issuer
    @url = url
    @requested_attributes = requested_attributes&.map(&:to_s)
    @acr_values = acr_values
    @vtr = vtr
  end

  def ==(other)
    to_json == other.to_json
  end
end
