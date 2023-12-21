require 'rails_helper'

RSpec.describe 'totp management' do
  context 'when the user has totp enabled' do
    let(:user) { create(:user, :fully_registered, :with_authentication_app) }

    it 'allows the user to disable their totp app' do
      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_content(t('two_factor_authentication.login_options.auth_app'))
      expect(page.find('.remove-auth-app')).to_not be_nil
      page.find('.remove-auth-app').click

      expect(current_path).to eq auth_app_delete_path
      click_on t('account.index.totp_confirm_delete')

      expect(current_path).to eq account_two_factor_authentication_path
    end
  end

  context 'when totp is the only mfa method' do
    let(:user) { create(:user, :with_authentication_app, :with_phone) }

    it 'does not show the user the option to disable their totp app' do
      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_content(
        t('two_factor_authentication.login_options.auth_app'),
      )
      form = find_form(page, action: disable_totp_url)
      expect(form).to be_nil
    end
  end

  context 'when the user has totp disabled' do
    let(:user) { create(:user, :fully_registered) }

    it 'allows the user to setup a totp app' do
      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      click_link t('account.index.auth_app_add'), href: authenticator_setup_url

      expect(
        [
          page.find('[aria-labelledby="totp-step-1-label"]'),
          page.find('[aria-labelledby="totp-step-4-label"]'),
        ],
      ).to be_logically_grouped(t('forms.totp_setup.totp_intro'))

      secret = find('#qr-code').text
      fill_in 'name', with: 'foo'
      fill_in 'code', with: generate_totp_code(secret)
      click_button 'Submit'

      expect(user.auth_app_configurations).to be_empty
      expect(user.events.order(created_at: :desc).last.event_type).to eq('authenticator_enabled')
    end

    it 'prevents association of an auth app with the same name' do
      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      click_link t('account.index.auth_app_add'), href: authenticator_setup_url

      secret = find('#qr-code').text
      fill_in 'name', with: 'foo'
      fill_in 'code', with: generate_totp_code(secret)
      click_button 'Submit'

      click_link t('account.index.auth_app_add'), href: authenticator_setup_url

      secret = find('#qr-code').text
      fill_in 'name', with: 'foo'
      fill_in 'code', with: generate_totp_code(secret)
      click_button 'Submit'

      expect(page).to have_current_path(authenticator_setup_path)
      expect(page).to have_content(I18n.t('errors.piv_cac_setup.unique_name'))
    end

    it 'allows 2 auth apps and removes the add link' do
      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      click_link t('account.index.auth_app_add'), href: authenticator_setup_url

      secret = find('#qr-code').text
      fill_in 'name', with: 'foo'
      fill_in 'code', with: generate_totp_code(secret)
      click_button 'Submit'

      # simulate user delay. totp has a 30 second time step
      travel_to(30.seconds.from_now) do
        click_link t('account.index.auth_app_add'), href: authenticator_setup_url

        secret = find('#qr-code').text
        fill_in 'name', with: 'bar'
        fill_in 'code', with: generate_totp_code(secret)
        click_button 'Submit'

        expect(page).to have_current_path(account_two_factor_authentication_path)
        expect(user.auth_app_configurations.count).to eq(2)
        expect(page).
          to_not have_link(t('account.index.auth_app_add'), href: authenticator_setup_url)
      end
    end
  end

  def find_form(page, attributes)
    page.all('form').detect do |form|
      attributes.all? { |key, value| form[key] == value }
    end
  end
end
