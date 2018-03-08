require 'rails_helper'

describe TwoFactorAuthentication::ResetDeviceController do
  describe '#show' do
    it 'redirects to the home page with no user' do
      expect(controller.user_session).to be_nil

      get :show

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'shows the normal page when the user is signed in' do
      sign_in_before_2fa
      get :show
      expect(response).to render_template(:show)
    end

    it 'redirect to phone setup if they are not two factor enabled' do
      sign_in_before_2fa
      user = subject.current_user
      allow(user).to receive(:two_factor_enabled?).and_return false
      get :show
      expect(response).to redirect_to(phone_setup_url)
    end
  end

  describe '#create' do
    it 'redirects to the home page with no user' do
      post :create

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'creates reset device request and logs analytics event' do
      sign_in_before_2fa
      stub_analytics
      allow(@analytics).to receive(:track_event)
      user = subject.current_user

      expect(@analytics).to(
        receive(:track_event).with(Analytics::RESET_DEVICE_REQUESTED)
      )

      post :create

      expect(reset_device_requested_at(user)).to be_present
      expect(response).to redirect_to(new_user_session_path)
      expect(flash.now[:success]).to(
        eq t('devise.two_factor_authentication.reset_device.success_message')
      )
    end
  end

  private

  def reset_device_requested_at(user)
    ChangePhoneRequest.find_by(user_id: user.id).requested_at
  end
end
