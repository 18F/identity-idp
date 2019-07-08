require 'rails_helper'

describe RecurringJob::SendAccountResetNotificationsController do
  describe '#create' do
    context 'with a good auth token' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = Figaro.env.account_reset_auth_token
      end

      # controller is disabled
      it 'grants account reset requests and sends emails', skip: true do
        service = instance_double(AccountReset::GrantRequestsAndSendEmails)
        allow(AccountReset::GrantRequestsAndSendEmails).to receive(:new).and_return(service)
        allow(service).to receive(:call).and_return(7)

        post :create
      end

      it 'returns 410 Gone to indicate the endpoint is deprecated' do
        post :create
        expect(response).to have_http_status(:gone)
      end
    end
  end
end
