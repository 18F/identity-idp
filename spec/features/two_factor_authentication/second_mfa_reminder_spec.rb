require 'rails_helper'

RSpec.feature 'Second MFA Reminder' do
  include OidcAuthHelper

  let(:service_provider) { ServiceProvider.find_by(issuer: OidcAuthHelper::OIDC_IAL1_ISSUER) }
  let(:user) { create(:user, :fully_registered, :with_phone) }

  before do
    allow(IdentityConfig.store).to receive(:second_mfa_reminder_sign_in_count).and_return(2)
    allow(IdentityConfig.store).to receive(:second_mfa_reminder_account_age_in_days).and_return(5)
    IdentityLinker.new(user, service_provider).link_identity(verified_attributes: %w[openid email])
  end

  context 'user with single mfa' do
    it 'does not prompt the user on sign in' do
      sign_in_user(user)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path(account_path)
    end

    context 'after sign in count threshold' do
      before do
        sign_in_user(user)
        fill_in_code_with_last_phone_otp
        click_submit_default
        first(:button, t('links.sign_out')).click
      end

      it 'prompts the user on sign in and allows them to continue', :js do
        # This spec includes regression coverage for a scenario where the user would be redirected
        # immediately to the partner, requiring CSP header overrides that are not enforced if not
        # using the JavaScript driver.

        visit_idp_from_ial1_oidc_sp
        sign_in_user(user)

        expect(page).to have_current_path(second_mfa_reminder_path)

        click_on t('users.second_mfa_reminder.continue', sp_name: service_provider.friendly_name)

        expect(current_url).to start_with(service_provider.redirect_uris.first)
      end
    end

    context 'after age threshold' do
      before { travel 6.days }

      it 'prompts the user on sign in and allows them to add an authentication method' do
        sign_in_user(user)
        fill_in_code_with_last_phone_otp
        click_submit_default

        click_on t('users.second_mfa_reminder.add_method')

        expect(page).to have_current_path(authentication_methods_setup_url)
      end
    end

    context 'user already acknowledged reminder' do
      before do
        travel 6.days
        sign_in_user(user)
        fill_in_code_with_last_phone_otp
        click_submit_default
        click_button t('users.second_mfa_reminder.continue', sp_name: APP_NAME)
        first(:button, t('links.sign_out')).click
      end

      it 'does not prompt the user on sign in' do
        sign_in_user(user)

        expect(page).to have_current_path(account_path)
      end
    end
  end

  context 'user with multiple mfas who would otherwise be candidate' do
    let(:user) { create(:user, :fully_registered, :with_phone, :with_authentication_app) }

    before do
      travel 6.days
    end

    it 'does not prompt the user on sign in' do
      sign_in_user(user)
      fill_in_code_with_last_totp(user)
      click_submit_default

      expect(page).to have_current_path(account_path)
    end
  end
end
