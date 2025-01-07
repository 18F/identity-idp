# frozen_string_literal: true

module Vot
  module AcrComponentValues
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
    IAL2_BIO_REQUIRED = ComponentValue.new(
      name: Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF,
      description: 'IAL2 - Interm value. Require id proofing with facial match (NIST SP 800-63-3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing, :facial_match,
                     :two_pieces_of_fair_evidence],
    ).freeze
    IAL2_BIO_PREFERRED = ComponentValue.new(
      name: Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF,
      description:
        'IAL2 - Interim value. Use id proofing with facial match if completed (NIST SP 800-63-3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing, :facial_match,
                     :two_pieces_of_fair_evidence],
    ).freeze
    IALMAX = ComponentValue.new(
      name: Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy IALMAX',
      implied_component_values: [],
      requirements: [:aal2, :ialmax],
    ).freeze

    IAL_AUTH_ONLY = ComponentValue.new(
      name: Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
      description: 'IAL1 - no identity proofing (NIST SP 800-63-3)',
      implied_component_values: [],
      requirements: [],
    ).freeze
    IAL_VERIFIED = ComponentValue.new(
      name: Saml::Idp::Constants::IAL_VERIFIED_ACR,
      description: 'IAL2 - basic identity proofing, no facial match (NIST SP 800-63-3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing],
    ).freeze
    IAL_VERIFIED_FACIAL_MATCH_PREFERRED = ComponentValue.new(
      name: Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_PREFERRED_ACR,
      description: 'IAL2 - facial-match verified identity used if available (NIST SP 800-63-3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing, :facial_match,
                     :two_pieces_of_fair_evidence],
    ).freeze
    IAL_VERIFIED_FACIAL_MATCH_REQUIRED = ComponentValue.new(
      name: Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR,
      description: 'IAL2 - require identity-proofing using facial match (NIST SP 800-63-3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing, :facial_match,
                     :two_pieces_of_fair_evidence],
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

    DELIM = ' '

    def self.by_name
      NAME_HASH
    end

    # @param acr_values [String,Array<String>]
    def self.any_semantic_acrs?(acr_values)
      return false unless acr_values.present?
      # @type [Array]
      values = (
                 acr_values.is_a?(String) && acr_values.split(DELIM) ||
                (acr_values.is_a?(Array) || acr_values.is_a?(Set)) && acr_values ||
                [acr_values].compact
               ).to_a
      Saml::Idp::Constants::SEMANTIC_ACRS.intersect?(values)
    end
  end
end
