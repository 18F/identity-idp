require 'rails_helper'

RSpec.describe PasswordToggleComponent, type: :component do
  include SimpleForm::ActionViewExtensions::FormHelper

  let(:view_context) { vc_test_controller.view_context }
  let(:form) { SimpleForm::FormBuilder.new('', {}, view_context, {}) }
  let(:options) { {} }

  subject(:rendered) { render_inline PasswordToggleComponent.new(form:, **options) }

  it 'renders default markup' do
    expect(rendered).to have_css('lg-password-toggle')
    expect(rendered).to have_field(t('components.password_toggle.label'), type: :password)
    expect(rendered).to have_field(t('components.password_toggle.toggle_label'), type: :checkbox)
  end

  it 'renders with accessible linking between toggle and input' do
    input_id = rendered.css('[type=password]').first.attr('id')

    expect(input_id).to be_present
    expect(rendered).to have_css("[aria-controls='#{input_id}']")
  end

  describe '#label' do
    context 'with custom label' do
      let(:label) { 'Custom Label' }
      let(:options) { { label: } }

      it 'renders custom field label' do
        expect(rendered).to have_field(label, type: :password)
      end
    end
  end

  describe '#toggle_label' do
    context 'with custom label' do
      let(:toggle_label) { 'Custom Toggle Label' }
      let(:options) { { toggle_label: } }

      it 'renders custom field label' do
        expect(rendered).to have_field(toggle_label, type: :checkbox)
      end
    end
  end

  describe '#toggle_id' do
    it 'is unique across instances' do
      toggle_one = PasswordToggleComponent.new(form:)
      toggle_two = PasswordToggleComponent.new(form:)

      expect(toggle_one.toggle_id).to be_present
      expect(toggle_two.toggle_id).to be_present
      expect(toggle_one.toggle_id).not_to eq(toggle_two.toggle_id)
    end
  end

  describe '#input_id' do
    it 'is unique across instances' do
      toggle_one = PasswordToggleComponent.new(form:)
      toggle_two = PasswordToggleComponent.new(form:)

      expect(toggle_one.input_id).to be_present
      expect(toggle_two.input_id).to be_present
      expect(toggle_one.input_id).not_to eq(toggle_two.input_id)
    end
  end

  context 'with tag options' do
    let(:options) do
      { class: 'my-custom-field', data: { foo: 'bar' } }
    end

    it 'forwards options to rendered tag' do
      expect(rendered).to have_css('lg-password-toggle.my-custom-field[data-foo="bar"]')
    end
  end

  context 'with field options' do
    let(:label) { 'Custom Label' }
    let(:options) do
      { field_options: { label:, required: true } }
    end

    it 'forwards options to rendered field' do
      expect(rendered).to have_css('.password-toggle__input[required]')
      expect(rendered).to have_field(label, type: :password)
    end
  end
end
