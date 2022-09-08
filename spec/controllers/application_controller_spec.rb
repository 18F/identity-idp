require 'rails_helper'

describe ApplicationController do
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

  describe '#set_x_request_url' do
    controller do
      def index
        render plain: 'Hello'
      end
    end

    it 'sets the X-Request-URL header' do
      get :index

      expect(response.headers['X-Request-URL']).to eq('http://www.example.com/anonymous')
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
        expect(cookie_expiration).to be_within(3.seconds).of(15.minutes.from_now)
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
      event_properties = { controller: 'anonymous#index', user_signed_in: true }
      expect(@analytics).to receive(:track_event).
        with('Invalid Authenticity Token', event_properties)

      get :index

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
      event_properties = { controller: 'anonymous#index', user_signed_in: true, referer: referer }
      expect(@analytics).to receive(:track_event).
        with('Unsafe Redirect', event_properties)

      get :index

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
    let(:payload) { {} }
    let(:user) { create(:user) }

    before do
      allow(controller).to receive(:analytics_user).and_return(user)
    end

    it 'adds user_uuid and git metadata to the lograge output' do
      stub_const(
        'IdentityConfig::GIT_BRANCH',
        'my branch',
      )

      controller.append_info_to_payload(payload)

      expect(payload).to eq(
        user_id: user.uuid,
        git_sha: IdentityConfig::GIT_SHA,
        git_branch: IdentityConfig::GIT_BRANCH,
      )
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

        expect(Analytics).to receive(:new).
          with(user: user, request: request, sp: sp.issuer, session: match_array({}),
               ahoy: controller.ahoy)

        controller.analytics
      end
    end

    context 'when a current_user is not present' do
      it 'calls the Analytics class with AnonymousUser.new and request parameters' do
        allow(controller).to receive(:current_user).and_return(nil)

        user = instance_double(AnonymousUser)
        allow(AnonymousUser).to receive(:new).and_return(user)

        expect(Analytics).to receive(:new).
          with(user: user, request: request, sp: nil, session: match_array({}),
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

  describe '#redirect_on_timeout' do
    before { routes.draw { get 'index' => 'anonymous#index' } }
    after { Rails.application.reload_routes! }

    controller do
      def index
        render plain: 'Hello'
      end
    end
    let(:user) { build_stubbed(:user) }

    context 'when the current user is present' do
      it 'does not display flash message' do
        allow(subject).to receive(:current_user).and_return(user)

        get :index, params: { timeout: true, request_id: '123' }

        expect(flash[:info]).to be_nil
      end
    end

    it 'returns a 400 bad request when a url generation error is raised on the redirect' do
      allow_any_instance_of(ApplicationController).to \
        receive(:redirect_to).and_raise(ActionController::UrlGenerationError.new('bad request'))
      allow(subject).to receive(:current_user).and_return(user)

      get :index, params: { timeout: true, request_id: '123' }

      expect(response).to be_bad_request
    end

    context 'when there is no current user' do
      it 'displays a flash message' do
        allow(subject).to receive(:current_user).and_return(nil)

        get :index, params: { timeout: true, request_id: '123' }

        expect(flash[:info]).to eq t(
          'notices.session_cleared',
          minutes: IdentityConfig.store.session_timeout_in_minutes,
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

  describe '#sp_session_request_url_with_updated_params' do
    controller do
      def index
        render plain: 'Hello'
      end
    end

    before do
      allow(controller).to receive(:session).
        and_return(sp: { request_url: sp_session_request_url })
    end

    subject(:url_with_updated_params) do
      controller.send(:sp_session_request_url_with_updated_params)
    end

    let(:sp_session_request_url) { nil }

    it 'leaves a nil url alone' do
      expect(url_with_updated_params).to eq(nil)
    end


    context 'with a SAML request' do
      let(:sp_session_request_url) { '/api/saml/auth2022' }
      it 'returns the saml completion url' do
        expect(url_with_updated_params).to eq complete_saml_url
      end
    end

    context 'with an OIDC request' do
      let(:sp_session_request_url) { '/openid_connect/authorize' }
      it 'returns the original request' do
        expect(url_with_updated_params).to eq '/openid_connect/authorize'
      end
    end

    context 'with a url that has prompt=login' do
      let(:sp_session_request_url) { '/authorize?prompt=login' }
      it 'changes it to prompt=select_account' do
        expect(url_with_updated_params).to eq('/authorize?prompt=select_account')
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

  def expect_user_event_to_have_been_created(user, event_type)
    device = Device.first
    expect(device.user_id).to eq(user.id)
    event = Event.first
    expect(event.event_type).to eq(event_type)
    expect(event.device_id).to eq(device.id)
  end
end
