require 'rails_helper'

RSpec.describe Vot::ComponentExpander do
  context 'with a component with no implied components' do
    it 'returns the single component' do
      component_a = Vot::ComponentValue.new(
        name: 'A1', description: 'Test component', requirements: [],
        implied_component_values: []
      )
      component_b = Vot::ComponentValue.new(
        name: 'B1', description: 'Test component', requirements: [],
        implied_component_values: []
      )
      component_map = { 'A1' => component_a, 'B1' => component_b }
      initial_components = [component_a]

      result = described_class.new(component_map:, initial_components:).expand

      expect(result).to eq([component_a])
    end
  end

  context 'with a component with several layers of implied components' do
    it 'returns the components expanded into an array' do
      component_a = Vot::ComponentValue.new(
        name: 'A1', description: 'Test component', requirements: [],
        implied_component_values: []
      )
      component_b = Vot::ComponentValue.new(
        name: 'B1', description: 'Test component', requirements: [],
        implied_component_values: ['A1']
      )
      component_c = Vot::ComponentValue.new(
        name: 'C1', description: 'Test component', requirements: [],
        implied_component_values: ['B1']
      )
      component_map = { 'A1' => component_a, 'B1' => component_b, 'C1' => component_c }
      initial_components = [component_c]

      result = described_class.new(component_map:, initial_components:).expand

      expect(result).to eq([component_a, component_b, component_c])
    end
  end

  context 'with a component with cyclic implied component relationships' do
    it 'returns the components expanded into an array' do
      component_a = Vot::ComponentValue.new(
        name: 'A1', description: 'Test component', requirements: [],
        implied_component_values: ['C1']
      )
      component_b = Vot::ComponentValue.new(
        name: 'B1', description: 'Test component', requirements: [],
        implied_component_values: ['A1']
      )
      component_c = Vot::ComponentValue.new(
        name: 'C1', description: 'Test component', requirements: [],
        implied_component_values: ['B1']
      )
      component_map = { 'A1' => component_a, 'B1' => component_b, 'C1' => component_c }
      initial_components = [component_c]

      result = described_class.new(component_map:, initial_components:).expand

      expect(result).to eq([component_a, component_b, component_c])
    end
  end
end
