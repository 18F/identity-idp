require 'rails_helper'

describe Users::SessionsController, devise: true do
  include ActionView::Helpers::DateHelper
  let(:mock_valid_site) { 'http://example.com' }

  describe 'GET /users/sign_in' do
    it 'clears the session when user is not yet 2fa-ed' do
      sign_in_before_2fa

      get :new

      expect(controller.current_user).to be nil
    end
  end

  describe 'GET /active' do
    context 'when user is present' do
      before do
        stub_sign_in
      end

      it 'returns a 200 status code' do
        get :active

        expect(response.status).to eq(200)
      end

      it 'clears the Etag header' do
        get :active

        expect(response.headers['Etag']).to eq ''
      end

      it 'renders json' do
        get :active

        expect(response.media_type).to eq('application/json')
      end

      it 'sets live key to true' do
        controller.session[:session_expires_at] = Time.zone.now + 10
        get :active

        json ||= JSON.parse(response.body)

        expect(json['live']).to eq true
      end

      it 'includes the timeout key' do
        timeout = Time.zone.now + 10
        controller.session[:session_expires_at] = timeout
        get :active

        json ||= JSON.parse(response.body)

        expect(json['timeout'].to_datetime.to_i).to be_within(1).of(timeout.to_i)
      end

      it 'includes the remaining key' do
        controller.session[:session_expires_at] = Time.zone.now + 10
        get :active

        json ||= JSON.parse(response.body)

        expect(json['remaining']).to be_within(1).of(10)
      end
    end

    context 'when user is not present' do
      it 'sets live key to false' do
        get :active

        json ||= JSON.parse(response.body)

        expect(json['live']).to eq false
      end

      it 'includes session_expires_at' do
        get :active

        json ||= JSON.parse(response.body)

        expect(json['timeout'].to_datetime.to_i).to be_within(1).of(Time.zone.now.to_i - 1)
      end

      it 'includes the remaining time' do
        get :active

        json ||= JSON.parse(response.body)

        expect(json['remaining']).to eq(-1)
      end

      it 'updates the pinged_at session key' do
        stub_sign_in
        now = Time.zone.now
        expected_time = now + 10
        session[:pinged_at] = now

        travel_to(Time.zone.now + 10) do
          get :active
        end

        expect(session[:pinged_at].to_i).to be_within(1).of(expected_time.to_i)
      end
    end

    it 'does not track analytics event' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to_not receive(:track_event)

      get :active
    end
  end

  describe 'GET /logout' do
    it 'tracks a logout event' do
      stub_analytics
      stub_attempts_tracker
      expect(@analytics).to receive(:track_event).with(
        'Logout Initiated',
        hash_including(
          sp_initiated: false,
          oidc: false,
        ),
      )

      sign_in_as_user

      expect(@irs_attempts_api_tracker).to receive(:logout_initiated).with(
        success: true,
      )

      get :destroy
      expect(controller.current_user).to be nil
    end
  end

  describe 'DELETE /logout' do
    it 'tracks a logout event' do
      stub_analytics
      stub_attempts_tracker
      expect(@analytics).to receive(:track_event).with(
        'Logout Initiated',
        hash_including(
          sp_initiated: false,
          oidc: false,
        ),
      )

      sign_in_as_user

      expect(@irs_attempts_api_tracker).to receive(:logout_initiated).with(
        success: true,
      )

      delete :destroy
      expect(controller.current_user).to be nil
    end
  end

  describe 'GET /timeout' do
    it 'signs the user out' do
      sign_in_as_user

      expect(subject.current_user).to_not be_nil

      get :timeout

      expect(flash[:info]).to eq t(
        'notices.session_timedout',
        app_name: APP_NAME,
        minutes: IdentityConfig.store.session_timeout_in_minutes,
      )

      expect(subject.current_user).to be_nil
    end

    it 'redirects to the homepage' do
      stub_sign_in

      get :timeout

      expect(response).to redirect_to(root_url)
    end

    it 'tracks the timeout' do
      stub_analytics
      sign_in_as_user

      expect(@analytics).to receive(:track_event).with('Session Timed Out')

      get :timeout
    end
  end

  describe 'POST /' do
    include AccountResetHelper
    it 'tracks the successful authentication for existing user' do
      user = create(:user, :signed_up)
      subject.session['user_return_to'] = mock_valid_site

      stub_analytics
      stub_attempts_tracker
      analytics_hash = {
        success: true,
        user_id: user.uuid,
        user_locked_out: false,
        stored_location: mock_valid_site,
        sp_request_url_present: false,
        remember_device: false,
      }

      expect(@analytics).to receive(:track_event).
        with('Email and Password Authentication', analytics_hash)

      expect(@irs_attempts_api_tracker).to receive(:login_email_and_password_auth).
        with(email: user.email, success: true)

      post :create, params: { user: { email: user.email, password: user.password } }
    end

    it 'tracks the unsuccessful authentication for existing user' do
      user = create(:user, :signed_up)

      stub_analytics
      analytics_hash = {
        success: false,
        user_id: user.uuid,
        user_locked_out: false,
        stored_location: nil,
        sp_request_url_present: false,
        remember_device: false,
      }

      expect(@analytics).to receive(:track_event).
        with('Email and Password Authentication', analytics_hash)

      post :create, params: { user: { email: user.email.upcase, password: 'invalid_password' } }
    end

    it 'tracks the authentication attempt for nonexistent user' do
      stub_analytics
      analytics_hash = {
        success: false,
        user_id: 'anonymous-uuid',
        user_locked_out: false,
        stored_location: nil,
        sp_request_url_present: false,
        remember_device: false,
      }

      expect(@analytics).to receive(:track_event).
        with('Email and Password Authentication', analytics_hash)

      post :create, params: { user: { email: 'foo@example.com', password: 'password' } }
    end

    it 'tracks unsuccessful authentication for too many auth failures' do
      allow(subject).to receive(:session_bad_password_count_max_exceeded?).and_return(true)
      mock_email_parameter = { email: 'bob@example.com' }

      stub_attempts_tracker

      expect(@irs_attempts_api_tracker).to receive(:login_email_and_password_auth).
        with({ **mock_email_parameter, success: false })
      expect(@irs_attempts_api_tracker).to receive(:login_rate_limited).
        with(mock_email_parameter)

      post :create, params: { user: { **mock_email_parameter, password: 'eatCake!' } }
    end

    it 'tracks unsuccessful authentication for locked out user' do
      user = create(
        :user,
        :signed_up,
        second_factor_locked_at: Time.zone.now,
      )

      stub_analytics
      analytics_hash = {
        success: false,
        user_id: user.uuid,
        user_locked_out: true,
        stored_location: nil,
        sp_request_url_present: false,
        remember_device: false,
      }

      expect(@analytics).to receive(:track_event).
        with('Email and Password Authentication', analytics_hash)

      post :create, params: { user: { email: user.email.upcase, password: user.password } }
    end

    it 'tracks the presence of SP request_url in session' do
      subject.session[:sp] = { request_url: mock_valid_site }
      stub_analytics
      analytics_hash = {
        success: false,
        user_id: 'anonymous-uuid',
        user_locked_out: false,
        stored_location: nil,
        sp_request_url_present: true,
        remember_device: false,
      }

      expect(@analytics).to receive(:track_event).
        with('Email and Password Authentication', analytics_hash)

      post :create, params: { user: { email: 'foo@example.com', password: 'password' } }
    end

    context 'IAL1 user' do
      it 'computes one SCrypt hash for the user password' do
        user = create(:user, :signed_up)

        expect(SCrypt::Engine).to receive(:hash_secret).once.and_call_original

        post :create, params: { user: { email: user.email.upcase, password: user.password } }
      end
    end

    context 'IAL2 user' do
      before do
        allow(FeatureManagement).to receive(:use_kms?).and_return(false)
      end

      it 'computes one SCrypt hash for the user password and one for the PII' do
        user = create(:user, :signed_up)
        create(:profile, :active, :verified, user: user, pii: { ssn: '1234' })

        expect(SCrypt::Engine).to receive(:hash_secret).twice.and_call_original

        post :create, params: { user: { email: user.email.upcase, password: user.password } }
      end

      it 'caches unverified PII pending confirmation' do
        user = create(:user, :signed_up)
        create(
          :profile,
          deactivation_reason: :gpo_verification_pending,
          user: user, pii: { ssn: '1234' }
        )

        post :create, params: { user: { email: user.email.upcase, password: user.password } }

        expect(controller.user_session[:decrypted_pii]).to match '1234'
      end

      it 'caches PII in the user session' do
        user = create(:user, :signed_up)
        create(:profile, :active, :verified, user: user, pii: { ssn: '1234' })

        post :create, params: { user: { email: user.email.upcase, password: user.password } }

        expect(controller.user_session[:decrypted_pii]).to match '1234'
      end

      it 'deactivates profile if not de-cryptable' do
        user = create(:user, :signed_up)
        profile = create(:profile, :active, :verified, user: user, pii: { ssn: '1234' })
        profile.update!(
          encrypted_pii: { encrypted_data: Base64.strict_encode64('nonsense') }.to_json,
        )

        stub_analytics
        analytics_hash = {
          success: true,
          user_id: user.uuid,
          user_locked_out: false,
          stored_location: nil,
          sp_request_url_present: false,
          remember_device: false,
        }

        expect(@analytics).to receive(:track_event).
          with('Email and Password Authentication', analytics_hash)

        profile_encryption_error = {
          error: 'Unable to parse encrypted payload',
        }
        expect(@analytics).to receive(:track_event).
          with('Profile Encryption: Invalid', profile_encryption_error)

        post :create, params: { user: { email: user.email, password: user.password } }

        expect(controller.user_session[:decrypted_pii]).to be_nil
        expect(profile.reload).to_not be_active
      end
    end

    it 'tracks CSRF errors' do
      user = create(:user, :signed_up)
      stub_analytics
      analytics_hash = { controller: 'users/sessions#create', user_signed_in: nil }
      allow(controller).to receive(:create).and_raise(ActionController::InvalidAuthenticityToken)

      expect(@analytics).to receive(:track_event).
        with('Invalid Authenticity Token', analytics_hash)

      post :create, params: { user: { email: user.email, password: user.password } }

      expect(response).to redirect_to new_user_session_url
      expect(flash[:error]).to eq t('errors.general')
    end

    it 'redirects back to home page if CSRF error and referer is invalid' do
      user = create(:user, :signed_up)
      stub_analytics
      analytics_hash = { controller: 'users/sessions#create', user_signed_in: nil }
      allow(controller).to receive(:create).and_raise(ActionController::InvalidAuthenticityToken)

      expect(@analytics).to receive(:track_event).
        with('Invalid Authenticity Token', analytics_hash)

      request.env['HTTP_REFERER'] = '@@@'
      post :create, params: { user: { email: user.email, password: user.password } }

      expect(response).to redirect_to new_user_session_url
      expect(flash[:error]).to eq t('errors.general')
    end

    it 'returns to sign in page if email is a Hash' do
      post :create, params: { user: { email: { foo: 'bar' }, password: 'password' } }

      expect(response).to render_template(:new)
    end

    context 'with remember_device cookie present and valid' do
      it 'tracks the cookie validity in analytics' do
        user = create(:user, :signed_up)

        cookies.encrypted[:remember_device] = {
          value: RememberDeviceCookie.new(user_id: user.id, created_at: Time.zone.now).to_json,
          expires: 2.days.from_now,
        }

        stub_analytics
        analytics_hash = {
          success: true,
          user_id: user.uuid,
          user_locked_out: false,
          stored_location: nil,
          sp_request_url_present: false,
          remember_device: true,
        }

        expect(@analytics).to receive(:track_event).
          with('Email and Password Authentication', analytics_hash)

        post :create, params: { user: { email: user.email, password: user.password } }
      end
    end

    context 'with remember_device cookie present but expired' do
      it 'only tracks the cookie presence in analytics' do
        user = create(:user, :signed_up)

        cookies.encrypted[:remember_device] = {
          value: RememberDeviceCookie.new(user_id: user.id, created_at: 2.days.ago).to_json,
        }

        stub_analytics
        analytics_hash = {
          success: true,
          user_id: user.uuid,
          user_locked_out: false,
          stored_location: nil,
          sp_request_url_present: false,
          remember_device: true,
        }

        expect(@analytics).to receive(:track_event).
          with('Email and Password Authentication', analytics_hash)

        post :create, params: { user: { email: user.email, password: user.password } }
      end
    end

    context 'with user that is up to date with rules of use' do
      let(:rules_of_use_updated_at) { 1.day.ago }
      let(:accepted_terms_at) { 12.hours.ago }
      let(:user) { create(:user, :signed_up, accepted_terms_at: accepted_terms_at) }

      before do
        allow(IdentityConfig.store).to receive(:rules_of_use_updated_at).
          and_return(rules_of_use_updated_at)
      end

      it 'redirects to 2fa since there is no pending account reset rewquests' do
        post :create, params: { user: { email: user.email, password: user.password } }
        expect(response).to redirect_to user_two_factor_authentication_url
      end
    end

    context 'with user that is not up to date with rules of use' do
      let(:rules_of_use_updated_at) { 1.day.ago }
      let(:accepted_terms_at) { 2.days.ago }
      let(:user) { create(:user, :signed_up, accepted_terms_at: accepted_terms_at) }

      before do
        allow(IdentityConfig.store).to receive(:rules_of_use_updated_at).
          and_return(rules_of_use_updated_at)
      end

      it 'redirects to rules of use url' do
        post :create, params: { user: { email: user.email, password: user.password } }
        expect(response).to redirect_to rules_of_use_url
      end
    end

    context 'with a user that accepted the rules of use more than 6 years ago' do
      let(:rules_of_use_horizon_years) { 6 }
      let(:rules_of_use_updated_at) { 7.years.ago }
      let(:accepted_terms_at) { 6.years.ago - 1.day }
      let(:user) { create(:user, :signed_up, accepted_terms_at: accepted_terms_at) }

      before do
        allow(IdentityConfig.store).to receive(:rules_of_use_horizon_years).
          and_return(rules_of_use_horizon_years)
        allow(IdentityConfig.store).to receive(:rules_of_use_updated_at).
          and_return(rules_of_use_updated_at)
      end

      it 'redirects to the rules of user url' do
        post :create, params: { user: { email: user.email, password: user.password } }
        expect(response).to redirect_to rules_of_use_url
      end
    end

    it 'redirects to 2FA if there are no pending account reset requests' do
      user = create(:user, :signed_up)
      post :create, params: { user: { email: user.email, password: user.password } }
      expect(response).to redirect_to user_two_factor_authentication_url
    end

    it 'redirects to the reset pending page if there are pending account reset requests' do
      user = create(:user, :signed_up)
      create_account_reset_request_for(user)
      post :create, params: { user: { email: user.email, password: user.password } }
      expect(response).to redirect_to account_reset_pending_url
    end
  end

  describe '#new' do
    context 'with fully authenticated user' do
      it 'redirects to the profile page' do
        stub_sign_in
        subject.session[:logged_in] = true
        get :new

        expect(response).to redirect_to account_path
        expect(subject.session[:logged_in]).to be true
      end
    end

    context 'with current user' do
      it 'logs the user out' do
        stub_sign_in_before_2fa
        subject.session[:logged_in] = true
        get :new

        expect(request.path).to eq root_path
        expect(subject.session[:logged_in]).to be_nil
      end
    end

    context 'with a new user' do
      it 'renders the new template' do
        get :new
        expect(response).to render_template(:new)
      end

      it 'tracks page visit, any alert flashes, and the Devise stored location' do
        stub_analytics
        allow(controller).to receive(:flash).and_return(alert: 'hello')
        subject.session['user_return_to'] = mock_valid_site
        properties = { flash: 'hello', stored_location: mock_valid_site }

        expect(@analytics).to receive(:track_event).with('Sign in page visited', properties)

        get :new
      end

      context 'renders partials' do
        render_views
        it 'renders the return to service provider template when arriving from an SP' do
          sp = create(:service_provider, issuer: 'https://awesome')
          subject.session[:sp] = { issuer: sp.issuer }

          get :new

          expect(response).to render_template(:new)
          expect(response).to render_template(
            partial: 'devise/sessions/_return_to_service_provider',
          )
        end
      end
    end

    context 'with fully authenticated user who has a pending profile' do
      it 'redirects to the verify profile page' do
        profile = create(
          :profile,
          deactivation_reason: :gpo_verification_pending,
          pii: { ssn: '6666', dob: '1920-01-01' },
        )
        user = profile.user

        stub_sign_in(user)
        get :new

        expect(response).to redirect_to idv_gpo_verify_path
      end
    end

    context 'with a garbage request_id' do
      render_views

      it 'does not blow up with a hash' do
        expect do
          get :new, params: { request_id: { '0' => "exp'\"\\(", '1' => '=1' } }
        end.to_not raise_error
      end

      it 'does not reflect request_id values that do not look like UUIDs' do
        get :new, params: { request_id: '<script>alert("my xss script")</script>' }

        expect(response.body).to_not include('my xss script')
      end
    end
  end

  describe 'POST /sessions/keepalive' do
    around do |ex|
      freeze_time { ex.run }
    end

    context 'when user is present' do
      before do
        stub_sign_in
      end

      it 'returns a 200 status code' do
        post :keepalive

        expect(response.status).to eq(200)
      end

      it 'clears the Etag header' do
        post :keepalive

        expect(response.headers['Etag']).to eq ''
      end

      it 'renders json' do
        post :keepalive

        expect(response.media_type).to eq('application/json')
      end

      it 'resets the timeout key' do
        timeout = Time.zone.now + 2
        controller.session[:session_expires_at] = timeout
        post :keepalive

        json ||= JSON.parse(response.body)

        expect(json['timeout'].to_datetime.to_i).to be >= timeout.to_i
        expect(json['timeout'].to_datetime.to_i).to be_within(1).of(
          Time.zone.now.to_i + IdentityConfig.store.session_timeout_in_minutes * 60,
        )
      end

      it 'resets the remaining key' do
        controller.session[:session_expires_at] = Time.zone.now + 10
        post :keepalive

        json ||= JSON.parse(response.body)

        expect(json['remaining']).to be_within(1).of(
          IdentityConfig.store.session_timeout_in_minutes * 60,
        )
      end

      it 'tracks session refresh visit' do
        controller.session[:session_expires_at] = Time.zone.now + 10
        stub_analytics

        expect(@analytics).to receive(:track_event).with('Session Kept Alive')

        post :keepalive
      end
    end

    context 'when user is not present' do
      it 'sets live key to false' do
        post :keepalive

        json ||= JSON.parse(response.body)

        expect(json['live']).to eq false
      end

      it 'includes session_expires_at' do
        post :keepalive

        json ||= JSON.parse(response.body)

        expect(json['timeout'].to_datetime.to_i).to be_within(1).of(Time.zone.now.to_i - 1)
      end

      it 'includes the remaining time' do
        post :keepalive

        json ||= JSON.parse(response.body)

        expect(json['remaining']).to eq(-1)
      end
    end

    it 'does not track analytics event' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to_not receive(:track_event)

      get :active
    end
  end
end
