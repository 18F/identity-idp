require 'rails_helper'

describe SignUp::PersonalKeysController do
  describe '#show' do
    it 'tracks an analytics event' do
      stub_analytics
      stub_sign_in
      subject.user_session[:first_time_personal_key_view] = 'true'

      expect(@analytics).to receive(:track_event).with(
        Analytics::USER_REGISTRATION_PERSONAL_KEY_VISIT
      )

      get :show
    end

    it 'redirects the user on subsequent views' do
      stub_sign_in
      subject.user_session[:first_time_personal_key_view] = 'true'

      expect(get(:show)).not_to redirect_to(account_path)
      expect(get(:show)).to redirect_to(account_path)
    end

    it 're-encrypts PII with new code if active profile exists' do
      user = stub_sign_in
      profile = create(:profile, :active, :verified, pii: { ssn: '1234' }, user: user)
      subject.user_session[:decrypted_pii] = { ssn: '1234' }.to_json
      subject.user_session[:first_time_personal_key_view] = 'true'

      old_encrypted_pii = profile.encrypted_pii_recovery

      get :show

      expect(profile.reload.encrypted_pii_recovery).to_not eq old_encrypted_pii
    end
  end

  describe '#update' do
    context 'sp present' do
      it 'redirects to the sign up completed url' do
        subject.session[:sp] = 'true'
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
      subject.session[:sp] = 'true'
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
  end
end
