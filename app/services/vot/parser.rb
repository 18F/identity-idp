# frozen_string_literal: true

module Vot
  class Parser
    class ParseException < StandardError; end

    class Result < Data.define(
      :component_values,
      :component_separator,
      :aal2?,
      :phishing_resistant?,
      :hspd12?,
      :identity_proofing?,
      :biometric_comparison?,
      :two_pieces_of_fair_evidence?,
      :ialmax?,
      :enhanced_ipp?,
    )
      def self.no_sp_result
        self.new(
          component_values: [],
          component_separator: ' ',
          aal2?: false,
          phishing_resistant?: false,
          hspd12?: false,
          identity_proofing?: false,
          biometric_comparison?: false,
          two_pieces_of_fair_evidence?: false,
          ialmax?: false,
          enhanced_ipp?: false,
        )
      end

      def identity_proofing_or_ialmax?
        identity_proofing? || ialmax?
      end

      def expanded_component_values
        component_values.map(&:name).join(component_separator)
      end
    end.freeze

    attr_reader :vector_of_trust, :acr_values

    def initialize(vector_of_trust: nil, acr_values: nil)
      @vector_of_trust = vector_of_trust
      @acr_values = acr_values
    end

    def parse
      if initial_components.blank?
        raise ParseException.new('VoT parser called without VoT or ACR values')
      end
      validate_component_uniqueness!(initial_components)

      expanded_components = Vot::ComponentExpander.new(initial_components:, component_map:).expand

      requirement_list = expanded_components.flat_map(&:requirements)
      Result.new(
        component_values: expanded_components,
        component_separator: component_separator,
        aal2?: requirement_list.include?(:aal2),
        phishing_resistant?: requirement_list.include?(:phishing_resistant),
        hspd12?: requirement_list.include?(:hspd12),
        identity_proofing?: requirement_list.include?(:identity_proofing),
        biometric_comparison?: requirement_list.include?(:biometric_comparison),
        two_pieces_of_fair_evidence?: requirement_list.include?(:two_pieces_of_fair_evidence),
        ialmax?: requirement_list.include?(:ialmax),
        enhanced_ipp?: requirement_list.include?(:enhanced_ipp),
      )
    end

    private

    def initial_components
      return @initial_components if defined?(@initial_components)

      component_string = vector_of_trust.presence || acr_values || ''
      @initial_components ||= component_string.split(component_separator).map do |component_name|
        component_map.fetch(component_name)
      rescue KeyError
        raise_unsupported_component_exception(component_name)
      end
    end

    def component_separator
      if vector_of_trust.present?
        '.'
      else
        ' '
      end
    end

    # @return [Hash{String => Vot::ComponentValue}]
    def component_map
      if vector_of_trust.present?
        SupportedComponentValues.by_name
      else
        AuthnContextClassRefComponentValues.by_name
      end
    end

    def validate_component_uniqueness!(component_values)
      if component_values.length != component_values.uniq.length
        raise_duplicate_component_exception
      end
    end

    def raise_unsupported_component_exception(component_value_name)
      if vector_of_trust.present?
        raise ParseException, "#{vector_of_trust} contains unkown component #{component_value_name}"
      else
        raise ParseException, "#{acr_values} contains unkown acr value #{component_value_name}"
      end
    end

    def raise_duplicate_component_exception
      if vector_of_trust.present?
        raise ParseException, "#{vector_of_trust} contains duplicate components"
      else
        raise ParseException, "#{acr_values} ontains duplicate acr values"
      end
    end
  end
end
