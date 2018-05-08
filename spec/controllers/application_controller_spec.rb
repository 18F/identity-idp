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

      expect(response.content_type).to eq 'text/html'
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
        with(Analytics::INVALID_AUTHENTICITY_TOKEN, event_properties)

      get :index

      expect(flash[:error]).to eq t('errors.invalid_authenticity_token')
      expect(response).to redirect_to(root_url)
      expect(subject.current_user).to be_present
    end

    it 'redirects back to referer if present' do
      referer = 'http://example.com/sign_up/enter_email?request_id=123'

      request.env['HTTP_REFERER'] = referer

      get :index

      expect(response).to redirect_to(referer)
    end
  end

  describe '#append_info_to_payload' do
    let(:payload) { {} }

    it 'adds user_id, user_agent and ip to the lograge output' do
      Timecop.freeze(Time.zone.now) do
        subject.append_info_to_payload(payload)

        expect(payload.keys).to eq %i[user_id user_agent ip host]
        expect(payload.values).
          to eq ['anonymous-uuid', request.user_agent, request.remote_ip, request.host]
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

        expect(response).to redirect_to phone_setup_url
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

        expect(Analytics).to receive(:new).with(user: user, request: request, sp: sp.issuer)

        controller.analytics
      end
    end

    context 'when a current_user is not present' do
      it 'calls the Analytics class with AnonymousUser.new and request parameters' do
        allow(controller).to receive(:current_user).and_return(nil)

        user = instance_double(AnonymousUser)
        allow(AnonymousUser).to receive(:new).and_return(user)

        expect(Analytics).to receive(:new).with(user: user, request: request, sp: nil)

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
    let(:user) { build_stubbed(:user) }

    context 'when the user is not specified' do
      it 'creates an Event object for the current_user' do
        allow(subject).to receive(:current_user).and_return(user)

        expect(Event).to receive(:create).with(user_id: user.id, event_type: :account_created)

        subject.create_user_event(:account_created)
      end
    end

    context 'when the user is specified' do
      it 'creates an Event object for the specified user' do
        expect(Event).to receive(:create).with(user_id: user.id, event_type: :account_created)

        subject.create_user_event(:account_created, user)
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

        expect(flash[:notice]).to be_nil
      end
    end

    context 'when there is no current user' do
      it 'displays a flash message' do
        allow(subject).to receive(:current_user).and_return(nil)

        get :index, params: { timeout: true, request_id: '123' }

        expect(flash[:notice]).
          to eq t('notices.session_cleared', minutes: Figaro.env.session_timeout_in_minutes)
      end
    end
  end

  describe '#sign_out' do
    it 'deletes the ahoy_visit cookie when signing out' do
      expect(request.cookie_jar).to receive(:delete).with('ahoy_visit')

      subject.sign_out
    end
  end
end
