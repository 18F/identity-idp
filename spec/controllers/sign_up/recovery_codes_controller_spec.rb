require 'rails_helper'

describe SignUp::RecoveryCodesController do
  describe '#show' do
    it 'tracks an analytics event' do
      stub_analytics
      stub_sign_in
      subject.user_session[:first_time_recovery_code_view] = 'true'

      expect(@analytics).to receive(:track_event).with(
        Analytics::USER_REGISTRATION_RECOVERY_CODE_VISIT
      )

      get :show
    end
  end

  describe '#update' do
    it 'redirects to the profile page' do
      stub_sign_in
      subject.current_user.recovery_code = 'foo'

      patch :update

      expect(response).to redirect_to profile_path
    end
  end
end
