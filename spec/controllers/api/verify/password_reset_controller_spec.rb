require 'rails_helper'

describe Api::Verify::PasswordResetController do
  let(:request_id) { 'request_id' }
  let(:user) { create(:user) }
  let(:sp_session) { { request_id: request_id } }

  before do
    allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return(['password_confirm'])
    allow(controller).to receive(:sp_session).and_return(sp_session)
    stub_sign_in(user)
  end

  it 'extends behavior of base api class' do
    expect(subject).to be_kind_of Api::Verify::BaseController
  end

  describe '#create' do
    it 'returns redirect url' do
      post :create

      parsed_body = JSON.parse(response.body)

      expect(parsed_body['redirect_url']).to eq forgot_password_url(request_id: request_id)
      expect(response.status).to eq 202
    end

    it 'sets the user email into session in preparation for redirect' do
      post :create

      expect(session[:email]).to eq user.email
    end

    context 'with absent request id' do
      let(:request_id) { nil }

      it 'returns redirect url' do
        post :create

        parsed_body = JSON.parse(response.body)

        expect(parsed_body['redirect_url']).to eq forgot_password_url
        expect(response.status).to eq 202
      end
    end
  end
end
