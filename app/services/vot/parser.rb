# frozen_string_literal: true

module Vot
  class Parser
    class ParseException < StandardError; end

    class DuplicateComponentsException < ParseException; end

    Result = Data.define(
      :component_values,
      :component_separator,
      :aal2?,
      :phishing_resistant?,
      :hspd12?,
      :identity_proofing?,
      :facial_match?,
      :two_pieces_of_fair_evidence?,
      :ialmax?,
      :enhanced_ipp?,
    ) do
      def self.no_sp_result
        self.new(
          component_values: [],
          component_separator: ' ',
          aal2?: false,
          phishing_resistant?: false,
          hspd12?: false,
          identity_proofing?: false,
          facial_match?: false,
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

      def component_names
        component_values.map(&:name)
      end
    end.freeze

    attr_reader :acr_values

    def initialize(acr_values: nil)
      @acr_values = acr_values
    end

    def parse
      if components.blank?
        raise ParseException.new('Component parser called without ACR values')
      end
      validate_component_uniqueness!(components)

      requirement_list = components.flat_map(&:requirements)
      Result.new(
        component_values: components,
        component_separator:,
        aal2?: requirement_list.include?(:aal2),
        phishing_resistant?: requirement_list.include?(:phishing_resistant),
        hspd12?: requirement_list.include?(:hspd12),
        identity_proofing?: requirement_list.include?(:identity_proofing),
        facial_match?: requirement_list.include?(:facial_match),
        two_pieces_of_fair_evidence?: requirement_list.include?(:two_pieces_of_fair_evidence),
        ialmax?: requirement_list.include?(:ialmax),
        enhanced_ipp?: requirement_list.include?(:enhanced_ipp),
      )
    end

    private

    def components
      return @components if defined?(@components)

      component_string = acr_values || ''
      @components ||= component_string.split(component_separator).map do |component_name|
        component_map.fetch(component_name)
      rescue KeyError
      end.compact
    end

    def component_separator
      ' '
    end

    def component_map
      AcrComponentValues.by_name
    end

    def validate_component_uniqueness!(component_values)
      if component_values.length != component_values.uniq.length
        raise_duplicate_component_exception
      end
    end

    def raise_duplicate_component_exception
      raise DuplicateComponentsException, "'#{acr_values}' contains duplicate acr values"
    end
  end
end
