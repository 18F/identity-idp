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

  it 'renders with error message texts' do
    expect(rendered).to have_css(
      'script',
      text: { valueMissing: t('simple_form.required.text') }.to_json,
      visible: :all,
    )
  end

  context 'boolean type' do
    let(:tag_options) { { as: :boolean } }

    it 'renders with error message texts' do
      expect(rendered).to have_css(
        'script',
        text: { valueMissing: t('forms.validation.required_checkbox') }.to_json,
        visible: :all,
      )
    end
  end

  context 'custom error message texts' do
    let(:error_messages) { { valueMissing: 'missing', tooLong: 'too long' } }

    it 'renders with error message texts' do
      expect(rendered).to have_css(
        'script',
        text: { valueMissing: 'missing', tooLong: 'too long' }.to_json,
        visible: :all,
      )
    end
  end
end
