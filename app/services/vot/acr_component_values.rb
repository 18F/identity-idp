# frozen_string_literal: true

# rubocop:disable Layout/LineLength
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
      description: 'IAL2 - require identity proofing with biometric comparison (NIST SP 800-63-3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing, :biometric_comparison,
                     :two_pieces_of_fair_evidence],
    ).freeze
    IAL2_BIO_PREFERRED = ComponentValue.new(
      name: Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF,
      description:
        'IAL2 - use identity proofing with biometric comparison if completed (NIST SP 800-63-3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing, :biometric_comparison,
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
      description: 'IAL2 - basic identity proofing, no biometrics (NIST SP 800-63-3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing],
    ).freeze
    IAL_VERIFIED_FACIAL_MATCH_PREFERRED = ComponentValue.new(
      name: Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_PREFERRED_ACR,
      description: 'IAL2 - biometric-verified identity used if available (NIST SP 800-63-3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing, :biometric_comparison,
                     :two_pieces_of_fair_evidence],
    ).freeze
    IAL_VERIFIED_FACIAL_MATCH_REQUIRED = ComponentValue.new(
      name: Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR,
      description: 'IAL2 - require identity-proofing using facial match (NIST SP 800-63-3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing, :biometric_comparison,
                     :two_pieces_of_fair_evidence],
    ).freeze

    ## Authentication ACR values
    DEFAULT_AAL = ComponentValue.new(
      name: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
      description:
        'Default - MFA required + remember device up to 30 days (AAL1, NIST SP 800-63B-3)',
      implied_component_values: [],
      requirements: [],
    ).freeze
    AAL1 = ComponentValue.new(
      name: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
      description:
        '(defunct) MFA required + remember device up to 30 days. (AAL1, NIST SP 800-63B-3)',
      implied_component_values: [],
      requirements: [],
    ).freeze
    AAL2 = ComponentValue.new(
      name: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
      description: 'MFA required, remember device disallowed. (AAL2, NIST SP 800-63B-3)',
      implied_component_values: [],
      requirements: [:aal2],
    ).freeze
    AAL2_PHISHING_RESISTANT = ComponentValue.new(
      name: Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
      description: %{Phishing-resistant MFA required (e.g., WebAuthn or PIV/CAC cards),
      remember device disallowed. (AAL2, NIST SP 800-63B-3)},
      implied_component_values: [],
      requirements: [:aal2, :phishing_resistant],
    ).freeze
    AAL2_HSPD12 = ComponentValue.new(
      name: Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
      description: 'HSPD12-compliant MFA required (i.e., PIV/CAC only), remember device disallowed. (AAL2, NIST SP 800-63B-3)',
      implied_component_values: [],
      requirements: [:aal2, :phishing_resistant, :hspd12],
    ).freeze
    AAL3 = ComponentValue.new(
      name: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
      description: 'Unsupported. (AAL3, NIST SP 800-63B-3)',
      implied_component_values: [],
      requirements: [:aal2, :phishing_resistant],
    ).freeze
    AAL3_HSPD12 = ComponentValue.new(
      name: Saml::Idp::Constants::AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF,
      description: 'Unsupported. (AAL3, NIST SP 800-63B-3)',
      implied_component_values: [],
      requirements: [:aal2, :hspd12, :phishing_resistant],
    ).freeze

    # @type [Hash]
    NAME_HASH = constants(false).
      map { |c| const_get(c, false) }.
      filter { |c| c.is_a?(ComponentValue) }.
      index_by(&:name).freeze

    VALUES = NAME_HASH.values.freeze

    DELIM = ' '

    IAL_COMPONENTS = [
      LOA1,
      LOA3,
      IAL1,
      IALMAX,
      IAL2,
      IAL2_BIO_PREFERRED,
      IAL2_BIO_REQUIRED,
    ].freeze
    IAL_COMPONENTS_BY_PRIORITY = [
      IAL2_BIO_REQUIRED,
      IAL2_BIO_PREFERRED,
      IAL2,
      LOA3,
      IALMAX,
      IAL1,
      LOA1,
    ].freeze
    IALS_BY_PRIORITY = IAL_COMPONENTS_BY_PRIORITY.map(&:name).freeze

    DELIM = ' '

    AAL_COMPONENTS = [
      DEFAULT_AAL,
      AAL1,
      AAL2,
      AAL2_PHISHING_RESISTANT,
      AAL2_HSPD12,
      AAL3,
      AAL3_HSPD12,
    ].freeze
    AAL_COMPONENTS_BY_PRIORITY = [
      AAL2_HSPD12,
      AAL3_HSPD12,
      AAL2_PHISHING_RESISTANT,
      AAL3,
      AAL2,
      AAL1,
      DEFAULT_AAL,
    ].freeze

    AALS_BY_PRIORITY = AAL_COMPONENTS_BY_PRIORITY.map(&:name).freeze

    ACR_COMPONENTS_BY_PRIORITY = [
      *IAL_COMPONENTS_BY_PRIORITY,
      *AAL_COMPONENTS_BY_PRIORITY,
    ].freeze

    ACRS_BY_PRIORITY = ACR_COMPONENTS_BY_PRIORITY.map(&:name).freeze

    # @return [Hash{String=>Vot::ComponentValue}]
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

    # Get the highest priority ACR value
    # @return [String, nil]
    def self.find_highest_priority(values)
      AcrComponentValues.order_by_priority(values).first
    end

    # Sort ACR values by priority, highest to lowest
    # @param values [Array<String,ComponentValue>, String]
    def self.order_by_priority(values)
      order_by_priority_with(values, series: ACRS_BY_PRIORITY)
    end

    # Order a list of ACR values by priority, highest to lowest
    # Returns a new {Array} of {String} values where the order has been by set by the +series+,
    # based on the index of the objects from the original  in the series.
    #
    # If the +series+ includes values that have no corresponding element in the Enumerable,
    # these are ignored.
    # If the Enumerable has additional elements that aren't named in the +series+,
    # these are not included in the result.
    # @param values [Array<String, ComponentValue>, String]
    # @param series [Array<String>,nil] Defaults to #ACRS_BY_PRIORITY
    def self.order_by_priority_with(values, series: nil)
      rankings = series.presence || ACRS_BY_PRIORITY
      to_names(values).
        filter { |acr| AcrComponentValues.acr?(acr) && rankings.include?(acr) }.
        sort_by { |acr| rankings.index(acr) }
    end

    def self.ial_values(values)
      to_names(values).filter { |acr| AcrComponentValues.ial?(acr) }
    end

    def self.aal_values(values)
      to_names(values).filter { |acr| AcrComponentValues.aal?(acr) }
    end

    # Convert list of strings or {Vot::ComponentValue} to ACR values
    # @return [Array<String>]
    def self.to_names(values)
      [] unless values.present? &&
                !(values.is_a?(String) || values.is_a?(Enumerable))
      names =
        if values.is_a?(Enumerable)
          values.
            map { |v| AcrComponentValues.to_name(v) }.
            to_a
        else
          values.split(DELIM)
        end
      names.compact_blank.uniq
    end

    def self.to_name(value)
      value.is_a?(ComponentValue) ? value.name : value.to_s
    end

    def self.join(values)
      to_names(values).join(DELIM)
    end

    def self.ial?(value)
      Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_IAL.include?(AcrComponentValues.to_name(value))
    end

    def self.aal?(value)
      Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_AAL.include?(AcrComponentValues.to_name(value))
    end

    def self.acr?(value)
      AcrComponentValues.ial?(value) || AcrComponentValues.aal?(value)
    end
  end
end
# rubocop:enable Layout/LineLength
