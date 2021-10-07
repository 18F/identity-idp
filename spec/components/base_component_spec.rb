require 'rails_helper'

RSpec.describe BaseComponent, type: :component do
  class ExampleComponent < described_class
    def render_in(...)
      ''
    end
  end

  let(:lookup_context) { ActionView::LookupContext.new(ActionController::Base.view_paths) }
  let(:view_context) { ActionView::Base.new(lookup_context, {}, controller) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:view_context).and_return(view_context)
  end

  it 'does nothing when rendered' do
    expect(view_context).not_to receive(:render_component_script)

    render_inline(ExampleComponent.new)
  end

  context 'declares rendered script' do
    class ExampleComponentWithScript < ExampleComponent; renders_script; end

    it 'adds script to class variable when rendered' do
      expect(view_context).to receive(:render_component_script).
        with('example_component_with_script')

      render_inline(ExampleComponentWithScript.new)
    end
  end

  context 'declares named rendered script' do
    class ExampleComponentWithNamedScript < ExampleComponent; renders_script 'my_script'; end

    it 'adds script to class variable when rendered' do
      expect(view_context).to receive(:render_component_script).with('my_script')

      render_inline(ExampleComponentWithNamedScript.new)
    end
  end
end
