require 'rails_helper'

RSpec.feature 'SAML Authorization Confirmation' do
  include SamlAuthHelper

  before do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(9999)
  end

  context 'authenticated user signs in to new sp' do
    def create_user_and_remember_device
      user = user_with_2fa

      sign_in_user(user)
      check t('forms.messages.remember_device')
      fill_in_code_with_last_phone_otp
      click_submit_default
      visit request_url
      click_agree_and_continue
      click_submit_default
      visit sign_out_url

      user
    end

    let(:user1) { create_user_and_remember_device }
    let(:user2) { create_user_and_remember_device }
    let(:request_url) { saml_authn_request_url }

    before do
      # Cycle user2 first so user1's remember device will stick
      user2
      user1
    end

    context 'when the user is already signed in with an email different from the one shared' do
      context 'when email sharing feature is enabled' do
        before do
          allow(IdentityConfig.store)
            .to receive(:feature_select_email_to_share_enabled).and_return(true)
        end

        it 'confirms the user wants to continue to SP with the shared email' do
          shared_email = user1.identities.first.email_address.email
          second_email = create(:email_address, user: user1)
          sign_in_user(user1, second_email.email)

          visit request_url
          expect(current_url).to match(user_authorization_confirmation_path)
          expect(page).to have_content shared_email

          continue_as(shared_email)
          expect(current_url).to eq(complete_saml_url)
        end

        context 'with requested attributes contains only email' do
          it ' creates an identity with proper email_address_id' do
            user = user_with_2fa

            sign_in_user(user)
            check t('forms.messages.remember_device')
            fill_in_code_with_last_phone_otp
            click_submit_default
            visit request_url
            click_agree_and_continue
            identity = user.identities.find_by(service_provider: SamlAuthHelper::SP_ISSUER)
            email_id = user.email_addresses.first.id
            expect(identity.email_address_id).to eq(email_id)
          end
        end

        context 'with requested attributes contains is emails and all_emails' do
          it 'creates an identity with no email_address_id saved' do
            user = user_with_2fa

            oidc_path = openid_connect_authorize_path params
            visit oidc_path
            fill_in_credentials_and_submit(user.email, user.password)
            click_submit_default
            check t('forms.messages.remember_device')
            fill_in_code_with_last_phone_otp
            click_submit_default
            click_agree_and_continue
            identity = user.identities.find_by(service_provider: SamlAuthHelper::SP_ISSUER)
            expect(identity.email_address_id).to eq(nil)
          end
        end
      end

      context 'when email sharing feature is disabled' do
        before do
          allow(IdentityConfig.store)
            .to receive(:feature_select_email_to_share_enabled).and_return(false)
        end

        it 'confirms the user wants to continue to SP with the signed in email' do
          second_email = create(:email_address, user: user1)
          sign_in_user(user1, second_email.email)

          visit request_url
          expect(current_url).to match(user_authorization_confirmation_path)
          expect(page).to have_content second_email.email

          continue_as(second_email.email)
          expect(current_url).to eq(complete_saml_url)
        end
      end
    end

    it 'allows the user to switch accounts prior to continuing to the SP' do
      sign_in_user(user1)

      visit request_url
      expect(current_url).to match(user_authorization_confirmation_path)
      continue_as(user2.email, user2.password)

      # Can't remember both users' devices?
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_url).to eq(complete_saml_url)
    end

    it 'does not render an error if a user goes back after opting to switch accounts' do
      sign_in_user(user1)
      visit request_url

      expect(page).to have_current_path(user_authorization_confirmation_path)

      click_button t('user_authorization_confirmation.sign_in')
      # Simulate clicking the back button by going right back to the original path
      visit user_authorization_confirmation_path

      expect(page).to have_current_path(new_user_session_path)
    end

    it 'does not render the confirmation screen on a return visit to the SP by default' do
      second_email = create(:email_address, user: user1)
      sign_in_user(user1, second_email.email)

      # first visit
      visit request_url
      continue_as(second_email.email)

      # second visit
      visit request_url
      expect(current_url).to eq(request_url)
    end

    it 'redirects to the account page with no sp in session' do
      sign_in_user(user1)
      visit user_authorization_confirmation_path

      expect(page).to have_current_path(account_path)
    end
  end

  context 'first time registration' do
    let(:request_url) { saml_authn_request_url }

    it 'redirects user to sp and does not go through authorization_confirmation page' do
      email = 'test@test.com'

      perform_in_browser(:one) do
        visit request_url
        sign_up_user_from_sp_without_confirming_email(email)
      end

      perform_in_browser(:two) do
        confirm_email_in_a_different_browser(email)
        expect(page).to have_current_path sign_up_completed_path
        expect(page).to have_content t('help_text.requested_attributes.email')
        expect(page).to have_content email

        click_agree_and_continue

        expect(current_url).to eq complete_saml_url
        expect(page.get_rack_session.keys).to include('sp')
      end
    end
  end
end
