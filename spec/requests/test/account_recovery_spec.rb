require 'rails_helper'

RSpec.describe 'Test::AccountRecovery', type: :request do
  let(:user) { create(:user, :fully_registered) }

  before do
    allow(IdentityConfig.store).to receive(:enable_test_routes).and_return(true)
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
  end

  describe 'GET /test/account_recovery' do
    it 'lists recovery requests with their state' do
      create(:account_recovery_request, :waiting, user: user)

      get test_account_recovery_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(AccountRecoveryRequest::WAITING)
    end

    it 'renders with no requests' do
      get test_account_recovery_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No account recovery requests yet.')
    end
  end

  describe 'POST /test/account_recovery/:id/grant' do
    let!(:recovery_request) { create(:account_recovery_request, :waiting, user: user) }

    it 'grants the request immediately, bypassing the waiting period' do
      post test_account_recovery_grant_path(id: recovery_request.id)

      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
      expect(response).to redirect_to(test_account_recovery_url)
    end

    it 'surfaces the recovery link' do
      post test_account_recovery_grant_path(id: recovery_request.id)
      follow_redirect!

      expect(response.body).to include('/account_recovery/verify')
    end

    it 'produces a recovery link that validates' do
      post test_account_recovery_grant_path(id: recovery_request.id)

      token = flash[:granted_links]['verify'][/token=([^&]+)/, 1]
      result = AccountRecovery::ValidateGrantedToken.new(token: token).call

      expect(result).to be_success
    end

    it 'renders a 404 for an unknown request' do
      post test_account_recovery_grant_path(id: 0)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /test/account_recovery/:id/cancel' do
    it 'cancels the request' do
      recovery_request = create(:account_recovery_request, :granted, user: user)

      post test_account_recovery_cancel_path(id: recovery_request.id)

      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
    end
  end

  describe 'POST /test/account_recovery/:id/expire' do
    it 'expires the request' do
      recovery_request = create(:account_recovery_request, :granted, user: user)

      post test_account_recovery_expire_path(id: recovery_request.id)

      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::EXPIRED)
    end
  end

  describe 'DELETE /test/account_recovery/:id' do
    it 'deletes the request so the flow can be re-run' do
      recovery_request = create(:account_recovery_request, :granted, user: user)

      delete test_account_recovery_destroy_path(id: recovery_request.id)

      expect(AccountRecoveryRequest.find_by(id: recovery_request.id)).to be_nil
    end
  end

  context 'when test routes are disabled' do
    before do
      allow(IdentityConfig.store).to receive(:enable_test_routes).and_return(false)
      Rails.application.reload_routes!
    end

    after do
      allow(IdentityConfig.store).to receive(:enable_test_routes).and_return(true)
      Rails.application.reload_routes!
    end

    it 'does not route' do
      get '/test/account_recovery'

      expect(response).to have_http_status(:not_found)
    end
  end
end
