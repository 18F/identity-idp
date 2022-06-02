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
  let(:confirmed_phone) { true }
  let(:required) { nil }
  let(:delivery_methods) { nil }
  let(:tag_options) { {} }
  let(:options) do
    {
      form: form_builder,
      allowed_countries: allowed_countries,
      confirmed_phone: confirmed_phone,
      required: required,
      delivery_methods: delivery_methods,
      **tag_options,
    }.compact
  end
  let(:instance) { described_class.new(**options) }

  subject(:rendered) do
    render_inline(instance)
  end

  it 'renders an lg-phone-input tag' do
    expect(rendered).to have_css('lg-phone-input')
  end

  it 'renders with JavaScript string initializers' do
    expect(rendered).to have_css(
      '.phone-input__strings',
      visible: false,
      text: t('two_factor_authentication.otp_delivery_preference.no_supported_options'),
    )
  end

  describe '#supported_country_codes' do
    subject { instance.supported_country_codes }

    it { is_expected.to start_with(['AD', 'AE', 'AF', 'AG']) }

    context 'with allowed_countries' do
      let(:allowed_countries) { ['US', 'CA'] }

      it { is_expected.to eq(['CA', 'US']) }
    end
  end

  describe '#translated_country_code_names' do
    subject { instance.translated_country_code_names }

    before do
      I18n.locale = :es
    end

    it { is_expected.to include('us' => 'Estados Unidos') }
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

  context 'when the locale has been changed' do
    before do
      I18n.locale = :es
    end

    let(:allowed_countries) { ['US'] }

    it 'translates the allowed country name' do
      expect(rendered).to have_select(
        t('components.phone_input.country_code_label'),
        options: ['Estados Unidos +1'],
      )
    end
  end

  context 'with sms delivery constraint' do
    let(:delivery_methods) { [:sms] }

    it 'renders with JavaScript string initializers' do
      expect(rendered).to have_css(
        '.phone-input__strings',
        visible: false,
        text: t('two_factor_authentication.otp_delivery_preference.sms_unsupported'),
      )
    end
  end

  context 'with voice delivery constraint' do
    let(:delivery_methods) { [:voice] }

    it 'renders with JavaScript string initializers' do
      expect(rendered).to have_css(
        '.phone-input__strings',
        visible: false,
        text: t('two_factor_authentication.otp_delivery_preference.voice_unsupported'),
      )
    end
  end

  context 'with delivery unsupported country' do
    before do
      stub_const(
        'PhoneNumberCapabilities::INTERNATIONAL_CODES',
        PhoneNumberCapabilities::INTERNATIONAL_CODES.merge(
          'US' => PhoneNumberCapabilities::INTERNATIONAL_CODES['US'].merge('supports_sms' => false),
        ),
      )
    end

    it 'renders with delivery supports' do
      expect(rendered).to have_css('option[value=US][data-supports-sms=false]')
    end

    context 'with unconfirmed phone' do
      let(:confirmed_phone) { false }

      it 'renders with delivery supports' do
        expect(rendered).to have_css('option[value=US][data-supports-sms=false]')
      end
    end
  end

  context 'with delivery unsupported unconfirmed country' do
    before do
      stub_const(
        'PhoneNumberCapabilities::INTERNATIONAL_CODES',
        PhoneNumberCapabilities::INTERNATIONAL_CODES.merge(
          'US' => PhoneNumberCapabilities::INTERNATIONAL_CODES['US'].merge(
            'supports_sms_unconfirmed' => false,
          ),
        ),
      )
    end

    it 'renders with delivery supports' do
      expect(rendered).to have_css('option[value=US][data-supports-sms=true]')
    end

    context 'with unconfirmed phone' do
      let(:confirmed_phone) { false }

      it 'renders with delivery supports' do
        expect(rendered).to have_css('option[value=US][data-supports-sms=false]')
      end
    end
  end
end
