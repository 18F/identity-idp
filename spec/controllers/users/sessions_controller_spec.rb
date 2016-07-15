require 'rails_helper'

include ActionView::Helpers::DateHelper

describe Users::SessionsController, devise: true do
  render_views

  describe 'GET /users/sign_in' do
    it 'sets the autocomplete attribute to off on the sign in form' do
      get :new

      expect(response.body).to include('<form autocomplete="off"')
    end
  end

  describe 'GET /active' do
    context 'when user is present' do
      before do
        sign_in_as_user

        get :active
      end

      it 'returns a 200 status code' do
        expect(response.status).to eq(200)
      end

      it 'clears the Etag header' do
        expect(response.headers['Etag']).to eq ''
      end

      it 'renders json' do
        expect(response.content_type).to eq('application/json')
      end

      it 'sets the timeout key to nil' do
        get :active

        json ||= JSON.parse(response.body)

        expect(json['timeout']).to be_nil
      end
    end

    context 'when user is not present' do
      it 'sets live key to false' do
        get :active

        json ||= JSON.parse(response.body)

        expect(json['live']).to eq false
      end
    end

    context 'when user is present' do
      it 'sets live key to true' do
        sign_in_as_user
        get :active

        json ||= JSON.parse(response.body)

        expect(json['live']).to eq true
      end
    end
  end

  describe 'GET /timeout' do
    it 'signs the user out' do
      sign_in_as_user

      get :timeout

      expect(response.request.env['rack.session']['flash']['flashes']).to(
        have_text(
          t('session_timedout',
            session_timeout: distance_of_time_in_words(Devise.timeout_in))
        )
      )
    end

    it 'redirects to the homepage' do
      sign_in_as_user

      get :timeout

      expect(response).to redirect_to(root_url)
    end
  end

  describe 'POST /' do
    it 'calls User#send_two_factor_authentication_code' do
      create(:user, :signed_up, email: 'user@example.com')

      expect_any_instance_of(User).to receive(:send_two_factor_authentication_code)

      post :create, user: { email: 'user@example.com', password: '!1aZ' * 32 }
    end

    it 'tracks the authentication for existing user' do
      user = create(:user, :signed_up)

      stub_analytics(user)
      expect(@analytics).to receive(:track_event).with('Authentication Attempt', user)
      expect(@analytics).to receive(:track_event).with('Authentication Successful')

      post :create, user: { email: user.email, password: user.password }
    end

    it 'tracks the authentication attempt for nonexistent user' do
      stub_analytics
      expect(@analytics).to receive(:track_anonymous_event).
        with('Authentication Attempt with nonexistent user')
      expect(@analytics).to_not receive(:track_event).with('Authentication Successful')

      post :create, user: { email: 'foo@example.com', password: 'password' }
    end
  end
end
