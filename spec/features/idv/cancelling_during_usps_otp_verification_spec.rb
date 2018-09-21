require 'rails_helper'

shared_examples 'cancelling and restarting idv' do
  it 'allows the user to retry verification with phone' do
    expect(user.reload.decorate.pending_profile?).to eq(true)

    click_on t('idv.messages.reset_and_restart_verification')

    expect(user.reload.decorate.pending_profile?).to eq(false)

    fill_out_idv_jurisdiction_ok
    click_idv_continue
    fill_out_idv_form_ok
    fill_in 'profile_address1', with: '8484 Peachtree St'
    click_idv_continue
    click_idv_continue
    click_idv_continue
    fill_in 'Password', with: user.password
    click_idv_continue
    click_acknowledge_personal_key

    expect(page).to have_current_path(sign_up_completed_path)
    expect(user.reload.decorate.identity_verified?).to eq(true)
  end

  it 'allows the user to retry verification with usps' do
    expect(user.reload.decorate.pending_profile?).to eq(true)

    click_on t('idv.messages.reset_and_restart_verification')

    expect(user.reload.decorate.pending_profile?).to eq(false)

    fill_out_idv_jurisdiction_ok
    click_idv_continue
    fill_out_idv_form_ok
    fill_in 'profile_address1', with: '8484 Peachtree St'
    click_idv_continue
    click_idv_continue
    click_on t('idv.form.activate_by_mail')
    click_on t('idv.buttons.mail.resend')
    fill_in 'Password', with: user.password
    click_idv_continue
    click_acknowledge_personal_key

    usps_confirmation = UspsConfirmation.order(created_at: :desc).first

    expect(page).to have_content(t('idv.messages.come_back_later', app: APP_NAME))
    expect(page).to have_current_path(idv_come_back_later_path)
    expect(user.reload.decorate.identity_verified?).to eq(false)
    expect(user.decorate.pending_profile?).to eq(true)
    expect(usps_confirmation.entry[:address1]).to eq('8484 Peachtree St')
  end
end

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
