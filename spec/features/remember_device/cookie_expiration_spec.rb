require 'rails_helper'

RSpec.describe 'signing in with remember device and closing browser' do
  include SamlAuthHelper

  let(:user) { user_with_2fa }

  it 'does not expire the remember device cookie' do
    sign_in_user_with_remember_device
    expire_cookies
    sign_in_user(user)

    expect(current_url).to match(%r{/account})
  end

  def sign_in_user_with_remember_device
    sign_in_user(user)
    check t('forms.messages.remember_device')
    fill_in_code_with_last_phone_otp
    click_submit_default
  end

  def expire_cookies
    cookie_jar = Capybara.current_session.driver.browser.current_session.cookie_jar
    cookie_jar.to_hash.each do |name, _value|
      cookie_jar.delete(name) if cookie_jar.get_cookie(name).expired? != false
    end
  end
end
