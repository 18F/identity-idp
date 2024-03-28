module Vot
  module SupportedComponentValues
    C1 = ComponentValue.new(
      name: 'C1',
      description: 'Multi-factor authentication',
      implied_component_values: [],
      requirements: [],
    )
    C2 = ComponentValue.new(
      name: 'C2',
      description: 'AAL2 conformant features are engaged',
      implied_component_values: [C1],
      requirements: [:aal2],
    )
    Ca = ComponentValue.new(
      name: 'Ca',
      description: 'A phishing resistant authenticator is required',
      implied_component_values: [C1],
      requirements: [:phishing_resistant],
    )
    Cb = ComponentValue.new(
      name: 'Cb',
      description: 'A PIV/CAC card is required',
      implied_component_values: [C1],
      requirements: [:hspd12],
    )
    P1 = ComponentValue.new(
      name: 'P1',
      description: 'Identity proofing is performed',
      implied_component_values: [C2],
      requirements: [:identity_proofing],
    )
    Pb = ComponentValue.new(
      name: 'Pb',
      description: 'A biometric comparison is required as part of identity proofing',
      implied_component_values: [P1],
      requirements: [:biometric_comparison],
    )

    NAME_HASH = constants.map do |constant|
      component_value = const_get(constant)
      [component_value.name, component_value]
    end.to_h

    def self.by_name
      NAME_HASH
    end
  end
end
