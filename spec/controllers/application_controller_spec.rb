require 'rails_helper'

describe ApplicationController do
  describe 'handling InvalidAuthenticityToken exceptions' do
    controller do
      def index
        raise ActionController::InvalidAuthenticityToken
      end
    end

    it 'tracks the InvalidAuthenticityToken event and signs user out' do
      sign_in_as_user
      expect(subject.current_user).to be_present

      stub_analytics
      expect(@analytics).to receive(:track_event).with('InvalidAuthenticityToken')

      get :index

      expect(flash[:error]).to eq t('errors.invalid_authenticity_token')
      expect(response).to redirect_to(root_url)
      expect(subject.current_user).to be_nil
    end
  end

  describe '#append_info_to_payload' do
    let(:payload) { {} }

    it 'adds time, user_agent and ip to the lograge output' do
      Timecop.freeze(Time.current) do
        subject.append_info_to_payload(payload)

        expect(payload.keys).to eq [:time, :user_agent, :ip]
        expect(payload.values).to eq [Time.current, request.user_agent, request.remote_ip]
      end
    end
  end

  describe '#confirm_two_factor_authenticated' do
    controller do
      before_action :confirm_two_factor_authenticated

      def index
        render text: 'Hello'
      end
    end

    context 'when the user is not signed in' do
      it 'redirects to sign in page' do
        get :index

        expect(response).to redirect_to root_url
      end
    end

    context 'when the user may bypass 2FA' do
      it 'returns nil' do
        sign_in_as_user

        user_decorator = instance_double(UserDecorator)

        allow(UserDecorator).to receive(:new).with(subject.current_user).
          and_return(user_decorator)
        allow(user_decorator).to receive(:may_bypass_2fa?).
          and_return(true)

        get :index

        expect(response.body).to eq 'Hello'
      end
    end

    context 'when the user may not bypass 2FA and is already two-factor authenticated' do
      it 'returns nil' do
        sign_in_as_user

        user_decorator = instance_double(UserDecorator)

        allow(UserDecorator).to receive(:new).with(subject.current_user).
          and_return(user_decorator)
        allow(user_decorator).to receive(:may_bypass_2fa?).
          and_return(false)

        get :index

        expect(response.body).to eq 'Hello'
      end
    end

    context 'when the user may not bypass 2FA and is not 2FA-enabled' do
      it 'redirects to phone_setup_url with a flash message' do
        user = create(:user)
        sign_in user

        user_decorator = instance_double(UserDecorator)

        allow(UserDecorator).to receive(:new).with(subject.current_user).
          and_return(user_decorator)
        allow(user_decorator).to receive(:may_bypass_2fa?).
          and_return(false)

        get :index

        expect(response).to redirect_to phone_setup_url
      end
    end

    context 'when the user may not bypass 2FA and is 2FA-enabled' do
      it 'prompts user to enter their OTP' do
        sign_in_before_2fa

        user_decorator = instance_double(UserDecorator)

        allow(UserDecorator).to receive(:new).with(subject.current_user).
          and_return(user_decorator)
        allow(user_decorator).to receive(:may_bypass_2fa?).
          and_return(false)

        get :index

        expect(response).to redirect_to user_two_factor_authentication_url
      end
    end
  end

  describe '#analytics' do
    context 'when a current_user is present' do
      it 'calls the Analytics class by default with current_user and request parameters' do
        user = build_stubbed(:user)
        allow(controller).to receive(:current_user).and_return(user)

        expect(Analytics).to receive(:new).with(user, request)

        controller.analytics
      end
    end

    context 'when a current_user is not present' do
      it 'calls the Analytics class with AnonymousUser.new and request parameters' do
        allow(controller).to receive(:current_user).and_return(nil)

        user = instance_double(AnonymousUser)
        allow(AnonymousUser).to receive(:new).and_return(user)

        expect(Analytics).to receive(:new).with(user, request)

        controller.analytics
      end
    end
  end

  describe 'after_action' do
    it 'includes the appropriate after_action' do
      expect(subject).to have_actions(
        :after,
        :track_get_requests
      )
    end
  end

  describe '#track_get_requests' do
    controller do
      def index
        render text: 'Hello'
      end
    end

    context 'when the request is a GET request' do
      it 'tracks the controller name and action' do
        stub_analytics

        expect(@analytics).to receive(:track_event).
          with('GET Request', controller: 'anonymous', action: 'index')

        get :index
      end
    end

    context 'when the request is not a GET request' do
      it 'does not track the controller name and action' do
        stub_analytics

        expect(@analytics).to_not receive(:track_event)

        put :index
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
end
