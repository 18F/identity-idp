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
    )

    attr_reader :vector_of_trust

    def initialize(vector_of_trust)
      @vector_of_trust = vector_of_trust
    end

    def parse
      initial_components = map_initial_vector_of_trust_components_to_component_values
      expand_components_with_initial_components(initial_components)
    end

    def parse_acr
      initial_components = map_initial_acr_values_to_component_values
      expand_components_with_initial_components(initial_components)
    end

    private

    def map_initial_vector_of_trust_components_to_component_values
      vector_of_trust.split('.').map do |component_value_name|
        component_value = SupportedComponentValues.by_name[component_value_name]
        if component_value.nil?
          raise_unsupported_component_exception(component_value_name)
        end
        component_value
      end
    end

    def map_initial_acr_values_to_component_values
      vector_of_trust.split(' ').map do |component_value_name|
        component_value = LegacyComponentValues.by_name[component_value_name]
        if component_value.nil?
          raise_unsupported_component_exception(component_value_name)
        end
        component_value
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
      raise ParseException, "#{vector_of_trust} contains unkown component #{component_value_name}"
    end

    def raise_duplicate_component_exception
      raise ParseException, "#{vector_of_trust} contains duplicate components"
    end
  end
end
