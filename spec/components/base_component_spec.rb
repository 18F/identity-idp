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
    expect(view_context).not_to receive(:enqueue_component_scripts)

    render_inline(ExampleComponent.new)
  end

  context 'with sidecar script' do
    class ExampleComponentWithScript < BaseComponent
      def call
        ''
      end

      def self._sidecar_files(extensions)
        files = []
        files << '/components/example_component_with_script_js.js' if extensions.include?('js')
        files << '/components/example_component_with_script_ts.ts' if extensions.include?('ts')
        files.presence || super(extensions)
      end
    end

    class ExampleComponentWithScriptRenderingOtherComponentWithScript < BaseComponent
      def call
        render(ExampleComponentWithScript.new)
      end

      def self._sidecar_files(extensions)
        if extensions.include?('js')
          ['/components/example_component_with_script_rendering_other_component_with_script.js']
        else
          super(extensions)
        end
      end
    end

    class NestedExampleComponentWithScript < ExampleComponentWithScript
      def self._sidecar_files(extensions)
        if extensions.include?('js')
          ['/components/nested_example_component_with_script.js']
        else
          super(extensions)
        end
      end
    end

    it 'adds script to class variable when rendered' do
      expect(view_context).to receive(:enqueue_component_scripts).with(
        'example_component_with_script_js',
        'example_component_with_script_ts',
      )

      render_inline(ExampleComponentWithScript.new)
    end

    it 'adds own and parent scripts to class variable when rendered' do
      expect(view_context).to receive(:enqueue_component_scripts).with(
        'nested_example_component_with_script',
        'example_component_with_script_js',
        'example_component_with_script_ts',
      )

      render_inline(NestedExampleComponentWithScript.new)
    end

    it 'adds own and scripts of any other component it renders' do
      call = 0
      expect(view_context).to receive(:enqueue_component_scripts).twice do |*args|
        call += 1
        case call
        when 1
          expect(args).to eq [
            'example_component_with_script_rendering_other_component_with_script',
          ]
        when 2
          expect(args).to eq [
            'example_component_with_script_js',
            'example_component_with_script_ts',
          ]
        end
      end

      render_inline(ExampleComponentWithScriptRenderingOtherComponentWithScript.new)
    end
  end

  describe '#unique_id' do
    it 'provides a unique id' do
      first_component = ExampleComponentWithScript.new
      second_component = ExampleComponentWithScript.new

      expect(first_component.unique_id).to be_present
      expect(second_component.unique_id).to be_present
      expect(first_component.unique_id).not_to eq(second_component.unique_id)
    end

    it 'is memoized' do
      component = ExampleComponentWithScript.new

      expect(component.unique_id).to eq(component.unique_id)
    end
  end
end
