require 'rails_helper'

RSpec.describe BaseComponent, type: :component do
  class ExampleComponent < BaseComponent
    def call
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

  context 'with sidecar script' do
    class ExampleComponentWithScript < BaseComponent
      def call
        ''
      end

      def self._sidecar_files(extensions)
        return ['/path/to/app/components/example_component_with_script.js'] if extensions == ['js']
        super(extensions)
      end
    end

    it 'adds script to class variable when rendered' do
      expect(view_context).to receive(:render_component_script).
        with('example_component_with_script')

      render_inline(ExampleComponentWithScript.new)
    end
  end
end
