# frozen_string_literal: true

module Vot
  module SupportedComponentValues
    C1 = ComponentValue.new(
      name: 'C1',
      description: 'Multi-factor authentication',
      implied_component_values: [],
      requirements: [],
    ).freeze
    C2 = ComponentValue.new(
      name: 'C2',
      description: 'AAL2 conformant features are engaged',
      implied_component_values: ['C1'],
      requirements: [:aal2],
    ).freeze
    Ca = ComponentValue.new(
      name: 'Ca',
      description: 'A phishing resistant authenticator is required',
      implied_component_values: ['C1'],
      requirements: [:phishing_resistant],
    ).freeze
    Cb = ComponentValue.new(
      name: 'Cb',
      description: 'A PIV/CAC card is required',
      implied_component_values: ['C1'],
      requirements: [:hspd12],
    ).freeze
    P1 = ComponentValue.new(
      name: 'P1',
      description: 'Identity proofing is performed',
      implied_component_values: ['C2'],
      requirements: [:identity_proofing],
    ).freeze
    Pb = ComponentValue.new(
      name: 'Pb',
      description: 'A facial match is required as part of identity proofing',
      implied_component_values: ['P1'],
      requirements: [:facial_match, :two_pieces_of_fair_evidence],
    ).freeze
    Pe = ComponentValue.new(
      name: 'Pe',
      description: 'Enhanced In Person Proofing is required',
      implied_component_values: ['P1'],
      requirements: [:enhanced_ipp],
    ).freeze

    NAME_HASH = constants.map do |constant|
      component_value = const_get(constant)
      [component_value.name, component_value]
    end.to_h.freeze

    def self.by_name
      NAME_HASH
    end
  end
end
