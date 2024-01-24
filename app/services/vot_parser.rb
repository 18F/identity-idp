class VotParser
  class VotParseException < StandardError; end

  VotParserResult = Data.define(:identity_proofing, :credential_usage)

  VECTOR_COMPONENT_REGEXP = /\A(?<component>[A-Z])(?<value>[0-9a-z])\z/

  IDENTITY_PROOFING_VECTOR_VALUES = {
    '0' => :no_identity_proofing,
    '1' => :identity_proofing_no_biometric,
    '2' => :identity_proofing_biometric_required,
  }.freeze
  CREDENTIAL_USAGE_VECTOR_VALUES = {
    '0' => :default,
    '1' => :no_remember_device,
    '2' => :unphishable_mfa,
    '3' => :piv_cac_required,
  }.freeze

  attr_reader :vector_of_trust

  def initialize(vector_of_trust)
    @vector_of_trust = vector_of_trust
  end

  def parse
    result = { identity_proofing: :no_identity_proofing, credential_usage: :default }
    vector_component_map.each do |component, value|
      if component == 'P'
        result[:identity_proofing] = read_vector_value_from_map(
          component: 'P',
          value: value,
          map: IDENTITY_PROOFING_VECTOR_VALUES,
        )
      elsif component == 'C'
        result[:credential_usage] = read_vector_value_from_map(
          component: 'C',
          value: value,
          map: CREDENTIAL_USAGE_VECTOR_VALUES,
        )
      else
        raise VotParseException, "#{vector_of_trust} contains unsupported component #{component}"
      end
    end
    VotParserResult.new(**result)
  end

  private

  def vector_component_map
    @vector_component_map ||= begin
      vector_components = vector_of_trust.split('.')
      vector_components.map do |component|
        match_data = component.match(VECTOR_COMPONENT_REGEXP)
        raise VotParseException, "#{vector_of_trust} is not a valid VoT" if match_data.nil?
        [match_data[:component], match_data[:value]]
      end.to_h
    end
  end

  def read_vector_value_from_map(component:, value:, map:)
    result = map[value]
    if result.nil?
      raise VotParseException, "#{vector_of_trust} contains unsupported #{component} value #{value}"
    end
    result
  end
end
