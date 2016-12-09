require 'rails_helper'

describe TwoFactorAuthentication::RecoveryCodeController do
  describe '#show' do
    it 'generates a new recovery code' do
      stub_sign_in
      generator = instance_double(RecoveryCodeGenerator)
      allow(RecoveryCodeGenerator).to receive(:new).
        with(subject.current_user).and_return(generator)

      expect(generator).to receive(:create)

      get :show
    end

    it 'redirects to the profile page' do
      stub_sign_in
      subject.current_user.recovery_code = 'foo'

      post :acknowledge

      expect(response).to redirect_to profile_path
    end

    context 'when there is no session (signed out or locked out), and the user reloads the page' do
      it 'redirects to the home page' do
        expect(controller.user_session).to be_nil

        get :show

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'LOA3 user' do
      it 're-encrypts PII using new code' do
        profile = create(:profile, :active, :verified, pii: { ssn: '1234' })
        user = profile.user
        stub_sign_in(user)

        generator = RecoveryCodeGenerator.new(user)
        allow(RecoveryCodeGenerator).to receive(:new).and_return(generator)

        user.unlock_user_access_key(user.password)
        cacher = Pii::Cacher.new(user, subject.user_session)
        cacher.save(user.user_access_key, profile)
        allow(Pii::Cacher).to receive(:new).and_return(cacher)

        expect(user.active_profile).to receive(:save!).and_call_original

        get :show
      end
    end
  end
end
