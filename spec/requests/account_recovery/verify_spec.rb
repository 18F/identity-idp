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

  def csrf_token
    password_form.find(
      "form[action=\"#{account_recovery_verify_path}\"] input[name=\"authenticity_token\"]",
      visible: false,
    ).value
  end

  it 'keeps the token out of the password page and creates only a partial session' do
    get account_recovery_verify_path, params: { token: token }

    expect(response).to redirect_to(account_recovery_verify_url)
    expect(response.location).not_to include(token)

    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(password_form).to have_css('input[type="password"]')
    expect(password_form).not_to have_css('input[name="token"]', visible: false)
    expect(response.body).not_to include(token)
    request_id = password_form.find('input[name="request_id"]', visible: false).value

    post account_recovery_verify_path,
         params: { request_id: request_id, user: { password: 'wrong password' } }

    expect(response).to have_http_status(:ok)
    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
    expect(password_form).to have_content(t('errors.confirm_password_incorrect'))
    expect(response.body).not_to include(token)

    post account_recovery_verify_path,
         params: { request_id: request_id, user: { password: password } }

    expect(response).to redirect_to(account_recovery_new_mfa_setup_url)
    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::PASSWORD_VERIFIED)
    expect(recovery_request.token_fingerprint).to be_nil

    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(password_form).to have_content(t('account_recovery.new_mfa_setup.intro'))

    get account_path

    expect(response).to redirect_to(user_two_factor_authentication_url)
  end

  it 'does not reach MFA setup from a verified link without the password' do
    get account_recovery_verify_path, params: { token: token }

    get account_recovery_new_mfa_setup_path

    expect(response).to have_http_status(:not_found)
    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
  end

  it 'does not accept a posted token without the session handoff' do
    post account_recovery_verify_path,
         params: { token: token, request_id: recovery_request.id, user: { password: password } }

    expect(response).to redirect_to(root_url)
    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
    expect(recovery_request.password_verified_at).to be_nil
  end

  it 'requires reopening the link after the browser session is lost' do
    get account_recovery_verify_path, params: { token: token }
    reset!

    get account_recovery_verify_path

    expect(response).to have_http_status(:not_found)

    get account_recovery_verify_path, params: { token: token }
    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(password_form).to have_css('input[type="password"]')
  end

  it 'clears the pending recovery token when a signed-in user logs out' do
    get account_recovery_verify_path, params: { token: token }
    post new_user_session_path, params: { user: { email: user.email, password: password } }

    expect(controller.current_user).to eq(user)

    delete '/logout'
    get account_recovery_verify_path

    expect(response).to have_http_status(:not_found)
    expect(recovery_request.reload.password_verified_at).to be_nil
  end

  context 'with CSRF protection enabled' do
    around do |example|
      original_protection = ActionController::Base.allow_forgery_protection
      original_origin_check = ActionController::Base.forgery_protection_origin_check
      ActionController::Base.allow_forgery_protection = true
      ActionController::Base.forgery_protection_origin_check = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = original_protection
      ActionController::Base.forgery_protection_origin_check = original_origin_check
    end

    it 'accepts same-origin password retries using the clean form and its CSRF token' do
      get account_recovery_verify_path, params: { token: token }
      follow_redirect!
      origin = request.base_url
      authenticity_token = csrf_token

      post account_recovery_verify_path,
           params: {
             request_id: recovery_request.id,
             authenticity_token: authenticity_token,
             user: { password: 'wrong password' },
           },
           headers: { 'Origin' => origin }

      expect(response).to have_http_status(:ok)
      expect(password_form).to have_content(t('errors.confirm_password_incorrect'))
      authenticity_token = csrf_token

      post account_recovery_verify_path,
           params: {
             request_id: recovery_request.id,
             authenticity_token: authenticity_token,
             user: { password: password },
           },
           headers: { 'Origin' => origin }

      expect(response).to redirect_to(account_recovery_new_mfa_setup_url)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::PASSWORD_VERIFIED)
    end

    it 'rejects a cross-origin password submission even with the form CSRF token' do
      get account_recovery_verify_path, params: { token: token }
      follow_redirect!
      authenticity_token = csrf_token

      post account_recovery_verify_path,
           params: {
             request_id: recovery_request.id,
             authenticity_token: authenticity_token,
             user: { password: password },
           },
           headers: { 'Origin' => 'https://other.example.com' }

      expect(recovery_request.reload.password_verified_at).to be_nil
      expect(response).to redirect_to(root_url)
    end
  end
end
