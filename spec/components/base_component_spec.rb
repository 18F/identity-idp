require 'rails_helper'

RSpec.describe BaseComponent, type: :component do
  class ExampleComponent < described_class
    def render_in(...)
      ''
    end
  end

  let!(:initial_rendered_scripts) { described_class.rendered_scripts }
  after { described_class.rendered_scripts = initial_rendered_scripts }

  def rendered_scripts
    described_class.rendered_scripts - initial_rendered_scripts
  end

  it 'does nothing when rendered' do
    render_inline(ExampleComponent.new)

    expect(rendered_scripts).to eq([])
  end

  context 'declares rendered script' do
    class ExampleComponentWithScript < ExampleComponent; renders_script; end

    it 'adds script to class variable when rendered' do
      render_inline(ExampleComponentWithScript.new)

      expect(rendered_scripts).to eq(['example_component_with_script'])
    end
  end

  context 'declares named rendered script' do
    class ExampleComponentWithNamedScript < ExampleComponent; renders_script 'my_script'; end

    it 'adds script to class variable when rendered' do
      render_inline(ExampleComponentWithNamedScript.new)

      expect(rendered_scripts).to eq(['my_script'])
    end
  end
end
