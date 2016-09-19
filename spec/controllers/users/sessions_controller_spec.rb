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
        stub_sign_in

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

      it 'sets the timeout key' do
        get :active

        json ||= JSON.parse(response.body)

        expect(json['timeout']).to_not be_nil
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
        stub_sign_in
        session[:session_expires_at] = Time.current + 10
        get :active

        json ||= JSON.parse(response.body)

        expect(json['live']).to eq true
      end

      it 'respects session_expires_at' do
        stub_sign_in
        session[:session_expires_at] = Time.current - 1
        get :active

        json ||= JSON.parse(response.body)

        expect(json['live']).to eq false
      end

      it 'updates pinged_at session key' do
        stub_sign_in
        now = Time.current
        session[:pinged_at] = now

        Timecop.travel(Time.current + 10)
        get :active
        Timecop.return

        expect(session[:pinged_at]).to_not eq(now)
      end
    end

    it 'does not track analytics event' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to_not receive(:track_event)

      get :active
    end
  end

  describe 'GET /timeout' do
    it 'signs the user out' do
      sign_in_as_user

      expect(subject.current_user).to_not be_nil

      get :timeout

      expect(flash[:timeout]).to eq t('session_timedout')
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
      expect(@analytics).to receive(:track_event).with('GET request for sessions#timeout')

      get :timeout
    end
  end

  describe 'POST /' do
    it 'tracks the authentication for existing user' do
      user = create(:user, :signed_up)

      stub_analytics
      expect(@analytics).to receive(:track_event).with('Authentication Attempt', user_id: user.uuid)
      expect(@analytics).to receive(:track_event).with('Authentication Successful')

      post :create, user: { email: user.email.upcase, password: user.password }
    end

    it 'tracks the authentication attempt for nonexistent user' do
      stub_analytics
      expect(@analytics).to receive(:track_event).
        with('Authentication Attempt with nonexistent user')
      expect(@analytics).to_not receive(:track_event).with('Authentication Successful')

      post :create, user: { email: 'foo@example.com', password: 'password' }
    end
  end
end
