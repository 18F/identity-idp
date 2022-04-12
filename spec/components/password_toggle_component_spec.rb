require 'rails_helper'

RSpec.describe PasswordToggleComponent, type: :component do
  include SimpleForm::ActionViewExtensions::FormHelper

  let(:lookup_context) { ActionView::LookupContext.new(ActionController::Base.view_paths) }
  let(:view_context) { ActionView::Base.new(lookup_context, {}, controller) }
  let(:form) { SimpleForm::FormBuilder.new('', {}, view_context, {}) }
  let(:options) { {} }

  subject(:rendered) { render_inline PasswordToggleComponent.new(form: form, **options) }

  it 'renders default markup' do
    expect(rendered).to have_css('lg-password-toggle.password-toggle--toggle-top')
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
      let(:options) { { label: label } }

      it 'renders custom field label' do
        expect(rendered).to have_field(label, type: :password)
      end
    end
  end

  describe '#toggle_label' do
    context 'with custom label' do
      let(:toggle_label) { 'Custom Toggle Label' }
      let(:options) { { toggle_label: toggle_label } }

      it 'renders custom field label' do
        expect(rendered).to have_field(toggle_label, type: :checkbox)
      end
    end
  end

  describe '#toggle_position' do
    context 'with top toggle position' do
      let(:options) { { toggle_position: :top } }

      it 'renders modifier class' do
        expect(rendered).to have_css('lg-password-toggle.password-toggle--toggle-top')
      end
    end

    context 'with bottom toggle position' do
      let(:options) { { toggle_position: :bottom } }

      it 'renders modifier class' do
        expect(rendered).to have_css('lg-password-toggle.password-toggle--toggle-bottom')
      end
    end
  end

  describe '#toggle_id' do
    it 'is unique across instances' do
      toggle_one = PasswordToggleComponent.new(form: form)
      toggle_two = PasswordToggleComponent.new(form: form)

      expect(toggle_one.toggle_id).to be_present
      expect(toggle_two.toggle_id).to be_present
      expect(toggle_one.toggle_id).not_to eq(toggle_two.toggle_id)
    end
  end

  describe '#input_id' do
    it 'is unique across instances' do
      toggle_one = PasswordToggleComponent.new(form: form)
      toggle_two = PasswordToggleComponent.new(form: form)

      expect(toggle_one.input_id).to be_present
      expect(toggle_two.input_id).to be_present
      expect(toggle_one.input_id).not_to eq(toggle_two.input_id)
    end
  end

  describe '#field' do
    context 'with field options' do
      let(:options) do
        { input_html: { class: 'my-custom-field', data: { foo: 'bar' } }, required: true }
      end

      it 'forwards field options' do
        expect(rendered).to have_css(
          '.password-toggle__input.my-custom-field[data-foo="bar"][required]',
        )
      end
    end
  end
end
