require 'rails_helper'

RSpec.describe AccountRecovery::VerifyController do
  let(:password) { ControllerHelper::VALID_PASSWORD }
  let(:user) { create(:user, :fully_registered, password: password) }
  let(:raw_token) { SecureRandom.uuid }
  let(:password_params) { { request_id: recovery_request.id, user: { password: password } } }
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

      expect(response).to redirect_to(account_recovery_verify_url)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
      expect(recovery_request.link_verified_at).to be_present
      expect(recovery_request).to be_token_valid
      expect(controller.current_user).to be_nil
      expect(session[:account_recovery_request_id]).to be_nil
      expect(session[:account_recovery_granted_token]).to eq(raw_token)
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

      expect(response).to redirect_to(account_recovery_verify_url)
      expect(recovery_request.reload.link_verified_at).to eq(verified_at)
      expect(controller.current_user).to be_nil
    end

    it 'requires a fresh password even if the owner is already signed in' do
      sign_in_as_user(user)

      get :show, params: { token: raw_token }

      expect(controller.current_user).to be_nil
      expect(response).to redirect_to(account_recovery_verify_url)
    end

    it 'signs out another user before displaying the token owner’s password prompt' do
      sign_in_as_user(create(:user, :fully_registered))

      get :show, params: { token: raw_token }

      expect(controller.current_user).to be_nil
      expect(response).to redirect_to(account_recovery_verify_url)

      get :show

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
    it 'renders the password form using the session token at a clean URL' do
      get :show, params: { token: raw_token }

      get :show

      expect(response).to render_template(:show)
      expect(response.headers['Referrer-Policy']).to eq('strict-origin-when-cross-origin')
      expect(controller.view_assigns['email']).to eq(user.last_sign_in_email_address.email)
      expect(controller.current_user).to be_nil
    end

    it 'clears an expired session token' do
      get :show, params: { token: raw_token }
      recovery_request.update!(token_expires_at: Time.zone.now)

      get :show

      expect(response).to redirect_to(root_url)
      expect(session[:account_recovery_granted_token]).to be_nil
    end

    it 'clears a previous session token when a new link is invalid' do
      get :show, params: { token: raw_token }

      get :show, params: { token: 'invalid' }

      expect(response).to redirect_to(root_url)
      expect(session[:account_recovery_granted_token]).to be_nil
    end

    it 'revalidates the session token before rendering the password form' do
      get :show, params: { token: raw_token }
      recovery_request.reload.cancel!(reason: AccountRecoveryRequest::CANCEL_REASON_USER_CANCELLED)

      get :show

      expect(response).to redirect_to(root_url)
      expect(session[:account_recovery_granted_token]).to be_nil
    end

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
    before do
      get :show, params: { token: raw_token }
    end

    it 'consumes the token and creates only a partial session after both checks succeed' do
      post :create, params: password_params

      expect(controller.current_user).to eq(user)
      expect(controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq(true)
      expect(response).to redirect_to(account_recovery_new_mfa_setup_url)
      expect(response.location).not_to include(raw_token)
      expect(session[:account_recovery_request_id]).to be_nil
      expect(session[:account_recovery_granted_token]).to be_nil
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::REPLACEMENT_MFA_PENDING)
      expect(recovery_request.link_verified_at).to be_present
      expect(recovery_request.password_verified_at).to be_present
      expect(recovery_request.token_fingerprint).to be_nil
      expect(recovery_request.token_expires_at).to be_nil
    end

    it 'suspends existing MFA methods without deleting them' do
      expect { post :create, params: password_params }
        .not_to change { user.reload.phone_configurations.count }
      expect(user.phone_configurations.first.account_recovery_request_id).to eq(recovery_request.id)
      expect(MfaContext.new(user).two_factor_enabled?).to eq(false)
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
      post :create, params: password_params.merge(user: { password: 'wrong password' })

      expect(controller.current_user).to be_nil
      expect(flash[:error]).to eq(t('errors.confirm_password_incorrect'))
      expect(response).to render_template(:show)
      expect(session[:account_recovery_granted_token]).to eq(raw_token)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
      expect(recovery_request).to be_token_valid
      expect(@analytics).to have_logged_event(
        :account_recovery_password_verification,
        success: false,
        rate_limited: false,
      )

      post :create, params: password_params

      expect(controller.current_user).to eq(user)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::REPLACEMENT_MFA_PENDING)
    end

    it 'rejects a posted token without session evidence' do
      session.delete(:account_recovery_granted_token)

      post :create, params: password_params.merge(token: raw_token)

      expect(response).to redirect_to(root_url)
      expect(controller.current_user).to be_nil
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
    end

    it 'rejects an invalid session token even with the correct password' do
      session[:account_recovery_granted_token] = SecureRandom.uuid

      post :create, params: password_params

      expect(response).to redirect_to(root_url)
      expect(controller.current_user).to be_nil
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
      expect(session[:account_recovery_granted_token]).to be_nil
    end

    it 'does not accept a request id without session evidence' do
      session.delete(:account_recovery_granted_token)

      post :create, params: password_params

      expect(response).to redirect_to(root_url)
      expect(controller.current_user).to be_nil
      expect(recovery_request.reload.password_verified_at).to be_nil
    end

    it 'requires the displayed request id even with a valid session token' do
      post :create, params: { user: { password: password } }

      expect(response).to redirect_to(root_url)
      expect(controller.current_user).to be_nil
      expect(recovery_request.reload.password_verified_at).to be_nil
    end

    it 'replaces the pending link but rejects a stale form from another tab' do
      other_request = create(
        :account_recovery_request,
        :granted,
        user: create(:user, :fully_registered, password: password),
        token_fingerprint: AccountRecovery::TokenCreator.fingerprint('another-token'),
      )

      get :show, params: { token: 'another-token' }

      expect(session[:account_recovery_granted_token]).to eq('another-token')
      expect(recovery_request.reload).to be_token_valid
      expect(other_request.reload).to be_token_valid

      post :create, params: password_params

      expect(response).to redirect_to(root_url)
      expect(controller.current_user).to be_nil
      expect(recovery_request.reload.password_verified_at).to be_nil
      expect(other_request.reload.password_verified_at).to be_nil
    end

    it 'uses the latest link rather than a token supplied with the password' do
      other_request = create(
        :account_recovery_request,
        :granted,
        user: create(:user, :fully_registered, password: password),
        token_fingerprint: AccountRecovery::TokenCreator.fingerprint('another-token'),
      )
      get :show, params: { token: 'another-token' }

      post :create, params: password_params.merge(request_id: other_request.id, token: raw_token)

      expect(controller.current_user).to eq(other_request.user)
      expect(other_request.reload.state).to eq(AccountRecoveryRequest::REPLACEMENT_MFA_PENDING)
      expect(recovery_request.reload.password_verified_at).to be_nil
      expect(session[:account_recovery_granted_token]).to be_nil
    end

    it 'requires the password of the token owner, not the previously signed-in user' do
      other_user = create(
        :user,
        :fully_registered,
        password: 'a different valid password',
      )
      sign_in_as_user(other_user)

      post :create, params: password_params.merge(user: { password: other_user.password })

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
      session[:account_recovery_granted_token] = raw_token

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
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
      expect(flash[:error]).to eq(t('account_recovery.verify.token_rate_limited'))
    end

    it 'renders the continuation only after password verification' do
      post :create, params: password_params

      get :show

      expect(response).to redirect_to(account_recovery_new_mfa_setup_url)
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
