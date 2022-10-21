require 'rails_helper'

describe 'signing in with remember device and closing browser' do
  include SamlAuthHelper

  let(:user) { user_with_2fa }

  context 'with feature flag set' do
    before do
      allow(IdentityConfig.store).to receive(:set_remember_device_session_expiration).
        and_return(true)
    end

    it 'expires the remember device cookie' do
      sign_in_user_with_remember_device
      expire_cookies
      sign_in_user(user)

      expect(current_url).to match(%r{/login/two_factor/})
    end
  end

  context 'with feature flag unset' do
    before do
      allow(IdentityConfig.store).to receive(:set_remember_device_session_expiration).
        and_return(false)
    end

    it 'does not expire the remember device cookie' do
      sign_in_user_with_remember_device
      expire_cookies
      sign_in_user(user)

      expect(current_url).to match(%r{/account})
    end
  end

  def sign_in_user_with_remember_device
    sign_in_user(user)
    check t('forms.messages.remember_device')
    fill_in_code_with_last_phone_otp
    click_submit_default
  end

  def expire_cookies
    cookie_jar = Capybara.current_session.driver.browser.current_session.cookie_jar
    cookie_jar.to_hash.each do |name, value|
      cookie_jar.delete(name) if cookie_jar.get_cookie(name).expired? != false
    end
  end
end
