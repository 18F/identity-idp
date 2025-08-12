require 'rails_helper'

RSpec.describe ApplicationController do
  describe '#disable_caching' do
    controller do
      def index
        render plain: 'Hello'
      end
    end

    it 'sets headers to disable cache' do
      get :index

      expect(response.headers['Cache-Control']).to eq 'no-store'
      expect(response.headers['Pragma']).to eq 'no-cache'
    end
  end

  describe '#cache_issuer_in_cookie' do
    controller do
      def index
        render plain: 'Hello'
      end
    end

    context 'with a current_sp' do
      let(:sp) { create(:service_provider, issuer: 'urn:gov:gsa:openidconnect:sp:test_cookie') }
      before do
        allow(controller).to receive(:current_sp).and_return(sp)
      end

      it 'sets sets the cookie sp_issuer' do
        get :index

        controller_set_cookies = controller.send(:cookies).instance_variable_get(:@set_cookies)
        cookie_expiration = controller_set_cookies['sp_issuer'][:expires]

        expect(cookies[:sp_issuer]).to eq(sp.issuer)
        expect(cookie_expiration).to be_within(3.seconds).of(
          IdentityConfig.store.session_timeout_in_seconds.seconds.from_now,
        )
      end
    end

    context 'without a current_sp' do
      before do
        cookies[:sp_issuer] = 'urn:gov:gsa:openidconnect:sp:test_cookie'
      end

      it 'clears the cookie sp_issuer' do
        get :index

        expect(cookies[:sp_issuer]).to be_nil
      end
    end
  end

  #
  # We don't test *every* exception we try to capture since we handle all such exceptions the same
  # way. This test doesn't ensure we have the right set of exceptions caught, but that, if caught,
  # we handle the exception with the proper response.
  #
  describe 'handling RequestTimeoutException exceptions' do
    controller do
      def index
        raise Rack::Timeout::RequestTimeoutException, {}
      end
    end

    it 'returns a proper status' do
      get :index

      expect(response.status).to eq 503
    end

    it 'returns an html page' do
      get :index

      expect(response.media_type).to eq 'text/html'
    end
  end

  describe 'handling InvalidAuthenticityToken exceptions' do
    controller do
      def index
        raise ActionController::InvalidAuthenticityToken
      end
    end

    it 'tracks the InvalidAuthenticityToken event and does not sign the user out' do
      sign_in_as_user
      expect(subject.current_user).to be_present
      stub_analytics

      get :index

      expect(@analytics).to have_logged_event(
        'Invalid Authenticity Token',
        controller: 'anonymous#index',
        user_signed_in: true,
      )
      expect(flash[:error]).to eq t('errors.general')
      expect(response).to redirect_to(root_url)
      expect(subject.current_user).to be_present
    end

    it 'redirects back to referer if present and is not external' do
      referer = login_piv_cac_url

      request.env['HTTP_REFERER'] = referer

      get :index

      expect(response).to redirect_to(referer)
    end

    it 'redirects back to home page if present and referer is external' do
      referer = 'http://testing.example.com'

      request.env['HTTP_REFERER'] = referer

      get :index

      expect(response).to redirect_to(new_user_session_url)
    end

    it 'redirects back to home page if present and referer is invalid' do
      referer = '@@ABC'

      request.env['HTTP_REFERER'] = referer

      get :index

      expect(response).to redirect_to(new_user_session_url)
    end
  end

  describe 'handling UnsafeRedirectError exceptions' do
    controller do
      def index
        raise ActionController::Redirecting::UnsafeRedirectError
      end
    end

    it 'tracks the Unsafe Redirect event and does not sign the user out' do
      referer = '@@ABC'
      request.env['HTTP_REFERER'] = referer
      sign_in_as_user
      expect(subject.current_user).to be_present
      stub_analytics

      get :index

      expect(@analytics).to have_logged_event(
        'Unsafe Redirect',
        controller: 'anonymous#index',
        user_signed_in: true,
        referer:,
      )
      expect(flash[:error]).to eq t('errors.general')
      expect(response).to redirect_to(root_url)
      expect(subject.current_user).to be_present
    end

    it 'redirects back to home page' do
      get :index

      expect(response).to redirect_to(new_user_session_url)
    end
  end

  describe '#append_info_to_payload' do
    let(:payload_controller) { 'Users::SessionsController' }
    let(:action) { 'new' }
    let(:payload) { { controller: payload_controller, action: } }
    let(:user) { create(:user) }
    let(:git_sha) { 'example_sha' }
    let(:git_branch) { 'example_branch' }

    before do
      allow(controller).to receive(:analytics_user).and_return(user)
      stub_const('IdentityConfig::GIT_SHA', git_sha)
      stub_const('IdentityConfig::GIT_BRANCH', git_branch)
    end

    it 'adds user_uuid and git metadata to the lograge output' do
      controller.append_info_to_payload(payload)

      expect(payload).to eq(
        controller: payload_controller, action:, user_id: user.uuid, git_sha:, git_branch:,
      )
    end

    describe 'lograge ignored actions' do
      let(:ignore_actions) {}

      before do
        allow(Lograge.lograge_config).to receive(:ignore_actions).and_return(ignore_actions)
      end

      context 'without configured ignored actions' do
        let(:ignore_actions) { nil }

        it 'adds metadata to the lograge output' do
          controller.append_info_to_payload(payload)

          expect(payload).to eq(
            controller: payload_controller, action:, user_id: user.uuid, git_sha:, git_branch:,
          )
        end
      end

      context 'with configured ignored actions' do
        let(:ignore_actions) { ['Users::SessionsController#update'] }

        context 'for a payload that should not be ignored' do
          it 'adds metadata to the lograge output' do
            controller.append_info_to_payload(payload)

            expect(payload).to eq(
              controller: payload_controller, action:, user_id: user.uuid, git_sha:, git_branch:,
            )
          end
        end

        context 'with a payload that should be ignored' do
          let(:action) { 'update' }

          it 'does not add metadata to the lograge output' do
            controller.append_info_to_payload(payload)

            expect(payload).to eq(controller: payload_controller, action:)
          end
        end
      end
    end
  end

  describe '#confirm_two_factor_authenticated' do
    controller do
      before_action :confirm_two_factor_authenticated

      def index
        render plain: 'Hello'
      end
    end

    context 'not signed in' do
      it 'redirects to sign in page' do
        get :index

        expect(response).to redirect_to root_url
      end
    end

    context 'is not 2FA-enabled' do
      it 'redirects to phone_setup_url with a flash message' do
        user = create(:user)
        sign_in user

        get :index

        expect(response).to redirect_to authentication_methods_setup_url
      end
    end

    context 'is 2FA-enabled' do
      it 'prompts user to enter their OTP' do
        sign_in_before_2fa

        get :index

        expect(response).to redirect_to user_two_factor_authentication_url
      end
    end
  end

  describe '#analytics' do
    context 'when a current_user is present' do
      it 'calls the Analytics class by default with current_user, request, and issuer' do
        user = build_stubbed(:user)
        sp = ServiceProvider.new(issuer: 'http://localhost:3000')
        allow(controller).to receive(:analytics_user).and_return(user)
        allow(controller).to receive(:current_sp).and_return(sp)

        expect(Analytics).to receive(:new)
          .with(user: user, request: request, sp: sp.issuer, session: match_array({}),
                ahoy: controller.ahoy)

        controller.analytics
      end
    end

    context 'when a current_user is not present' do
      it 'calls the Analytics class with AnonymousUser.new and request parameters' do
        allow(controller).to receive(:current_user).and_return(nil)

        user = instance_double(AnonymousUser)
        allow(AnonymousUser).to receive(:new).and_return(user)

        expect(Analytics).to receive(:new)
          .with(user: user, request: request, sp: nil, session: match_array({}),
                ahoy: controller.ahoy)

        controller.analytics
      end
    end

    context 'when a current_sp is not present' do
      it 'does not perform a DB lookup' do
        expect(ServiceProvider).to_not receive(:find_by)

        controller.analytics
      end
    end
  end

  describe '#create_user_event' do
    let(:user) { create(:user) }

    context 'when the user is not specified' do
      it 'creates an Event object for the current_user' do
        allow(subject).to receive(:current_user).and_return(user)

        subject.create_user_event(:account_created)

        expect_user_event_to_have_been_created(user, 'account_created')
      end
    end

    context 'when the user is specified' do
      it 'creates an Event object for the specified user' do
        subject.create_user_event(:account_created, user)

        expect_user_event_to_have_been_created(user, 'account_created')
      end
    end
  end

  describe '#session_expires_at' do
    before { routes.draw { get 'index' => 'anonymous#index' } }
    after { Rails.application.reload_routes! }

    controller do
      prepend_before_action :session_expires_at

      def index
        render plain: 'Hello'
      end
    end

    context 'when URL contains the host parameter' do
      it 'does not redirect to the host' do
        get :index, params: { timeout: true, host: 'www.monfresh.com' }

        expect(response.header['Location']).to_not match 'www.monfresh.com'
      end
    end

    context 'when URL does not contain the timeout parameter' do
      it 'does not redirect anywhere' do
        get :index, params: { host: 'www.monfresh.com' }

        expect(response).to_not be_redirect
      end
    end

    context 'when URL contains the request_id parameter' do
      it 'preserves the request_id parameter' do
        get :index, params: { timeout: true, request_id: '123' }

        expect(response.header['Location']).to match '123'
      end
    end
  end

  describe '#skip_session_commit' do
    controller do
      before_action :skip_session_commit
      def index
        render plain: 'Hello'
      end
    end

    it 'tells rack not to commit session' do
      get :index
      expect(request.session_options[:skip]).to eql(true)
    end
  end

  describe '#redirect_with_flash_if_timeout' do
    before { routes.draw { get 'index' => 'anonymous#index' } }
    after { Rails.application.reload_routes! }

    controller do
      def index
        render plain: 'Hello'
      end
    end
    let(:user) { build_stubbed(:user) }

    context 'with session timeout parameter' do
      it 'logs an event' do
        stub_analytics
        stub_attempts_tracker
        expect(@attempts_api_tracker).to receive(:session_timeout)

        get :index, params: { timeout: 'session', request_id: '123' }

        expect(@analytics).to have_logged_event('Session Timed Out')
      end

      it 'displays flash message for session timeout' do
        get :index, params: { timeout: 'session', request_id: '123' }

        expect(flash[:info]).to eq t(
          'notices.session_timedout',
          app_name: APP_NAME,
          minutes: IdentityConfig.store.session_timeout_in_seconds.seconds.in_minutes.to_i,
        )
      end
    end

    context 'when the current user is present' do
      it 'does not display flash message' do
        allow(subject).to receive(:current_user).and_return(user)

        get :index, params: { timeout: 'form', request_id: '123' }

        expect(flash[:info]).to be_nil
      end
    end

    it 'returns a 400 bad request when a url generation error is raised on the redirect' do
      allow_any_instance_of(ApplicationController).to \
        receive(:redirect_to).and_raise(ActionController::UrlGenerationError.new('bad request'))
      allow(subject).to receive(:current_user).and_return(user)

      get :index, params: { timeout: 'form', request_id: '123' }

      expect(response).to be_bad_request
    end

    context 'when there is no current user' do
      it 'displays a flash message' do
        allow(subject).to receive(:current_user).and_return(nil)

        get :index, params: { timeout: 'form', request_id: '123' }

        expect(flash[:info]).to eq t(
          'notices.session_cleared',
          minutes: IdentityConfig.store.session_timeout_in_seconds.seconds.in_minutes.to_i,
        )
      end
    end
  end

  describe '#sign_out' do
    it 'deletes the ahoy_visit cookie when signing out' do
      expect(request.cookie_jar).to receive(:delete).with('ahoy_visit')

      subject.sign_out
    end
  end

  describe '#resolved_authn_context_result' do
    let(:sp) { build(:service_provider, ial: 2) }

    let(:sp_session) { { vtr: vtr, acr_values: acr_values } }

    let(:result) { subject.resolved_authn_context_result }

    before do
      allow(controller).to receive(:sp_from_sp_session).and_return(sp)
      allow(controller).to receive(:sp_session).and_return(sp_session)
    end

    context 'when using acr values' do
      let(:vtr) { nil }
      let(:acr_values) do
        [
          Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
        ].join(' ')
      end

      it 'returns a resolved authn context result' do
        expect(result.aal2?).to eq(true)
        expect(result.identity_proofing?).to eq(true)
      end

      context 'when an unknown acr value is passed in' do
        let(:acr_values) { 'unknown-acr-value' }

        it 'raises an exception' do
          expect { result }.to raise_exception(
            Vot::Parser::ParseException,
            'VoT parser called without VoT or ACR values',
          )
        end

        context 'with a known acr value' do
          let(:acr_values) do
            [
              Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
              'unknown-acr-value',
            ].join(' ')
          end

          it 'returns a resolved authn context result' do
            expect(result.aal2?).to eq(true)
            expect(result.identity_proofing?).to eq(true)
          end
        end
      end

      context 'without an SP' do
        let(:sp) { nil }
        let(:sp_session) { nil }

        it 'returns a no-SP result' do
          expect(result).to eq(Vot::Parser::Result.no_sp_result)
        end
      end
    end

    context 'when using vot values' do
      let(:acr_values) { nil }
      let(:vtr) { ['P1'] }

      it 'returns a resolved authn context result' do
        expect(result.aal2?).to eq(true)
        expect(result.identity_proofing?).to eq(true)
      end

      context 'without an SP' do
        let(:sp) { nil }
        let(:sp_session) { nil }

        it 'returns a no-SP result' do
          expect(result).to eq(Vot::Parser::Result.no_sp_result)
        end
      end
    end
  end

  describe '#sp_session_request_url_with_updated_params' do
    controller do
      def index
        render plain: 'Hello'
      end
    end

    before do
      allow(controller).to receive(:session)
        .and_return(sp: { request_url: sp_session_request_url })
    end

    subject(:url_with_updated_params) do
      controller.send(:sp_session_request_url_with_updated_params)
    end

    let(:sp_session_request_url) { nil }

    it 'leaves a nil url alone' do
      expect(url_with_updated_params).to eq(nil)
    end

    context 'with a SAML request' do
      let(:sp_session_request_url) { '/api/saml/auth2025' }
      it 'returns the saml completion url' do
        expect(url_with_updated_params).to eq complete_saml_url
      end

      context 'updates the sp_session to mark the final auth request' do
        it 'updates the sp_session to mark the final auth request' do
          url_with_updated_params
          expect(controller.session[:sp][:final_auth_request]).to be true
        end
      end
    end

    context 'with an OIDC request' do
      let(:sp_session_request_url) { '/openid_connect/authorize' }
      it 'returns the original request' do
        expect(url_with_updated_params).to eq '/openid_connect/authorize'
      end
    end

    context 'when the locale has been changed' do
      before { I18n.locale = :es }
      let(:sp_session_request_url) { '/authorize' }
      it 'adds the locale to the url' do
        expect(url_with_updated_params).to eq('/authorize?locale=es')
      end
    end
  end

  describe '#user_duplicate_profiles_detected?' do
    controller do
      def index
        render plain: user_duplicate_profiles_detected?.to_s
      end
    end

    let(:user) { create(:user) }
    let(:issuer) { 'https://example.gov' }

    let(:sp) { create(:service_provider, ial: 2, issuer: issuer) }

    before do
      sign_in user
      allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
        .and_return([issuer])
      allow(controller).to receive(:sp_from_sp_session)
        .and_return(sp)

      allow(controller).to receive(:user_in_one_account_verification_bucket?).and_return(true)
    end

    context 'when SP is not eligible for one account' do
      let(:issuer2) { 'wrong.com' }
      let(:sp) { create(:service_provider, ial: 2, issuer: issuer2) }
      before do
      end

      it 'returns false' do
        get :index
        expect(response.body).to eq('false')
      end

      it 'returns false even with duplicate profile confirmations' do
        profile = create(:profile, :active, user: user)
        create(:duplicate_profile_confirmation, profile: profile, confirmed_all: nil)

        get :index
        expect(response.body).to eq('false')
      end
    end

    context 'when SP is eligible for one account' do
      context 'when user has no active profile' do
        it 'returns false' do
          get :index
          expect(response.body).to eq('false')
        end
      end

      context 'when user has active profile' do
        let!(:active_profile) { create(:profile, :active, user: user) }

        context 'when no duplicate profile ids found in session' do
          it 'returns false' do
            get :index
            expect(response.body).to eq('false')
          end
        end
        context 'when duplicate profile ids found in session' do
          before do
            controller.user_session[:duplicate_profile_ids] = [active_profile.id]
          end

          it 'returns true' do
            get :index
            expect(response.body).to eq('true')
          end
        end
      end
    end
  end

  describe '#sp_eligible_for_one_account?' do
    controller do
      def index
        render plain: sp_eligible_for_one_account?.to_s
      end
    end

    let(:result) { controller.sp_eligible_for_one_account? }
    let(:user) { create(:user) }
    let(:issuer) { 'https://example.gov' }

    let(:sp) { create(:service_provider, ial: 2, issuer: issuer) }

    before do
      sign_in user
      allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
        .and_return([issuer])
      allow(controller).to receive(:sp_from_sp_session)
        .and_return(sp)
    end

    context 'when SP issuer is in eligible providers list' do
      it 'returns true' do
        get :index
        expect(response.body).to eq('true')
      end
    end

    context 'when SP issuer is not in eligible providers list' do
      let(:issuer2) { 'wrong.com' }
      let(:sp) { create(:service_provider, ial: 2, issuer: issuer2) }

      it 'returns false' do
        get :index
        expect(response.body).to eq('false')
      end
    end

    context 'when sp_from_sp_session returns nil' do
      before do
        allow(controller).to receive(:sp_from_sp_session).and_return(nil)
      end

      it 'returns false' do
        get :index
        expect(response.body).to eq('false')
      end
    end
  end

  describe '#attempts_api_tracker' do
    let(:enabled) { true }
    let(:sp) { create(:service_provider) }
    let(:user) { create(:user) }

    before do
      expect(IdentityConfig.store).to receive(:attempts_api_enabled).and_return enabled
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:current_sp).and_return(sp)
    end

    context 'when the attempts api is not enabled' do
      let(:enabled) { false }

      it 'calls the AttemptsApi::Tracker class with enabled_for_session set to false' do
        expect(AttemptsApi::Tracker).to receive(:new).with(
          user:, request:, sp:, session_id: nil,
          cookie_device_uuid: nil, sp_request_uri: nil, enabled_for_session: false
        )

        controller.attempts_api_tracker
      end
    end

    context 'when attempts api is enabled' do
      context 'when the service provider is not authorized' do
        before do
          expect(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return([])
        end

        it 'calls the AttemptsApi::Tracker class with enabled_for_session set to false' do
          expect(AttemptsApi::Tracker).to receive(:new).with(
            user:, request:, sp:, session_id: nil,
            cookie_device_uuid: nil, sp_request_uri: nil, enabled_for_session: false
          )

          controller.attempts_api_tracker
        end
      end

      context 'when the service provider is authorized' do
        before do
          expect(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return(
            [
              {
                'issuer' => sp.issuer,
              },
            ],
          )
        end

        context 'when there is no attempts_api_session_id' do
          it 'calls the AttemptsApi::Tracker class with enabled_for_session set to false' do
            expect(AttemptsApi::Tracker).to receive(:new).with(
              user:, request:, sp:, session_id: nil,
              cookie_device_uuid: nil, sp_request_uri: nil, enabled_for_session: false
            )

            controller.attempts_api_tracker
          end
        end

        context 'when there is an attempts_api_session_id' do
          before do
            expect(controller.decorated_sp_session).to receive(:attempts_api_session_id)
              .and_return('abc123')
          end
          it 'calls the AttemptsApi::Tracker class with enabled_for_session set to true' do
            expect(AttemptsApi::Tracker).to receive(:new).with(
              user:, request:, sp:, session_id: 'abc123',
              cookie_device_uuid: nil, sp_request_uri: nil, enabled_for_session: true
            )

            controller.attempts_api_tracker
          end
        end
      end
    end
  end

  def expect_user_event_to_have_been_created(user, event_type)
    device = Device.first
    expect(device.user_id).to eq(user.id)
    event = Event.first
    expect(event.event_type).to eq(event_type)
    expect(event.device_id).to eq(device.id)
  end
end
