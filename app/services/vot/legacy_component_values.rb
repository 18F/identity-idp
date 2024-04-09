# frozen_string_literal: true

module Vot
  module LegacyComponentValues
    ## Identity proofing ACR values
    LOA1 = ComponentValue.new(
      name: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy LOA1',
      implied_component_values: [],
      requirements: [],
    ).freeze
    LOA3 = ComponentValue.new(
      name: Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy LOA3',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing],
    ).freeze
    IAL1 = ComponentValue.new(
      name: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy IAL1',
      implied_component_values: [],
      requirements: [],
    ).freeze
    IAL2 = ComponentValue.new(
      name: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy IAL2',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing],
    ).freeze
    IALMAX = ComponentValue.new(
      name: Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy IALMAX',
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
      description: 'Legacy AAL2 with HSPD12',
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
      description: 'Legacy AAL3 with HSPD12',
      implied_component_values: [],
      requirements: [:aal2, :hspd12],
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
