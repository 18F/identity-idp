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
  end
end
