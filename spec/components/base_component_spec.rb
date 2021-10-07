require 'rails_helper'

RSpec.describe BaseComponent, type: :component do
  class ExampleComponent < described_class
    def render_in(...)
      ''
    end
  end

  after { described_class.rendered_scripts = [] }

  it 'initializes rendered scripts as empty array' do
    expect(described_class.rendered_scripts).to eq([])
  end

  it 'does nothing when rendered' do
    render_inline(ExampleComponent.new)

    expect(described_class.rendered_scripts).to eq([])
  end

  context 'declares rendered script' do
    class ExampleComponentWithScript < ExampleComponent; renders_script; end

    it 'adds script to class variable when rendered' do
      render_inline(ExampleComponentWithScript.new)

      expect(described_class.rendered_scripts).to eq(['example_component_with_script'])
    end
  end

  context 'declares named rendered script' do
    class ExampleComponentWithNamedScript < ExampleComponent; renders_script 'my_script'; end

    it 'adds script to class variable when rendered' do
      render_inline(ExampleComponentWithNamedScript.new)

      expect(described_class.rendered_scripts).to eq(['my_script'])
    end
  end
end
