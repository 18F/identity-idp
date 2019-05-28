require 'rails_helper'

describe 'totp management' do
  context 'when the user has totp enabled' do
    let(:user) { create(:user, :signed_up, :with_authentication_app) }

    it 'allows the user to disable their totp app' do
      sign_in_and_2fa_user(user)

      expect(page).to have_content(t('account.index.authentication_app'))
      form = find_form(page, action: disable_totp_url)
      expect(form).to_not be_nil

      form.click_button(t('forms.buttons.disable'))

      expect(page).to have_current_path(account_path)
      expect(user.reload.otp_secret_key).to be_nil
    end
  end

  context 'when totp is the only mfa method' do
    let(:user) { create(:user, :with_authentication_app, :with_phone) }

    it 'does not show the user the option to disable their totp app' do
      sign_in_and_2fa_user(user)

      expect(page).to have_content(t('account.index.authentication_app'))
      form = find_form(page, action: disable_totp_url)
      expect(form).to be_nil
    end
  end

  context 'when the user has totp disabled' do
    let(:user) { create(:user, :signed_up) }

    it 'allows the user to setup a totp app' do
      sign_in_and_2fa_user(user)

      click_link t('forms.buttons.enable'), href: authenticator_setup_url

      secret = find('#qr-code').text
      fill_in 'code', with: generate_totp_code(secret)
      click_button 'Submit'

      expect(user.reload.otp_secret_key).to_not be_nil
      expect(user.events.order(created_at: :desc).last.event_type).to eq('authenticator_enabled')
    end
  end

  # :reek:NestedIterators
  def find_form(page, attributes)
    page.all('form').detect do |form|
      attributes.all? { |key, value| form[key] == value }
    end
  end
end
