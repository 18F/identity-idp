require 'rails_helper'

describe TwoFactorAuthentication::CancelResetDeviceController do
  describe '#cancel' do
    before do
      sign_in_before_2fa
    end
    context 'with the user cancelling their own request' do
      it 'removes reset device request when there is one and logs analytics event' do
        stub_analytics
        allow(@analytics).to receive(:track_event)
        user = subject.current_user
        ResetDevice.new(user).create_request
        expect(request_token(user)).to be_present
        analytics_hash = {
          fraud: false,
          token_valid: true,
        }
        expect(@analytics).to(
          receive(:track_event).with(Analytics::RESET_DEVICE_CANCELLED, analytics_hash)
        )
        cancel(token: user.change_phone_request.request_token)
        expect(request_token(user)).to be_nil
        expect_successful_response
      end

      it 'gracefully handles cancelling a reset device request where the is no pending request' do
        user = subject.current_user
        expect(request_token(user)).to eq(nil)
        cancel(token: 'ABC')
        expect(request_token(user)).to eq(nil)
        expect_successful_response
      end

      it 'gracefully handles cancelling a reset device request where the is no token' do
        cancel
        expect_successful_response
      end
    end
  end
  context 'with the user cancelling and reporting fraud' do
    let(:user) { create(:user, :signed_up) }
    it 'removes reset device request when there is one and logs analytics event' do
      stub_analytics
      allow(@analytics).to receive(:track_event)
      ResetDevice.new(user).create_request

      expect(request_token(user)).to be_present
      analytics_hash = {
        fraud: true,
        token_valid: true,
      }
      expect(@analytics).to(
        receive(:track_event).with(Analytics::RESET_DEVICE_CANCELLED, analytics_hash)
      )

      get :cancel, params: { token: user.change_phone_request.request_token }

      expect(request_token(user)).to be_nil
      expect_successful_response
    end

    it 'gracefully handles cancelling a reset device request where the is no pending request' do
      expect(request_token(user)).to eq(nil)

      get :cancel, params: { token: 'ABC' }

      expect(request_token(user)).to eq(nil)
      expect_successful_response
    end

    it 'gracefully handles cancelling a reset device request where the is no token' do
      get :cancel
      expect_successful_response
    end
  end

  context 'when the token is present but not valid' do
    it 'logs the event' do
      stub_analytics
      allow(@analytics).to receive(:track_event)
      analytics_hash = {
        fraud: true,
        token_valid: false,
      }
      expect(@analytics).to(
        receive(:track_event).with(Analytics::RESET_DEVICE_CANCELLED, analytics_hash)
      )
      get :cancel, params: { token: 'ABC' }

      expect_successful_response
    end
  end

  def request_token(user)
    return unless user
    cpr = ChangePhoneRequest.find_by(user_id: user.id)
    return unless cpr
    cpr.request_token
  end

  def cancel(hash = {})
    hash[:only] = 1
    get :cancel, params: hash
  end

  def expect_successful_response
    expect(response).to redirect_to(new_user_session_path)
    expect(flash.now[:success]).to(
      eq t('devise.two_factor_authentication.reset_device.successful_cancel')
    )
  end
end
