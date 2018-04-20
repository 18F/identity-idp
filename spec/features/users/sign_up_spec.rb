require 'rails_helper'

feature 'Sign Up' do
  include SamlAuthHelper

  context 'confirmation token error message does not persist on success' do
    scenario 'with no or invalid token' do
      visit sign_up_create_email_confirmation_url(confirmation_token: '')
      expect(page).to have_content t('errors.messages.confirmation_invalid_token')

      sign_up

      expect(page).not_to have_content t('errors.messages.confirmation_invalid_token')
    end
  end

  context 'user cancels sign up on email screen' do
    before do
      visit sign_up_email_path
      click_on t('links.cancel')
    end

    it 'redirects user to the home page' do
      expect(current_path).to eq root_path
    end
  end

  context 'user cancels on the enter password screen', email: true do
    it 'returns them to the home page' do
      email = 'test@test.com'

      visit sign_up_email_path

      submit_form_with_valid_email(email)
      click_confirmation_link_in_email(email)

      click_on t('links.cancel_account_creation')

      expect(current_path).to eq root_path
    end
  end

  context 'user cancels with language preference set' do
    it 'redirects user to the translated home page' do
      visit sign_up_email_path(locale: 'es')
      click_on t('links.cancel')
      expect(current_path).to eq '/es'
    end
  end

  scenario 'renders an error when twilio api responds with an error' do
    twilio_error = Twilio::REST::RestError.new(
      '', FakeTwilioErrorResponse.new(TwilioService::SMS_ERROR_CODE)
    )

    allow(SmsOtpSenderJob).to receive(:perform_now).and_raise(twilio_error)
    sign_up_and_set_password
    fill_in 'Phone', with: '202-555-1212'
    click_send_security_code

    expect(current_path).to eq(phone_setup_path)
    expect(page).to have_content(unsupported_sms_message)
  end

  context 'with js', js: true do
    context 'sp loa1' do
      it 'allows the user to toggle the modal' do
        begin_sign_up_with_sp_and_loa(loa3: false)
        expect(page).not_to have_xpath("//div[@id='cancel-action-modal']")

        click_on t('links.cancel')
        expect(page).to have_xpath("//div[@id='cancel-action-modal']")

        click_on t('sign_up.buttons.continue')
        expect(page).not_to have_xpath("//div[@id='cancel-action-modal']")
      end

      it 'allows the user to delete their account and returns them to the branded start page' do
        user = begin_sign_up_with_sp_and_loa(loa3: false)

        click_on t('links.cancel')
        click_on t('sign_up.buttons.cancel')

        expect(page).to have_current_path(sign_up_start_path)
        expect { User.find(user.id) }.to raise_error ActiveRecord::RecordNotFound
      end
    end

    context 'sp loa3' do
      it 'behaves like loa1 when user has not finished sign up' do
        begin_sign_up_with_sp_and_loa(loa3: true)

        click_on t('links.cancel')

        expect(page).to have_xpath("//input[@value=\"#{t('sign_up.buttons.cancel')}\"]")
      end
    end

    context 'user enters their email as their password', email: true do
      it 'treats it as a weak password' do
        email = 'test@test.com'

        visit sign_up_email_path
        submit_form_with_valid_email(email)
        click_confirmation_link_in_email(email)

        fill_in 'Password', with: email
        expect(page).to have_content('Very weak')
      end
    end
  end

  context 'user accesses password screen with already confirmed token', email: true do
    it 'returns them to the home page' do
      create(:user, :signed_up, confirmation_token: 'foo')

      visit sign_up_enter_password_path(confirmation_token: 'foo', request_id: 'bar')

      expect(page).to have_current_path(root_path)

      action = t('devise.confirmations.sign_in')
      expect(page).
        to have_content t('devise.confirmations.already_confirmed', action: action)
    end
  end

  context 'user accesses password screen with invalid token', email: true do
    it 'returns them to the resend email confirmation page' do
      visit sign_up_enter_password_path(confirmation_token: 'foo', request_id: 'bar')

      expect(page).to have_current_path(sign_up_email_resend_path)

      expect(page).
        to have_content t('errors.messages.confirmation_invalid_token')
    end
  end

  context "user A is signed in and accesses password creation page with User B's token" do
    it "redirects to User A's account page" do
      create(:user, :signed_up, email: 'userb@test.com', confirmation_token: 'foo')
      sign_in_and_2fa_user
      visit sign_up_enter_password_path(confirmation_token: 'foo')

      expect(page).to have_current_path(account_path)
      expect(page).to_not have_content 'userb@test.com'
    end
  end

  it_behaves_like 'csrf error when acknowledging personal key', :saml
  it_behaves_like 'csrf error when acknowledging personal key', :oidc
  it_behaves_like 'creating an account with the site in Spanish', :saml
  it_behaves_like 'creating an account with the site in Spanish', :oidc

  it_behaves_like 'creating an account using authenticator app for 2FA', :saml
  it_behaves_like 'creating an account using authenticator app for 2FA', :oidc

  it 'allows a user to choose TOTP as 2FA method during sign up' do
    user = create(:user)
    sign_in_user(user)
    set_up_2fa_with_authenticator_app
    click_acknowledge_personal_key

    expect(page).to have_current_path account_path
  end

  it 'does not bypass 2FA when accessing authenticator_setup_path if the user is 2FA enabled' do
    user = create(:user, :signed_up)
    sign_in_user(user)
    visit authenticator_setup_path

    expect(page).to have_current_path login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false)
  end

  it 'prompts to sign in when accessing authenticator_setup_path before signing in' do
    user = create(:user, :signed_up)
    visit authenticator_setup_path

    expect(page).to have_current_path root_path
  end
end
