require 'rails_helper'

describe KbaSecurityController do
  let(:user) { create(:user, :signed_up) }

  describe '#show' do
    it 'redirects if the token is blank' do
      get :show

      expect(response).to redirect_to(root_url)
    end

    it 'redirects if the token is bad' do
      get :show, params: { token: '123' }

      expect(response).to redirect_to(root_url)
    end

    it 'renders the page properly with a good token' do
      stub_sign_in(user)
      ResetDevice.new(user).grant_request

      get :show, params: { token: user.change_phone_request.granted_token }

      expect(response).to render_template :show
    end

    it 'redirects if the token is expired' do
      ResetDevice.new(user).grant_request
      Timecop.travel(Time.zone.now + (Figaro.env.reset_device_valid_for_hours.to_i * 3600)) do
        stub_sign_in(user)
        get :show, params: { token: user.change_phone_request.granted_token }
      end
      expect(response).to redirect_to(root_url)
    end

    it 'redirects if system reset device is disabled' do
      stub_sign_in(user)
      ResetDevice.new(user).grant_request
      allow(Figaro.env).to receive(:reset_device_enabled).and_return('false')

      get :show, params: { token: user.change_phone_request.granted_token }

      expect(response).to redirect_to(root_url)
    end
  end

  describe '#update' do
    it 'handles errors' do
      stub_sign_in(user)
      post :update, params: { kba_security_form: { answer: '-1' } }
      expect(flash[:error]).to eq I18n.t('kba_security.select_answer_error')
      expect(response).to redirect_to(change_phone_url)
    end

    it 'handles failure' do
      ResetDevice.new(user).grant_request
      stub_analytics
      allow(@analytics).to receive(:track_event)
      stub_sign_in(user)
      token = user.change_phone_request.granted_token
      analytics_hash = {
        success: false,
        errors: {},
        answer: '1',
      }
      expect(@analytics).to(
        receive(:track_event).with(Analytics::RESET_DEVICE_SECURITY_ANSWER, analytics_hash)
      )
      post :update, params: {
        kba_security_form: {
          token: token,
          errors: {},
          answer: '1',
        },
      }
      expect(flash[:error]).to eq I18n.t('kba_security.wrong_answer')
      expect(response).to redirect_to(root_url)
    end

    it 'handles success' do
      ResetDevice.new(user).grant_request
      stub_analytics
      allow(@analytics).to receive(:track_event)
      stub_sign_in(user)
      token = user.change_phone_request.granted_token
      analytics_hash = {
        success: true,
        errors: {},
        answer: '0',
      }
      expect(@analytics).to(
        receive(:track_event).with(Analytics::RESET_DEVICE_SECURITY_ANSWER, analytics_hash)
      )
      post :update, params: {
        kba_security_form: {
          token: token,
          answer: '0',
        },
      }
      expect(flash[:success]).to eq I18n.t('kba_security.success')
      expect(response).to redirect_to(root_url)
    end
  end
end
