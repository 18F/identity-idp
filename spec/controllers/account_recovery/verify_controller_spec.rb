require 'rails_helper'

RSpec.describe AccountRecovery::VerifyController do
  let(:password) { ControllerHelper::VALID_PASSWORD }
  let(:user) { create(:user, :fully_registered, password: password) }
  let(:raw_token) { SecureRandom.uuid }
  let(:password_params) { { token: raw_token, user: { password: password } } }
  let!(:recovery_request) do
    create(
      :account_recovery_request,
      :granted,
      user: user,
      token_fingerprint: AccountRecovery::TokenCreator.fingerprint(raw_token),
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    allow(controller).to receive(:ab_test_bucket)
      .with(:NDS_LOOK_AND_FEEL, any_args).and_return(:default)
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end

  describe '#show with a token' do
    it 'verifies the link without consuming the token or creating a user session' do
      get :show, params: { token: raw_token }

      expect(response).to render_template(:show)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
      expect(recovery_request.link_verified_at).to be_present
      expect(recovery_request).to be_token_valid
      expect(controller.current_user).to be_nil
      expect(session[:account_recovery_request_id]).to be_nil
      expect(controller.view_assigns['token']).to eq(raw_token)
      expect(response.headers['Referrer-Policy']).to eq('no-referrer')
      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'logs the link validation without the raw token' do
      stub_analytics

      get :show, params: { token: raw_token }

      expect(@analytics).to have_logged_event(
        :account_recovery_link_validation,
        success: true,
        recovery_state: AccountRecoveryRequest::GRANTED,
        rate_limited: false,
      )
    end

    it 'rejects an invalid token without changing the request' do
      get :show, params: { token: SecureRandom.uuid }

      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
      expect(flash[:error]).to eq(t('account_recovery.verify.token_invalid'))
      expect(response).to redirect_to(root_url)
    end

    it 'rejects an expired token' do
      recovery_request.update!(token_expires_at: Time.zone.now - 1.minute)

      get :show, params: { token: raw_token }

      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
      expect(response).to redirect_to(root_url)
    end

    it 'allows reopening the link until password verification consumes it' do
      get :show, params: { token: raw_token }
      verified_at = recovery_request.reload.link_verified_at

      get :show, params: { token: raw_token }

      expect(response).to render_template(:show)
      expect(recovery_request.reload.link_verified_at).to eq(verified_at)
      expect(controller.current_user).to be_nil
    end

    it 'requires a fresh password even if the owner is already signed in' do
      sign_in_as_user(user)

      get :show, params: { token: raw_token }

      expect(controller.current_user).to be_nil
      expect(response).to render_template(:show)
    end

    it 'signs out another user before displaying the token owner’s password prompt' do
      sign_in_as_user(create(:user, :fully_registered))

      get :show, params: { token: raw_token }

      expect(controller.current_user).to be_nil
      expect(controller.view_assigns['email']).to eq(user.last_sign_in_email_address.email)
    end

    it 'rate limits token submissions' do
      RateLimiter.new(
        target: '0.0.0.0',
        rate_limit_type: :account_recovery_verify_token,
      ).increment_to_limited!

      get :show, params: { token: raw_token }

      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
      expect(flash[:error]).to eq(t('account_recovery.verify.token_rate_limited'))
    end
  end

  describe '#show without a token' do
    it 'does not use a previously stored ARR id as token evidence' do
      recovery_request.transition_to!(AccountRecoveryRequest::LINK_VERIFIED)
      session[:account_recovery_request_id] = recovery_request.id

      get :show

      expect(response).to render_template('pages/page_not_found')
      expect(controller.current_user).to be_nil
    end

    it 'does not accept normal sign-in as proof of token and password verification' do
      recovery_request.transition_to!(AccountRecoveryRequest::LINK_VERIFIED)
      stub_sign_in_before_2fa(user)

      get :show

      expect(response).to render_template('pages/page_not_found')
    end

    it 'does not resume another user’s password-verified request' do
      recovery_request.update!(state: AccountRecoveryRequest::PASSWORD_VERIFIED)
      stub_sign_in_before_2fa(create(:user, :fully_registered))

      get :show

      expect(response).to render_template('pages/page_not_found')
    end
  end

  describe '#create' do
    it 'consumes the token and creates only a partial session after both checks succeed' do
      post :create, params: password_params

      expect(controller.current_user).to eq(user)
      expect(controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq(true)
      expect(response).to redirect_to(account_recovery_verify_url)
      expect(response.location).not_to include(raw_token)
      expect(session[:account_recovery_request_id]).to be_nil
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::PASSWORD_VERIFIED)
      expect(recovery_request.link_verified_at).to be_present
      expect(recovery_request.password_verified_at).to be_present
      expect(recovery_request.token_fingerprint).to be_nil
      expect(recovery_request.token_expires_at).to be_nil
    end

    it 'does not change existing MFA methods' do
      expect { post :create, params: password_params }
        .not_to change { user.reload.phone_configurations.count }
    end

    it 'logs successful password verification' do
      stub_analytics

      post :create, params: password_params

      expect(@analytics).to have_logged_event(
        :account_recovery_password_verification,
        success: true,
        rate_limited: false,
      )
    end

    it 'retains the token for retry after an incorrect password without signing in' do
      stub_analytics
      post :create, params: { token: raw_token, user: { password: 'wrong password' } }

      expect(controller.current_user).to be_nil
      expect(flash[:error]).to eq(t('errors.confirm_password_incorrect'))
      expect(response).to render_template(:show)
      expect(controller.view_assigns['token']).to eq(raw_token)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
      expect(recovery_request).to be_token_valid
      expect(@analytics).to have_logged_event(
        :account_recovery_password_verification,
        success: false,
        rate_limited: false,
      )

      post :create, params: password_params

      expect(controller.current_user).to eq(user)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::PASSWORD_VERIFIED)
    end

    it 'requires the token again on password submission' do
      get :show, params: { token: raw_token }

      post :create, params: { user: { password: password } }

      expect(response).to redirect_to(root_url)
      expect(controller.current_user).to be_nil
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
    end

    it 'rejects a substituted token even with the correct password' do
      post :create, params: password_params.merge(token: SecureRandom.uuid)

      expect(response).to redirect_to(root_url)
      expect(controller.current_user).to be_nil
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
    end

    it 'requires the password of the token owner, not the previously signed-in user' do
      other_user = create(
        :user,
        :fully_registered,
        password: 'a different valid password',
      )
      sign_in_as_user(other_user)

      post :create, params: { token: raw_token, user: { password: other_user.password } }

      expect(controller.current_user).to be_nil
      expect(response).to render_template(:show)
      expect(recovery_request.reload.password_verified_at).to be_nil
    end

    it 'rejects a token that expires between displaying and submitting the form' do
      get :show, params: { token: raw_token }
      recovery_request.update!(token_expires_at: Time.zone.now)

      post :create, params: password_params

      expect(response).to redirect_to(root_url)
      expect(controller.current_user).to be_nil
      expect(recovery_request.reload.password_verified_at).to be_nil
    end

    it 'rejects a request invalidated after displaying the form' do
      get :show, params: { token: raw_token }
      recovery_request.reload.expire!

      post :create, params: password_params

      expect(response).to redirect_to(root_url)
      expect(controller.current_user).to be_nil
    end

    it 'rejects concurrent consumption during password verification' do
      allow_any_instance_of(User).to receive(:valid_password?) do
        AccountRecoveryRequest.find(recovery_request.id).transition_to!(
          AccountRecoveryRequest::PASSWORD_VERIFIED,
          token_fingerprint: nil,
          token_expires_at: nil,
        )
        true
      end

      post :create, params: password_params

      expect(response).to redirect_to(root_url)
      expect(controller.current_user).to be_nil
    end

    it 'rechecks token expiry after password verification' do
      allow_any_instance_of(User).to receive(:valid_password?) do
        recovery_request.update!(token_expires_at: Time.zone.now - 1.second)
        true
      end

      post :create, params: password_params

      expect(response).to redirect_to(root_url)
      expect(controller.current_user).to be_nil
      expect(recovery_request.reload.password_verified_at).to be_nil
    end

    it 'rejects replay after password verification' do
      post :create, params: password_params
      sign_out(user)

      post :create, params: password_params

      expect(response).to redirect_to(root_url)
      expect(controller.current_user).to be_nil
      expect(flash[:error]).to eq(t('account_recovery.verify.token_invalid'))
    end

    it 'rejects reopening the email link after consumption' do
      post :create, params: password_params
      sign_out(user)

      get :show, params: { token: raw_token }

      expect(response).to redirect_to(root_url)
      expect(controller.current_user).to be_nil
    end

    it 'rate limits repeated password failures without consuming the token' do
      RateLimiter.new(
        user: user,
        rate_limit_type: :account_recovery_verify_password,
      ).increment_to_limited!

      post :create, params: password_params

      expect(controller.current_user).to be_nil
      expect(recovery_request.reload).to be_token_valid
      expect(flash[:error]).to eq(t('account_recovery.verify.password_rate_limited'))
    end

    it 'rate limits tokens on POST as well as GET' do
      RateLimiter.new(
        target: '0.0.0.0',
        rate_limit_type: :account_recovery_verify_token,
      ).increment_to_limited!

      post :create, params: password_params

      expect(controller.current_user).to be_nil
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
      expect(flash[:error]).to eq(t('account_recovery.verify.token_rate_limited'))
    end

    it 'renders the continuation only after password verification' do
      post :create, params: password_params

      get :show

      expect(response).to render_template(:pending_mfa_setup)
      expect(controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq(true)
    end

    it 'does not continue a request that was subsequently expired' do
      post :create, params: password_params
      recovery_request.reload.expire!

      get :show

      expect(response).to render_template('pages/page_not_found')
    end
  end

  it 'does not route cancellation through verification' do
    expect(post: '/account_recovery/verify/cancel').to route_to(
      controller: 'pages',
      action: 'page_not_found',
      path: 'account_recovery/verify/cancel',
    )
  end
end
