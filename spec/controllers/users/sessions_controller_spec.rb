require 'rails_helper'

RSpec.describe Users::SessionsController, devise: true do
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::UrlHelper
  include AbTestsHelper

  let(:mock_valid_site) { 'http://example.com' }

  describe 'before_actions' do
    describe 'recaptcha csp' do
      it 'does not allow recaptcha in the csp' do
        expect(subject).not_to receive(:allow_csp_recaptcha_src)

        get :new
      end

      context 'recaptcha enabled' do
        before do
          allow(FeatureManagement).to receive(:sign_in_recaptcha_enabled?).and_return(true)
        end

        it 'allows recaptcha in the csp' do
          expect(subject).to receive(:allow_csp_recaptcha_src)

          get :new
        end
      end
    end
  end

  describe 'after actions' do
    it 'does not add recaptcha resource hints' do
      expect(subject).not_to receive(:add_recaptcha_resource_hints)

      get :new
    end

    context 'recaptcha enabled' do
      before do
        allow(FeatureManagement).to receive(:sign_in_recaptcha_enabled?).and_return(true)
      end

      it 'adds recaptcha resource hints' do
        expect(subject).to receive(:add_recaptcha_resource_hints)

        get :new
      end
    end
  end

  describe 'DELETE /logout' do
    it 'tracks a logout event' do
      stub_analytics
      sign_in_as_user
      stub_attempts_tracker

      expect(@attempts_api_tracker).to receive(:logout_initiated).with(
        success: true,
      )

      delete :destroy

      expect(@analytics).to have_logged_event(
        'Logout Initiated',
        sp_initiated: false,
        oidc: false,
      )
      expect(controller.current_user).to be nil
    end
  end

  describe 'POST /' do
    include AccountResetHelper
    before do
      stub_attempts_tracker
    end

    context 'successful authentication' do
      let(:user) { create(:user, :fully_registered) }

      subject(:response) do
        post :create, params: { user: { email: user.email, password: user.password } }
      end

      it 'tracks the successful authentication for existing user' do
        stub_analytics(user:)
        expect(@attempts_api_tracker).to receive(:email_and_password_auth).with(
          success: true,
        )

        response

        expect(@analytics).to have_logged_event(
          'Email and Password Authentication',
          success: true,
          user_locked_out: false,
          rate_limited: false,
          valid_captcha_result: true,
          captcha_validation_performed: false,
          sign_in_failure_count: 0,
          sp_request_url_present: false,
          remember_device: false,
          new_device: true,
        )
      end

      it 'assigns sign_in_flow session value' do
        response

        expect(controller.session[:sign_in_flow]).to eq(:sign_in)
      end

      it 'sets new device session value' do
        expect(controller).to receive(:set_new_device_session).with(nil)

        response
      end

      it 'schedules new device alert' do
        expect(UserAlerts::AlertUserAboutNewDevice).to receive(:schedule_alert) do |event:|
          expect(event).to eq(user.events.where(event_type: :sign_in_before_2fa).last)
        end

        response
      end

      it 'saves and refreshes cookie for device for successful authentication' do
        first_expires = nil

        freeze_time do
          device_cookie = response.headers['set-cookie'].find { |c| c.start_with?('device=') }
          first_expires = Time.zone.parse(CGI::Cookie.parse(device_cookie)['expires'].first)
          expect(first_expires).to be >= 20.years.from_now
        end

        sign_out(user)
        expect(cookies[:device]).to be_present

        travel_to 10.minutes.from_now do
          response = post :create, params: { user: { email: user.email, password: user.password } }

          device_cookie = response.headers['set-cookie'].find { |c| c.start_with?('device=') }
          second_expires = Time.zone.parse(CGI::Cookie.parse(device_cookie)['expires'].first)
          expect(second_expires).to be >= first_expires + 10.minutes
        end
      end

      context 'with authenticated device' do
        let(:user) { create(:user, :with_authenticated_device) }

        before do
          request.cookies[:device] = user.devices.last.cookie_uuid
        end

        it 'does not schedule new device alert' do
          expect(UserAlerts::AlertUserAboutNewDevice).not_to receive(:schedule_alert)

          response
        end

        it 'tracks as not being from a new device' do
          stub_analytics(user:)
          expect(@attempts_api_tracker).to receive(:email_and_password_auth).with(
            success: true,
          )

          response

          expect(@analytics).to have_logged_event(
            'Email and Password Authentication',
            success: true,
            user_locked_out: false,
            rate_limited: false,
            valid_captcha_result: true,
            captcha_validation_performed: false,
            sign_in_failure_count: 0,
            sp_request_url_present: false,
            remember_device: false,
            new_device: false,
          )
        end
      end
    end

    context 'locked out session' do
      let(:locked_at) { Time.zone.now }
      let(:user) { create(:user, :fully_registered) }
      let(:sign_in_failure_window) { IdentityConfig.store.max_sign_in_failures_window_in_seconds }

      before do
        session[:sign_in_failure_count] = IdentityConfig.store.max_sign_in_failures + 1
        session[:max_sign_in_failures_at] = locked_at.to_i
      end

      it 'renders an error letting user know they are locked out for a period of time',
         :freeze_time do
        post :create, params: { user: { email: user.email.upcase, password: user.password } }
        current_time = Time.zone.now
        time_in_hours = distance_of_time_in_words(
          current_time,
          (locked_at + sign_in_failure_window.seconds),
          true,
        )

        expect(response).to redirect_to root_url
        expect(flash[:error]).to eq(
          t(
            'errors.sign_in.sign_in_failure_limit',
            time_left: time_in_hours,
          ),
        )
      end
    end

    it 'prevents attempt and logs after exceeding maximum rate limit' do
      allow(IdentityConfig.store).to receive(:max_sign_in_failures).and_return(10_000)
      allow(RateLimiter).to receive(:rate_limit_config).and_return(
        sign_in_user_id_per_ip: {
          max_attempts: 6,
          attempt_window: 60,
          attempt_window_exponential_factor: 3,
          attempt_window_max: 12.hours.in_minutes,
        },
      )
      user = create(:user, :fully_registered)
      stub_analytics(user:)

      expect(@attempts_api_tracker).to receive(:email_and_password_auth).with(
        success: false,
      ).exactly(9).times

      travel_to (3.hours + 1.minute).ago do
        2.times do
          post :create, params: { user: { email: user.email, password: 'incorrect' } }
        end
      end

      post :create, params: { user: { email: user.email, password: 'incorrect' } }
      expect(flash[:error]).to be_blank

      4.times do
        post :create, params: { user: { email: user.email, password: 'incorrect' } }
      end

      travel_to (12.hours - 1.minute).from_now do
        post :create, params: { user: { email: user.email, password: 'incorrect' } }
        expect(flash[:error]).to be_blank

        post :create, params: { user: { email: user.email, password: 'incorrect' } }
        expect(flash[:error]).to eq(
          t(
            'errors.sign_in.sign_in_failure_limit',
            time_left: distance_of_time_in_words(12.hours),
          ),
        )
        expect(@analytics).to have_logged_event(
          'Email and Password Authentication',
          success: false,
          user_locked_out: false,
          rate_limited: true,
          valid_captcha_result: true,
          captcha_validation_performed: false,
          sign_in_failure_count: 8,
          sp_request_url_present: false,
          remember_device: false,
        )
      end
    end

    it 'tracks the unsuccessful authentication for existing user' do
      user = create(:user, :fully_registered)

      stub_analytics(user:)
      expect(SCrypt::Engine).to receive(:hash_secret).once.and_call_original
      expect(@attempts_api_tracker).to receive(:email_and_password_auth).with(
        success: false,
      )

      post :create, params: { user: { email: user.email.upcase, password: 'invalid_password' } }

      expect(@analytics).to have_logged_event(
        'Email and Password Authentication',
        success: false,
        user_locked_out: false,
        rate_limited: false,
        valid_captcha_result: true,
        captcha_validation_performed: false,
        sign_in_failure_count: 1,
        sp_request_url_present: false,
        remember_device: false,
      )
      expect(subject.session[:sign_in_flow]).to eq(:sign_in)
    end

    it 'tracks the authentication attempt for nonexistent user' do
      stub_analytics(user: kind_of(AnonymousUser))
      expect(SCrypt::Engine).to receive(:hash_secret).once.and_call_original
      expect(@attempts_api_tracker).to receive(:email_and_password_auth).with(
        success: false,
      )

      post :create, params: { user: { email: 'foo@example.com', password: 'password' } }

      expect(@analytics).to have_logged_event(
        'Email and Password Authentication',
        success: false,
        user_locked_out: false,
        rate_limited: false,
        valid_captcha_result: true,
        captcha_validation_performed: false,
        sign_in_failure_count: 1,
        sp_request_url_present: false,
        remember_device: false,
      )
    end

    it 'tracks unsuccessful authentication for locked out user' do
      user = create(
        :user,
        :fully_registered,
        second_factor_locked_at: Time.zone.now,
      )

      stub_analytics(user:)
      expect(@attempts_api_tracker).to receive(:email_and_password_auth).with(
        success: false,
      )

      post :create, params: { user: { email: user.email.upcase, password: user.password } }

      expect(@analytics).to have_logged_event(
        'Email and Password Authentication',
        success: false,
        user_locked_out: true,
        rate_limited: false,
        valid_captcha_result: true,
        captcha_validation_performed: false,
        sign_in_failure_count: 0,
        sp_request_url_present: false,
        remember_device: false,
      )
    end

    context 'with reCAPTCHA validation enabled' do
      before do
        allow(FeatureManagement).to receive(:sign_in_recaptcha_enabled?).and_return(true)
        allow(IdentityConfig.store).to receive(:recaptcha_mock_validator).and_return(true)
        allow(IdentityConfig.store).to receive(:sign_in_recaptcha_score_threshold).and_return(0.2)
        allow(controller).to receive(:ab_test_bucket).with(:RECAPTCHA_SIGN_IN, kind_of(Hash))
          .and_return(:sign_in_recaptcha)
      end

      it 'stores the reCAPTCHA assessment id in the session' do
        user = create(:user, :fully_registered)

        post :create, params: { user: { email: user.email,
                                        password: user.password,
                                        score: 0.1,
                                        recaptcha_token: 'token' } }

        expect(controller.session[:sign_in_recaptcha_assessment_id]).to be_kind_of(String)
      end

      it 'tracks unsuccessful authentication for failed reCAPTCHA' do
        user = create(:user, :fully_registered)

        stub_analytics(user:)
        expect(@attempts_api_tracker).to receive(:email_and_password_auth).with(
          success: false,
        )

        post :create, params: { user: { email: user.email, password: user.password, score: 0.1 } }

        expect(@analytics).to have_logged_event(
          'Email and Password Authentication',
          success: false,
          error_details: { recaptcha_token: { blank: true } },
          user_locked_out: false,
          rate_limited: false,
          valid_captcha_result: false,
          captcha_validation_performed: true,
          sign_in_failure_count: 1,
          remember_device: false,
          sp_request_url_present: false,
        )
      end

      it 'redirects unsuccessful authentication for failed reCAPTCHA to failed page' do
        user = create(:user, :fully_registered)

        post :create, params: { user: { email: user.email, password: user.password, score: 0.1 } }

        expect(response).to redirect_to sign_in_security_check_failed_url
      end

      context 'recaptcha lock out' do
        let(:locked_at) { Time.zone.now }
        let(:sign_in_failure_window) { IdentityConfig.store.max_sign_in_failures_window_in_seconds }
        it 'prevents attempt after exceeding maximum rate limit' do
          allow(IdentityConfig.store).to receive(:max_sign_in_failures).and_return(5)
          expect(@attempts_api_tracker).to receive(:email_and_password_auth).with(
            success: false,
          ).exactly(6).times

          user = create(:user, :fully_registered)
          freeze_time do
            current_time = Time.zone.now
            rate_limit_time_left = distance_of_time_in_words(
              current_time,
              (locked_at + sign_in_failure_window.seconds),
              true,
            )
            6.times do
              post :create, params: {
                user: { email: user.email, password: user.password, score: 0.1 },
              }
            end

            expect(response).to redirect_to root_url
            expect(flash[:error]).to eq(
              t(
                'errors.sign_in.sign_in_failure_limit',
                time_left: rate_limit_time_left,
              ),
            )
          end
        end
      end
    end

    it 'tracks count of multiple unsuccessful authentication attempts' do
      user = create(
        :user,
        :fully_registered,
      )

      stub_analytics(user:)
      expect(@attempts_api_tracker).to receive(:email_and_password_auth).with(
        success: false,
      ).exactly(2).times

      post :create, params: { user: { email: user.email.upcase, password: 'invalid' } }
      post :create, params: { user: { email: user.email.upcase, password: 'invalid' } }
      expect(@analytics).to have_logged_event(
        'Email and Password Authentication',
        success: false,
        user_locked_out: false,
        rate_limited: false,
        valid_captcha_result: true,
        captcha_validation_performed: false,
        sign_in_failure_count: 2,
        sp_request_url_present: false,
        remember_device: false,
      )
    end

    it 'tracks the presence of SP request_url in session' do
      subject.session[:sp] = { request_url: mock_valid_site }
      stub_analytics(user: kind_of(AnonymousUser))
      expect(@attempts_api_tracker).to receive(:email_and_password_auth).with(
        success: false,
      )

      post :create, params: { user: { email: 'foo@example.com', password: 'password' } }

      expect(@analytics).to have_logged_event(
        'Email and Password Authentication',
        success: false,
        user_locked_out: false,
        rate_limited: false,
        valid_captcha_result: true,
        captcha_validation_performed: false,
        sign_in_failure_count: 1,
        sp_request_url_present: true,
        remember_device: false,
      )
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
            allow(IdentityConfig.store).to receive(:compromised_password_randomizer_threshold)
              .and_return(2)
          end

          it 'updates user attribute password_compromised_checked_at' do
            expect(user.password_compromised_checked_at).to be_falsey
            post :create, params: { user: { email: user.email, password: user.password } }
            user.reload
            expect(user.password_compromised_checked_at).to be_truthy
          end

          it 'stores in session redirect to check compromise' do
            post :create, params: { user: { email: user.email, password: user.password } }
            expect(controller.session[:redirect_to_change_password]).to be_truthy
          end
        end

        context 'user not chosen to be tested' do
          before do
            allow(SecureRandom).to receive(:random_number).and_return(1)
            allow(IdentityConfig.store).to receive(:compromised_password_randomizer_threshold)
              .and_return(5)
          end

          it 'does not store anything in user_session' do
            post :create, params: { user: { email: user.email, password: user.password } }
            expect(user.password_compromised_checked_at).to be_falsey
          end

          it 'does not update the user ' do
            post :create, params: { user: { email: user.email, password: user.password } }
            expect(controller.session[:redirect_to_change_password]).to be_falsey
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
            allow(IdentityConfig.store).to receive(:compromised_password_randomizer_threshold)
              .and_return(2)
          end

          it 'updates user attribute password_compromised_checked_at' do
            expect(user.password_compromised_checked_at).to be_falsey
            post :create, params: { user: { email: user.email, password: user.password } }
            user.reload
            expect(user.password_compromised_checked_at).to be_truthy
          end

          it 'stores in session false to attempt to redirect password compromised' do
            post :create, params: { user: { email: user.email, password: user.password } }
            expect(controller.session[:redirect_to_change_password]).to be_falsey
          end
        end

        context 'user not chosen to be tested' do
          before do
            allow(SecureRandom).to receive(:random_number).and_return(1)
            allow(IdentityConfig.store).to receive(:compromised_password_randomizer_threshold)
              .and_return(5)
          end

          it 'does not store anything in user_session' do
            post :create, params: { user: { email: user.email, password: user.password } }
            expect(user.password_compromised_checked_at).to be_falsey
          end

          it 'does not update the user ' do
            post :create, params: { user: { email: user.email, password: user.password } }
            expect(controller.session[:redirect_to_change_password]).to be_falsey
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

        stub_analytics(user:)
        expect(@attempts_api_tracker).to receive(:email_and_password_auth).with(
          success: true,
        )

        post :create, params: { user: { email: user.email, password: user.password } }

        expect(@analytics).to have_logged_event(
          'Email and Password Authentication',
          success: true,
          user_locked_out: false,
          rate_limited: false,
          valid_captcha_result: true,
          captcha_validation_performed: false,
          sign_in_failure_count: 0,
          sp_request_url_present: false,
          remember_device: false,
          new_device: true,
        )
        expect(@analytics).to have_logged_event(
          'Profile Encryption: Invalid',
          error: 'Unable to parse encrypted payload',
        )
        expect(controller.user_session[:encrypted_profiles]).to be_nil
        expect(profile.reload).to_not be_active
      end
    end

    it 'tracks CSRF errors' do
      user = create(:user, :fully_registered)
      stub_analytics
      allow(controller).to receive(:create).and_raise(ActionController::InvalidAuthenticityToken)

      post :create, params: { user: { email: user.email, password: user.password } }

      expect(@analytics).to have_logged_event(
        'Invalid Authenticity Token',
        controller: 'users/sessions#create',
      )
      expect(response).to redirect_to new_user_session_url
      expect(flash[:error]).to eq t('errors.general')
    end

    it 'redirects back to home page if CSRF error and referer is invalid' do
      user = create(:user, :fully_registered)
      stub_analytics
      allow(controller).to receive(:create).and_raise(ActionController::InvalidAuthenticityToken)

      request.env['HTTP_REFERER'] = '@@@'
      post :create, params: { user: { email: user.email, password: user.password } }

      expect(@analytics).to have_logged_event(
        'Invalid Authenticity Token',
        controller: 'users/sessions#create',
      )
      expect(response).to redirect_to new_user_session_url
      expect(flash[:error]).to eq t('errors.general')
    end

    it 'returns to sign in page if email is a Hash' do
      post :create, params: { user: { email: { foo: 'bar' }, password: 'password' } }

      expect(response).to render_template(:new)
    end

    it 'does not allow signing in with empty email' do
      post :create, params: { user: { email: '', password: 'foo' } }

      expect(flash[:alert])
        .to eq t(
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

      expect(flash[:alert])
        .to eq t(
          'devise.failure.invalid_html',
          link_html: link_to(
            t('devise.failure.invalid_link_text'),
            new_user_password_url,
          ),
        )
    end

    it 'does not allow signing in with empty password' do
      post :create, params: { user: { email: 'test@example.com', password: '' } }

      expect(flash[:alert])
        .to eq t(
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

      expect(flash[:alert])
        .to eq t(
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

        stub_analytics(user:)

        post :create, params: { user: { email: user.email, password: user.password } }

        expect(@analytics).to have_logged_event(
          'Email and Password Authentication',
          success: true,
          user_locked_out: false,
          rate_limited: false,
          valid_captcha_result: true,
          captcha_validation_performed: false,
          sign_in_failure_count: 0,
          sp_request_url_present: false,
          remember_device: true,
          new_device: true,
        )
      end
    end

    context 'with remember_device cookie present but expired' do
      it 'only tracks the cookie presence in analytics' do
        user = create(:user, :fully_registered)

        cookies.encrypted[:remember_device] = {
          value: RememberDeviceCookie.new(user_id: user.id, created_at: 2.days.ago).to_json,
        }

        stub_analytics(user:)

        post :create, params: { user: { email: user.email, password: user.password } }

        expect(@analytics).to have_logged_event(
          'Email and Password Authentication',
          success: true,
          user_locked_out: false,
          rate_limited: false,
          valid_captcha_result: true,
          captcha_validation_performed: false,
          sign_in_failure_count: 0,
          sp_request_url_present: false,
          remember_device: true,
          new_device: true,
        )
      end
    end

    context 'with user that is up to date with rules of use' do
      let(:rules_of_use_updated_at) { 1.day.ago }
      let(:accepted_terms_at) { 12.hours.ago }
      let(:user) { create(:user, :fully_registered, accepted_terms_at: accepted_terms_at) }

      before do
        allow(IdentityConfig.store).to receive(:rules_of_use_updated_at)
          .and_return(rules_of_use_updated_at)
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
        allow(IdentityConfig.store).to receive(:rules_of_use_updated_at)
          .and_return(rules_of_use_updated_at)
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
        allow(IdentityConfig.store).to receive(:rules_of_use_horizon_years)
          .and_return(rules_of_use_horizon_years)
        allow(IdentityConfig.store).to receive(:rules_of_use_updated_at)
          .and_return(rules_of_use_updated_at)
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

    context 'with Duplicate SSN feature check enabled' do 
      let(:user) { create(:user, :proofed_with_selfie) }

      subject(:response) do
        post :create, params: { user: { email: user.email, password: user.password } }
      end
      
      context 'sp not eligible for duplicate ssn check' do
        before do
          allow(IdentityConfig.store).to receive(:eligible_one_account_providers).and_return(['badSP'])
        end

        it 'tracks the successful authentication for existing user' do
          stub_analytics(user:)
          expect(@attempts_api_tracker).to receive(:email_and_password_auth).with(
            success: true,
          )
  
          response
  
          expect(@analytics).to have_logged_event(
            'Email and Password Authentication',
            success: true,
            user_locked_out: false,
            rate_limited: false,
            valid_captcha_result: true,
            captcha_validation_performed: false,
            sign_in_failure_count: 0,
            sp_request_url_present: false,
            remember_device: false,
            new_device: true,
          )
        end
  

        it 'does not create a duplicate profile confirmation' do

        end
      end

      context 'sp eligible for duplicate SSN check' do
        context 'user has valid IAL2 Profile' do
          context 'user was found with multiple profiles matching SSN' do

          end

          context 'user profile has unique SSN' do

          end
        end

        context 'user does not have valid IAL2 Profile' do
          
        end
      end
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

        get :new

        expect(@analytics).to have_logged_event(
          'Sign in page visited',
          flash: 'hello',
        )
        expect(subject.session[:sign_in_page_visited_at]).to_not be(nil)
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
        email = Faker::Internet.email
        password = SecureRandom.uuid

        get :new, params: { user: { email: email, password: password } }

        doc = Nokogiri::HTML(response.body)

        expect(doc.at_css('input[name="user[email]"]')[:value]).to be_nil
        expect(doc.at_css('input[name="user[password]"]')[:value]).to be_nil
      end
    end
  end
end
