require 'rails_helper'
feature 'Webauthn Management' do
  include WebauthnHelper

  let(:user) { create(:user, :signed_up, with: { phone: '+1 202-555-1212' }) }

  context 'with no webauthn associated yet' do
    it 'allows user to add a webauthn configuration' do
      mock_challenge
      sign_in_and_2fa_user(user)
      visit account_path
      expect(current_path).to eq account_path

      click_link t('account.index.webauthn_add'), href: webauthn_setup_path
      expect(current_path).to eq webauthn_setup_path

      fill_in_nickname_and_click_continue
      mock_press_button_on_hardware_key

      expect(current_path).to eq webauthn_setup_success_path

      click_button t('forms.buttons.continue')

      expect(page).to have_current_path(account_path)
      expect(page).to have_content t('event_types.webauthn_key_added')
    end

    it 'gives an error if the challenge/secret is incorrect' do
      sign_in_and_2fa_user(user)
      visit account_path
      expect(current_path).to eq account_path

      click_link t('account.index.webauthn_add'), href: webauthn_setup_path
      expect(current_path).to eq webauthn_setup_path

      fill_in_nickname_and_click_continue
      mock_press_button_on_hardware_key

      expect(current_path).to eq account_path
      expect(page).to have_content t('errors.webauthn_setup.general_error')
    end

    it 'gives an error if the hardware key button has not been pressed' do
      mock_challenge
      sign_in_and_2fa_user(user)
      visit account_path
      expect(current_path).to eq account_path

      click_link t('account.index.webauthn_add'), href: webauthn_setup_path
      expect(current_path).to eq webauthn_setup_path

      mock_submit_without_pressing_button_on_hardware_key

      expect(current_path).to eq account_path
      expect(page).to have_content t('errors.webauthn_setup.general_error')
    end

    it 'gives an error if name is taken and stays on the configuration screen' do
      mock_challenge
      sign_in_and_2fa_user(user)

      visit account_path
      expect(current_path).to eq account_path

      click_link t('account.index.webauthn_add'), href: webauthn_setup_path
      expect(current_path).to eq webauthn_setup_path

      fill_in_nickname_and_click_continue
      mock_press_button_on_hardware_key

      expect(current_path).to eq webauthn_setup_success_path
      click_button t('forms.buttons.continue')

      click_link t('account.index.webauthn_add'), href: webauthn_setup_path
      expect(current_path).to eq webauthn_setup_path

      fill_in_nickname_and_click_continue
      mock_press_button_on_hardware_key

      expect(current_path).to eq webauthn_setup_path
      expect(page).to have_content t('errors.webauthn_setup.unique_name')
    end

    it 'displays a link to add a hardware security key' do
      sign_in_and_2fa_user(user)

      visit account_path
      expect(page).to have_link(t('account.index.webauthn_add'), href: webauthn_setup_path)
    end
  end

  context 'with webauthn associations' do
    it 'displays the user supplied names of the webauthn keys' do
      create_webauthn_configuration(user, 'key1', '1', 'foo1')
      create_webauthn_configuration(user, 'key2', '2', 'bar2')

      sign_in_and_2fa_user(user)
      visit account_path

      expect(page).to have_content 'key1'
      expect(page).to have_content 'key2'
    end

    it 'allows the user to delete the webauthn key' do
      create_webauthn_configuration(user, 'key1', '1', 'foo1')

      sign_in_and_2fa_user(user)
      visit account_path

      expect(page).to have_content 'key1'

      click_link t('account.index.webauthn_delete')

      expect(current_path).to eq webauthn_setup_delete_path

      click_button t('account.index.webauthn_delete')

      expect(page).to_not have_content 'key1'
      expect(page).to have_content t('notices.webauthn_deleted')
    end

    it 'allows the user to cancel delete the webauthn key' do
      create_webauthn_configuration(user, 'key1', '1', 'foo1')

      sign_in_and_2fa_user(user)
      visit account_path

      expect(page).to have_content 'key1'

      click_link t('account.index.webauthn_delete')

      expect(current_path).to eq webauthn_setup_delete_path

      click_link t('links.cancel')

      expect(page).to have_content 'key1'
    end

    it 'prevents a user from deleting the last key' do
      create_webauthn_configuration(user, 'key1', '1', 'foo1')

      sign_in_and_2fa_user(user)
      PhoneConfiguration.first.update(mfa_enabled: false)
      visit account_path

      expect(page).to have_content 'key1'
      expect(page).to_not have_link t('account.index.webauthn_delete')
    end
  end

  def create_webauthn_configuration(user, name, id, key)
    WebauthnConfiguration.create(user_id: user.id,
                                 credential_public_key: key,
                                 credential_id: id,
                                 name: name)
  end
end
