# frozen_string_literal: true

# rubocop:disable Layout/LineLength
module Vot
  module AcrComponentValues
    # A subtype of ComponentValue that will sort by priority (descending) when used in
    # an Enumerable-like object.
    class AcrComponentValue < Vot::ComponentValue
      include Comparable

      attr_reader :name, :description, :implied_component_values, :requirements
      def initialize(name:, description:, implied_component_values: [], requirements: [])
        @name = name
        @description = description
        @implied_component_values = implied_component_values.freeze
        @requirements = requirements.inquiry.freeze
      end

      def eql?(other)
        name.eql?(other.name)
      end

      def <=>(other)
        Vot::AcrComponentValues::ACRS_BY_PRIORITY_LIST.index(name) <=> Vot::AcrComponentValues::ACRS_BY_PRIORITY_LIST.index(other.name)
      end
    end
    ## Identity proofing ACR values
    LOA1 = AcrComponentValue.new(
      name: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy LOA1',
      implied_component_values: [],
      requirements: [],
    ).freeze
    LOA3 = AcrComponentValue.new(
      name: Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy LOA3',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing],
    ).freeze
    IAL1 = AcrComponentValue.new(
      name: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy IAL1',
      implied_component_values: [],
      requirements: [],
    ).freeze
    IAL2 = AcrComponentValue.new(
      name: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy IAL2',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing],
    ).freeze
    IAL2_BIO_REQUIRED = AcrComponentValue.new(
      name: Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF,
      description: 'IAL2 - require identity proofing with biometric comparison (NIST SP 800-63-3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing, :biometric_comparison,
                     :two_pieces_of_fair_evidence],
    ).freeze
    IAL2_BIO_PREFERRED = AcrComponentValue.new(
      name: Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF,
      description:
        'IAL2 - use identity proofing with biometric comparison if completed (NIST SP 800-63-3)',
      implied_component_values: [],
      requirements: [:aal2, :identity_proofing, :biometric_comparison,
                     :two_pieces_of_fair_evidence],
    ).freeze
    IALMAX = AcrComponentValue.new(
      name: Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy IALMAX',
      implied_component_values: [],
      requirements: [:aal2, :ialmax],
    ).freeze

    ## Authentication ACR values
    DEFAULT_AAL = AcrComponentValue.new(
      name: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy default authentication',
      implied_component_values: [],
      requirements: [],
    ).freeze
    AAL1 = AcrComponentValue.new(
      name: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy AAL1',
      implied_component_values: [],
      requirements: [],
    ).freeze
    AAL2 = AcrComponentValue.new(
      name: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy AAL2',
      implied_component_values: [],
      requirements: [:aal2],
    ).freeze
    AAL2_PHISHING_RESISTANT = AcrComponentValue.new(
      name: Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy AAL2 with phishing resistance',
      implied_component_values: [],
      requirements: [:aal2, :phishing_resistant],
    ).freeze
    AAL2_HSPD12 = AcrComponentValue.new(
      name: Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy AAL2 with HSPD12',
      implied_component_values: [],
      requirements: [:aal2, :hspd12],
    ).freeze
    AAL3 = AcrComponentValue.new(
      name: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy AAL3',
      implied_component_values: [],
      requirements: [:aal2, :phishing_resistant],
    ).freeze
    AAL3_HSPD12 = AcrComponentValue.new(
      name: Saml::Idp::Constants::AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF,
      description: 'Legacy AAL3 with HSPD12',
      implied_component_values: [],
      requirements: [:aal2, :hspd12],
    ).freeze

    # @type [Hash]
    NAME_HASH = constants(false).
      map { |c| const_get(c, false) }.
      filter { |c| c.is_a?(AcrComponentValue) }.
      index_by(&:name).freeze

    VALUES = NAME_HASH.values.freeze

    DELIM = ' '

    IAL_COMPONENTS_BY_NAME_HASH = [
      LOA1,
      LOA3,
      IAL1,
      IALMAX,
      IAL2,
      IAL2_BIO_PREFERRED,
      IAL2_BIO_REQUIRED,
    ].index_by(&:name).freeze

    # IAL components ordered by priority, descending
    IAL_COMPONENTS_BY_PRIORITY_LIST = [
      IAL2_BIO_REQUIRED,
      IAL2_BIO_PREFERRED,
      IAL2,
      LOA3,
      IALMAX,
      IAL1,
      LOA1,
    ].freeze

    # IAL names ordered by priority, descending
    IALS_BY_PRIORITY_LIST = IAL_COMPONENTS_BY_PRIORITY_LIST.map(&:name).freeze

    # AAL components ordered by priority, descending
    AAL_COMPONENTS_BY_NAME_HASH = [
      DEFAULT_AAL,
      AAL1,
      AAL2,
      AAL2_PHISHING_RESISTANT,
      AAL2_HSPD12,
      AAL3,
      AAL3_HSPD12,
    ].index_by(&:name).freeze

    # AAL components ordered by priority, descending
    AAL_COMPONENTS_BY_PRIORITY_LIST = [
      AAL2_HSPD12,
      AAL3_HSPD12,
      AAL2_PHISHING_RESISTANT,
      AAL3,
      AAL2,
      AAL1,
      DEFAULT_AAL,
    ].freeze

    # AAL names ordered by priority, descending
    AALS_BY_PRIORITY_LIST = AAL_COMPONENTS_BY_PRIORITY_LIST.map(&:name).freeze

    # All ACR components ordered by type (IAL, AAL) and then descending priority
    ACR_COMPONENTS_BY_PRIORITY_LIST = [
      *IAL_COMPONENTS_BY_PRIORITY_LIST,
      *AAL_COMPONENTS_BY_PRIORITY_LIST,
    ].freeze

    ACRS_BY_PRIORITY_LIST = ACR_COMPONENTS_BY_PRIORITY_LIST.map(&:name).freeze

    # @return [Hash{String=>AcrComponentValue}]
    def self.by_name
      NAME_HASH
    end

    def self.satisfies?(name, *requirements)
      component = NAME_HASH[name]

      component.present? &&
        component.requirements.intersection(requirements).size == requirements.length
    end

    def self.highest_priority_ial(values)
      ial_component_values(values).min&.name
    end

    def self.highest_priority_aal(values)
      aal_component_values(values).min&.name
    end

    # Get the highest priority ACR value
    # @return [String, nil]
    def self.find_highest_priority(values)
      AcrComponentValues.order_by_priority(values).first
    end

    # Sort ACR values by priority, highest to lowest
    # @param values [Array<String,AcrComponentValue>, String]
    def self.order_by_priority(values)
      order_by_priority_with(values)
    end

    # Order a list of ACR values by priority, highest to lowest
    # Returns a new {Array} of {String} values where the order has been by set by the +series+,
    # based on the index of the objects from the original  in the series.
    #
    # If the +series+ includes values that have no corresponding element in the Enumerable,
    # these are ignored.
    # If the Enumerable has additional elements that aren't named in the +series+,
    # these are not included in the result.
    # @param values [Array<String, AcrComponentValue>, String]
    # @param series [Array<String>,nil] Defaults to #ACRS_BY_PRIORITY_LIST
    def self.order_by_priority_with(values, series: nil)
      if series.present?
        to_names(values).
          filter { |acr| AcrComponentValues.acr?(acr) && series.presence.include?(acr) }.
          sort_by { |acr| series.presence.index(acr) }
      else
        to_components(values).sort.map(&:name)
      end
    end

    def self.ial_values(values)
      to_names(values).filter { |acr| AcrComponentValues.ial?(acr) }
    end

    def self.ial_component_values(values)
      to_components(values).filter { |acr| AcrComponentValues.ial?(acr) }
    end

    def self.aal_values(values)
      to_names(values).filter { |acr| AcrComponentValues.aal?(acr) }
    end

    def self.aal_component_values(values)
      to_components(values).filter { |acr| AcrComponentValues.aal?(acr) }
    end

    # Convert list of strings or {Vot::ComponentValue} to ACR values
    # @return [Array<String>]
    def self.to_names(values = '')
      [] unless values.present? &&
                (values.is_a?(String) || values.is_a?(Enumerable))
      values_ary = values.is_a?(String) && values.split(DELIM) || values.presence || []

      values_ary.
        map { |v| AcrComponentValues.to_name(v) }.
        compact_blank.
        uniq
    end

    # Convert list of strings or {Vot::ComponentValue} to an array of ComponentValue
    # @param values [String, Enumerable]
    # @return [Array<AcrComponentValue>]
    def self.to_components(values)
      [] unless values.present? &&
                (values.is_a?(String) || values.is_a?(Enumerable))

      values_ary = values.is_a?(String) && values.split(DELIM) || values

      values_ary.
        map { |v| AcrComponentValues.to_component(v) }.
        compact_blank.
        uniq
    end

    def self.to_name(value)
      value.is_a?(ComponentValue) ? value.name : value.to_s
    end

    def self.to_component(value)
      value.is_a?(ComponentValue) && value || by_name[to_name(value)]
    end

    def self.build(values)
      to_names(values).join(DELIM)
    end

    def self.ial?(value)
      value.present? && IAL_COMPONENTS_BY_NAME_HASH.has_key?(to_name(value))
    end

    def self.aal?(value)
      value.present? && AAL_COMPONENTS_BY_NAME_HASH.has_key?(to_name(value))
    end

    def self.acr?(value)
      value.is_a?(AcrComponentValue) || by_name.has_key?(to_name(value))
    end
end
end
# rubocop:enable Layout/LineLength
