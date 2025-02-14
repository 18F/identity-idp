require 'rails_helper'

RSpec.describe CaptchaScriptComponent, type: :component do
  subject(:rendered) do
    render_inline CaptchaScriptComponent.new
  end

  context 'with configured recaptcha site key' do
    let(:recaptcha_site_key) { 'site_key' }
    before do
      allow(IdentityConfig.store).to receive(:recaptcha_site_key).and_return(recaptcha_site_key)
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
end
