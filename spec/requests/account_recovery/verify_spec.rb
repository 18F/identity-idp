require 'rails_helper'

RSpec.describe 'Account recovery password verification', type: :request do
  let(:password) { ControllerHelper::VALID_PASSWORD }
  let(:user) { create(:user, :fully_registered, password: password) }
  let(:token) { SecureRandom.uuid }
  let!(:recovery_request) do
    create(
      :account_recovery_request,
      :granted,
      user: user,
      token_fingerprint: AccountRecovery::TokenCreator.fingerprint(token),
    )
  end

  def password_form
    Capybara.string(response.body)
  end

  it 'carries the token through password retry and creates only a partial session' do
    get account_recovery_verify_path, params: { token: token }

    expect(response).to have_http_status(:ok)
    expect(password_form).to have_css('input[type="password"]')
    submitted_token = password_form.find('input[name="token"]', visible: false).value
    expect(submitted_token).to eq(token)

    post account_recovery_verify_path,
         params: { token: submitted_token, user: { password: 'wrong password' } }

    expect(response).to have_http_status(:ok)
    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
    expect(password_form).to have_content(t('errors.confirm_password_incorrect'))
    submitted_token = password_form.find('input[name="token"]', visible: false).value

    post account_recovery_verify_path,
         params: { token: submitted_token, user: { password: password } }

    expect(response).to redirect_to(account_recovery_verify_url)
    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::PASSWORD_VERIFIED)
    expect(recovery_request.token_fingerprint).to be_nil

    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(password_form).to have_content(t('account_recovery.pending_mfa_setup.intro'))

    get account_path

    expect(response).to redirect_to(user_two_factor_authentication_url)
  end

  it 'does not allow the previous pending page to cancel after token verification' do
    get account_recovery_verify_path, params: { token: token }

    post account_recovery_pending_cancel_path

    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
  end

  it 'does not allow a token-free password submission after opening the link' do
    get account_recovery_verify_path, params: { token: token }

    post account_recovery_verify_path, params: { user: { password: password } }

    expect(response).to redirect_to(root_url)
    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
    expect(recovery_request.password_verified_at).to be_nil
  end
end
