require 'rails_helper'

describe SignUp::RecoveryCodesController do
  describe '#update' do
    it 'redirects to the profile page' do
      stub_sign_in
      subject.current_user.recovery_code = 'foo'

      patch :update

      expect(response).to redirect_to profile_path
    end
  end
end
