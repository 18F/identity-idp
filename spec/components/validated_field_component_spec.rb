require 'rails_helper'

RSpec.describe ValidatedFieldComponent, type: :component do
  include SimpleForm::ActionViewExtensions::FormHelper

  let(:lookup_context) { ActionView::LookupContext.new(ActionController::Base.view_paths) }
  let(:view_context) { ActionView::Base.new(lookup_context, {}, controller) }
  let(:form_object) { User.new }
  let(:form_builder) do
    SimpleForm::FormBuilder.new(form_object.model_name.param_key, form_object, view_context, {})
  end
  let(:name) { :uuid }
  let(:error_messages) { nil }
  let(:tag_options) { {} }
  let(:options) do
    {
      name: name,
      form: form_builder,
      error_messages: error_messages,
      **tag_options,
    }.compact
  end

  subject(:rendered) do
    render_inline(described_class.new(**options))
  end

  describe 'error message strings' do
    subject(:strings) do
      script = rendered.at_css('script[type="application/json"]')
      JSON.parse(script.content, symbolize_names: true)
    end

    it 'renders with error message texts' do
      expect(strings[:valueMissing]).to eq t('simple_form.required.text')
    end

    context 'boolean type' do
      let(:tag_options) { { as: :boolean } }

      it 'renders with error message texts' do
        expect(strings[:valueMissing]).to eq t('forms.validation.required_checkbox')
      end
    end

    context 'email type' do
      let(:tag_options) { { as: :email } }

      it 'renders with error message texts' do
        expect(strings[:typeMismatch]).to eq t('valid_email.validations.email.invalid')
      end
    end

    context 'custom error message texts' do
      let(:error_messages) { { valueMissing: 'missing', tooLong: 'too long' } }

      it 'renders with error message texts' do
        expect(strings).to include(valueMissing: 'missing', tooLong: 'too long')
      end
    end
  end
end
