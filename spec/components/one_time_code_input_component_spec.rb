require 'rails_helper'

RSpec.describe OneTimeCodeInputComponent, type: :component do
  include SimpleForm::ActionViewExtensions::FormHelper

  let(:view_context) { vc_test_controller.view_context }
  let(:form) { SimpleForm::FormBuilder.new('', {}, view_context, {}) }
  let(:options) { {} }

  subject(:rendered) { render_inline OneTimeCodeInputComponent.new(form:, **options) }

  before do
    stub_const('TwoFactorAuthenticatable::DIRECT_OTP_LENGTH', 6)
  end

  describe 'name' do
    context 'no name given' do
      it 'renders default name "code"' do
        expect(rendered).to have_selector('[name="code"]')
      end
    end

    context 'name given' do
      let(:options) { { name: 'example' } }

      it 'renders given name' do
        expect(rendered).to have_selector('[name="example"]')
      end
    end
  end

  describe 'numeric' do
    context 'no numeric given' do
      it 'renders input mode "numeric"' do
        expect(rendered).to have_selector('[inputmode="numeric"]')
      end

      it 'renders input pattern' do
        expect(rendered).to have_css('[pattern="[0-9]{6}"]')
      end
    end

    context 'numeric is false' do
      let(:options) { { numeric: false } }

      it 'renders input mode "text"' do
        expect(rendered).to have_selector('[inputmode="text"]')
      end

      it 'renders input pattern' do
        expect(rendered).to have_css('[pattern="[a-zA-Z0-9]{6}"]')
      end
    end
  end

  describe 'classes' do
    context 'without custom classes given on input' do
      it 'renders with default classes' do
        expect(rendered).to have_selector('.one-time-code-input__input')
      end
    end

    context 'with custom classes on input' do
      let(:options) { { field_options: { input_html: { class: 'my-custom-class' } } } }

      it 'renders with additional custom classes' do
        expect(rendered).to have_selector('.one-time-code-input__input.my-custom-class')
      end
    end
  end

  describe 'hint' do
    it 'includes hint text as a descriptor of the field' do
      field = rendered.at_css('.one-time-code-input__input')

      expect(field).to have_description t('components.one_time_code_input.hint.numeric')
    end

    context 'numeric is false' do
      let(:options) { { numeric: false } }

      it 'includes hint text as a descriptor of the field' do
        field = rendered.at_css('.one-time-code-input__input')

        expect(field).to have_description t('components.one_time_code_input.hint.alphanumeric')
      end
    end
  end

  describe 'transport' do
    context 'omitted' do
      it 'renders default sms transport' do
        expect(rendered).to have_selector('lg-one-time-code-input[transport="sms"]')
      end
    end

    context 'given' do
      let(:options) { { transport: 'example' } }

      it 'renders given transport' do
        expect(rendered).to have_selector('lg-one-time-code-input[transport="example"]')
      end
    end

    context 'explicitly nil' do
      let(:options) { { transport: nil } }

      it 'renders without transport' do
        expect(rendered).to have_selector('lg-one-time-code-input:not([transport])')
      end
    end
  end

  describe 'extra attributes' do
    let(:options) { { data: { foo: 'bar' } } }

    it 'applies attributes to wrapper' do
      expect(rendered).to have_selector('lg-one-time-code-input[data-foo="bar"]')
    end
  end

  describe 'code_length' do
    context 'without code_length' do
      it 'renders input default maxlength' do
        expect(rendered).to have_css('[maxlength="6"]')
      end

      it 'renders input pattern' do
        expect(rendered).to have_css('[pattern="[0-9]{6}"]')
      end
    end

    context 'with code_length' do
      let(:options) { { code_length: 10 } }

      it 'renders input maxlength based on given code_length' do
        expect(rendered).to have_css('[maxlength="10"]')
      end

      it 'renders input pattern' do
        expect(rendered).to have_css('[pattern="[0-9]{10}"]')
      end
    end
  end

  describe 'optional_prefix' do
    context 'without optional_prefix' do
      it 'renders input default maxlength' do
        expect(rendered).to have_css('[maxlength="6"]')
      end

      it 'renders input pattern' do
        expect(rendered).to have_css('[pattern="[0-9]{6}"]')
      end
    end

    context 'with optional_prefix given' do
      let(:options) { { optional_prefix: '$' } }

      it 'renders input maxlength based on given optional_prefix' do
        expect(rendered).to have_css('[maxlength="7"]')
      end

      it 'renders input pattern' do
        expect(rendered).to have_css('[pattern="\\\$?[0-9]{6}"]')
      end

      context 'with prefix which would be escaped in ruby but unescaped in javascript' do
        let(:options) { { optional_prefix: '#' } }

        it 'renders input pattern without escaping' do
          expect(rendered).to have_css('[pattern="#?[0-9]{6}"]')
        end
      end
    end
  end
end
