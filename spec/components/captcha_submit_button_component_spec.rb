require 'rails_helper'

RSpec.describe CaptchaSubmitButtonComponent, type: :component do
  let(:lookup_context) { ActionView::LookupContext.new(ActionController::Base.view_paths) }
  let(:view_context) { ActionView::Base.new(lookup_context, {}, controller) }
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

  context 'with recaptcha token input errors' do
    let(:error_message) { 'Invalid token' }
    before do
      form_object.errors.add(:recaptcha_token, error_message)
    end

    it 'renders recaptcha token errors' do
      expect(rendered).to have_content(error_message)
    end
  end

  context 'without configured recaptcha site key' do
    before do
      allow(IdentityConfig.store).to receive(:recaptcha_site_key_v3).and_return(nil)
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
      allow(IdentityConfig.store).to receive(:recaptcha_site_key_v3).and_return(recaptcha_site_key)
    end

    it 'renders with recaptcha site key attribute' do
      expect(rendered).to have_css(
        "lg-captcha-submit-button[recaptcha-site-key='#{recaptcha_site_key}']",
      )
    end

    it 'renders script tag for recaptcha' do
      src = "#{CaptchaSubmitButtonComponent::RECAPTCHA_SCRIPT_SRC}?render=#{recaptcha_site_key}"
      expect(rendered).to have_css("script[src='#{src}']", visible: :all)
    end
  end

  context 'with additional tag options' do
    let(:options) { super().merge(data: { foo: 'bar' }) }

    it 'renders tag options on root wrapper element' do
      expect(rendered).to have_css('lg-captcha-submit-button[data-foo="bar"]')
    end
  end
end
