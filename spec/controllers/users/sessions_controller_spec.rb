require 'rails_helper'

RSpec.describe Users::SessionsController, devise: true do
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::UrlHelper

  let(:mock_valid_site) { 'http://example.com' }

  describe 'GET /logout' do
    it 'does not log user out and redirects to root' do
      sign_in_as_user
      get :destroy
      expect(controller.current_user).to_not be nil
      expect(response).to redirect_to root_url
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

  describe 'POST /' do
    include AccountResetHelper

    it 'tracks the successful authentication for existing user' do
      user = create(:user, :fully_registered)

      stub_analytics
      stub_attempts_tracker
      analytics_hash = {
        success: true,
        user_id: user.uuid,
        user_locked_out: false,
        bad_password_count: 0,
        sp_request_url_present: false,
        remember_device: false,
      }

      expect(@analytics).to receive(:track_event).
        with('Email and Password Authentication', analytics_hash)

      expect(@irs_attempts_api_tracker).to receive(:login_email_and_password_auth).
        with(email: user.email, success: true)

      post :create, params: { user: { email: user.email, password: user.password } }
      expect(subject.session[:sign_in_flow]).to eq(:sign_in)
    end

    it 'saves and refreshes cookie for device for successful authentication' do
      user = create(:user, :fully_registered)

      first_expires = nil

      freeze_time do
        post :create, params: { user: { email: user.email, password: user.password } }

        device_cookie = response.headers['set-cookie'].find { |c| c.start_with?('device=') }
        first_expires = CGI::Cookie.parse(device_cookie)['expires'].first
        expect(Time.zone.parse(first_expires)).to be >= 20.years.from_now
      end

      sign_out(user)
      expect(cookies[:device]).to be_present

      travel_to 10.minutes.from_now do
        post :create, params: { user: { email: user.email, password: user.password } }

        device_cookie = response.headers['set-cookie'].find { |c| c.start_with?('device=') }
        second_expires = CGI::Cookie.parse(device_cookie)['expires'].first
        expect(Time.zone.parse(second_expires)).to be >= Time.zone.parse(first_expires) + 10.minutes
      end
    end

    it 'tracks the unsuccessful authentication for existing user' do
      user = create(:user, :fully_registered)

      stub_analytics
      analytics_hash = {
        success: false,
        user_id: user.uuid,
        user_locked_out: false,
        bad_password_count: 1,
        sp_request_url_present: false,
        remember_device: false,
      }
      expect(SCrypt::Engine).to receive(:hash_secret).once.and_call_original

      expect(@analytics).to receive(:track_event).
        with('Email and Password Authentication', analytics_hash)

      post :create, params: { user: { email: user.email.upcase, password: 'invalid_password' } }
      expect(subject.session[:sign_in_flow]).to eq(:sign_in)
    end

    it 'tracks the authentication attempt for nonexistent user' do
      stub_analytics
      analytics_hash = {
        success: false,
        user_id: 'anonymous-uuid',
        user_locked_out: false,
        bad_password_count: 1,
        sp_request_url_present: false,
        remember_device: false,
      }
      expect(SCrypt::Engine).to receive(:hash_secret).once.and_call_original

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
        :fully_registered,
        second_factor_locked_at: Time.zone.now,
      )

      stub_analytics
      analytics_hash = {
        success: false,
        user_id: user.uuid,
        user_locked_out: true,
        bad_password_count: 0,
        sp_request_url_present: false,
        remember_device: false,
      }

      expect(@analytics).to receive(:track_event).
        with('Email and Password Authentication', analytics_hash)

      post :create, params: { user: { email: user.email.upcase, password: user.password } }
    end

    it 'tracks count of multiple unsuccessful authentication attempts' do
      user = create(
        :user,
        :fully_registered,
      )

      stub_analytics

      analytics_hash = {
        success: false,
        user_id: user.uuid,
        user_locked_out: false,
        bad_password_count: 2,
        sp_request_url_present: false,
        remember_device: false,
      }

      post :create, params: { user: { email: user.email.upcase, password: 'invalid' } }
      expect(@analytics).to receive(:track_event).
        with('Email and Password Authentication', analytics_hash)
      post :create, params: { user: { email: user.email.upcase, password: 'invalid' } }
    end

    it 'tracks the presence of SP request_url in session' do
      subject.session[:sp] = { request_url: mock_valid_site }
      stub_analytics
      analytics_hash = {
        success: false,
        user_id: 'anonymous-uuid',
        user_locked_out: false,
        bad_password_count: 1,
        sp_request_url_present: true,
        remember_device: false,
      }

      expect(@analytics).to receive(:track_event).
        with('Email and Password Authentication', analytics_hash)

      post :create, params: { user: { email: 'foo@example.com', password: 'password' } }
    end

    context 'IAL1 user' do
      it 'computes one SCrypt hash for the user password' do
        user = create(:user, :fully_registered)

        expect(SCrypt::Engine).to receive(:hash_secret).once.and_call_original

        post :create, params: { user: { email: user.email.upcase, password: user.password } }
      end
    end

    context 'Password Compromised toggle is set to true' do
      before do
        allow(FeatureManagement).to receive(:check_password_enabled?).and_return(true)
      end

      context 'User has a compromised password' do
        let(:user) { create(:user, :fully_registered) }
        before do
          allow(PwnedPasswords::LookupPassword).to receive(:call).and_return true
        end

        context 'user randomly chosen to be tested' do
          before do
            allow(SecureRandom).to receive(:random_number).and_return(5)
            allow(IdentityConfig.store).to receive(:compromised_password_randomizer_threshold).
              and_return(2)
          end

          it 'updates user attribute password_compromised_checked_at' do
            expect(user.password_compromised_checked_at).to be_falsey
            post :create, params: { user: { email: user.email, password: user.password } }
            user.reload
            expect(user.password_compromised_checked_at).to be_truthy
          end

          it 'stores in session redirect to check compromise' do
            post :create, params: { user: { email: user.email, password: user.password } }
            expect(controller.session[:redirect_to_password_compromised]).to be_truthy
          end
        end

        context 'user not chosen to be tested' do
          before do
            allow(SecureRandom).to receive(:random_number).and_return(1)
            allow(IdentityConfig.store).to receive(:compromised_password_randomizer_threshold).
              and_return(5)
          end

          it 'does not store anything in user_session' do
            post :create, params: { user: { email: user.email, password: user.password } }
            expect(user.password_compromised_checked_at).to be_falsey
          end

          it 'does not update the user ' do
            post :create, params: { user: { email: user.email, password: user.password } }
            expect(controller.session[:redirect_to_password_compromised]).to be_falsey
          end
        end
      end

      context 'user does not have a compromised password' do
        let(:user) { create(:user, :fully_registered) }
        before do
          allow(PwnedPasswords::LookupPassword).to receive(:call).and_return false
        end

        context 'user randomly chosen to be tested' do
          before do
            allow(SecureRandom).to receive(:random_number).and_return(5)
            allow(IdentityConfig.store).to receive(:compromised_password_randomizer_threshold).
              and_return(2)
          end

          it 'updates user attribute password_compromised_checked_at' do
            expect(user.password_compromised_checked_at).to be_falsey
            post :create, params: { user: { email: user.email, password: user.password } }
            user.reload
            expect(user.password_compromised_checked_at).to be_truthy
          end

          it 'stores in session false to attempt to redirect password compromised' do
            post :create, params: { user: { email: user.email, password: user.password } }
            expect(controller.session[:redirect_to_password_compromised]).to be_falsey
          end
        end

        context 'user not chosen to be tested' do
          before do
            allow(SecureRandom).to receive(:random_number).and_return(1)
            allow(IdentityConfig.store).to receive(:compromised_password_randomizer_threshold).
              and_return(5)
          end

          it 'does not store anything in user_session' do
            post :create, params: { user: { email: user.email, password: user.password } }
            expect(user.password_compromised_checked_at).to be_falsey
          end

          it 'does not update the user ' do
            post :create, params: { user: { email: user.email, password: user.password } }
            expect(controller.session[:redirect_to_password_compromised]).to be_falsey
          end
        end
      end
    end

    context 'IAL2 user' do
      before do
        allow(FeatureManagement).to receive(:use_kms?).and_return(false)
      end

      it 'computes one SCrypt hash for the user password and one for the PII' do
        user = create(:user, :fully_registered)
        create(:profile, :active, :verified, user: user, pii: { ssn: '1234' })

        expect(SCrypt::Engine).to receive(:hash_secret).twice.and_call_original

        post :create, params: { user: { email: user.email.upcase, password: user.password } }
      end

      it 'caches unverified PII pending confirmation' do
        user = create(:user, :fully_registered)
        create(
          :profile,
          gpo_verification_pending_at: 1.day.ago,
          user: user, pii: { ssn: '1234' }
        )

        post :create, params: { user: { email: user.email.upcase, password: user.password } }

        cached_pii = Pii::Cacher.new(user, controller.user_session).fetch(user.pending_profile.id)
        expect(cached_pii).to eq(Pii::Attributes.new(ssn: '1234'))
      end

      it 'caches PII in the user session' do
        user = create(:user, :fully_registered)
        create(:profile, :active, :verified, user: user, pii: { ssn: '1234' })

        post :create, params: { user: { email: user.email.upcase, password: user.password } }

        cached_pii = Pii::Cacher.new(user, controller.user_session).fetch(user.active_profile.id)
        expect(cached_pii).to eq(Pii::Attributes.new(ssn: '1234'))
      end

      it 'deactivates profile if not de-cryptable' do
        user = create(:user, :fully_registered)
        profile = create(:profile, :active, :verified, user: user, pii: { ssn: '1234' })
        profile.update!(
          encrypted_pii: { encrypted_data: Base64.strict_encode64('nonsense') }.to_json,
          encrypted_pii_multi_region: {
            encrypted_data: Base64.strict_encode64('nonsense'),
          }.to_json,
        )

        stub_analytics
        analytics_hash = {
          success: true,
          user_id: user.uuid,
          user_locked_out: false,
          bad_password_count: 0,
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

        expect(controller.user_session[:encrypted_profiles]).to be_nil
        expect(profile.reload).to_not be_active
      end
    end

    it 'tracks CSRF errors' do
      user = create(:user, :fully_registered)
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
      user = create(:user, :fully_registered)
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

    it 'does not allow signing in with empty email' do
      post :create, params: { user: { email: '', password: 'foo' } }

      expect(flash[:alert]).
        to eq t(
          'devise.failure.not_found_in_database_html',
          link_html: link_to(
            t('devise.failure.not_found_in_database_link_text'),
            new_user_password_url,
          ),
        )
    end

    it 'does not allow signing in with the wrong email' do
      user = create(:user)
      post :create, params: { user: { email: 'invalid@example.com', password: user.password } }

      expect(flash[:alert]).
        to eq t(
          'devise.failure.invalid_html',
          link_html: link_to(
            t('devise.failure.invalid_link_text'),
            new_user_password_url,
          ),
        )
    end

    it 'does not allow signing in with empty password' do
      post :create, params: { user: { email: 'test@example.com', password: '' } }

      expect(flash[:alert]).
        to eq t(
          'devise.failure.not_found_in_database_html',
          link_html: link_to(
            t('devise.failure.not_found_in_database_link_text'),
            new_user_password_url,
          ),
        )
    end

    it 'does not allow signing in with the wrong password' do
      user = create(:user)
      post :create, params: { user: { email: user.email, password: 'invalidpass' } }

      expect(flash[:alert]).
        to eq t(
          'devise.failure.invalid_html',
          link_html: link_to(
            t('devise.failure.invalid_link_text'),
            new_user_password_url,
          ),
        )
    end

    context 'with remember_device cookie present and valid' do
      it 'tracks the cookie validity in analytics' do
        user = create(:user, :fully_registered)

        cookies.encrypted[:remember_device] = {
          value: RememberDeviceCookie.new(user_id: user.id, created_at: Time.zone.now).to_json,
          expires: 2.days.from_now,
        }

        stub_analytics
        analytics_hash = {
          success: true,
          user_id: user.uuid,
          user_locked_out: false,
          bad_password_count: 0,
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
        user = create(:user, :fully_registered)

        cookies.encrypted[:remember_device] = {
          value: RememberDeviceCookie.new(user_id: user.id, created_at: 2.days.ago).to_json,
        }

        stub_analytics
        analytics_hash = {
          success: true,
          user_id: user.uuid,
          user_locked_out: false,
          bad_password_count: 0,
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
      let(:user) { create(:user, :fully_registered, accepted_terms_at: accepted_terms_at) }

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
      let(:user) { create(:user, :fully_registered, accepted_terms_at: accepted_terms_at) }

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
      let(:user) { create(:user, :fully_registered, accepted_terms_at: accepted_terms_at) }

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
      user = create(:user, :fully_registered)
      post :create, params: { user: { email: user.email, password: user.password } }
      expect(response).to redirect_to user_two_factor_authentication_url
    end

    it 'redirects to the reset pending page if there are pending account reset requests' do
      user = create(:user, :fully_registered)
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
      it 'redirects to 2FA' do
        stub_sign_in_before_2fa
        get :new

        expect(response).to redirect_to user_two_factor_authentication_url
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

        expect(@analytics).to receive(:track_event).with(
          'Sign in page visited',
          flash: 'hello',
        )

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
          gpo_verification_pending_at: 1.day.ago,
          pii: { ssn: '6666', dob: '1920-01-01' },
        )
        user = profile.user

        stub_sign_in(user)
        get :new

        expect(response).to redirect_to idv_verify_by_mail_enter_code_path
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

    it 'does not blow up with malformed params' do
      expect do
        get :new, params: { user: 'this_is_not_a_hash' }
      end.to_not raise_error
    end

    context 'with prefilled email/password via url params' do
      render_views

      it 'does not prefill the form' do
        email = Faker::Internet.safe_email
        password = SecureRandom.uuid

        get :new, params: { user: { email: email, password: password } }

        doc = Nokogiri::HTML(response.body)

        expect(doc.at_css('input[name="user[email]"]')[:value]).to be_nil
        expect(doc.at_css('input[name="user[password]"]')[:value]).to be_nil
      end
    end
  end
end
