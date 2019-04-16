require 'rails_helper'

describe RecurringJob::SendAccountResetNotificationsController do
  describe '#create' do
    it_behaves_like 'a recurring job controller', Figaro.env.account_reset_auth_token

    context 'with a good auth token' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = Figaro.env.account_reset_auth_token
      end

      it 'grants account reset requests and sends emails' do
        service = instance_double(AccountReset::GrantRequestsAndSendEmails)
        allow(AccountReset::GrantRequestsAndSendEmails).to receive(:new).and_return(service)
        allow(service).to receive(:call).and_return(7)

        stub_analytics
        expect(@analytics).to receive(:track_event).
          with(Analytics::ACCOUNT_RESET, event: :notifications, count: 7)

        post :create
      end
    end
  end
end
