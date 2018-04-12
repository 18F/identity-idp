require 'rails_helper'

feature 'Password Recovery' do
  include PersonalKeyHelper

  context 'user enters valid email in forgot password form', email: true do
    it 'redirects to forgot_password path and sends an email to the user' do
      allow(Figaro.env).to receive(:participate_in_dap).and_return('true')
      user = create(:user, :signed_up)

      visit root_path
      click_link t('links.passwords.forgot')
      fill_in 'Email', with: user.email
      click_button t('forms.buttons.continue')

      expect(current_path).to eq forgot_password_path

      expect(last_email.subject).to eq t('devise.mailer.reset_password_instructions.' \
                                          'subject')
      expect(last_email.html_part.body).to include MarketingSite.help_url
      expect(last_email.html_part.body).to have_content(
        t(
          'mailer.reset_password.footer',
          expires: (Devise.reset_password_within / 3600)
        )
      )

      open_last_email
      click_email_link_matching(/reset_password_token/)

      expect(page.html).not_to include(t('notices.dap_participation'))
      expect(current_path).to eq edit_user_password_path
    end
  end

  context 'user has confirmed email, but not set a password yet', email: true do
    it 'shows the reset password form and confirms user after setting a password' do
      user = create(:user, :unconfirmed)
      confirm_last_user
      reset_email

      trigger_reset_password_and_click_email_link(user.email)

      expect(current_path).to eq edit_user_password_path

      fill_in t('forms.passwords.edit.labels.password'), with: 'NewVal!dPassw0rd'
      click_button t('forms.passwords.edit.buttons.submit')

      expect(current_path).to eq new_user_session_path

      fill_in_credentials_and_submit(user.email, 'NewVal!dPassw0rd')

      expect(current_path).to eq two_factor_options_path
    end
  end

  context 'user who has only confirmed email resends confirmation', email: true do
    before do
      user = create(:user, :unconfirmed)
      confirm_last_user
      reset_email
      visit sign_up_email_resend_path
      fill_in 'Email', with: user.email
      click_button t('forms.buttons.resend_confirmation')
      open_last_email
      click_email_link_matching(/confirmation_token/)
    end

    it 'shows the password form' do
      expect(page).to have_content t('forms.confirmation.show_hdr')
    end
  end

  context 'user has confirmed email and set a password, then resets password', email: true do
    before do
      @user = create(:user)
      trigger_reset_password_and_click_email_link(@user.email)
    end

    it 'keeps user signed out after they successfully reset their password' do
      fill_in 'New password', with: 'NewVal!dPassw0rd'
      click_button t('forms.passwords.edit.buttons.submit')

      expect(current_path).to eq new_user_session_path
    end

    it 'prompts user to set up their 2FA options after signing back in' do
      reset_password_and_sign_back_in(@user)

      expect(current_path).to eq two_factor_options_path
    end
  end

  context 'user with invalid token cannot reset password', email: true do
    before do
      user = create(:user)
      visit new_user_password_path
      fill_in 'Email', with: user.email
      click_button t('forms.buttons.continue')
      visit edit_user_password_path(reset_password_token: 'invalid_token')
    end

    it 'redirects to new user password form' do
      expect(current_path).to eq new_user_password_path
    end

    it 'displays a flash error message' do
      expect(page).to have_content t('devise.passwords.invalid_token')
    end
  end

  context 'user with 2FA confirmation resets password', email: true do
    before do
      @user = create(:user, :signed_up)
      trigger_reset_password_and_click_email_link(@user.email)
    end

    it 'redirects user to profile after signing back in' do
      reset_password_and_sign_back_in(@user)
      click_button t('forms.buttons.submit.default')
      fill_in 'code', with: @user.reload.direct_otp
      click_button t('forms.buttons.submit.default')

      expect(current_path).to eq account_path
    end
  end

  scenario 'user submits blank email address' do
    visit new_user_password_path
    click_button t('forms.buttons.continue')

    expect(page).to have_content t('valid_email.validations.email.invalid')
  end

  context 'user can reset their password' do
    before do
      @user = create(:user, :signed_up)

      visit new_user_password_path
      fill_in 'Email', with: @user.email
      click_button t('forms.buttons.continue')

      raw_reset_token, db_confirmation_token =
        Devise.token_generator.generate(User, :reset_password_token)
      UpdateUser.new(user: @user, attributes: { reset_password_token: db_confirmation_token }).call

      visit edit_user_password_path(reset_password_token: raw_reset_token)
    end

    it 'lands on the reset password page' do
      expect(current_path).to eq edit_user_password_path
    end

    context 'when password form values are valid' do
      it 'changes the password, sends an email about the change, and does not sign the user in' do
        fill_in t('forms.passwords.edit.labels.password'), with: 'NewVal!dPassw0rd'

        click_button t('forms.passwords.edit.buttons.submit')

        expect(page).to have_content(t('devise.passwords.updated_not_active'))

        expect(last_email.subject).to eq t('devise.mailer.password_updated.subject')

        visit account_path
        expect(current_path).to eq new_user_session_path
      end
    end

    context 'when password form values are invalid' do
      it 'does not allow the user to submit until password score is good', js: true do
        fill_in t('forms.passwords.edit.labels.password'), with: 'invalid'
        expect(page).not_to have_button(t('forms.passwords.edit.buttons.submit'))

        fill_in t('forms.passwords.edit.labels.password'), with: 'password@132!'
        expect(page).not_to have_button(t('forms.passwords.edit.buttons.submit'))

        fill_in t('forms.passwords.edit.labels.password'), with: 'a unique and exciting zxjsahfas'
        expect(page).to have_button(t('forms.passwords.edit.buttons.submit'))
      end

      it 'displays field validation error when password fields are empty' do
        click_button t('forms.passwords.edit.buttons.submit')
        expect(page).to have_content t('errors.messages.blank')
      end

      it 'displays field validation error when password field is too short' do
        fill_in 'New password', with: '1234'
        click_button t('forms.passwords.edit.buttons.submit')

        expect(page).to have_content 'is too short (minimum is 9 characters)'
      end

      it "does not update the user's password when password is invalid" do
        fill_in 'New password', with: '1234'
        click_button t('forms.passwords.edit.buttons.submit')

        signin(@user.email, '1234')
        expect(current_path).to eq new_user_session_path
      end

      it 'allows multiple attempts with invalid password' do
        fill_in 'New password', with: '1234'
        click_button t('forms.passwords.edit.buttons.submit')

        expect(page).to have_content 'is too short'

        fill_in 'New password', with: '5678'
        click_button t('forms.passwords.edit.buttons.submit')

        expect(page).to have_content 'is too short'
      end
    end
  end

  scenario 'user takes too long to click the reset password link' do
    user = create(:user, :signed_up)

    visit new_user_password_path
    fill_in 'Email', with: user.email
    click_button t('forms.buttons.continue')

    user.reset_password_sent_at =
      Time.zone.now - Devise.reset_password_within - 1.hour

    raw_reset_token, db_confirmation_token =
      Devise.token_generator.generate(User, :reset_password_token)

    UpdateUser.new(user: user, attributes: { reset_password_token: db_confirmation_token }).call

    visit edit_user_password_path(reset_password_token: raw_reset_token)

    expect(page).to have_content t('devise.passwords.token_expired')

    expect(current_path).to eq new_user_password_path
  end

  context 'CSP whitelists recaptcha for style-src' do
    scenario 'recaptcha is disabled' do
      allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(false)

      visit new_user_password_path

      expect(page.response_headers['Content-Security-Policy']).
        to(include('style-src \'self\''))
    end

    scenario 'recaptcha is enabled' do
      allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(true)

      visit new_user_password_path

      expect(page.response_headers['Content-Security-Policy']).
        to(include('style-src \'self\' \'unsafe-inline\''))
    end
  end
end
