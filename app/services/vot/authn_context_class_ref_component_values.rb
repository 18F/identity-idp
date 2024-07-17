# frozen_string_literal: true

module Vot
  module AuthnContextClassRefComponentValues
    ## Identity proofing ACR values

    # @deprecated - Use IAL1
    LOA1 = ComponentValue.new(
      name: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy LOA1 - no identity proofing',
      implied_component_values: [],
      requirements: [],
    ).freeze
    # @deprecated - Use IAL2
    LOA3 = ComponentValue.new(
      name: Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy LOA3 - identity proofing is performed',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing],
    ).freeze

    IAL1 = ComponentValue.new(
      name: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      description: 'IAL1 - no identity proofing (rev 3)',
      implied_component_values: [],
      requirements: [],
    ).freeze
    IAL2 = ComponentValue.new(
      name: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
      description: 'IAL2 - identity proofing is performed (rev3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing],
    ).freeze
    IAL2_BIO_REQUIRED = ComponentValue.new(
      name: Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF,
      description: 'IAL2 - identity proofing with biometric comparison (rev3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing, :biometric_comparison,
                     :two_pieces_of_fair_evidence, :biometric_comparison_required],
    ).freeze
    IAL2_BIO_PREFERRED = ComponentValue.new(
      name: Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF,
      description: 'IAL2 - identity proofing with biometric comparison (rev3) preferred',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing, :biometric_comparison,
                     :two_pieces_of_fair_evidence],
    ).freeze
    IALMAX = ComponentValue.new(
      name: Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
      description: 'IALMAX - internal step-up flow from IAL1 to IAL2',
      implied_component_values: [],
      requirements: [:aal2, :ialmax],
    ).freeze

    ## Authentication ACR values
    DEFAULT = ComponentValue.new(
      name: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy default authentication',
      implied_component_values: [],
      requirements: [],
    ).freeze
    AAL1 = ComponentValue.new(
      name: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy AAL1',
      implied_component_values: [],
      requirements: [],
    ).freeze
    AAL2 = ComponentValue.new(
      name: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy AAL2',
      implied_component_values: [],
      requirements: [:aal2],
    ).freeze
    AAL2_PHISHING_RESISTANT = ComponentValue.new(
      name: Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy AAL2 with phishing resistance',
      implied_component_values: [],
      requirements: [:aal2, :phishing_resistant],
    ).freeze
    AAL2_HSPD12 = ComponentValue.new(
      name: Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy AAL2 with HSPD12 (PIV/CAC card)',
      implied_component_values: [],
      requirements: [:aal2, :hspd12],
    ).freeze
    AAL3 = ComponentValue.new(
      name: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy AAL3',
      implied_component_values: [],
      requirements: [:aal2, :phishing_resistant],
    ).freeze
    AAL3_HSPD12 = ComponentValue.new(
      name: Saml::Idp::Constants::AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy AAL3 with HSPD12 (PIV/CAC card)',
      implied_component_values: [],
      requirements: [:aal2, :hspd12],
    ).freeze

    NAME_HASH = constants.map do |constant|
      component_value = const_get(constant)
      [component_value.name, component_value]
    end.to_h.freeze

    # @return [Hash{String => Vot::ComponentValue}]
    def self.by_name
      NAME_HASH
    end
  end
end
