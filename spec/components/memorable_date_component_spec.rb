require 'rails_helper'

RSpec.describe MemorableDateComponent, type: :component do
  include SimpleForm::ActionViewExtensions::FormHelper

  let(:lookup_context) { ActionView::LookupContext.new(ActionController::Base.view_paths) }
  let(:view_context) { ActionView::Base.new(lookup_context, {}, controller) }
  let(:form_object) { Date.new }
  let(:form_builder) do
    SimpleForm::FormBuilder.new('MemorableDate', form_object, view_context, {})
  end
  let(:name) { 'test-name' }
  let(:month) { 12 }
  let(:day) { 1 }
  let(:year) { 1990 }
  let(:hint) { 'hint' }
  let(:label) { 'label' }
  let(:error_messages) { nil }
  let(:tag_options) { {} }
  let(:options) do
    {
      name: name,
      month: month,
      day: day,
      year: year,
      hint: hint,
      label: label,
      form: form_builder,
      error_messages: error_messages,
      **tag_options,
    }.compact
  end

  subject(:rendered) do
    render_inline(described_class.new(**options))
  end

  it 'renders aria-describedby to establish connection between input and error message' do
    field = rendered.at_css('input')

    expect(field.attr('aria-describedby')).to start_with('validated-field-error-')
  end
end
