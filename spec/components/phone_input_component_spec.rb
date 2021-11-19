require 'rails_helper'

RSpec.describe PhoneInputComponent, type: :component do
  include SimpleForm::ActionViewExtensions::FormHelper

  let(:lookup_context) { ActionView::LookupContext.new(ActionController::Base.view_paths) }
  let(:view_context) { ActionView::Base.new(lookup_context, {}, controller) }
  let(:user) { build_stubbed(:user) }
  let(:form_object) { NewPhoneForm.new(user) }
  let(:form_builder) do
    SimpleForm::FormBuilder.new(form_object.model_name.param_key, form_object, view_context, {})
  end
  let(:allowed_countries) { nil }
  let(:required) { nil }
  let(:tag_options) { {} }
  let(:options) do
    {
      form: form_builder,
      allowed_countries: allowed_countries,
      required: required,
      **tag_options,
    }.compact
  end

  subject(:rendered) do
    render_inline(described_class.new(**options))
  end

  it 'renders an lg-phone-input tag' do
    expect(rendered).to have_css('lg-phone-input')
  end

  context 'with class tag option' do
    let(:tag_options) { { class: 'example-class' } }

    it 'renders with custom class' do
      expect(rendered).to have_css('lg-phone-input.example-class')
    end
  end

  context 'with allowed countries' do
    let(:allowed_countries) { ['US'] }

    it 'limits the allowed countries' do
      expect(rendered).to have_select(
        t('components.phone_input.country_code_label'),
        options: ['United States +1'],
      )
    end

    context 'with invalid allowed countries' do
      let(:allowed_countries) { ['US', 'ZZ'] }

      it 'limits the allowed countries to valid countries' do
        expect(rendered).to have_select(
          t('components.phone_input.country_code_label'),
          options: ['United States +1'],
        )
      end
    end
  end
end
