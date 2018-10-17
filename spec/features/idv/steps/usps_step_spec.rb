require 'rails_helper'

feature 'idv usps step' do
  include IdvStepHelper

  it 'redirects to the review step when the user chooses to verify by letter' do
    start_idv_from_sp
    complete_idv_steps_before_usps_step
    click_on t('idv.buttons.mail.send')

    expect(page).to have_content(t('idv.titles.session.review'))
    expect(page).to have_current_path(idv_review_path)
  end

  it 'allows the user to clear IdV and restart' do
    start_idv_from_sp
    complete_idv_steps_before_usps_step

    click_on t('idv.messages.clear_and_start_over')

    expect(page).to have_content(t('idv.messages.jurisdiction.why'))
    expect(page).to have_current_path(idv_jurisdiction_path)
  end

  context 'the user has sent a letter but not verified an OTP' do
    let(:user) { user_with_2fa }

    it 'allows the user to resend a letter and redirects to the come back later step' do
      complete_idv_and_return_to_usps_step

      expect { click_on t('idv.buttons.mail.resend') }.
        to change { UspsConfirmation.count }.from(1).to(2)
      expect_user_to_be_unverified(user)
      expect(page).to have_content(t('idv.titles.come_back_later'))
      expect(page).to have_current_path(idv_come_back_later_path)
    end

    it 'allows the user to cancel and return to usps otp confirmation' do
      complete_idv_and_return_to_usps_step
      click_link t('links.cancel')

      expect(page).to have_content(t('forms.verify_profile.title'))
      expect(page).to have_current_path(verify_account_path)
      expect_user_to_be_unverified(user)
    end

    def complete_idv_and_return_to_usps_step
      start_idv_from_sp
      complete_idv_steps_before_usps_step(user)
      click_on t('idv.buttons.mail.send')
      fill_in 'Password', with: user_password
      click_continue
      click_acknowledge_personal_key
      visit root_path
      click_on t('idv.buttons.cancel')
      first(:link, t('links.sign_out')).click
      sign_in_live_with_2fa(user)
      click_on t('idv.messages.usps.resend')
    end

    def expect_user_to_be_unverified(user)
      expect(user.events.account_verified.size).to be(0)
      expect(user.profiles.count).to eq 1

      profile = user.profiles.first

      expect(profile.active?).to eq false
      expect(profile.deactivation_reason).to eq 'verification_pending'
    end
  end

  context 'cancelling IdV' do
    it_behaves_like 'cancel at idv step', :usps
    it_behaves_like 'cancel at idv step', :usps, :oidc
    it_behaves_like 'cancel at idv step', :usps, :saml
  end
end
