require 'rails_helper'

describe 'clearing IdV and restarting' do
  include IdvStepHelper

  let(:user) { user_with_2fa }

  context 'during USPS otp verification' do
    before do
      start_idv_from_sp
      complete_idv_steps_with_usps_before_confirmation_step(user)
      click_acknowledge_personal_key
    end

    context 'before signing out' do
      before do
        visit verify_account_path
      end

      it_behaves_like 'clearing and restarting idv'
    end

    context 'after signing out' do
      before do
        visit account_path
        first(:link, t('links.sign_out')).click
        start_idv_from_sp
        sign_in_live_with_2fa(user)
      end

      it_behaves_like 'clearing and restarting idv'
    end
  end

  context 'during USPS step' do
    context 'sending a letter before signing out' do
      before do
        start_idv_from_sp
        complete_idv_steps_before_usps_step(user)
      end

      it_behaves_like 'clearing and restarting idv'
    end

    context 're-sending a letter after signing out' do
      before do
        start_idv_from_sp
        complete_idv_steps_with_usps_before_confirmation_step(user)
        click_acknowledge_personal_key
        visit account_path
        first(:link, t('links.sign_out')).click
        start_idv_from_sp
        sign_in_live_with_2fa(user)
        click_on t('idv.messages.usps.resend')
      end

      it_behaves_like 'clearing and restarting idv'
    end
  end
end
