require 'rails_helper'

describe SignUp::PersonalKeysController do
  describe '#show' do
    it 'tracks an analytics event' do
      stub_analytics
      stub_sign_in

      expect(@analytics).to receive(:track_event).with(
        Analytics::USER_REGISTRATION_PERSONAL_KEY_VISIT,
      )

      get :show
    end

    it "does not reset the user's personal key on subsequent views" do
      user = build(:user)
      stub_sign_in(user)

      get :show
      personal_key = subject.user_session[:personal_key]

      expect(PersonalKeyGenerator.new(user).verify(personal_key)).to eq(true)

      get :show

      expect(subject.user_session[:personal_key]).to eq(personal_key)
      expect(PersonalKeyGenerator.new(user).verify(personal_key)).to eq(true)
    end
  end

  describe '#update' do
    context 'sp present' do
      it 'redirects to the sign up completed url' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')
        subject.session[:sp] = { issuer: sp.issuer, request_id: '123' }
        stub_sign_in

        patch :update

        expect(response).to redirect_to sign_up_completed_url
      end
    end

    context 'no sp present' do
      it 'redirects to the profile page' do
        stub_sign_in

        patch :update

        expect(response).to redirect_to account_path
      end
    end

    it 'tracks CSRF errors' do
      sp = ServiceProvider.from_issuer('http://localhost:3000')
      subject.session[:sp] = { issuer: sp.issuer, request_id: '123' }
      stub_sign_in
      stub_analytics
      analytics_hash = {
        controller: 'sign_up/personal_keys#update',
        user_signed_in: true,
      }
      allow(controller).to receive(:update).and_raise(ActionController::InvalidAuthenticityToken)

      expect(@analytics).to receive(:track_event).
        with(Analytics::INVALID_AUTHENTICITY_TOKEN, analytics_hash)

      patch :update

      expect(response).to redirect_to new_user_session_url
      expect(flash[:alert]).to eq t('errors.invalid_authenticity_token')
    end

    it 'deletes the personal key from the session' do
      stub_sign_in

      get :show

      expect(subject.user_session[:personal_key]).to_not be_nil

      patch :update

      expect(subject.user_session[:personal_key]).to be_nil
    end
  end
end
