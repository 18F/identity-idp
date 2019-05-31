require 'rails_helper'

feature 'adding email address' do
  let(:email) { 'test@test.com' }

  context 'when adding emails is disabled' do
    before do
      allow(FeatureManagement).to receive(:email_addition_enabled?).and_return(false)
    end

    it 'does not display a link to allow adding an email' do
      user = create(:user, :signed_up)
      sign_in_and_2fa_user(user)

      visit account_path
      expect(page).to_not have_link(t('account.index.email_add'), href: add_email_path)
    end
  end

  context 'when adding emails is enabled' do
    before do
      allow(FeatureManagement).to receive(:email_addition_enabled?).and_return(true)
    end

    it 'allows the user to add an email and confirm with an active session' do
      user = create(:user, :signed_up)
      sign_in_user_and_add_email(user)
      click_on_link_in_confirmation_email

      expect(page).to have_current_path(account_path)
      expect(page).to have_content(t('devise.confirmations.confirmed'))
    end

    it 'allows the user to add an email and confirm without an active session' do
      user = create(:user, :signed_up)
      sign_in_user_and_add_email(user)

      Capybara.reset_session!

      click_on_link_in_confirmation_email
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(t('devise.confirmations.confirmed_but_sign_in'))
    end

    it 'notifies user they are already confirmed without an active session' do
      user = create(:user, :signed_up)
      sign_in_user_and_add_email(user)

      Capybara.reset_session!

      email_to_click_on = last_email_sent
      click_on_link_in_confirmation_email(email_to_click_on)
      click_on_link_in_confirmation_email(email_to_click_on)

      expect(page).to have_current_path(root_path)
      action = t('devise.confirmations.sign_in')
      expect(page).to have_content(t('devise.confirmations.already_confirmed', action: action))
    end

    it 'routes to root with a bad token' do
      visit add_email_path(confirmation_token: 'foo')

      expect(page).to have_current_path(root_path)
    end
  end

  def sign_in_user_and_add_email(user)
    sign_in_and_2fa_user(user)

    visit account_path
    click_link t('account.index.email_add')

    expect(page).to have_current_path(add_email_path)

    expect(UserMailer).to receive(:add_email).
      with(user, anything, anything).and_call_original

    fill_in 'Email', with: email
    click_button t('forms.buttons.submit.default')

    expect(page).to have_current_path(add_email_verify_email_path)
    expect(page).to have_content email
  end

  def click_on_link_in_confirmation_email(email_to_click_on = last_email_sent)
    set_current_email(email_to_click_on)

    click_email_link_matching(%r{add/email/confirm\?confirmation_token})
  end
end
