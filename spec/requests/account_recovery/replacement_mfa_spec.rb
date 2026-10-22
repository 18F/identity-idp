require 'rails_helper'

RSpec.describe 'Account recovery replacement enrollment', type: :request do
  let(:user) { create(:user, :fully_registered) }
  let(:token) { SecureRandom.uuid }
  let!(:recovery_request) do
    create(
      :account_recovery_request,
      :granted,
      user: user,
      token_fingerprint: AccountRecovery::TokenCreator.fingerprint(token),
    )
  end

  before do
    get account_recovery_verify_path, params: { token: token }
    post account_recovery_verify_path,
         params: { request_id: recovery_request.id, user: { password: user.password } }
  end

  it 'cannot access the account or verify existing MFA during recovery' do
    [account_path, login_two_factor_authenticator_path,
     login_two_factor_webauthn_path, login_two_factor_backup_code_path].each do |path|
      get path

      expect(response).to redirect_to(account_recovery_new_mfa_setup_url)
    end
    expect(recovery_request.reload).to be_replacement_mfa_pending
  end

  it 'keeps old MFA until the replacement codes are acknowledged' do
    post account_recovery_new_mfa_setup_path,
         params: { two_factor_options_form: { selection: ['backup_code'] } }
    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(recovery_request.reload).to be_replacement_mfa_pending
    expect(user.phone_configurations).not_to be_empty

    patch backup_code_continue_path,
          params: { backup_code_accepted_form: { backup_code_notice_accepted: '0' } }
    expect(recovery_request.reload).to be_replacement_mfa_pending

    patch backup_code_continue_path,
          params: { backup_code_accepted_form: { backup_code_notice_accepted: '1' } }

    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::COMPLETED)
    expect(user.reload.phone_configurations).to be_empty
    expect(user.backup_code_configurations.count).to eq(BackupCodeGenerator::NUMBER_OF_CODES)
    get account_path
    expect(response).to have_http_status(:ok)
  end

  it 'verifies a new authenticator before deleting old MFA and granting access' do
    post account_recovery_new_mfa_setup_path,
         params: { two_factor_options_form: { selection: ['auth_app'] } }
    follow_redirect!
    secret = Capybara.string(response.body).find('#qr-code').text.strip

    patch authenticator_setup_path, params: { name: 'Replacement app', code: 'invalid' }
    expect(recovery_request.reload).to be_replacement_mfa_pending
    expect(user.phone_configurations).not_to be_empty

    code = ROTP::TOTP.new(secret, interval: IdentityConfig.store.totp_code_interval).now
    patch authenticator_setup_path, params: { name: 'Replacement app', code: code }

    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::COMPLETED)
    expect(user.reload.phone_configurations).to be_empty
    expect(user.auth_app_configurations.available_for_authentication.count).to eq(1)
    get account_path
    expect(response).to have_http_status(:ok)
  end
end
