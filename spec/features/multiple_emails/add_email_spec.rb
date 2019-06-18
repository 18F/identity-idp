require 'rails_helper'

feature 'adding email address' do
  let(:email) { 'test@test.com' }

  context 'when adding emails is disabled' do
    before do
      allow(FeatureManagement).to receive(:email_addition_enabled?).and_return(false)
      Rails.application.reload_routes!
    end

    it 'does not display a link to allow adding an email' do
      user = create(:user, :signed_up)
      sign_in_and_2fa_user(user)

      visit account_path
      expect(page).to_not have_link(t('account.index.email_add'), href: '/add/email')
    end
  end

  context 'when adding emails is enabled' do
    before do
      allow(FeatureManagement).to receive(:email_addition_enabled?).and_return(true)
      Rails.application.reload_routes!
    end

    it 'allows the user to add an email and confirm with an active session' do
      allow(UserMailer).to receive(:email_added).and_call_original
      user = create(:user, :signed_up)
      sign_in_user_and_add_email(user)

      visit account_path
      expect(page).to have_content email + t('email_addresses.unconfirmed')

      click_on_link_in_confirmation_email

      expect(page).to have_current_path(account_path)
      expect(page).to have_content(t('devise.confirmations.confirmed'))
      expect(page).to_not have_content email + t('email_addresses.unconfirmed')
      expect(UserMailer).to have_received(:email_added).twice
    end

    it 'allows the user to add an email and confirm without an active session' do
      allow(UserMailer).to receive(:email_added).and_call_original
      user = create(:user, :signed_up)
      sign_in_user_and_add_email(user)

      Capybara.reset_session!

      click_on_link_in_confirmation_email
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(t('devise.confirmations.confirmed_but_sign_in'))
      expect(UserMailer).to have_received(:email_added).twice
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

    it 'notifies user they are already confirmed with an active session' do
      user = create(:user, :signed_up)
      sign_in_user_and_add_email(user)

      email_to_click_on = last_email_sent
      click_on_link_in_confirmation_email(email_to_click_on)
      click_on_link_in_confirmation_email(email_to_click_on)

      expect(page).to have_current_path(account_path)
      expect(page).to have_content(t('devise.confirmations.already_confirmed', action: nil).strip)
    end

    it 'notifies user they are already confirmed on another account' do
      create(:user, :signed_up, email: email)

      user = create(:user, :signed_up)
      sign_in_user_and_add_email(user)

      email_to_click_on = last_email_sent
      click_on_link_in_confirmation_email(email_to_click_on)

      expect(page).to have_current_path(account_path)
      expect(page).to have_content(
        t('devise.confirmations.confirmed_but_remove_from_other_account'),
      )
    end

    it 'routes to root with a bad confirmation token' do
      visit add_email_confirmation_url(confirmation_token: 'foo')

      expect(page).to have_current_path(root_path)
    end

    it 'does not show add email button when max emails is reached' do
      allow(Figaro.env).to receive(:max_emails_per_account).and_return('1')
      user = create(:user, :signed_up)
      sign_in_and_2fa_user(user)

      visit account_path
      expect(page).to_not have_link(t('account.index.email_add'), href: add_email_path)
    end

    it 'does not allow the user to add an email when max emails is reached' do
      allow(Figaro.env).to receive(:max_emails_per_account).and_return('1')
      user = create(:user, :signed_up)
      sign_in_and_2fa_user(user)

      visit add_email_path
      expect(page).to have_current_path(account_path)
    end

    it 'stays on form with bad email' do
      user = create(:user, :signed_up)
      sign_in_and_2fa_user(user)
      visit account_path
      click_link t('account.index.email_add')

      expect(page).to have_current_path(add_email_path)

      fill_in 'Email', with: 'foo'
      click_button t('forms.buttons.submit.default')

      expect(page).to have_current_path(add_email_path)
    end

    it 'stays on form and gives an error message when adding an email already on the account' do
      user = create(:user, :signed_up)
      sign_in_and_2fa_user(user)
      visit account_path
      click_link t('account.index.email_add')

      expect(page).to have_current_path(add_email_path)

      fill_in 'Email', with: user.email_addresses.first.email
      click_button t('forms.buttons.submit.default')

      expect(page).to have_current_path(add_email_path)
      expect(page).to have_content(I18n.t('email_addresses.add.duplicate'))
    end

    it 'does not show verify screen without an email in session from add email' do
      user = create(:user, :signed_up)
      sign_in_and_2fa_user(user)
      visit add_email_verify_email_path

      expect(page).to have_current_path(add_email_path)
    end

    it 'allows user to resend add email link' do
      user = create(:user, :signed_up)
      sign_in_user_and_add_email(user)

      expect(UserMailer).to receive(:add_email).
        with(user, anything, anything).and_call_original
      click_button t('links.resend')
    end

    it 'invalidates the confirmation email/token after 24 hours' do
      user = create(:user, :signed_up)
      sign_in_user_and_add_email(user)

      Capybara.reset_session!

      Timecop.travel 25.hours.from_now do
        click_on_link_in_confirmation_email
        expect(page).to have_current_path(root_path)
        expect(page).to_not have_content(t('devise.confirmations.confirmed_but_sign_in'))
      end
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
