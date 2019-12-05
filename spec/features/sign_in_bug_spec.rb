class PryFlag
  class << self
    attr_accessor :set
  end
end

require 'rails_helper'

describe 'A bug that happens on sign in w/ remember device' do
  it 'create the bug' do
    user = create(:user, :with_phone, :with_personal_key)
    sign_in_user(user)
    fill_in_code_with_last_phone_otp
    check :remember_device
    click_submit_default
    click_on '‹ Cancel sign in'
    visit root_path

    visit openid_connect_authorize_path(
      client_id: 'urn:gov:gsa:openidconnect:sp:server',
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: SecureRandom.hex,
      prompt: 'select_account',
      nonce: SecureRandom.hex,
    )
    sign_in_user(user)
    select_2fa_option :backup_code
    click_continue
    PryFlag.set = true
    click_continue

  end
end
