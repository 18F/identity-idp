require 'rails_helper'

RSpec.feature 'Remembering a phone' do
  include IdvStepHelper

  before do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(1000)
  end

  let(:user) { user_with_2fa }

  context 'sign in' do
    def remember_device_and_sign_out_user
      user = user_with_2fa
      sign_in_user(user)
      check t('forms.messages.remember_device')
      fill_in_code_with_last_phone_otp
      click_submit_default
      first(:button, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'sign up' do
    def remember_device_and_sign_out_user
      user = sign_up_and_set_password
      user.password = Features::SessionHelper::VALID_PASSWORD

      select_2fa_option('phone')
      fill_in :new_phone_form_phone, with: '2025551212'
      click_send_one_time_code
      check t('forms.messages.remember_device')
      fill_in_code_with_last_phone_otp
      click_submit_default
      skip_second_mfa_prompt

      first(:button, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end
end
