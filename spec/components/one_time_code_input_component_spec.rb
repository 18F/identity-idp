require 'rails_helper'

RSpec.describe OneTimeCodeInputComponent, type: :component do
  include SimpleForm::ActionViewExtensions::FormHelper

  let(:lookup_context) { ActionView::LookupContext.new(ActionController::Base.view_paths) }
  let(:view_context) { ActionView::Base.new(lookup_context, {}, controller) }
  let(:form) { SimpleForm::FormBuilder.new('', {}, view_context, {}) }
  let(:options) { {} }

  subject(:rendered) { render_inline OneTimeCodeInputComponent.new(form: form, **options) }

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
    end

    context 'numeric is false' do
      let(:options) { { numeric: false } }

      it 'renders input mode "text"' do
        expect(rendered).to have_selector('[inputmode="text"]')
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
      descriptors = rendered.
        at_css('.one-time-code-input__input')['aria-describedby'].
        split(' ').
        map { |descriptor_id| rendered.at_css("##{descriptor_id}")&.text }

      expect(descriptors).to include t('components.one_time_code_input.hint.numeric')
    end

    context 'numeric is false' do
      let(:options) { { numeric: false } }

      it 'includes hint text as a descriptor of the field' do
        descriptors = rendered.
          at_css('.one-time-code-input__input')['aria-describedby'].
          split(' ').
          map { |descriptor_id| rendered.at_css("##{descriptor_id}")&.text }

        expect(descriptors).to include t('components.one_time_code_input.hint.alphanumeric')
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

  describe 'maxlength' do
    context 'no maxlength given' do
      it 'renders input maxlength DIRECT_OTP_LENGTH' do
        expect(rendered).to have_selector(
          "[maxlength=\"#{TwoFactorAuthenticatable::DIRECT_OTP_LENGTH}\"]",
        )
      end
    end

    context 'maxlength given' do
      let(:options) { { maxlength: 10 } }

      it 'renders input given maxlength' do
        expect(rendered).to have_selector(
          '[maxlength="10"]',
        )
      end
    end
  end
end
