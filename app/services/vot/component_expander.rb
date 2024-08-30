# frozen_string_literal: true

module Vot
  class ComponentExpander
    attr_reader :initial_components, :component_map, :expanded_components

    def initialize(initial_components:, component_map:)
      @initial_components = initial_components
      @component_map = component_map
      @expanded_components = []
    end

    def expand
      initial_components.each do |component|
        expand_and_add_component(component)
      end
      expanded_components.sort_by(&:name)
    end

    private

    def expand_and_add_component(component)
      # Do not add components if we have alread expanded and added them.
      # This prevents infinite recursion.
      return if expanded_components.include?(component)

      expanded_components.push(component)
      component.implied_component_values.each do |implied_component_name|
        implied_component = component_map[implied_component_name]
        expand_and_add_component(implied_component)
      end
    end
  end
end
