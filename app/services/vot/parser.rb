module Vot
  class Parser
    class ParseException < StandardError; end
    Result = Data.define(
      :component_values,
      :aal2?,
      :phishing_resistant?,
      :hspd12?,
      :identity_proofing?,
      :biometric_comparison?,
      :ialmax?,
    ) do
      def self.no_sp_result
        self.new(
          component_values: [],
          aal2?: false,
          phishing_resistant?: false,
          hspd12?: false,
          identity_proofing?: false,
          biometric_comparison?: false,
          ialmax?: false,
        )
      end

      def identity_proofing_or_ialmax?
        identity_proofing? || ialmax?
      end

      def aal_level_requested
        if aal2?
          2
        else
          1
        end
      end

      def ial_value_requested
        if ialmax?
          0
        elsif identity_proofing?
          2
        else
          1
        end
      end

      def ial2_requested?
        identity_proofing?
      end

      def ialmax_requested?
        ialmax?
      end

      def piv_cac_requested?
        hspd12?
      end
    end

    attr_reader :vector_of_trust, :acr_values

    def initialize(vector_of_trust: nil, acr_values: nil)
      @vector_of_trust = vector_of_trust
      @acr_values = acr_values
    end

    def parse
      initial_components =
        if vector_of_trust.present?
          map_initial_vector_of_trust_components_to_component_values
        elsif acr_values.present?
          map_initial_acr_values_to_component_values
        end

      if !initial_components
        raise ParseException.new('VoT parser called without VoT or ACR values')
      end

      expand_components_with_initial_components(initial_components)
    end

    private

    def map_initial_vector_of_trust_components_to_component_values
      vector_of_trust.split('.').map do |component_value_name|
        SupportedComponentValues.by_name.fetch(component_value_name)
      rescue KeyError
        raise_unsupported_component_exception(component_value_name)
      end
    end

    def map_initial_acr_values_to_component_values
      acr_values.split(' ').map do |component_value_name|
        LegacyComponentValues.by_name.fetch(component_value_name)
      rescue KeyError
        raise_unsupported_component_exception(component_value_name)
      end
    end

    def expand_components_with_initial_components(initial_components)
      validate_component_uniqueness!(initial_components)
      resulting_components = add_implied_components(initial_components).sort_by(&:name)
      requirement_list = resulting_components.flat_map(&:requirements)
      Result.new(
        component_values: resulting_components,
        aal2?: requirement_list.include?(:aal2),
        phishing_resistant?: requirement_list.include?(:phishing_resistant),
        hspd12?: requirement_list.include?(:hspd12),
        identity_proofing?: requirement_list.include?(:identity_proofing),
        biometric_comparison?: requirement_list.include?(:biometric_comparison),
        ialmax?: requirement_list.include?(:ialmax),
      )
    end

    def validate_component_uniqueness!(component_values)
      if component_values.length != component_values.uniq.length
        raise_duplicate_component_exception
      end
    end

    def add_implied_components(component_values)
      component_values.flat_map do |component_value|
        component_with_implied_components(component_value)
      end.uniq
    end

    def component_with_implied_components(component_value)
      [
        component_value,
        *component_value.implied_component_values.map do |implied_component_value|
          component_with_implied_components(implied_component_value)
        end,
      ].flatten
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
