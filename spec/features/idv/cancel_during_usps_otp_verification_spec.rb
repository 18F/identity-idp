require 'rails_helper'

describe 'cancelling IdV during USPS otp verification' do
  include IdvStepHelper

  let(:user) { user_with_2fa }

  context 'clicking the cancel button after signing out' do
    before do
      start_idv_from_sp
      complete_idv_steps_with_usps_before_confirmation_step(user)
      click_acknowledge_personal_key
      visit account_path
      first(:link, t('links.sign_out')).click
      start_idv_from_sp
      sign_in_live_with_2fa(user)
    end

    it_behaves_like 'cancelling and restarting idv'
  end

  context 'clicking the cancel button before signing out' do
    before do
      start_idv_from_sp
      complete_idv_steps_with_usps_before_confirmation_step(user)
      click_acknowledge_personal_key
      visit verify_account_path
    end

    it_behaves_like 'cancelling and restarting idv'
  end
end
