require 'rails_helper'

shared_examples 'preventing backup mfa bypass' do
  include WebAuthnHelper

  it 'does not allow the user to bypass backup mfa setup' do
    sign_in_user(user)

    # MFA should be required before allowing the user to setup backup MFA
    expect(page).to have_current_path(mfa_path_for_user(user))
    visit account_path
    expect(page).to have_current_path(mfa_path_for_user(user))
    visit phone_setup_path
    expect(page).to have_current_path(mfa_path_for_user(user))
    visit authenticator_setup_path
    expect(page).to have_current_path(mfa_path_for_user(user))
    visit webauthn_setup_path
    expect(page).to have_current_path(mfa_path_for_user(user))
    visit setup_piv_cac_path
    expect(page).to have_current_path(mfa_path_for_user(user))
    visit backup_code_setup_path
    expect(page).to have_current_path(mfa_path_for_user(user))

    complete_mfa
    click_continue

    # MFA should be required before advancing to account or verificaiton
    expect(current_path).to eq(two_factor_options_path)
    visit account_path
    expect(current_path).to eq(two_factor_options_path)
    visit idv_path
    expect(current_path).to eq(two_factor_options_path)

    set_up_2fa_with_valid_phone

    expect(current_path).to eq(account_path)
  end

  def mfa_path_for_user(user)
    user.reload
    if TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
      login_two_factor_piv_cac_path
    elsif TwoFactorAuthentication::WebauthnPolicy.new(user).enabled?
      login_two_factor_webauthn_path
    elsif TwoFactorAuthentication::AuthAppPolicy.new(user).enabled?
      login_two_factor_authenticator_path
    elsif TwoFactorAuthentication::PhonePolicy.new(user).enabled?
      login_two_factor_path(otp_delivery_preference: :sms, reauthn: false)
    elsif TwoFactorAuthentication::BackupCodePolicy.new(user).configured?
      login_two_factor_backup_code_path
    end
  end
end

describe 'attempting to bypass backup mfa setup' do
  before do
    allow(Figaro.env).to receive(:otp_delivery_blocklist_maxretry).and_return('9999')
  end

  context 'with a phone' do
    let(:user) do
      create(:user, :with_phone, with: { phone: '+1 (225) 555-1111' })
    end

    def complete_mfa
      fill_in_code_with_last_phone_otp
      click_submit_default
    end

    it_behaves_like 'preventing backup mfa bypass'
  end

  context 'with an auth app' do
    let(:user) { create(:user, :with_authentication_app) }

    def complete_mfa
      fill_in 'code', with: generate_totp_code(user.otp_secret_key)
      click_submit_default
    end

    it_behaves_like 'preventing backup mfa bypass'
  end

  context 'with a webauthn key' do
    let(:user) { create(:user) }

    before do
      create(
        :webauthn_configuration,
        user: user,
        credential_id: credential_id,
        credential_public_key: credential_public_key,
      )
      allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
      mock_webauthn_verification_challenge
    end

    def complete_mfa
      mock_press_button_on_hardware_key_on_verification
      click_button t('forms.buttons.continue')
    end

    it_behaves_like 'preventing backup mfa bypass'
  end

  context 'with PIV/CAC' do
    let(:user) { create(:user, :with_piv_or_cac) }

    before do
      stub_piv_cac_service
    end

    def complete_mfa
      nonce = get_piv_cac_nonce_from_link(find_link(t('forms.piv_cac_mfa.submit')))
      visit_piv_cac_service(login_two_factor_piv_cac_path,
                            nonce: nonce,
                            uuid: user.x509_dn_uuid,
                            subject: 'SomeIgnoredSubject')
    end

    it_behaves_like 'preventing backup mfa bypass'
  end
end
