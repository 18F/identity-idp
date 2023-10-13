require 'rails_helper'

RSpec.describe BaseComponent, type: :component do
  # rubocop:disable RSpec/LeakyConstantDeclaration
  class ExampleComponent < BaseComponent
    def call
      ''
    end
  end
  # rubocop:enable RSpec/LeakyConstantDeclaration

  let(:view_context) { vc_test_controller.view_context }

  before do
    allow_any_instance_of(ApplicationController).to receive(:view_context).and_return(view_context)
  end

  it 'does nothing when rendered' do
    expect(view_context).not_to receive(:enqueue_component_scripts)

    render_inline(ExampleComponent.new)
  end

  context 'with sidecar script' do
    # rubocop:disable RSpec/LeakyConstantDeclaration
    class ExampleComponentWithScript < BaseComponent
      def call
        ''
      end

      def self.sidecar_files(extensions)
        files = []
        files << '/components/example_component_with_script_js.js' if extensions.include?('js')
        files << '/components/example_component_with_script_ts.ts' if extensions.include?('ts')
        files.presence || super(extensions)
      end
    end
    # rubocop:enable RSpec/LeakyConstantDeclaration

    # rubocop:disable RSpec/LeakyConstantDeclaration
    class ExampleComponentWithScriptRenderingOtherComponentWithScript < BaseComponent
      def call
        render(ExampleComponentWithScript.new)
      end

      def self.sidecar_files(extensions)
        if extensions.include?('js')
          ['/components/example_component_with_script_rendering_other_component_with_script.js']
        else
          super(extensions)
        end
      end
    end
    # rubocop:enable RSpec/LeakyConstantDeclaration

    # rubocop:disable RSpec/LeakyConstantDeclaration
    class NestedExampleComponentWithScript < ExampleComponentWithScript
      def self.sidecar_files(extensions)
        if extensions.include?('js')
          ['/components/nested_example_component_with_script.js']
        else
          super(extensions)
        end
      end
    end
    # rubocop:enable RSpec/LeakyConstantDeclaration

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

  context 'with sidecar stylesheet' do
    # rubocop:disable RSpec/LeakyConstantDeclaration
    class ExampleComponentWithStylesheet < BaseComponent
      def call
        ''
      end

      def self.sidecar_files(extensions)
        files = []
        files << '/example_component_with_stylesheet.scss' if extensions.include?('scss')
        files.presence || super(extensions)
      end
    end
    # rubocop:enable RSpec/LeakyConstantDeclaration

    # rubocop:disable RSpec/LeakyConstantDeclaration
    class ExampleComponentWithStylesheetRenderingOtherComponentWithStylesheet < BaseComponent
      def call
        render(ExampleComponentWithStylesheet.new)
      end

      def self.sidecar_files(extensions)
        if extensions.include?('scss')
          ['/example_component_with_stylesheet_rendering_other_component_with_stylesheet.scss']
        else
          super(extensions)
        end
      end
    end
    # rubocop:enable RSpec/LeakyConstantDeclaration

    # rubocop:disable RSpec/LeakyConstantDeclaration
    class NestedExampleComponentWithStylesheet < ExampleComponentWithStylesheet
      def self.sidecar_files(extensions)
        if extensions.include?('scss')
          ['/nested_example_component_with_stylesheet.scss']
        else
          super(extensions)
        end
      end
    end
    # rubocop:enable RSpec/LeakyConstantDeclaration

    it 'adds script to class variable when rendered' do
      expect(view_context).to receive(:enqueue_component_stylesheets).with(
        'example_component_with_stylesheet',
      )

      render_inline(ExampleComponentWithStylesheet.new)
    end

    it 'adds own and parent scripts to class variable when rendered' do
      expect(view_context).to receive(:enqueue_component_stylesheets).with(
        'nested_example_component_with_stylesheet',
        'example_component_with_stylesheet',
      )

      render_inline(NestedExampleComponentWithStylesheet.new)
    end

    it 'adds own and scripts of any other component it renders' do
      call = 0
      expect(view_context).to receive(:enqueue_component_stylesheets).twice do |*args|
        call += 1
        case call
        when 1
          expect(args).to eq [
            'example_component_with_stylesheet_rendering_other_component_with_stylesheet',
          ]
        when 2
          expect(args).to eq [
            'example_component_with_stylesheet',
          ]
        end
      end

      render_inline(ExampleComponentWithStylesheetRenderingOtherComponentWithStylesheet.new)
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
