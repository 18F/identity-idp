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

      click_link t('account.index.webauthn_add'), href: webauthn_setup_url
      expect(current_path).to eq webauthn_setup_path

      mock_press_button_on_hardware_key
      click_submit_default

      expect(current_path).to eq account_path
      expect(page).to have_content t('notices.webauthn_added')
    end

    it 'gives an error if the challenge/secret is incorrect' do
      sign_in_and_2fa_user(user)
      visit account_path
      expect(current_path).to eq account_path

      click_link t('account.index.webauthn_add'), href: webauthn_setup_url
      expect(current_path).to eq webauthn_setup_path

      mock_press_button_on_hardware_key
      click_submit_default

      expect(current_path).to eq account_path
      expect(page).to have_content t('errors.webauthn_setup.general_error')
    end

    it 'gives an error if the hardware key button has not been pressed' do
      mock_challenge
      sign_in_and_2fa_user(user)
      visit account_path
      expect(current_path).to eq account_path

      click_link t('account.index.webauthn_add'), href: webauthn_setup_url
      expect(current_path).to eq webauthn_setup_path

      click_submit_default

      expect(current_path).to eq account_path
      expect(page).to have_content t('errors.webauthn_setup.general_error')
    end

    it 'gives an error if name is taken and stays on the configuration screen' do
      mock_challenge
      sign_in_and_2fa_user(user)

      visit account_path
      expect(current_path).to eq account_path

      click_link t('account.index.webauthn_add'), href: webauthn_setup_url
      expect(current_path).to eq webauthn_setup_path

      mock_press_button_on_hardware_key
      click_submit_default

      expect(current_path).to eq account_path
      expect(page).to have_content t('notices.webauthn_added')

      click_link t('account.index.webauthn_add'), href: webauthn_setup_url
      expect(current_path).to eq webauthn_setup_path

      mock_press_button_on_hardware_key
      click_submit_default

      expect(current_path).to eq webauthn_setup_path
      expect(page).to have_content t('errors.webauthn_setup.unique_name')
    end

    it 'displays a link to add a hardware security key' do
      sign_in_and_2fa_user(user)

      visit account_path
      expect(page).to have_link(t('account.index.webauthn_add'), href: webauthn_setup_url)
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

      click_button t('account.index.webauthn_delete')

      expect(page).to_not have_content 'key1'
      expect(page).to have_content t('notices.webauthn_deleted')
    end

    it 'prevents a user from deleting the last key' do
      create_webauthn_configuration(user, 'key1', '1', 'foo1')

      sign_in_and_2fa_user(user)
      PhoneConfiguration.first.update(mfa_enabled: false)
      visit account_path

      expect(page).to have_content 'key1'

      click_button t('account.index.webauthn_delete')

      expect(page).to have_content 'key1'
      expect(page).to have_content t('errors.webauthn_setup.delete_last')
    end
  end

  def mock_challenge
    allow(WebAuthn).to receive(:credential_creation_options).and_return(
      challenge: challenge.pack('c*')
    )
  end

  def mock_press_button_on_hardware_key
    # this is required because the domain is embedded in the supplied attestation object
    allow(WebauthnSetupForm).to receive(:domain_name).and_return('localhost:3000')

    set_hidden_field('attestation_object', attestation_object)
    set_hidden_field('client_data_json', client_data_json)
    set_hidden_field('name', 'mykey')
  end

  def set_hidden_field(id, value)
    first("input##{id}", visible: false).set(value)
  end

  def create_webauthn_configuration(user, name, id, key)
    WebauthnConfiguration.create(user_id: user.id,
                                 credential_public_key: key,
                                 credential_id: id,
                                 name: name)
  end
end
