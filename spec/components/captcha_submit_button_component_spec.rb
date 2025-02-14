require 'rails_helper'

RSpec.describe CaptchaSubmitButtonComponent, type: :component do
  let(:view_context) { vc_test_controller.view_context }
  let(:form_object) { NewPhoneForm.new(user: User.new) }
  let(:form) { SimpleForm::FormBuilder.new('', form_object, view_context, {}) }
  let(:content) { 'Button' }
  let(:action) { 'action_name' }
  let(:options) { { form:, action: } }

  subject(:rendered) do
    render_inline CaptchaSubmitButtonComponent.new(**options).with_content(content)
  end

  it 'renders with action' do
    expect(rendered).to have_css("lg-captcha-submit-button[recaptcha-action='#{action}']")
  end

  it 'renders with content' do
    expect(rendered).to have_content(content)
  end

  context 'without configured recaptcha site key' do
    before do
      allow(IdentityConfig.store).to receive(:recaptcha_site_key).and_return(nil)
    end

    it 'renders without recaptcha site key attribute' do
      expect(rendered).to have_css('lg-captcha-submit-button:not([recaptcha-site-key])')
    end

    it 'does not render script tag for recaptcha' do
      expect(rendered).not_to have_css('script', visible: :all)
    end
  end

  context 'with configured recaptcha site key' do
    let(:recaptcha_site_key) { 'site_key' }
    before do
      allow(IdentityConfig.store).to receive(:recaptcha_site_key).and_return(recaptcha_site_key)
    end

    it 'renders with recaptcha site key attribute' do
      expect(rendered).to have_css(
        "lg-captcha-submit-button[recaptcha-site-key='#{recaptcha_site_key}']",
      )
    end

    it 'renders script tag for recaptcha' do
      src = "https://www.google.com/recaptcha/api.js?render=#{recaptcha_site_key}"
      expect(rendered).to have_css("script[src='#{src}']", visible: :all)
    end

    context 'with recaptcha enterprise' do
      before do
        allow(FeatureManagement).to receive(:recaptcha_enterprise?).and_return(true)
      end

      it 'renders script tag for recaptcha' do
        src = "https://www.google.com/recaptcha/enterprise.js?render=#{recaptcha_site_key}"

        expect(rendered).to have_css("script[src='#{src}']", visible: :all)
      end
    end
  end

  context 'with additional tag options' do
    let(:options) { super().merge(data: { foo: 'bar' }) }

    it 'renders tag options on root wrapper element' do
      expect(rendered).to have_css('lg-captcha-submit-button[data-foo="bar"]')
    end
  end

  context 'with button options' do
    let(:options) { super().merge(button_options: { full_width: true }) }

    it 'renders spinner button with additional options' do
      expect(rendered).to have_css('lg-spinner-button .usa-button--full-width')
    end
  end

  describe 'mock score field' do
    let(:recaptcha_mock_validator) { nil }

    before do
      allow(IdentityConfig.store).to receive(:recaptcha_mock_validator)
        .and_return(recaptcha_mock_validator)
    end

    context 'with mock validator disabled' do
      let(:recaptcha_mock_validator) { false }

      it 'does not render mock score field' do
        expect(rendered).not_to have_field(t('components.captcha_submit_button.mock_score_label'))
      end
    end

    context 'with mock validator enabled' do
      let(:recaptcha_mock_validator) { true }

      it 'renders mock score field' do
        expect(rendered).to have_field(t('components.captcha_submit_button.mock_score_label'))
      end
    end
  end

  describe '[recaptcha-enterprise] attribute' do
    subject(:enterprise_attribute) do
      rendered.at_css('lg-captcha-submit-button').attr('recaptcha-enterprise')
    end

    it { expect(enterprise_attribute).to eq('false') }

    context 'with recaptcha enterprise' do
      before do
        allow(FeatureManagement).to receive(:recaptcha_enterprise?).and_return(true)
      end

      it { expect(enterprise_attribute).to eq('true') }
    end
  end
end
